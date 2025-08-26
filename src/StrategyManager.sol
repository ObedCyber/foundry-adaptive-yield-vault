// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {StrategyErrors} from "./errors/StrategyErrors.sol";

/**
 * @title StrategyManager
 * @author Obed Okoh
 * @notice This contract manages multiple investment strategies, allowing for the allocation and reallocation of funds based on strategy performance.
 * It interacts with a vault to receive and withdraw funds, and it can activate or deactivate strategies as needed.
 */

contract StrategyManager is Ownable, StrategyErrors{
    using SafeERC20 for IERC20;

    address immutable i_vault;
    address public roboKeeper;
    uint256 minimumAPY;
    uint256 public lastRebalanceTimestamp; // timestamp of the last rebalance
    StrategyData[] strategies;
    IERC20 public underlying;
    uint256 public currentStrategyIndex;
    uint256 public totalBalanceAcrossStrategies;

    mapping (uint256  => address ) strategy;
    

    event StrategyAdded(address indexed strategyAddress);
    event StrategyActivated(address indexed strategyAddress);
    event StrategyDeactivated(address indexed strategyAddress);
    event Allocationsuccessful(address indexed strategyAddress, uint256 amount);
    event WithdrawalSuccessful(address indexed strategyAddress, uint256 amount);
    event RebalanceSuccessful(address indexed strategyAddress, uint256 amount);
    event WithdrawalToVaultSuccessful(address indexed strategyWithdrawnFrom, uint256 amount);

    struct StrategyData {
        string strategyName;
        address strategyAddress;
        uint256 lastRecordedAPY;
        bool active;
    }

    // @dev Initializes the StrategyManager with the vault address, owner, minimum APY, and underlying token address.
    /// @param vault The address of the vault that this strategy manager will interact with.
    /// @param owner The address of the owner of this strategy manager.
    /// @param minAPY The minimum acceptable annual percentage yield (APY) for strategies.
    /// @param _underlying The address of the underlying token that strategies will use.
    constructor(
        address vault, 
        address owner, 
        uint256 minAPY, 
        address _underlying) Ownable(owner){
        if(vault == address(0) || owner == address(0) || minAPY == 0 || _underlying == address(0)) revert StrategyManager__InvalidConstructorParameters();
        i_vault = vault;
        minimumAPY = minAPY;
        underlying = IERC20(_underlying);
    }

    /// @dev Restricts access to only the vault
    modifier onlyVault() {
        if (msg.sender != i_vault) revert StrategyManager__NotVault();
        _;
    }

            //////////////////////////////////////////////////////////
            ////////////////// ONLY OWNER FUNCTIONS //////////////////
            //////////////////////////////////////////////////////////

    /**
     * @dev Updates the minimum APY required for strategies.
     * @param newMinAPY The new minimum APY to be set.
     */
    function updateMinimumAPY(uint256 newMinAPY) public onlyOwner {
        minimumAPY = newMinAPY;
    }

    /**
     * @dev Sets the roboKeeper address.
     * @param _roboKeeper The address of the new roboKeeper.
     */
    function setRoboKeeper(address _roboKeeper) public onlyOwner{

        if(roboKeeper != address(0) || _roboKeeper == address(0)){
            revert StrategyManager__CannotSetRoboKeeper();
        }
        roboKeeper = _roboKeeper;
    }

    // @dev Adds a new strategy to the manager.
    /// @param _strategyAddress The address of the strategy to be added.
    /// @notice This function can only be called by the owner of the contract.
    /// @dev It checks that the strategy address is not zero, retrieves the strategy name and initial APY, and adds the strategy to the list of strategies.
    function addStrategy(address _strategyAddress) public onlyOwner{
        if(_strategyAddress == address(0)){ revert StrategyManager__NonZeroAddress(); }
        string memory name = IStrategy(_strategyAddress).strategyName();
        uint256 initialAPY = IStrategy(_strategyAddress).estimateAPY();

        strategies.push(StrategyData({
            strategyName: name,
            strategyAddress: _strategyAddress,
            lastRecordedAPY: initialAPY,
            active: false
        }));

        emit StrategyAdded(_strategyAddress);
    }

    // @dev Activates a strategy at the specified index.
    /// @param index The index of the strategy to be activated.
    /// @notice This function can only be called by the owner of the contract.
    /// @dev It checks that the index is valid, retrieves the strategy data, and activates the strategy if it is not already active. It also updates the strategy mapping and emits an event.
    function activateStrategy(uint256 index) public onlyOwner{
        uint256 len = strategies.length;
        if (index >= len){ revert StrategyManager__InvalidIndex(); }
        StrategyData storage strategyData = strategies[index];
        if (strategyData.active){ revert StrategyManager__StrategyAlreadyActive();} 

        strategyData.active = true;
        emit StrategyActivated(strategyData.strategyAddress);
    }

    // @dev Deactivates a strategy at the specified index.
    /// @param index The index of the strategy to be deactivated.
    /// @notice This function can only be called by the owner of the contract.
    /// @dev It checks that the index is valid, retrieves the strategy data, and deactivates the strategy if it is not already active. It also checks that the strategy has no funds
    function deactivateStrategy(uint256 index) public onlyOwner{
        uint256 len = strategies.length;
        if (index >= len){ revert StrategyManager__InvalidIndex(); }
        
        StrategyData storage strategyData = strategies[index];
        if(IStrategy(strategyData.strategyAddress).getVaultBalance() > 0){
            revert StrategyManager__CannotDeactivateStrategyWithFunds();
        }

        strategyData.active = false;
        emit StrategyDeactivated(strategyData.strategyAddress);
    }

            //////////////////////////////////////////////////////////
            ////////////////// CORE FUNCTIONS ///////////////////////
            //////////////////////////////////////////////////////////

    // @dev Refreshes the APYs of all strategies.
    /// @notice This function can be called by anyone to update the APY estimates for all strategies.
    /// @dev It iterates through all strategies, calls the estimateAPY function on each strategy, and updates the lastRecordedAPY field.
    function refreshAPYs() public  {
        uint256 len = strategies.length;
        for (uint256 i = 0; i < len; i++) {
            StrategyData storage strategyData = strategies[i];
            strategyData.lastRecordedAPY = IStrategy(strategyData.strategyAddress).estimateAPY();
        }
    }


    // @dev Allocates funds to a strategy at the specified index.
    // @notice this is the only function that updates the currentStrategyIndex.
    /// @param amount The amount of funds to allocate to the strategy.
    /// @param index The index of the strategy to allocate funds to.
    /// @notice This function can only be called by the vault.
    /// @dev It checks that the amount is non-zero, retrieves the strategy data, checks that the strategy is active, and then deposits the funds into the strategy. It also checks that the transaction was successful and emits an event.
    /// @notice It also checks that the underlying token balance is sufficient before proceeding with the allocation.
    /// @notice It updates the strategy balance mapping to track
    function allocate(uint256 amount, uint256 index) internal {
        if (amount == 0) revert StrategyManager__InvalidAmount();
        if (underlying.balanceOf(address(this)) < amount) revert StrategyManager__InsufficientBalance();

        StrategyData storage strategyData = strategies[index];
        if (!strategyData.active) revert StrategyManager__InactiveStrategy();

        address strategyAddr = strategyData.strategyAddress;
        currentStrategyIndex = index;
        
        IStrategy(strategyAddr).deposit(amount);
   
        emit Allocationsuccessful(strategyAddr, amount);
    }

    function withdraw(uint256 amount, uint256 index) internal {
        address strategyAddr = getStrategyAddress(index);
        // revert if amount is more than balance in strategy
        if(amount > IStrategy(strategyAddr).getVaultBalance()){
            revert StrategyManager__InsufficientBalanceInStrategy();
        }

        IStrategy(strategyAddr).withdraw(amount);
        underlying.transfer(i_vault, amount); // transfer the withdrawn amount to the vault
        emit WithdrawalSuccessful(strategyAddr, amount);
    }

    

    // @dev Rebalances the strategies based on their APYs.
    // We are assuming only one strategy can hold the underlying tokens.
    // withdrawals and deposits can only happen from one strategy and not between strategies
    // in the future, I will implement rebalancing between strategies. I'm just trying to keep thing simple for now.

    function Rebalance() external {
        if(msg.sender != roboKeeper) revert StrategyManager__NotRoboKeeper();
         
        refreshAPYs();

        uint256 bestStrategyIndex = getBestAPYStrategy();
        address bestStrategyAddr = getStrategyAddress(bestStrategyIndex);
        
        // If no funds are allocated anywhere, just deposit directly
        if (getTotalBalanceAcrossStrategies() == 0) {
            allocate(underlying.balanceOf(address(this)), bestStrategyIndex);
            return;
        }

        // Withdraw from current strategy & allocate to best one
        withdraw(underlying.balanceOf(address(this)), currentStrategyIndex);
        allocate(underlying.balanceOf(address(this)), bestStrategyIndex);

        emit RebalanceSuccessful(bestStrategyAddr, underlying.balanceOf(address(this)));
    }

            //////////////////////////////////////////////////////////
            ////////////////// PUBLIC VIEW FUNCTIONS /////////////////
            //////////////////////////////////////////////////////////


    // @dev Return the best APY strategy.
    /// @return The address of the strategy with the highest APY.
    function getBestAPYStrategy() public view returns (uint256) {
        uint256 highestAPY = 0;
        address bestStrategy = address(0);
        uint256 strategyIndex = 0;
        uint256 len = strategies.length;
        for (uint256 i = 0; i < len; i++) {
            StrategyData storage strategyData = strategies[i];
            // strategy must be active
            // strategy last recorderd APY must be greater than the current highest APY
            // strategy last recorded APY must be greater than or equal to the minimum APY
            // if all conditions are met, update the highest APY and best strategy
            if (strategyData.active && strategyData.lastRecordedAPY > highestAPY && strategyData.lastRecordedAPY >= minimumAPY) {
                highestAPY = strategyData.lastRecordedAPY;
                bestStrategy = strategyData.strategyAddress;
                strategyIndex = i;
            }
    }
        if (bestStrategy == address(0)) {
            revert StrategyManager__NoBestStrategy();
        }
        return strategyIndex;
    }

    function getTotalBalanceAcrossStrategies() public view returns (uint256) {
        uint256 totalBalance = 0;
        uint256 len = strategies.length;
        for (uint256 i = 0; i < len; i++) {
            StrategyData storage strategyData = strategies[i];
            if (strategyData.active) {
                totalBalance += IStrategy(strategyData.strategyAddress).getVaultBalance();
            }
        }
        return totalBalance;
    }
            //////////////////////////////////////////////////////////
            ////////////////// ONLY VAULT FUNCTIONS //////////////////
            //////////////////////////////////////////////////////////

    /**
     * @dev Withdraws a specified amount from the current strategy to the vault.
     * @param amount The amount to withdraw to the vault.
     */
    function withdrawToVault(uint256 amount) external onlyVault {
        refreshAPYs();
        // flow goes from strategy -> manager -> vault
        if (amount == 0) revert StrategyManager__InvalidAmount();
        address strategyAddr = getStrategyAddress(currentStrategyIndex);
        if(IStrategy(strategyAddr).getVaultBalance() != 0){
            IStrategy(strategyAddr).withdraw(amount);
        }
        underlying.safeTransfer(i_vault, amount); 
        emit WithdrawalToVaultSuccessful(strategyAddr, amount);
    }

           

            //////////////////////////////////////////////////////////
            ////////////////// GETTER FUNCTIONS //////////////////////
            //////////////////////////////////////////////////////////
   
   /**
    * @dev Returns the address of the strategy at the specified index.
    * @param index The index of the strategy in the strategies array.
    * @return The address of the strategy.
    */
    function getStrategyAddress(uint256 index) public view returns (address) {
        if (index >= strategies.length) {
            revert StrategyManager__InvalidIndex();
        }
        return strategies[index].strategyAddress;
    }

    /**
     * @dev Returns the address of the current strategy.
     * @return currentStrategyAddress The address of the current strategy.
     */
    function getCurrentStrategyAddress() public view returns (address currentStrategyAddress) {
        currentStrategyAddress = getStrategyAddress(currentStrategyIndex);
    }

    /**
     * @dev Returns the index of the current strategy.
     * @return The index of the current strategy.
     */
    function getCurrentStrategyIndex() public view returns(uint256){
        return currentStrategyIndex;
    }

    /**
     * @dev Returns the minimum APY required for strategies.
     * @return The minimum APY.
     */
    function getMinimumAPY() public view returns (uint256) {
        return minimumAPY;
    }

    /**
     * @dev Returns the address of the keeper.
     * @return The address of the keeper.
     */
    function getRoboKeeper() public view returns (address) {
        return roboKeeper;
    }


    /**
     * @dev Returns the APY of the strategy at the specified index.
     * @param index The index of the strategy in the strategies array.
     * @return The APY of the strategy.
     */
    function getStrategyAPY(uint256 index) public view returns (uint256) {
        if (index >= strategies.length) {
            revert StrategyManager__InvalidIndex();
        }
        return strategies[index].lastRecordedAPY;
    }

    /**
     * @dev Checks if the strategy at the specified index is active.
     * @param index The index of the strategy in the strategies array.
     * @return True if the strategy is active, false otherwise.
     */
    function checkIfStrategyIsActive(uint256 index) public view returns (bool) {
        if (index >= strategies.length) {
            revert StrategyManager__InvalidIndex();
        }
        return strategies[index].active;
    }
}