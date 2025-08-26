// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {Test, console} from "forge-std/Test.sol";
import {RoboVault} from "../../src/RoboVault.sol";
import {USDCMock} from "../mocks/USDCMock.sol";
import {StrategyManager} from "../../src/StrategyManager.sol";
import {Mockstrategy} from "../../src/MockStrategy.sol";
import {RoboKeeper} from "../../src/RoboKeeper.sol";

contract IntegrationTest is Test {
    USDCMock usdc;
    RoboVault vault;
    StrategyManager manager;
    Mockstrategy strategyA;
    Mockstrategy strategyB;
    RoboKeeper keeper;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    
    uint256 DEPOSIT_AMOUNT = 10e18;
    uint256 WITHDRAW_AMOUNT = 5e18;
    uint256 WITHDRAWAL_PERIOD = 22 days;
    uint256 USER_WITHDRAWAL_DELAY = 30 days;
    uint256 minAPY = 1000; // 10%
    uint256 APYGap = 100; // 1%
    uint256 rebalanceCooldown = 7 days;
    uint256 strategyA_APY = 100;
    uint256 strategyB_APY = 110;
    uint256 YIELD_DEVIATION = 50;

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
        vault.setStrategyManager(address(manager));
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

        keeper = new RoboKeeper(
            YIELD_DEVIATION,
            address(manager),
            rebalanceCooldown
        );
        vm.stopPrank();

        vm.prank(address(vault));
        usdc.approve(address(manager), type(uint256).max);

        usdc.mint(alice, 10e18);
        usdc.mint(address(strategyA), 100e18);
        usdc.mint(address(strategyB), 100e18);
    }

    // workflow to test
    // user deposits into vault
    // vault allocates to strategy manager
    // strategy manager allocates to strategies
    // time passes, strategies earn yield

    function testUserDepositWorkflow() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositWithSlippageCheck(DEPOSIT_AMOUNT, 0);
    }





}
























































































