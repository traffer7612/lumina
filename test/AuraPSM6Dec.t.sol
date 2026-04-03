// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { AuraUSD } from "../src/AuraUSD.sol";
import { AuraPSM } from "../src/AuraPSM.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

/// @notice PSM with 6-decimal pegged token (Arbitrum native USDC style).
contract AuraPSM6DecTest is Test {
    AuraUSD public ausd;
    AuraPSM public psm;
    MockERC20 public usdc6;

    address admin = address(this);
    address alice = address(0xA11CE);

    function setUp() public {
        ausd = new AuraUSD(admin);
        usdc6 = new MockERC20("USDC", "USDC", 6);
        psm = new AuraPSM(address(ausd), address(usdc6), admin, 10, 10);
        ausd.addMinter(address(psm));
    }

    function test_peggedDecimals_is6() public view {
        assertEq(psm.peggedDecimals(), uint8(6));
    }

    function test_swapIn_1USDC_mints_expected_aUSD() public {
        uint256 oneUsdc = 1_000_000;
        usdc6.mint(alice, oneUsdc);
        vm.startPrank(alice);
        usdc6.approve(address(psm), type(uint256).max);
        uint256 out = psm.swapIn(oneUsdc);
        vm.stopPrank();

        uint256 feePeg = (oneUsdc * 10) / 10_000;
        uint256 netPeg = oneUsdc - feePeg;
        uint256 expectedAusd = netPeg * 10 ** 12;
        assertEq(out, expectedAusd);
        assertEq(ausd.balanceOf(alice), expectedAusd);
        assertEq(usdc6.balanceOf(address(psm)), oneUsdc);
        assertEq(psm.feeReserves(), feePeg);
    }

    function test_swapOut_roundTrip() public {
        uint256 oneUsdc = 1_000_000;
        usdc6.mint(alice, oneUsdc);
        vm.startPrank(alice);
        usdc6.approve(address(psm), type(uint256).max);
        uint256 ausdOut = psm.swapIn(oneUsdc);
        ausd.approve(address(psm), type(uint256).max);
        uint256 usdcBefore = usdc6.balanceOf(alice);
        uint256 stableBack = psm.swapOut(ausdOut);
        vm.stopPrank();

        assertGt(stableBack, 0);
        assertEq(usdc6.balanceOf(alice), usdcBefore + stableBack);
        assertEq(ausd.balanceOf(alice), 0);
    }

    function test_withdrawLiquidity_moves_pool_not_feeReserves() public {
        uint256 oneUsdc = 1_000_000;
        usdc6.mint(alice, oneUsdc);
        vm.startPrank(alice);
        usdc6.approve(address(psm), type(uint256).max);
        psm.swapIn(oneUsdc);
        vm.stopPrank();

        assertEq(psm.feeReserves(), (oneUsdc * 10) / 10_000);
        assertEq(usdc6.balanceOf(address(psm)), oneUsdc);

        address treasury = address(0xBEEF);
        uint256 poolBefore = oneUsdc - psm.feeReserves();
        psm.withdrawLiquidity(treasury, poolBefore);

        assertEq(usdc6.balanceOf(treasury), poolBefore);
        assertEq(usdc6.balanceOf(address(psm)), psm.feeReserves());
        assertEq(psm.feeReserves(), (oneUsdc * 10) / 10_000);
    }

    function test_withdrawLiquidity_reverts_if_exceeds_pool() public {
        uint256 oneUsdc = 1_000_000;
        usdc6.mint(alice, oneUsdc);
        vm.startPrank(alice);
        usdc6.approve(address(psm), type(uint256).max);
        psm.swapIn(oneUsdc);
        vm.stopPrank();

        uint256 pool = oneUsdc - psm.feeReserves();
        vm.expectRevert(AuraPSM.PSM__InsufficientReserves.selector);
        psm.withdrawLiquidity(address(0xBEEF), pool + 1);
    }
}
