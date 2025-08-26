// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStrategyManager} from "./interfaces/IStrategyManager.sol";
import {console} from "forge-std/Test.sol";

/**
 * @title RoboKeeper
 * @author Obed Okoh
 * @notice This contract uses Chainlink Automation to monitor and rebalance investment strategies based on yield deviation.
 * It interacts with a StrategyManager contract to get strategy APYs and perform rebalancing when necessary.
 * The contract owner can update the rebalance cooldown period.
 */
contract RoboKeeper is AutomationCompatibleInterface, Ownable {
    error RoboKeeper__RebalanceOnCooldown();
    error RoboKeeper__InvalidConstructorParameters();

    uint256 public yieldDeviation;
    uint256 public rebalanceCooldown;
    uint256 public lastRebalanceTimestamp; // timestamp of the last rebalance

    IStrategyManager public strategyManager;

    /** @dev Initializes the RoboKeeper contract with the specified parameters.
     * @param _yieldDeviation The minimum yield deviation required to trigger a rebalance.
     * @param _strategyManager The address of the StrategyManager contract.
     * @param _rebalanceCooldown The cooldown period between rebalances.
     */
    constructor(
        uint256 _yieldDeviation,
        address _strategyManager,
        uint256 _rebalanceCooldown
    ) Ownable(msg.sender) {
        if (
            _strategyManager == address(0) ||
            _rebalanceCooldown == 0 ||
            _yieldDeviation == 0
        ) revert RoboKeeper__InvalidConstructorParameters();

        yieldDeviation = _yieldDeviation;
        strategyManager = IStrategyManager(_strategyManager);
        rebalanceCooldown = _rebalanceCooldown;
    }

    // NOTE: This function will potentially return stale APY's if
    // refreshAPY function has not been called before this function is called.
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        uint256 bestIndex = strategyManager.getBestAPYStrategy();
        uint256 currentIndex = strategyManager.getCurrentStrategyIndex();

        // if best strategy is current, upkeepNeeded is false
        if (bestIndex == currentIndex) {
            upkeepNeeded = false;
            return (upkeepNeeded, "");
        }

        uint256 currentAPY = strategyManager.getStrategyAPY(currentIndex);
        uint256 bestAPY = strategyManager.getStrategyAPY(bestIndex);

        if (bestAPY > currentAPY && (bestAPY - currentAPY) > yieldDeviation) {
            upkeepNeeded = true;
            return (upkeepNeeded, "");
        }
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        // check if rebalance cooldown has reached
        if ((block.timestamp - lastRebalanceTimestamp) > rebalanceCooldown) {
            strategyManager.Rebalance();
        }
    }

    // @dev Updates the rebalance cooldown period.
    // RebalanceCooldown period can only be updated when rebalance is on cooldown
    // so that values won't be changes while rebalancing is in progress
    function updateRebalanceCooldown(
        uint256 newRebalanceCooldown
    ) public onlyOwner {
        if ((block.timestamp - lastRebalanceTimestamp) < rebalanceCooldown) {
            rebalanceCooldown = newRebalanceCooldown;
        }
    }

    // @dev Returns the current rebalance cooldown period.
    function getRebalanceCooldown() public view returns (uint256) {
        return rebalanceCooldown;
    }
}
