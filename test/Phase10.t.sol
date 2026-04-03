// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test }               from "forge-std/Test.sol";
import { CeitnotEngine }         from "../src/CeitnotEngine.sol";
import { CeitnotProxy }          from "../src/CeitnotProxy.sol";
import { CeitnotMarketRegistry } from "../src/CeitnotMarketRegistry.sol";
import { CeitnotUSD }            from "../src/CeitnotUSD.sol";
import { CeitnotRouter }         from "../src/CeitnotRouter.sol";
import { MockERC20 }          from "./mocks/MockERC20.sol";
import { MockVault4626 }      from "./mocks/MockVault4626.sol";
import { MockOracle }         from "./mocks/MockOracle.sol";

/**
 * @title  Phase10Test
 * @notice Tests for Phase 10: EIP-2612 Permit, Multicall, Delegates, Compound functions, Router.
 */
contract Phase10Test is Test {

    // ------------------------------- Mirrored events (for vm.expectEmit)
    event DelegateSet(address indexed user, address indexed delegate, bool approved);
    event DepositAndBorrowed(address indexed user, uint256 indexed marketId, uint256 shares, uint256 borrowed);
    event RepaidAndWithdrawn(address indexed user, uint256 indexed marketId, uint256 repaid, uint256 shares);

    // ------------------------------- Constants
    uint256 constant WAD       = 1e18;
    uint256 constant MARKET_ID = 0;

    // ------------------------------- Actors
    address public admin = address(this);
    address public alice = address(0xA11CE);
    address public bob   = address(0xB0B);

    // Private key for permit testing (alice's key)
    uint256 constant ALICE_PK = 0xA11CE_BEEF_DEAD_C0DE;

    // ------------------------------- Contracts
    CeitnotUSD            public ausd;
    CeitnotEngine         public engine;
    CeitnotProxy          public proxy;
    CeitnotMarketRegistry public registry;
    CeitnotRouter         public router;

    MockERC20     public assetToken;
    MockVault4626 public vault;
    MockOracle    public oracle;

    // ------------------------------- Setup
    function setUp() public {
        // 1. Deploy CeitnotUSD
        ausd = new CeitnotUSD(admin);

        // 2. Collateral infrastructure
        assetToken = new MockERC20("Wrapped stETH", "wstETH", 18);
        vault      = new MockVault4626(address(assetToken), "Ceitnot wstETH Vault", "wstETH");
        oracle     = new MockOracle();

        // 3. Registry
        registry = new CeitnotMarketRegistry(admin);
        registry.addMarket(
            address(vault), address(oracle),
            uint16(8000), uint16(8500), uint16(500),
            0, 0, false, 0
        );

        // 4. Engine (CDP mode)
        CeitnotEngine impl = new CeitnotEngine();
        bytes memory initData = abi.encodeCall(
            CeitnotEngine.initialize,
            (address(ausd), address(registry), uint256(1 days), uint256(2 days))
        );
        proxy  = new CeitnotProxy(address(impl), initData);
        engine = CeitnotEngine(address(proxy));
        registry.setEngine(address(proxy));

        ausd.addMinter(address(proxy));
        ausd.addMinter(admin);
        engine.setMintableDebtToken(true);

        // 5. Router
        router = new CeitnotRouter(address(proxy), address(ausd));

        // 6. Fund actors
        // alice — derive address from known private key
        address aliceDerived = vm.addr(ALICE_PK);
        alice = aliceDerived;

        assetToken.mint(alice, 10_000 * WAD);
        vm.startPrank(alice);
        assetToken.approve(address(vault), type(uint256).max);
        vault.deposit(2_000 * WAD, alice);
        vault.approve(address(proxy), type(uint256).max);
        vault.approve(address(router), type(uint256).max);
        vm.stopPrank();

        assetToken.mint(bob, 10_000 * WAD);
        vm.startPrank(bob);
        assetToken.approve(address(vault), type(uint256).max);
        vault.deposit(2_000 * WAD, bob);
        vault.approve(address(proxy), type(uint256).max);
        vault.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    /// @dev Build a valid aUSD permit signature signed by ALICE_PK.
    function _signPermit(
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                alice,
                spender,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", ausd.DOMAIN_SEPARATOR(), structHash)
        );
        (v, r, s) = vm.sign(ALICE_PK, digest);
    }

    /// @dev Deposit collateral for user, then advance one block before borrowing.
    function _depositAndBorrowLegacy(address user, uint256 collateral, uint256 borrow) internal {
        vm.prank(user);
        engine.depositCollateral(user, MARKET_ID, collateral);
        vm.roll(block.number + 1);
        vm.prank(user);
        engine.borrow(user, MARKET_ID, borrow);
    }

    // =========================================================================
    // 1. CeitnotUSD EIP-2612 Permit
    // =========================================================================

    function test_permit_basic() public {
        uint256 value    = 500 * WAD;
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(bob, value, 0, deadline);

        ausd.permit(alice, bob, value, deadline, v, r, s);

        assertEq(ausd.allowance(alice, bob), value, "allowance not set");
        assertEq(ausd.nonces(alice), 1, "nonce not incremented");
    }

    function test_permit_expired_reverts() public {
        uint256 deadline = block.timestamp - 1; // already expired
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(bob, WAD, 0, deadline);

        vm.expectRevert(CeitnotUSD.CeitnotUSD__PermitExpired.selector);
        ausd.permit(alice, bob, WAD, deadline, v, r, s);
    }

    function test_permit_wrongSigner_reverts() public {
        uint256 deadline = block.timestamp + 1 hours;
        // Sign with bob's key but claim alice as owner
        uint256 BOB_PK = 0xB0B111; // different key from ALICE_PK
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                alice, bob, WAD, uint256(0), deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", ausd.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(BOB_PK, digest);

        vm.expectRevert(CeitnotUSD.CeitnotUSD__InvalidSignature.selector);
        ausd.permit(alice, bob, WAD, deadline, v, r, s);
    }

    function test_permit_nonce_increments_and_replay_reverts() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(bob, WAD, 0, deadline);

        ausd.permit(alice, bob, WAD, deadline, v, r, s);
        assertEq(ausd.nonces(alice), 1);

        // Replay the exact same signature — should fail (nonce is now 1)
        vm.expectRevert(CeitnotUSD.CeitnotUSD__InvalidSignature.selector);
        ausd.permit(alice, bob, WAD, deadline, v, r, s);
    }

    function test_permit_maxAllowance() public {
        uint256 deadline = block.timestamp + 1 hours;
        uint256 maxVal   = type(uint256).max;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(address(proxy), maxVal, 0, deadline);

        ausd.permit(alice, address(proxy), maxVal, deadline, v, r, s);
        assertEq(ausd.allowance(alice, address(proxy)), maxVal);
    }

    function test_permit_allowsThenBurns() public {
        // Mint aUSD to alice, then use permit to set allowance for engine, then burnFrom
        ausd.mint(alice, 100 * WAD);
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(address(this), 100 * WAD, 0, deadline);

        ausd.permit(alice, address(this), 100 * WAD, deadline, v, r, s);
        // admin (this) burns on behalf of alice using the allowance set by permit
        ausd.burnFrom(alice, 50 * WAD);
        assertEq(ausd.balanceOf(alice), 50 * WAD);
    }

    // =========================================================================
    // 2. Multicall on CeitnotEngine
    // =========================================================================

    function test_multicall_emptyArray_noop() public {
        bytes[] memory calls = new bytes[](0);
        bytes[] memory results = engine.multicall(calls);
        assertEq(results.length, 0);
    }

    function test_multicall_batchAdminCalls() public {
        // Admin batches two governance calls in one tx
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(CeitnotEngine.setHeartbeat, (2 days));
        calls[1] = abi.encodeCall(CeitnotEngine.setMinHarvestYieldDebt, (10 * WAD));

        engine.multicall(calls);
        // Verify both took effect (use view functions if available — heartbeat is not directly exposed,
        // but the calls succeeding without revert is the key assertion)
    }

    function test_multicall_revertPropagates() public {
        // Batch a valid call followed by an invalid one; the whole tx should revert
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(CeitnotEngine.setHeartbeat, (1 days));
        // depositCollateral with 0 shares → Ceitnot__ZeroAmount
        calls[1] = abi.encodeCall(CeitnotEngine.depositCollateral, (alice, MARKET_ID, 0));

        vm.expectRevert(CeitnotEngine.Ceitnot__ZeroAmount.selector);
        engine.multicall(calls);
    }

    // =========================================================================
    // 3. Delegate / Operator Pattern
    // =========================================================================

    function test_delegate_setAndGet() public {
        assertFalse(engine.isDelegate(alice, bob));

        vm.prank(alice);
        engine.setDelegate(bob, true);

        assertTrue(engine.isDelegate(alice, bob));

        vm.prank(alice);
        engine.setDelegate(bob, false);
        assertFalse(engine.isDelegate(alice, bob));
    }

    function test_delegate_setEmitsEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit DelegateSet(alice, bob, true);
        engine.setDelegate(bob, true);
    }

    function test_delegate_borrow_viaDelegate() public {
        // Alice deposits, then authorises bob to borrow on her behalf
        vm.prank(alice);
        engine.depositCollateral(alice, MARKET_ID, 200 * WAD);

        vm.prank(alice);
        engine.setDelegate(bob, true);

        vm.roll(block.number + 1);

        vm.prank(bob); // bob borrows FOR alice
        engine.borrow(alice, MARKET_ID, 50 * WAD);

        assertEq(ausd.balanceOf(alice), 50 * WAD, "alice should receive the aUSD");
        assertGt(engine.getPositionDebt(alice, MARKET_ID), 0, "alice has debt");
    }

    function test_delegate_repay_viaDelegate() public {
        _depositAndBorrowLegacy(alice, 200 * WAD, 50 * WAD);

        vm.prank(alice);
        engine.setDelegate(bob, true);
        vm.prank(alice);
        ausd.approve(address(proxy), type(uint256).max);

        vm.roll(block.number + 1);

        uint256 debtBefore = engine.getPositionDebt(alice, MARKET_ID);

        vm.prank(bob); // bob repays FOR alice (burns from alice)
        engine.repay(alice, MARKET_ID, 20 * WAD);

        assertLt(engine.getPositionDebt(alice, MARKET_ID), debtBefore);
        assertEq(ausd.balanceOf(alice), 30 * WAD, "alice's aUSD reduced");
    }

    function test_delegate_unauthorized_reverts() public {
        vm.prank(alice);
        engine.depositCollateral(alice, MARKET_ID, 200 * WAD);
        vm.roll(block.number + 1);

        // bob is NOT a delegate
        vm.prank(bob);
        vm.expectRevert(CeitnotEngine.Ceitnot__Unauthorized.selector);
        engine.borrow(alice, MARKET_ID, 10 * WAD);
    }

    // =========================================================================
    // 4. Compound engine functions
    // =========================================================================

    function test_compound_depositAndBorrow_directCall() public {
        uint256 shares = 200 * WAD;
        uint256 borrow = 80 * WAD;

        vm.prank(alice);
        engine.depositAndBorrow(alice, MARKET_ID, shares, borrow);

        assertEq(engine.getPositionCollateralShares(alice, MARKET_ID), shares);
        assertEq(engine.getPositionDebt(alice, MARKET_ID), borrow);
        assertEq(ausd.balanceOf(alice), borrow);
    }

    function test_compound_depositAndBorrow_emitsEvents() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit DepositAndBorrowed(alice, MARKET_ID, 100 * WAD, 40 * WAD);
        engine.depositAndBorrow(alice, MARKET_ID, 100 * WAD, 40 * WAD);
    }

    function test_compound_repayAndWithdraw_directCall() public {
        // Setup: deposit + borrow
        vm.prank(alice);
        engine.depositAndBorrow(alice, MARKET_ID, 200 * WAD, 80 * WAD);

        vm.prank(alice);
        ausd.approve(address(proxy), type(uint256).max);

        vm.roll(block.number + 1);

        uint256 vaultBefore = vault.balanceOf(alice);

        vm.prank(alice);
        engine.repayAndWithdraw(alice, MARKET_ID, 40 * WAD, 50 * WAD);

        assertEq(engine.getPositionDebt(alice, MARKET_ID), 40 * WAD, "half repaid");
        assertEq(engine.getPositionCollateralShares(alice, MARKET_ID), 150 * WAD, "half withdrawn");
        assertEq(vault.balanceOf(alice), vaultBefore + 50 * WAD, "vault shares returned to alice");
    }

    function test_compound_repayAndWithdraw_emitsEvent() public {
        vm.prank(alice);
        engine.depositAndBorrow(alice, MARKET_ID, 200 * WAD, 80 * WAD);
        vm.prank(alice);
        ausd.approve(address(proxy), type(uint256).max);
        vm.roll(block.number + 1);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit RepaidAndWithdrawn(alice, MARKET_ID, 40 * WAD, 50 * WAD);
        engine.repayAndWithdraw(alice, MARKET_ID, 40 * WAD, 50 * WAD);
    }

    // =========================================================================
    // 5. CeitnotRouter flows
    // =========================================================================

    function test_router_depositCollateral() public {
        uint256 shares = 100 * WAD;

        vm.prank(alice);
        router.depositCollateral(MARKET_ID, address(vault), shares);

        assertEq(engine.getPositionCollateralShares(alice, MARKET_ID), shares);
    }

    function test_router_depositAndBorrow() public {
        uint256 shares = 200 * WAD;
        uint256 borrow = 80 * WAD;

        // Alice must set router as delegate for the borrow portion
        vm.prank(alice);
        engine.setDelegate(address(router), true);

        vm.prank(alice);
        router.depositAndBorrow(MARKET_ID, address(vault), shares, borrow);

        assertEq(engine.getPositionCollateralShares(alice, MARKET_ID), shares);
        assertEq(ausd.balanceOf(alice), borrow);
    }

    function test_router_repayAndWithdraw() public {
        // Setup position via router
        vm.prank(alice);
        engine.setDelegate(address(router), true);

        vm.prank(alice);
        router.depositAndBorrow(MARKET_ID, address(vault), 200 * WAD, 80 * WAD);

        vm.prank(alice);
        ausd.approve(address(proxy), type(uint256).max);

        vm.roll(block.number + 1);

        uint256 vaultBefore = vault.balanceOf(alice);

        vm.prank(alice);
        router.repayAndWithdraw(MARKET_ID, 40 * WAD, 50 * WAD);

        assertEq(engine.getPositionDebt(alice, MARKET_ID), 40 * WAD);
        assertEq(engine.getPositionCollateralShares(alice, MARKET_ID), 150 * WAD);
        assertEq(vault.balanceOf(alice), vaultBefore + 50 * WAD);
    }

    function test_router_repayWithPermit() public {
        _depositAndBorrowLegacy(alice, 200 * WAD, 50 * WAD);

        vm.prank(alice);
        engine.setDelegate(address(router), true);

        vm.roll(block.number + 1);

        uint256 repayAmt = 20 * WAD;
        uint256 deadline = block.timestamp + 1 hours;
        // Sign permit: alice approves ENGINE (not router) for repayAmt
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                alice, address(proxy), repayAmt, ausd.nonces(alice), deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", ausd.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PK, digest);

        uint256 debtBefore = engine.getPositionDebt(alice, MARKET_ID);

        vm.prank(alice);
        router.repayWithPermit(MARKET_ID, repayAmt, deadline, v, r, s);

        assertLt(engine.getPositionDebt(alice, MARKET_ID), debtBefore);
    }

    function test_router_leverageUp_aliasWorks() public {
        vm.prank(alice);
        engine.setDelegate(address(router), true);

        vm.prank(alice);
        router.leverageUp(MARKET_ID, address(vault), 200 * WAD, 80 * WAD);

        assertGt(engine.getPositionCollateralShares(alice, MARKET_ID), 0);
        assertEq(ausd.balanceOf(alice), 80 * WAD);
    }

    function test_router_leverageDown_aliasWorks() public {
        vm.prank(alice);
        engine.setDelegate(address(router), true);

        vm.prank(alice);
        router.leverageUp(MARKET_ID, address(vault), 200 * WAD, 80 * WAD);

        vm.prank(alice);
        ausd.approve(address(proxy), type(uint256).max);
        vm.roll(block.number + 1);

        vm.prank(alice);
        router.leverageDown(MARKET_ID, 40 * WAD, 50 * WAD);

        assertEq(engine.getPositionDebt(alice, MARKET_ID), 40 * WAD);
        assertEq(engine.getPositionCollateralShares(alice, MARKET_ID), 150 * WAD);
    }
}
