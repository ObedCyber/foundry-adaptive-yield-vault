// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Errors {
    // error for zero address
    error RoboVault__ZeroAddress();

    // error for invalid amount
    error RoboVault__InvalidAmount();

    // error for deposit below required deposit
    error RoboVault__DepositTooSmall();

    // error for deposit slippage being exceded
    error RoboVault__DepositSlippageExceeded();

    // error for insufficient shares in user balance
    error RoboVault__InsufficientShares();

    // errors for withdraw slippage being excedeed
    error RoboVault__WithdrawSlippageExceeded();
    
    // error for withdrawal delay not met
    error RoboVault__WithdrawalDelayNotMet();

    // error for invalid withdrawal delay
    error RoboVault__InvalidWithdrawalDelay();

    // error for setting the manager address
    error RoboVault__ManagerAlreadyExists();
}