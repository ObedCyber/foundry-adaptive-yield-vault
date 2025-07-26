// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseStrategy} from "./BaseStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Mockstrategy is BaseStrategy, ERC20 {

    using SafeERC20 for IERC20;

    string public vaultName;
    uint256 immutable APY;
    uint256 constant APY_PRECISION = 1e18;
    address vault;
    address underlying;
    uint256 vaultBalance;
    uint256 lastDepositTimestamp;
    uint256 constant interestPeriod = 60 seconds;
    uint256 withdrawalPeriod = 21 days;
    

    error InvalidAmount();
    error NotVault();
    error InsufficientAllowance();
    error InvalidWithdrawalPeriod();

    event WithdrawSuccessful(address indexed vault, uint256 indexed amount);
    event DepositSuccessful(address indexed vault, uint256 indexed amount);

    constructor(string memory _vaultName, uint256 _APY, address _vault, address _underlying)
    BaseStrategy(_vault)
    ERC20("MockShares","MCK") {
        vaultName = _vaultName;
        APY = _APY;
        vault = _vault;
        underlying = _underlying;
    }

    /// @dev Restricts access to only the vault
    modifier onlyVault() {
        if (msg.sender != i_vault) revert NotVault();
        _;
    } 

    function deposit(uint256 assets) external override onlyVault returns (uint256) {
        if (assets == 0) revert InvalidAmount();

        if (IERC20(underlying).allowance(msg.sender, address(this)) < assets) {
            revert InsufficientAllowance();
        }

        vaultBalance += assets;
        lastDepositTimestamp = block.timestamp;

        IERC20(underlying).safeTransferFrom(vault, address(this), assets);
 
        _mint(msg.sender, assets); // naive 1:1, replace with share calc later
        emit DepositSuccessful(vault, assets);
        return assets;
    }

    function withdraw(uint256 assets) external override returns (uint256) {
    if (assets == 0) revert InvalidAmount();
    if (block.timestamp - lastDepositTimestamp <= withdrawalPeriod) revert InvalidWithdrawalPeriod();

    uint256 amountToWithdraw = assets;

    // Handle full withdrawal
    if (assets == type(uint256).max) {
        amountToWithdraw = IERC20(underlying).balanceOf(vault);
        vaultBalance = 0;
        lastDepositTimestamp = 0;
    } else {
        vaultBalance -= amountToWithdraw;
    }

    _burn(vault, amountToWithdraw);
    IERC20(underlying).safeTransfer(vault, amountToWithdraw);
    emit WithdrawSuccessful(vault, amountToWithdraw);

    return amountToWithdraw;
}


    function estimateAPY() external view override returns (uint256) {
        return APY;
    }

    function strategyName() external view override returns (string memory) {
        return vaultName;
    }

}