// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Errors} from "./Errors.sol";
import {IStrategyManager} from "./IStrategyManager.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RoboVault is ERC4626, ReentrancyGuard, Errors{

    event Deposited(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 shares, uint256 timestamp);

    IERC20 immutable underlyingAsset;
    uint256 immutable i_minimumDeposit = 1e18;
    IStrategyManager public strategyManager;
    mapping (address => uint256) public userDeposits;
    mapping (address => uint256) public userLastDepositTimestamp;
    uint256 public constant WITHDRAWAL_DELAY;

    constructor(address _asset, uint256 withdrawalDelay, address strategyManager) ERC4626(IERC20(_asset)) ERC20("RoboVault","ROBO"){
        if(_asset == address(0)) revert ZeroAddress();
        if(strategyManager == address(0)) revert ZeroAddress();
        if(withdrawalDelay == 0) revert InvalidWithdrawalDelay();
        underlyingAsset = IERC20(_asset);
        WITHDRAWAL_DELAY = withdrawalDelay;
        strategyManager = IStrategyManager(strategyManager);
    }
    
    function depositWithSlippageCheck(uint256 amount, uint256 minimumOutputShares) external nonReentrant returns(uint256){
        if(amount == 0) revert InvalidAmount();
        if(amount < i_minimumDeposit) revert DepositTooSmall();
        userDeposits[msg.sender] += amount;
        userLastDepositTimestamp[msg.sender] = block.timestamp;
        uint256 userShares = deposit(amount, msg.sender);
        if (userShares < minimumOutputShares) revert DepositSlippageExceeded();
        emit Deposited(msg.sender, amount, block.timestamp);
        return userShares;
    }

    function withdrawWithSlippageCheck(uint256 shares, uint256 minimumOutputAssets) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        address user = msg.sender;
        uint256 amountToReceive = previewWithdraw(shares);

        if (shares == 0) revert InvalidAmount();
        if (shares > balanceOf(user)) revert InsufficientShares();
        if (block.timestamp < userLastDepositTimestamp[user] + WITHDRAWAL_DELAY) 
            revert WithdrawalDelayNotMet();

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
        if (assetsReceived < minimumOutputAssets) revert WithdrawSlippageExceeded();

        emit Withdrawn(user, assetsReceived, block.timestamp);
        return assetsReceived;
    }


    // @notice Returns the total assets in the vault, which includes both idle assets and those allocated to strategies.
    function totalAssets() public view override returns (uint256) {
        uint256 idleBalance = underlyingAsset.balanceOf(address(this));
        uint256 balanceAccrossStrategies = strategyManager.getTotalBalanceAcrossStrategies();
        return idleBalance + balanceAccrossStrategies;
    }

    function getTotalSharesOfUser(address user) external view returns(uint256){
        return balanceOf(user);
    }

    function getUnderlyingAsset() external view returns(address){
        return address(underlyingAsset);
    }

    function getMinimumDeposit() external view returns(uint256){
        return i_minimumDeposit;
    }
    function getUserDeposit(address user) external view returns(uint256){
        return userDeposits[user];
    }
    
}