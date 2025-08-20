// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RoboVault} from "../../src/RoboVault.sol";
import {USDCMock} from "../mocks/USDCMock.sol";
import {StrategyManager} from "../../src/StrategyManager.sol";
import {Errors} from "../../src/Errors.sol";

contract RoboVaultTest is Test {
    RoboVault vault;
    USDCMock usdc;
    StrategyManager strategyManager;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address owner = makeAddr("owner");

    uint256 DEPOSIT_AMOUNT = 1e18;
    uint256 WITHDRAW_AMOUNT = 1e18;
    uint256 WITHDRAWAL_DELAY = 30 days;
    uint256 minAPY = 1000; // 10%
    uint256 _APYGap = 100; // 1%
    uint256 _rebalanceCooldown = 7 days;

   // vm.expectRevert(abi.encodeWithSelector(MultiSigWalletBase.MultiSigWallet__DuplicateBatchTransactionNotAllowed.selector));

    event Deposited(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 shares, uint256 timestamp);

    function setUp() public {
        usdc = new USDCMock();
        vault = new RoboVault(address(usdc), WITHDRAWAL_DELAY);
        strategyManager = new StrategyManager(
                    address(vault), 
                    owner, 
                    minAPY, 
                    _rebalanceCooldown,
                    address(usdc)
        );
        vm.prank(address(vault));
        usdc.approve(address(strategyManager), type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(Errors.RoboVault__ZeroAddress.selector));
        vault.setStrategyManager(address(0)); // should revert if zero address

        vault.setStrategyManager(address(strategyManager));

        vm.expectRevert(abi.encodeWithSelector(Errors.RoboVault__ManagerAlreadyExists.selector));
        vault.setStrategyManager(address(strategyManager)); // should revert if manager already set 

        usdc.mint(alice, 10e18);
        usdc.mint(bob, 10e18);
    }
    // test minimum deposit
    function testMinimumDeposit() public view {
        assertEq(vault.getMinimumDeposit(), 1e18);
    }

    // test underlying asset
    function testUnderlyingAsset() public view {
        assertEq(address(usdc), vault.getUnderlyingAsset());
    }

    // test vault constructor does not accept zero address for asset
    function testConstructorRevertsOnZeroAsset() public {
    vm.expectRevert(abi.encodeWithSelector(Errors.RoboVault__ZeroAddress.selector));
    new RoboVault(address(0), WITHDRAWAL_DELAY);
    }

    // test constructor does not accept zero withdrawal delay
    function testConstructorRevertsOnZeroDelay() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.RoboVault__InvalidWithdrawalDelay.selector));
        new RoboVault(address(usdc), 0);
    }
    // test deposit reverts on zero amount
    function testDepositRevertsOnZeroAmount() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vm.expectRevert();
        vault.depositWithSlippageCheck(0, 0);
        vm.stopPrank();
    }
    // test deposit reverts on amount less than minimum deposit
    function testDepositRevertsOnSmallAmount() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vm.expectRevert();
        vault.depositWithSlippageCheck(1, 1);
        vm.stopPrank();
    }

    // test deposit reverts on slippage exceeding minimum output shares
    function testDepositRevertsOnSlippage() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(Errors.RoboVault__DepositSlippageExceeded.selector));
        vault.depositWithSlippageCheck(DEPOSIT_AMOUNT, DEPOSIT_AMOUNT + 1e18); // minimumOutputShares too high
        vm.stopPrank();
    }

    // test deposit updates state and emits event
    function testDepositUpdatesStateAndEmitsEvent() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vm.expectEmit(true, false, false, true);
        emit Deposited(alice, 1e18, block.timestamp);
        uint256 shares = vault.depositWithSlippageCheck(1e18, 1e18);
        vm.stopPrank();
        assertEq(vault.userDeposits(alice), 1e18);
        assertEq(vault.userLastDepositTimestamp(alice), block.timestamp);
        assertEq(shares, vault.getTotalSharesOfUser(alice));
    }

    // test withdraw reverts on zero shares
    function testWithdrawRevertsOnZeroShares() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositWithSlippageCheck(DEPOSIT_AMOUNT, 1e18);
        vm.expectRevert();
        vault.withdrawWithSlippageCheck(0, 0);
        vm.stopPrank();
    }

    // test withdraw reverts on insufficient shares
    function testWithdrawRevertsOnInsufficientShares() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositWithSlippageCheck(DEPOSIT_AMOUNT, 1e18);
        vm.expectRevert();
        vault.withdrawWithSlippageCheck(2e18, 1e18);
        vm.stopPrank();
    }

    // test withdraw reverts on withdrawal delay not met
    function testWithdrawRevertsOnDelay() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.depositWithSlippageCheck(DEPOSIT_AMOUNT, 1e18);
        vm.expectRevert();
        vault.withdrawWithSlippageCheck(shares, 1e18);
        vm.stopPrank();
    }

    function testWithdrawRevertsOnSlippage() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), 1e18);
        uint256 shares = vault.depositWithSlippageCheck(1e18, 1e18);
        vm.warp(block.timestamp + WITHDRAWAL_DELAY);
        vm.expectRevert();
        vault.withdrawWithSlippageCheck(shares, 2e18); // minimumOutputAssets too high
        vm.stopPrank();
    }

    // test getTotalSharesOfUser returns correct shares
    function testGetTotalSharesOfUser() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.depositWithSlippageCheck(DEPOSIT_AMOUNT, 1e18);
        vm.stopPrank();
        assertEq(vault.getTotalSharesOfUser(alice), shares);
    }


    // test totalAssets returns correct value (idle + strategy)
    function testTotalAssetsReturnsSum() public {
        // No assets in strategy, all in vault
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositWithSlippageCheck(DEPOSIT_AMOUNT, 1e18);
        vm.stopPrank();
        // Should equal vault's USDC balance (since strategyManager returns 0)
        assertEq(vault.totalAssets(), usdc.balanceOf(address(vault)));
    }

    // test successful withdraw after delay
    function testUserCanWithdrawAfterDelay() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.depositWithSlippageCheck(DEPOSIT_AMOUNT, 1e18);
        vm.warp(block.timestamp + WITHDRAWAL_DELAY);
        uint256 before = usdc.balanceOf(alice);
        uint256 assets = vault.withdrawWithSlippageCheck(shares, 1e18);
        vm.stopPrank();
        assertEq(assets, 1e18);
        assertEq(usdc.balanceOf(alice), before + 1e18);
    }

    // test transferToStrategyManager reverts on zero amount
    function testTransferToStrategyManagerRevertsOnZeroAmount() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositWithSlippageCheck(DEPOSIT_AMOUNT, 1e18);
        vm.stopPrank();

        vm.prank(address(this));
        vm.expectRevert(abi.encodeWithSelector(Errors.RoboVault__InvalidAmount.selector));
        vault.transferToStrategyManager(0); // should revert on zero amount
        vm.stopPrank();
    }

    function testTransferToStrategyManagerRevertsOnInsufficientIdleBalance() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositWithSlippageCheck(DEPOSIT_AMOUNT, 1e18);
        vm.stopPrank();

        vm.prank(address(this));
        vm.expectRevert(abi.encodeWithSelector(Errors.RoboVault__InsufficientIdleBalance.selector));
        vault.transferToStrategyManager(DEPOSIT_AMOUNT + 1e18); // should revert on insufficient idle balance
        vm.stopPrank();
    }

    

}
