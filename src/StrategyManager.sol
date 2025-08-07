// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IStrategy {
    function deposit(uint256 amount) external returns(uint256);
    function withdraw(uint256 amount) external returns(uint256);
    function strategyName() external returns (string memory);
    function estimateAPY() external returns(uint256);
    function getVaultBalance() external returns(uint256);
}

/**
 * A Strategy Manager contract acts as the controller or router between your vault and strategies. Its purpose is to coordinate how funds are allocated between different strategies, enforce constraints, and manage strategy lifecycle.
 * 
 * minimum APY enforced on all strategies, makes sure no assets in deposited in a strategy blow a certain APY.
 * It can select between multiple strategies and picks the one with the best APY.
 * It can decide to withdraw from the strategy just to secure profits
 * It can deactivate and activate any strategy
 * 
 * if vault wants to make deposit, it calls strategy manager first to check for the best APY's on different strategies and vault's makes the deposit.
 * Also the RoboKeeper will check from time to time that the vault's deposits are in the best APY and if not it will call the withdraw function and check for the next highest strategy and make the deposit there.
 * 
 * 
 */

contract StrategyManager is Ownable{
    address immutable i_vault;
    uint256 minimumAPY;
    StrategyData[] strategies;
    IERC20 public underlying;
    uint256 public currentStrategyIndex;
    uint256 public totalBalanceAcrossStrategies;
    mapping (uint256  => address ) strategy;
    mapping (address  => uint256 ) strategyBalance;
    

    error StrategyManager__NotVault();
    error StrategyManager__NonZeroAddress();
    error StrategyManager__InvalidIndex();
    error StrategyManager__StrategyAlreadyActive();
    error StrategyManager__CannotDeactivateStrategyWithFunds();
    error StrategyManager__InsufficientBalance();
    error StrategyManager__InsufficientAllowance();
    error StrategyManager__InvalidAmount();
    error StrategyManager__InactiveStrategy();
    error StrategyManager__TransactionFailed();
    error StrategyManager__InsufficientBalanceInStrategy();
    error StrategyManager__NoBestStrategy();
    error StrategyManager__CurrentStrategyIsBestStrategy();


    event StrategyAdded(address indexed strategyAddress);
    event StrategyActivated(address indexed strategyAddress);
    event StrategyDeactivated(address indexed strategyAddress);
    event Allocationsuccessful(address indexed strategyAddress, uint256 amount);
    event WithdrawalSuccessful(address indexed strategyAddress, uint256 amount);

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
        i_vault = vault;
        minimumAPY = minAPY;
        underlying = IERC20(_underlying);
    }

    /// @dev Restricts access to only the vault
    modifier onlyVault() {
        if (msg.sender != i_vault) revert StrategyManager__NotVault();
        _;
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
        if (index >= len - 1){ revert StrategyManager__InvalidIndex(); }
        StrategyData storage strategyData = strategies[index];
        if (strategyData.active){ revert StrategyManager__StrategyAlreadyActive();} 

        strategy[index] = strategyData.strategyAddress;

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

        delete strategy[index];

        strategyData.active = false;
        emit StrategyDeactivated(strategyData.strategyAddress);
    }

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

    function updateMinimumAPY(uint256 newMinAPY) public onlyOwner {
        minimumAPY = newMinAPY;
    }
    // @dev Allocates funds to a strategy at the specified index.
    /// @param amount The amount of funds to allocate to the strategy.
    /// @param index The index of the strategy to allocate funds to.
    /// @notice This function can only be called by the vault.
    /// @dev It checks that the amount is non-zero, retrieves the strategy data, checks that the strategy is active, and then deposits the funds into the strategy. It also checks that the transaction was successful and emits an event.
    /// @notice It also checks that the underlying token balance is sufficient before proceeding with the allocation.
    /// @notice It updates the strategy balance mapping to track
    function allocate(uint256 amount, uint256 index) internal {
        if (amount == 0) revert StrategyManager__InvalidAmount();
        if (underlying.balanceOf(address(this)) == 0) revert StrategyManager__InsufficientBalance();

        StrategyData storage strategyData = strategies[index];
        if (!strategyData.active) revert StrategyManager__InactiveStrategy();

        address strategyAddr = strategyData.strategyAddress;
        strategyBalance[strategyAddr] += amount;
        currentStrategyIndex = index;
        
        uint256 balanceBefore = IStrategy(strategyAddr).getVaultBalance();
        IStrategy(strategyAddr).deposit(amount);
        uint256 balanceAfter = IStrategy(strategyAddr).getVaultBalance();

        if (balanceAfter != balanceBefore + amount) {
            revert StrategyManager__TransactionFailed();
        }

        emit Allocationsuccessful(strategyAddr, amount);
    }

    function withdraw(uint256 amount, uint256 index) internal {
        // revert for invalid amount
        if(amount == 0){ revert StrategyManager__InvalidAmount();}
        address strategyAddr = strategy[index];
        // revert if amount is more than balance in strategy
        if(amount > IStrategy(strategyAddr).getVaultBalance()){
            revert StrategyManager__InsufficientBalanceInStrategy();
        }
        // to track the amount deposited to each strategy
        strategyBalance[strategyAddr] -= amount;
        IStrategy(strategyAddr).withdraw(amount);

        emit WithdrawalSuccessful(strategyAddr, amount);
    }

    // @dev Rebalances the strategies based on their APYs.
    // We are assuming only one strategy can hold the underlying tokens.
    // withdrawals and deposits can only happen from one strategy and not between strategies
    // in the future, I will implement rebalancing between strategies. I'm just trying to keep thing simple for now.
    function Rebalance() external  onlyVault {
        refreshAPYs();
        uint256 bestStrategyIndex = getBestAPYStrategy();
        // if total balance across strategies is 0, then we can just allocate to the best APY strategy
        // no need to withdraw from the current strategy, because there is no money there
        // it should just allocate to the best APY strategy
        if(getTotalBalanceAcrossStrategies() == 0) {
            allocate(underlying.balanceOf(i_vault), bestStrategyIndex);
            return;
        }
        if(getTotalBalanceAcrossStrategies() != 0){
            // but if it's not the first time, we need to check if the current strategy is the best APY strategy
            if(currentStrategyIndex == bestStrategyIndex){
                revert StrategyManager__CurrentStrategyIsBestStrategy();
            }
            withdraw(underlying.balanceOf(i_vault), currentStrategyIndex);

        }

       
        // then, withdraw from the current strategy and allocate to the best APY strategy

        // refresh APYs before rebalancing

        // get the best APY strategy

        
        // check if the current strategy is the best APY strategy
 
        // if not, remove funds from the current strategy and allocate to the best APY strategy
        // if the current strategy is the best APY strategy, do nothing
        
    }

    // @dev Return the best APY strategy.
    /// @return The address of the strategy with the highest APY.
    function getBestAPYStrategy() public returns (uint256) {
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

    function getTotalBalanceAcrossStrategies() public returns (uint256) {
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
}