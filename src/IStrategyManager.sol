// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategyManager {
    function getTotalBalanceAcrossStrategies() external view returns (uint256);
    function getActiveStrategy() external view returns (uint256);
    function getMinimumDeposit() external view returns (uint256);
    function getUserDeposit(address user) external view returns (uint256);
    function withdrawToVault(uint256 amount) external returns (uint256);
}