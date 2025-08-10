// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategy {
    function deposit(uint256 amount) external returns(uint256);
    function withdraw(uint256 amount) external returns(uint256);
    function strategyName() external view returns (string memory);
    function estimateAPY() external view returns(uint256);
    function getVaultBalance() external view returns(uint256);
}