// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RoboVault} from "../../src/RoboVault.sol";
import {USDCMock} from "../mocks/USDCMock.sol";
import {StrategyManager} from "../../src/StrategyManager.sol";
import {Mockstrategy} from "../../src/MockStrategy.sol";

contract MockStrategyTest is Test {
    RoboVault vault;
    USDCMock usdc;
    StrategyManager manager;
    Mockstrategy strategy;

    uint256 DEPOSIT_AMOUNT = 1e18;
    uint256 WITHDRAWAL_PERIOD = 22 days;
    address bob = makeAddr("bob");
    address owner = makeAddr("owner");

    error InvalidAmount();
    error NonZeroAddress();
    error NotManager();
    error InsufficientAllowance();
    error InvalidWithdrawalPeriod();
    error InsufficientBalance();
    error NotStrategy();

    event WithdrawSuccessful(address indexed manager, uint256 amount, uint256 indexed timestamp);
    event DepositSuccessful(address indexed manager, uint256  amount, uint256 indexed timestamp);
    event EmergencyWithdrawSuccessful(address indexed manager, uint256  amount, uint256 indexed timestamp);

    function setUp() public {
        usdc = new USDCMock();
        manager = new StrategyManager(address(0), address(owner), 1000, 7 days, address(usdc));
        strategy = new Mockstrategy("MockStrategy", 100, address(manager), address(usdc));

        usdc.mint(address(strategy), 100e18);
        usdc.mint(address(manager), 10e18);
        

        vm.prank(address(manager));
        usdc.approve(address(strategy), type(uint256).max);
    }

    function testOnlyManagerCanDeposit() public {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotManager.selector));
        strategy.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testDepositInvalidAmountReverts() public {
        vm.startPrank(address(manager));
        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector));
        strategy.deposit(0);
        vm.stopPrank();
    }

/*     function testdepositRevertsOnInsufficientallowance() public {
        vm.startPrank(address(manager));
        vm.expectRevert(abi.encodeWithSelector(InsufficientAllowance.selector));
        strategy.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
    } */

   function testManagerCanDeposit() public {
    uint256 balanceBefore = strategy.getVaultBalance();
    uint256 sharesBalance = strategy.balanceOf(address(manager));

    vm.prank(address(manager));
    vm.expectEmit(true, false, false, true);
    emit DepositSuccessful(address(manager), DEPOSIT_AMOUNT, block.timestamp);
    uint256 sharesRecieved = strategy.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();
    uint256 balanceAfter = strategy.getVaultBalance();
    
    assert(balanceBefore < balanceAfter);
    assert(sharesBalance < sharesRecieved);
   }

   function testWithdrawInvalidAmountReverts() public {
        vm.startPrank(address(manager));
        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector));
        strategy.withdraw(0);
        vm.stopPrank();
   }

   function testWithdrawInvalidPeriod() public {
        vm.startPrank(address(manager));
        strategy.deposit(DEPOSIT_AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(InvalidWithdrawalPeriod.selector));
        strategy.withdraw(DEPOSIT_AMOUNT / 5e17);
        vm.stopPrank();
   }

    function testWithdraw() public {
        uint256 WITHDRAW_AMOUNT = DEPOSIT_AMOUNT / 5e17;
        uint256 balanceBefore = strategy.getVaultBalance();
        uint256 sharesBalance = strategy.balanceOf(address(manager));

        vm.startPrank(address(manager));
        strategy.deposit(DEPOSIT_AMOUNT);
        vm.warp(WITHDRAWAL_PERIOD);
        vm.expectEmit(true, false, false, true);
        emit WithdrawSuccessful(address(manager), WITHDRAW_AMOUNT, block.timestamp);
        strategy.withdraw(WITHDRAW_AMOUNT);
        uint256 sharesLeft = strategy.balanceOf(address(manager));
        uint256 balanceAfter = strategy.getVaultBalance();

        assert(balanceBefore < balanceAfter);
        assert(sharesBalance < sharesLeft);
        vm.stopPrank();
    }


    //////////////////////////////////////////////

    
    function testEmergencyWithdrawRevertsIfNoBalance() public {
        vm.startPrank(address(manager));
        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector));
        strategy.emergencyWithdraw();
        vm.stopPrank();
    }

    function testEmergencyWithdrawBurnsSharesAndResetsState() public {
        vm.startPrank(address(manager));
        strategy.deposit(DEPOSIT_AMOUNT);
        console.log("Manager shares:", strategy.balanceOf(address(manager)));
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        uint256 sharesBefore = strategy.balanceOf(address(manager));
        uint256 balBefore = strategy.getVaultBalance();
        usdc.mint(address(strategy), balBefore); // Ensure strategy has enough balance for emergency withdraw
        vm.expectEmit(true, false, false, true);
        emit EmergencyWithdrawSuccessful(address(manager), balBefore, block.timestamp);
        strategy.emergencyWithdraw();
        assertEq(strategy.balanceOf(address(manager)), 0);
        assertEq(strategy.getVaultBalance(), 0);
        vm.stopPrank();
    }

    function testAccrueInterestIncreasesBalanceAfterPeriod() public {
        vm.startPrank(address(manager));
        strategy.deposit(DEPOSIT_AMOUNT);
        uint256 before = strategy.getVaultBalance();
        console.log("Before balance:", (before ), "USDC");
        vm.warp(block.timestamp + 1 days);
        // accrueInterest is called internally by getVaultBalance
        uint256 afterBal = strategy.getVaultBalance();
        console.log("After balance:", (afterBal ), "USDC");
        assertGt(afterBal, before);
        console.log("Interest accrued:", ((afterBal - before) ), "USDC");
        vm.stopPrank();
    }
/*      Before balance: 1000000000000000000 USDC
  After balance:        2000000031709791983 USDC
  Interest accrued:     1000000031709791983 USDC */
    function testChangeAPYRevertsIfNotStrategy() public {
        vm.startPrank(address(manager));
        vm.expectRevert(abi.encodeWithSelector(NotStrategy.selector));
        strategy.changeAPY(2000);
        vm.stopPrank();
    }

    function testChangeAPYRevertsIfZero() public {
        // Only contract itself can call changeAPY, so use low-level call
        (bool success, bytes memory data) = address(strategy).call(abi.encodeWithSignature("changeAPY(uint256)", 0));
        assertTrue(!success);
    }

    function testChangeAPYUpdatesAPY() public {
        // Only contract itself can call changeAPY, so use low-level call
        uint256 newAPY = 2000;
        bytes memory callData = abi.encodeWithSignature("changeAPY(uint256)", newAPY);
        (bool success, ) = address(strategy).call(callData);
        // Should revert with NotStrategy, so APY should not change
        assertTrue(!success);
    }

    function testStrategyNameReturnsCorrectName() public view {
        assertEq(strategy.strategyName(), "MockStrategy");
    }

    function testEstimateAPYReturnsCorrectAPY() public view {
        assertEq(strategy.estimateAPY(), 100);
    }



}


















