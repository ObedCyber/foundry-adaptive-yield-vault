// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RoboVault} from "../../src/RoboVault.sol";
import {USDCMock} from "../mocks/USDCMock.sol";
import {StrategyManager} from "../../src/StrategyManager.sol";
import {Mockstrategy} from "../../src/MockStrategy.sol";

contract StrategyManagerTest is Test {
    RoboVault vault;
    USDCMock usdc;
    StrategyManager manager;
    Mockstrategy strategy;

    address nonOwner = makeAddr("nonOwner");
    address owner = makeAddr("owner");

    uint256 DEPOSIT_AMOUNT = 1e18;
    uint256 WITHDRAW_AMOUNT = 1e18;
    uint256 WITHDRAWAL_DELAY = 30 days;
    uint256 minAPY = 1000; // 10%
    uint256 _APYGap = 100; // 1%
    uint256 _rebalanceCooldown = 7 days;

    error StrategyManager__NotVault();
    error StrategyManager__NonZeroAddress();
    error StrategyManager__InvalidIndex();
    error StrategyManager__StrategyAlreadyActive();
    error StrategyManager__CannotDeactivateStrategyWithFunds();
    error StrategyManager__InsufficientBalance();
    error StrategyManager__InsufficientAllowance();
    error StrategyManager__InvalidAmount();
    error StrategyManager__InactiveStrategy();
    error StrategyManager__TransactionFailed();
    error StrategyManager__InsufficientBalanceInStrategy();
    error StrategyManager__NoBestStrategy();
    error StrategyManager__CurrentStrategyIsBestStrategy();
    error StrategyManager__CannotSetRoboKeeper();
    error StrategyManager__NotRoboKeeper();

    event StrategyAdded(address indexed strategyAddress);
    event StrategyActivated(address indexed strategyAddress);
    event StrategyDeactivated(address indexed strategyAddress);
    event Allocationsuccessful(address indexed strategyAddress, uint256 amount);
    event WithdrawalSuccessful(address indexed strategyAddress, uint256 amount);
    event RebalanceSuccessful(address indexed strategyAddress, uint256 amount);
    event WithdrawalToVaultSuccessful(address indexed strategyWithdrawnFrom, uint256 amount);

    function setUp() public {
        usdc = new USDCMock();
        vault = new RoboVault(address(usdc), WITHDRAWAL_DELAY);
        manager = new StrategyManager(
                    address(vault), 
                    owner, 
                    minAPY, 
                     _APYGap,
                    _rebalanceCooldown,
                    address(usdc)
        );
        strategy = new Mockstrategy(
            "Mockstrategy",
            2000,
            address(manager),
            address(usdc)
        );

        usdc.mint(address(manager), 10e18);
        vm.prank(address(manager));
        usdc.approve(address(strategy), type(uint256).max);
    }

    modifier ownerHasAddedAndActivatedStrategy() {
        vm.startPrank(owner);
        manager.addStrategy(address(strategy));
        manager.activateStrategy(0);
        
        vm.stopPrank();
        _;
    }

    function testNonOwnerCannotAddStrategy()public {
        vm.startPrank(nonOwner);
        vm.expectRevert();
        manager.addStrategy(address(strategy));
        vm.stopPrank();
    }

    function testOwnerCannotAddZeroAddressStrategy() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(StrategyManager__NonZeroAddress.selector));
        manager.addStrategy(address(0));
        vm.stopPrank();
    }

    function testOwnerCanAddStrategy() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit StrategyAdded(address(strategy));
        manager.addStrategy(address(strategy));
        vm.stopPrank();
        assert(manager.getStrategyAddress(0) == address(strategy));
    }

    function testOwnerCannotActivateStrategyWithInvalidIndex() public {
        vm.startPrank(owner);
        manager.addStrategy(address(strategy));
        vm.expectRevert(abi.encodeWithSelector(StrategyManager__InvalidIndex.selector));
        manager.activateStrategy(1);
        vm.stopPrank();
    }

    function testOwnerCannotActivateStrategyTwice() public {
        vm.startPrank(owner);
        manager.addStrategy(address(strategy));
        manager.activateStrategy(0);
        vm.expectRevert(abi.encodeWithSelector(StrategyManager__StrategyAlreadyActive.selector));
        manager.activateStrategy(0);
        vm.stopPrank();
    }

    function testOwnerCanActivateStrategy() public {
        vm.startPrank(owner);
        manager.addStrategy(address(strategy));
        vm.expectEmit(true, false, false, false);
        emit StrategyActivated(address(strategy));
        assert(manager.checkIfStrategyIsActive(0) == false);
        manager.activateStrategy(0);
        assert(manager.checkIfStrategyIsActive(0) == true);
        vm.stopPrank();
    }

    function testOwnerCannotDeactivateStrategyWithInvalidIndex() public {
        vm.startPrank(owner);
        manager.addStrategy(address(strategy));
        vm.expectRevert(abi.encodeWithSelector(StrategyManager__InvalidIndex.selector));
        manager.deactivateStrategy(1);
        vm.stopPrank();
    }

    function testOwnerCannotDeactivateActiveStrategyWithFunds() public {
        vm.prank(address(manager));

        strategy.deposit(DEPOSIT_AMOUNT);
        vm.startPrank(owner);
        manager.addStrategy(address(strategy));
        manager.activateStrategy(0);
        vm.expectRevert(abi.encodeWithSelector(StrategyManager__CannotDeactivateStrategyWithFunds.selector));
        manager.deactivateStrategy(0);
        vm.stopPrank();
    }

    function testOwnerCanDeactivateStrategy() public {
        vm.startPrank(owner);
        manager.addStrategy(address(strategy));
        manager.activateStrategy(0);
        assert(manager.checkIfStrategyIsActive(0) == true);
        vm.expectEmit(true, false, false, false);
        emit StrategyDeactivated(address(strategy));
        manager.deactivateStrategy(0);
        assert(manager.checkIfStrategyIsActive(0) == false);
        vm.stopPrank();
    }
    
    function testRefreshAPYs() public ownerHasAddedAndActivatedStrategy {
        uint256 initialAPY = manager.getStrategyAPY(0);
        assert(initialAPY == 2000); // 20%

        vm.prank(address(strategy));
        strategy.changeAPY(3000); // Change APY to 30%
        manager.refreshAPYs();
        uint256 updatedAPY = manager.getStrategyAPY(0);
        assert(updatedAPY == 3000);
    }

    function testOwnerCanUpdateMinimumAPY() public {
        uint256 initialAPY = manager.getMinimumAPY();
        assert(initialAPY == minAPY);
        vm.prank(owner);
        manager.updateMinimumAPY(1500); // Update to 15%
        uint256 updatedAPY = manager.getMinimumAPY();
        assert(updatedAPY == 1500);
    }

    function testOwnerCanUpdateAPYGap() public {
        uint256 initialAPYGap = manager.getAPYGap();
        assert(initialAPYGap == _APYGap);
        vm.prank(owner);
        manager.updateAPYGap(200); // Update to 2%
        uint256 updatedAPYGap = manager.getAPYGap();
        assert(updatedAPYGap == 200);
    }
    
}
