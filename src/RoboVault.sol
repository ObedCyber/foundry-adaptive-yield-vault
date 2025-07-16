// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Errors} from "./Errors.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RoboVault is ERC4626, ReentrancyGuard, Errors{

    IERC20 immutable underlyingAsset;
    uint256 immutable i_minimumDeposit = 1e18;
    mapping (address => uint) userDeposits;

    constructor(address _asset) ERC4626(IERC20(_asset)) ERC20("RoboVault","ROBO"){
        if(_asset == address(0)) revert ZeroAddress();
        underlyingAsset = IERC20(_asset);
    }
    
    function depositWithSlippageCheck(uint256 amount, uint256 minimumOutputShares) external nonReentrant returns(uint256){
        if(amount == 0) revert InvalidAmount();
        if(amount < i_minimumDeposit) revert DepositTooSmall();
        userDeposits[msg.sender] += amount;
        uint256 userShares = deposit(amount, msg.sender);
        if (userShares < minimumOutputShares) revert DepositSlippageExceeded();
        return userShares;
    }

    function withdrawWithSlippageCheck(uint256 shares, uint256 minimumOutputAssets) external nonReentrant returns(uint256) {
        address user = msg.sender;
        if(shares == 0) revert InvalidAmount();
        if(shares > balanceOf(user)) revert InsufficientShares();
        userDeposits[user] -= previewRedeem(shares);
        uint256 assetsRecieved = withdraw(shares, user, user);
        if (assetsRecieved < minimumOutputAssets) revert WithdrawSlippageExceeded();
        return assetsRecieved;
    }

    function getTotalSharesOfUser(address user) external view returns(uint256){
        return balanceOf(user);
    }

    function getUnderlyingAsset() external view returns(address){
        return address(underlyingAsset);
    }

    function getMinimumDeposit() external pure returns(uint256){
        return i_minimumDeposit;
    }
    function getActiveStrategy() external view returns(uint256){}
    
}