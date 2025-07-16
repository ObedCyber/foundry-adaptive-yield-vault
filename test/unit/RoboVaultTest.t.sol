// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RoboVault} from "../../src/RoboVault.sol";
import {USDCMock} from "../mocks/USDCMock.sol";

contract RoboVaultTest is Test {
    RoboVault vault;
    USDCMock usdc;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 DEPOSIT_AMOUNT = 1e18;
    uint256 WITHDRAW_AMOUNT = 1e18;

    function setUp() public {
        usdc = new USDCMock();
        vault = new RoboVault(address(usdc));

        usdc.mint(alice, 10e18);
        usdc.mint(bob, 10e18);
    }

    function testMinimumDeposit() public view {
        assertEq(vault.getMinimumDeposit(), 1e18);
    }

    function testUnderlyingAsset() public view {
        assertEq(address(usdc), vault.getUnderlyingAsset());
    }

    function testUserCanDepositToVault() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), usdc.balanceOf(alice));
        uint256 aliceShares = vault.depositWithSlippageCheck(DEPOSIT_AMOUNT, DEPOSIT_AMOUNT);
        vm.stopPrank();
        assertEq(aliceShares, vault.getTotalSharesOfUser(alice));
    }

    function testUSerCanWithdrawFromVault() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), usdc.balanceOf(alice));
        uint256 aliceShares = vault.depositWithSlippageCheck(DEPOSIT_AMOUNT, DEPOSIT_AMOUNT);
        uint aliceAssets = vault.withdrawWithSlippageCheck(aliceShares, aliceShares);   
        vm.stopPrank();
        assertEq(aliceAssets, 1e18);
    }
}