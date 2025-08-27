// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseStrategy} from "./BaseStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {StrategyErrors} from "./errors/StrategyErrors.sol";

/**
 * @title Mockstrategy
 * @author Obed Okoh
 * @notice A mock implementation of an investment strategy for testing purposes.
 * It simulates deposits, withdrawals, and interest accrual based on a predefined APY.
 */
contract Mockstrategy is BaseStrategy, ERC20, StrategyErrors, ReentrancyGuard {
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

    event WithdrawSuccessful(
        address indexed manager,
        uint256 amount,
        uint256 indexed timestamp
    );
    event DepositSuccessful(
        address indexed manager,
        uint256 amount,
        uint256 indexed timestamp
    );
    event EmergencyWithdrawSuccessful(
        address indexed manager,
        uint256 amount,
        uint256 indexed timestamp
    );

    constructor(
        string memory _strategyName,
        uint256 _APY,
        address strategyManager,
        address _underlying
    ) ERC20("MockShares", "MCK") {
        if (_underlying == address(0)) revert MockStrategy__NonZeroAddress();

        StrategyName = _strategyName;
        APY = _APY;
        i_manager = strategyManager;
        underlying = _underlying;
    }

    /// @dev Restricts access to only the manager
    modifier onlyManager() {
        if (msg.sender != i_manager) revert MockStrategy__NotManager();
        _;
    }

    /**
     * @dev Deposits a specified amount of the underlying asset into the strategy.
     * Mints shares to the manager based on the deposited amount.
     * @param assets The amount of the underlying asset to deposit.
     * @return uint256 The number of shares minted to the manager.
     */
    function deposit(
        uint256 assets
    ) external override nonReentrant onlyManager returns (uint256) {
        if (assets == 0) revert MockStrategy__InvalidAmount();

        if (IERC20(underlying).allowance(msg.sender, address(this)) < assets) {
            revert MockStrategy__InsufficientAllowance();
        }

        managerBalance += assets;
        lastDepositTimestamp = block.timestamp;

        IERC20(underlying).safeTransferFrom(i_manager, address(this), assets);

        _mint(msg.sender, assets); // naive 1:1, replace with share calc later
        emit DepositSuccessful(i_manager, assets, block.timestamp);
        return assets;
    }

    /**
     * @dev Withdraws a specified amount of the underlying asset from the strategy.
     * Burns shares from the manager based on the withdrawn amount.
     * Accrues interest before processing the withdrawal.
     * @param assets The amount of the underlying asset to withdraw.
     * @return uint256 The actual amount of the underlying asset withdrawn.
     */
    function withdraw(
        uint256 assets
    ) external override nonReentrant onlyManager returns (uint256) {
if (assets == 0) revert MockStrategy__InvalidAmount();
        if (block.timestamp - lastDepositTimestamp <= withdrawalPeriod)
            revert MockStrategy__InvalidWithdrawalPeriod();

        accrueInterest();

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

    /**
     * @dev Performs an emergency withdrawal of all assets from the strategy.
     * Burns all shares held by the manager and transfers the entire balance of the underlying asset back to the manager.
     * Accrues interest before processing the emergency withdrawal.
     * @return uint256 The total amount of the underlying asset withdrawn.
     */
    function emergencyWithdraw()
        external
        override
        nonReentrant
        onlyManager
        returns (uint256)
    {
        if (managerBalance == 0) revert MockStrategy__InsufficientBalance();
        accrueInterest();

        _burn(i_manager, balanceOf(i_manager)); // burn all vault's shares

        uint256 amountToWithdraw = managerBalance;
        // reset state
        managerBalance = 0;
        lastDepositTimestamp = 0;

        IERC20(underlying).safeTransfer(i_manager, amountToWithdraw);
        emit EmergencyWithdrawSuccessful(
            i_manager,
            amountToWithdraw,
            block.timestamp
        );

        return amountToWithdraw;
    }

    /**
     * @dev Accrues interest on the manager's balance based on the defined APY.
     * @notice This function is called internally before withdrawals to ensure the balance reflects earned interest.
     */
    function accrueInterest() internal {
        uint256 period = block.timestamp - lastAccruedInterestTimestamp;
        if (block.timestamp - lastAccruedInterestTimestamp < interestPeriod) {
            return;
        }

        uint256 yearlyInterest = (managerBalance * 1e18 * APY) / APY_PRECISION;
        uint256 interestEarned = (yearlyInterest * period) / 365 days;
        managerBalance += interestEarned;
        lastAccruedInterestTimestamp = block.timestamp;
    }

    // this function is just for testing purposes
    function changeAPY(uint256 newAPY) external {
        if (msg.sender != address(this)) {
            revert MockStrategy__NotStrategy();
        }
        if (newAPY == 0) revert MockStrategy__InvalidAmount();
        APY = newAPY;
    }

    /** @dev Returns the name of the strategy.
     */
    function strategyName() external view override returns (string memory) {
        return StrategyName;
    }

    /** @dev Estimates the annual percentage yield (APY) of the strategy.
     * @return uint256 The estimated APY of the strategy.
     */
    function estimateAPY() external view override returns (uint256) {
        return APY;
    }

    function getVaultBalance() external override returns (uint256) {
        if (managerBalance == 0) {
            return 0;
        }
        accrueInterest();
        return managerBalance;
    }
}
