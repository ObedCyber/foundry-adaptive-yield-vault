// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseStrategy} from "./BaseStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Mockstrategy is BaseStrategy, ERC20, ReentrancyGuard {

    using SafeERC20 for IERC20;

    string public StrategyName;
    uint256 public APY;
    uint256 constant APY_PRECISION = 100e18;
    address immutable i_manager;
    address immutable underlying;
    uint256 managerBalance;
    uint256 lastDepositTimestamp;
    uint256 lastAccruedInterestTimestamp;
    uint256 constant interestPeriod = 1 days;
    uint256 withdrawalPeriod = 21 days;
    

    error InvalidAmount();
    error NonZeroAddress();
    error NotManager();
    error InsufficientAllowance();
    error InvalidWithdrawalPeriod();
    error InsufficientBalance();
    error NotStrategy();

    event WithdrawSuccessful(address indexed manager, uint256 amount, uint256 indexed timestamp);
    event DepositSuccessful(address indexed manager, uint256  amount, uint256 indexed timestamp);
    event EmergencyWithdrawSuccessful(address indexed manager, uint256  amount, uint256 indexed timestamp);

    constructor(
        string memory _strategyName, 
        uint256 _APY, 
        address strategyManager, 
        address _underlying)
    ERC20("MockShares","MCK") {
        if(_underlying == address(0)) revert NonZeroAddress();
        StrategyName = _strategyName;
        APY = _APY;
        i_manager = strategyManager;
        underlying = _underlying;
    }

    /// @dev Restricts access to only the manager
    modifier onlyManager() {    
        if (msg.sender != i_manager) revert NotManager();
        _;
    } 

    function deposit(uint256 assets) nonReentrant external override onlyManager returns (uint256) {
        if (assets == 0) revert InvalidAmount();

        if (IERC20(underlying).allowance(msg.sender, address(this)) < assets) {
            revert InsufficientAllowance();
        }

        managerBalance += assets;
        lastDepositTimestamp = block.timestamp;

        IERC20(underlying).safeTransferFrom(i_manager, address(this), assets);
 
        _mint(msg.sender, assets); // naive 1:1, replace with share calc later
        emit DepositSuccessful(i_manager, assets, block.timestamp);
        return assets;
    }

    function withdraw(uint256 assets) nonReentrant external override onlyManager returns (uint256) {
    accrueInterest();
    if (assets == 0) revert InvalidAmount();
    if (block.timestamp - lastDepositTimestamp <= withdrawalPeriod) revert InvalidWithdrawalPeriod();

    uint256 amountToWithdraw = assets;

    // Handle full withdrawal
    if (assets == type(uint256).max) {
        amountToWithdraw = managerBalance;
        managerBalance = 0;
        lastDepositTimestamp = 0;
    } else {
        managerBalance -= amountToWithdraw;
    }

    _burn(i_manager, amountToWithdraw);
    IERC20(underlying).safeTransfer(i_manager, amountToWithdraw);
    emit WithdrawSuccessful(i_manager, amountToWithdraw, block.timestamp);

    return amountToWithdraw;
    }

    function emergencyWithdraw() nonReentrant external override  onlyManager returns (uint256) {
        accrueInterest();
        // uint256 balance = IERC20(underlying).balanceOf(vault);
        if (managerBalance == 0) revert InsufficientBalance();

        _burn(i_manager, balanceOf(i_manager)); // burn all vault's shares

        uint256 amountToWithdraw = managerBalance;
        // reset state
        managerBalance = 0;
        lastDepositTimestamp = 0;

        IERC20(underlying).safeTransfer(i_manager, amountToWithdraw);
        emit EmergencyWithdrawSuccessful(i_manager, amountToWithdraw, block.timestamp);

        return amountToWithdraw;
    }

    // interest only accumulates after every 60 seconds
    // this is very buggy, in a real strategy It would implement the APY's from AAVE and compound.
    function accrueInterest() internal {
        uint256 period =  block.timestamp - lastAccruedInterestTimestamp ;
        if(block.timestamp - lastAccruedInterestTimestamp < interestPeriod)
        {
            return;
        }
            // (1e18 * 2000 * 1e18) / 100e18 = 20e18
        // how much he earns in a year
        uint256 yearlyInterest = (managerBalance * 1e18 * APY ) / APY_PRECISION; 
        uint256 interestEarned = (yearlyInterest * period) / 365 days; // 20e18 * 365 / 365 = 20e18
        managerBalance += interestEarned;
        lastAccruedInterestTimestamp = block.timestamp;
    }   

    // this function is just for testing purposes
    function changeAPY(uint256 newAPY) external  {
        if(msg.sender != address(this)){
            revert NotStrategy();
        }
        if (newAPY == 0) revert InvalidAmount();
        APY = newAPY;
    }


    function strategyName() external view override returns (string memory) {
        return StrategyName;
    }

    function estimateAPY() external view override returns (uint256) {
        return APY;
    }

    function getVaultBalance() external override returns (uint256){
        accrueInterest();
        return managerBalance;
    }
}