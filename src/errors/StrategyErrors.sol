// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title StrategyErrors
 * @author Obed Okoh
 * @notice This contract defines custom error types for strategy-related operations.
 */
contract StrategyErrors {
    // errors for Mock strategy
    error MockStrategy__InvalidAmount();
    error MockStrategy__NonZeroAddress();
    error MockStrategy__NotManager();
    error MockStrategy__InsufficientAllowance();
    error MockStrategy__InvalidWithdrawalPeriod();
    error MockStrategy__InsufficientBalance();
    error MockStrategy__NotStrategy();

    // errors for StrategyManager
    error StrategyManager__NotVault();
    error StrategyManager__NonZeroAddress();
    error StrategyManager__InvalidConstructorParameters();
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
    error StrategyManager__CannotSetRoboKeeper();
    error StrategyManager__NotRoboKeeper();

}