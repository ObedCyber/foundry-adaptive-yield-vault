// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseStrategy} from "./BaseStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Mockstrategy is BaseStrategy, ERC20, ReentrancyGuard {

    using SafeERC20 for IERC20;

    string public vaultName;
    uint256 immutable APY;
    uint256 constant APY_PRECISION = 1e18;
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

    event WithdrawSuccessful(address indexed vault, uint256 indexed amount);
    event DepositSuccessful(address indexed vault, uint256 indexed amount);
    event EmergencyWithdrawSuccessful(address indexed vault, uint256 indexed amount);

    constructor(string memory _vaultName, uint256 _APY, address _vault, address strategyManager, address _underlying)
    BaseStrategy(_vault)
    ERC20("MockShares","MCK") {
        if(_vault == address(0) || _underlying == address(0)) revert NonZeroAddress();
        vaultName = _vaultName;
        APY = _APY;
        i_vault = _vault;
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
        emit DepositSuccessful(i_manager, assets);
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
    emit WithdrawSuccessful(i_manager, amountToWithdraw);

    return amountToWithdraw;
    }

    function emergencyWithdraw() nonReentrant external override  onlyManager returns (uint256) {
        accrueInterest();
        // uint256 balance = IERC20(underlying).balanceOf(vault);
        if (managerBalance == 0) revert InsufficientBalance();

        _burn(vault, balanceOf(vault)); // burn all vault's shares

        managerBalance = 0;
        lastDepositTimestamp = 0;

        IERC20(underlying).safeTransfer(vault, managerBalance);
        emit EmergencyWithdrawSuccessful(vault, managerBalance);

        return managerBalance;
    }

    // interest only accumulates after every 60 seconds
    function accrueInterest() internal {
        if(block.timestamp - lastAccruedInterestTimestamp < interestPeriod)
        {
            return;
        }

        // how much he earns in a year
        uint256 yearlyInterest = (managerBalance * 1e18 * APY ) / APY_PRECISION; // (2 ether * 1e18 * 10e18) / 1e18 = 20 ether * 1e18
        uint256 interestEarned = (yearlyInterest * interestPeriod) / 365 ;
        managerBalance += interestEarned;
        lastAccruedInterestTimestamp = block.timestamp;
    }   


    function strategyName() external view override returns (string memory) {
        return vaultName;
    }

    function estimateAPY() external view override returns (uint256) {
        return APY;
    }

    function getVaultBalance() external override view returns (uint256){
        accrueInterest();
        return managerBalance;
    }
}