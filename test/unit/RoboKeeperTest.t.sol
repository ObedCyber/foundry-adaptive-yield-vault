// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RoboVault} from "../../src/RoboVault.sol";
import {USDCMock} from "../mocks/USDCMock.sol";
import {StrategyManager} from "../../src/StrategyManager.sol";
import {RoboKeeper} from "../../src/RoboKeeper.sol";
import {Mockstrategy} from "../../src/MockStrategy.sol";

contract RoboKeeperTest is Test {
    StrategyManager manager;
    RoboKeeper keeper;  
    USDCMock usdc;
    RoboVault vault;
    Mockstrategy strategyA;
    Mockstrategy strategyB;

    uint256 deviation = 50;
    uint256 minAPY = 100; 
    uint256 USER_WITHDRAWAL_DELAY = 30 days;
    uint256 rebalanceCooldown = 7 days;
    uint256 strategyA_APY = 200;
    uint256 strategyB_APY = 110;

    address owner = makeAddr("owner");

    error RoboKeeper__RebalanceOnCooldown();
    error RoboKeeper__InvalidConstructorParameters();


    function setUp() public {
        usdc = new USDCMock();
        vm.startPrank(owner);
        vault = new RoboVault(address(usdc), USER_WITHDRAWAL_DELAY);

         manager = new StrategyManager(
                    address(vault), 
                    owner, 
                    minAPY, 
                    address(usdc)
        );
        keeper = new RoboKeeper(
                deviation,
                address(manager),
                rebalanceCooldown
        );
        manager.setRoboKeeper(address(keeper));
        strategyA = new Mockstrategy(
            "StrategyA",
            strategyA_APY,
            address(manager),
            address(usdc)
        );
        strategyB = new Mockstrategy(
            "StrategyB",
            strategyB_APY,
            address(manager),
            address(usdc)
        );

        manager.addStrategy(address(strategyA));
        manager.addStrategy(address(strategyB));
        manager.activateStrategy(0);
        manager.activateStrategy(1);
        assertTrue(manager.checkIfStrategyIsActive(0));
        assertTrue(manager.checkIfStrategyIsActive(1));
        vm.stopPrank();

        vm.startPrank(address(manager));
        usdc.approve(address(strategyA), type(uint256).max);
        usdc.approve(address(strategyB), type(uint256).max);
        vm.stopPrank();

        // mint some usdc to manager for rebalancing
        usdc.mint(address(manager), 100e18);
    }

    function testCannotDeployRoboKeeperWithEmptyParameters() public {
        vm.expectRevert(abi.encodeWithSelector(RoboKeeper__InvalidConstructorParameters.selector));
        keeper = new RoboKeeper(
                0,
                address(0),
                0
        );
    }

    function testUpKeepIsFalsewhenBestIndexIsCurrentIndex() public view{
        manager.getBestAPYStrategy();
        bytes memory data = abi.encode("");
        (bool upKeepNeeded, ) = keeper.checkUpkeep(data);
        assertFalse(upKeepNeeded);
    }

    function testUpKeepIsTrueWhenBestIndexIsNotCurrentIndex() public {
        // strategy A is currently best strategy
        manager.getBestAPYStrategy();

        // change strategy APY to make strategy B the best
        vm.startPrank(address(strategyB));
        strategyB.changeAPY(300);
        vm.stopPrank();

        manager.refreshAPYs();

        uint256 bestIndex = manager.getBestAPYStrategy();
        assertEq(bestIndex, 1); // strategy B is best

        bytes memory data = abi.encode("");
        (bool upKeepNeeded, ) = keeper.checkUpkeep(data);
        assertTrue(upKeepNeeded);
    }

    function testPerfomUpKeep() public {
        vm.startPrank(address(strategyB));
        strategyB.changeAPY(300);
        vm.stopPrank();

        manager.refreshAPYs();
        bytes memory data = abi.encode("");
        keeper.checkUpkeep(data);

        vm.warp(rebalanceCooldown + 1 days);
        console.log("Keeper from Test: ", address(keeper));
        vm.prank(address(keeper));
        keeper.performUpkeep(data);

        assert(address(strategyB) == manager.getCurrentStrategyAddress());
    }

    function testCanUpdateRebalanceCooldown() public {
        vm.warp(3 days);
        vm.prank(owner);
        keeper.updateRebalanceCooldown(10 days);

        assert(keeper.getRebalanceCooldown() == 10 days);
    }
}
