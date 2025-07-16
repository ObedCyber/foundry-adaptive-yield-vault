// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Errors {
    // error for zero address
    error ZeroAddress();

    // error for invalid amount
    error InvalidAmount();

    // error for deposit below required deposit
    error DepositTooSmall();

    // error for deposit slippage being exceded
    error DepositSlippageExceeded();

    // error for insufficient shares in user balance
    error InsufficientShares();

    // errors for withdraw slippage being excedeed
    error WithdrawSlippageExceeded();
}