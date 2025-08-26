// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategyManager {
    function getTotalBalanceAcrossStrategies() external view returns (uint256);
    function getActiveStrategy() external view returns (uint256);
    function getMinimumDeposit() external view returns (uint256);
    function getUserDeposit(address user) external view returns (uint256);
    function withdrawToVault(uint256 amount) external returns (uint256);
    function Rebalance() external;
    function getBestAPYStrategy() external view returns(uint256);
    function getStrategyAddress(uint256 index) external view returns(address);
    function getCurrentStrategyAddress() external view returns(address);
    function getCurrentStrategyIndex() external view returns(uint256);
    function getStrategyAPY(uint256) external view returns(uint256);
}