// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IStrategy {
    function strategyName() external returns (string memory);
    function estimateAPY() external returns(uint256);
    function getVaultBalance() external returns(uint256);
}

/**
 * A Strategy Manager contract acts as the controller or router between your vault and strategies. Its purpose is to coordinate how funds are allocated between different strategies, enforce constraints, and manage strategy lifecycle.
 * 
 * minimum APY enforced on all strategies, makes sure no assets in deposited in a strategy blow a certain APY.
 * It can select between multiple strategies and picks the one with the best APY.
 * It can decide to withdraw from the strategy just to secure profits
 * It can deactivate and activate any strategy
 * 
 * if vault wants to make deposit, it calls strategy manager first to check for the best APY's on different strategies and vault's makes the deposit.
 * Also the RoboKeeper will check from time to time that the vault's deposits are in the best APY and if not it will call the withdraw function and check for the next highest strategy and make the deposit there.
 * 
 * 
 */

contract StrategyManager is Ownable{
    address immutable i_vault;
    uint256 minimumAPY;
    StrategyData[] strategies;

    error NotVault();
    error NonZeroAddress();
    error InvalidIndex();
    error StrategyAlreadyActive();
    error CannotDeactivateStrategyWithFunds();

    event StrategyAdded(address indexed strategyAddress);
    event StrategyActivated(address indexed strategyAddress);
    event StrategyDeactivated(address indexed strategyAddress);


    struct StrategyData {
        string strategyName;
        address strategyAddress;
        uint256 lastRecordedAPY;
        bool active;
    }

    constructor(address vault, address strategyManager, uint256 minAPY )Ownable(strategyManager){
        i_vault = vault;
        minimumAPY = minAPY;
    }

    /// @dev Restricts access to only the vault
    modifier onlyVault() {
        if (msg.sender != i_vault) revert NotVault();
        _;
    }

    function addStrategy(address _strategyAddress) public onlyOwner{
        if(_strategyAddress == address(0)){ revert NonZeroAddress(); }
        string memory name = IStrategy(_strategyAddress).strategyName();
        uint256 initialAPY = IStrategy(_strategyAddress).estimateAPY();

        strategies.push(StrategyData({
            strategyName: name,
            strategyAddress: _strategyAddress,
            lastRecordedAPY: initialAPY,
            active: false
        }));
        emit StrategyAdded(_strategyAddress);
    }

    function activateStrategy(uint256 index) public onlyOwner{
        uint256 len = strategies.length;
        if (index > len){ revert InvalidIndex(); }
        StrategyData storage strategy = strategies[index];
        if (strategy.active){ revert StrategyAlreadyActive();} 

        strategy.active = true;
        emit StrategyActivated(strategy.strategyAddress);
    }

    function deactivateStrategy(uint256 index) public onlyOwner{
        uint256 len = strategies.length;
        if (index >= len){ revert InvalidIndex(); }
        
        StrategyData storage strategy = strategies[index];
        if(IStrategy(strategy.strategyAddress).getVaultBalance() > 0){
            revert CannotDeactivateStrategyWithFunds();
        }
        strategy.active = false;
        emit StrategyDeactivated(strategy.strategyAddress);
    }


    function refreshAPYs() public onlyVault {
        uint256 len = strategies.length;
        for (uint256 i = 0; i < len; i++) {
            StrategyData storage strategy = strategies[i];
            strategy.lastRecordedAPY = IStrategy(strategy.strategyAddress).estimateAPY();
        }
    }

    function setMinimumAPY(uint256 minAPY) public onlyOwner {
        minimumAPY = minAPY;
    }

}