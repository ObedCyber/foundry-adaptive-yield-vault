// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Common errors for strategy contracts

abstract contract BaseStrategy {
    /// @notice Vault that controls this strategy

    /// @notice Deposit assets into the strategy
    function deposit(uint256 assets) external virtual returns(uint256 sharesMinted);

    /// @notice Withdraw assets from the strategy
    function withdraw(uint256 assets) external virtual returns(uint256 sharesBurned);

    /// @notice Emergency withdraw all funds back to the vault
    function emergencyWithdraw() external virtual returns (uint256);

    /// @notice Returns the balance of underlying in the strategy 
    function getVaultBalance() external virtual returns (uint256);

    /// @notice Estimate the current APY of the strategy
    function estimateAPY() external view virtual returns (uint256);

    /// @notice Returns the strategy name
    function strategyName() external view virtual returns (string memory);
}
