// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Errors} from "./errors/Errors.sol";
import {IStrategyManager} from "./interfaces/IStrategyManager.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title RoboVault
 * @author Obed Okoh
 * @dev An ERC4626 compliant vault that allows users to deposit and withdraw assets,
 *      while integrating with a strategy manager for asset allocation.
 */
contract RoboVault is ERC4626, ReentrancyGuard, Errors, Ownable {
    using SafeERC20 for IERC20;

    event Deposited(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 shares, uint256 timestamp);

    IERC20 immutable underlyingAsset;
    uint256 immutable i_minimumDeposit = 1e18;
    IStrategyManager public strategyManager;
    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userLastDepositTimestamp;
    uint256 public WITHDRAWAL_DELAY;

    /**
     * @param _asset address of the underlying asset (ERC20 token)
     * @param withdrawalDelay time that a user must wait after depositing before they can withdraw
     */
    constructor(
        address _asset,
        uint256 withdrawalDelay
    ) ERC4626(IERC20(_asset)) ERC20("RoboVault", "ROBO") Ownable(msg.sender) {
        if (_asset == address(0)) revert RoboVault__ZeroAddress();
        if (withdrawalDelay == 0) revert RoboVault__InvalidWithdrawalDelay();

        underlyingAsset = IERC20(_asset);
        WITHDRAWAL_DELAY = withdrawalDelay;
    }

    /**
     * @param amount number of underlying assets to deposit
     * @param minimumOutputShares minimum number of shares the user expects to receive
     * @return uint256 actual number of shares received by the user
     */
    function depositWithSlippageCheck(
        uint256 amount,
        uint256 minimumOutputShares
    ) external nonReentrant returns (uint256) {
        if (amount == 0) revert RoboVault__InvalidAmount();
        if (amount < i_minimumDeposit) revert RoboVault__DepositTooSmall();

        userDeposits[msg.sender] += amount;
        userLastDepositTimestamp[msg.sender] = block.timestamp;
        uint256 userShares = deposit(amount, msg.sender);

        if (userShares < minimumOutputShares)
            revert RoboVault__DepositSlippageExceeded();
        emit Deposited(msg.sender, amount, block.timestamp);
        return userShares;
    }

    /**
     *
     * @param shares number of shares to withdraw
     * @param minimumOutputAssets minimum amount of underlying assets the user expects to receive
     * @return uint256 actual amount of underlying assets received by the user
     */
    function withdrawWithSlippageCheck(
        uint256 shares,
        uint256 minimumOutputAssets
    ) external nonReentrant returns (uint256) {
        address user = msg.sender;
        uint256 amountToReceive = previewWithdraw(shares);

        if (shares == 0) revert RoboVault__InvalidAmount();
        if (shares > balanceOf(user)) revert RoboVault__InsufficientShares();
        if (block.timestamp < userLastDepositTimestamp[user] + WITHDRAWAL_DELAY)
            revert RoboVault__WithdrawalDelayNotMet();

        userDeposits[user] -= amountToReceive;

        uint256 vaultLiquidity = underlyingAsset.balanceOf(address(this));

        // if not enough liquidity, pull extra cushion from strategies
        if (vaultLiquidity < amountToReceive) {
            uint256 shortfall = amountToReceive - vaultLiquidity;

            // Pull not just the shortfall, but extra cushion (e.g., 20% more)
            uint256 cushion = (shortfall * 20) / 100; // hardcoded 20% cushion
            uint256 totalToWithdraw = shortfall + cushion;

            strategyManager.withdrawToVault(totalToWithdraw);
        }

        uint256 assetsReceived = redeem(shares, user, user);
        if (assetsReceived < minimumOutputAssets)
            revert RoboVault__WithdrawSlippageExceeded();

        emit Withdrawn(user, assetsReceived, block.timestamp);
        return assetsReceived;
    }

    // @notice Returns the total assets in the vault, which includes both idle assets and those allocated to strategies.
    function totalAssets() public view override returns (uint256) {
        uint256 idleBalance = underlyingAsset.balanceOf(address(this));
        uint256 balanceAccrossStrategies = strategyManager
            .getTotalBalanceAcrossStrategies();
        return idleBalance + balanceAccrossStrategies;
    }

    // @dev function to set the strategy manager,
    // can only be set once by the owner
    function setStrategyManager(address _strategyManager) external onlyOwner {
        if (_strategyManager == address(0)) revert RoboVault__ZeroAddress();
        if (address(strategyManager) != address(0))
            revert RoboVault__ManagerAlreadyExists();
        strategyManager = IStrategyManager(_strategyManager);
    }

    // @dev function to transfer assets from the vault to the strategy manager
    function transferToStrategyManager(uint256 amount) external onlyOwner {
        if (amount == 0) revert RoboVault__InvalidAmount();
        uint256 idleBalance = underlyingAsset.balanceOf(address(this));
        if (amount > idleBalance) revert RoboVault__InsufficientIdleBalance();
        underlyingAsset.safeTransfer(address(strategyManager), amount);
    }

    //------ View/Pure functions -------//

    // @notice Returns the total shares owned by a specific user.
    function getTotalSharesOfUser(
        address user
    ) external view returns (uint256) {
        return balanceOf(user);
    }

    // @notice Returns the address of the underlying asset used by the vault.
    function getUnderlyingAsset() external view returns (address) {
        return address(underlyingAsset);
    }

    // @notice Returns the minimum deposit amount required to make a deposit into the vault.
    function getMinimumDeposit() external pure returns (uint256) {
        return i_minimumDeposit;
    }
}
