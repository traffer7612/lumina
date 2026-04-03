// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test }                from "forge-std/Test.sol";
import { IGovernor }           from "@openzeppelin/contracts/governance/IGovernor.sol";
import { TimelockController }  from "@openzeppelin/contracts/governance/TimelockController.sol";
import { IVotes }              from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { CeitnotToken }           from "../src/governance/CeitnotToken.sol";
import { VeCeitnot }              from "../src/governance/VeCeitnot.sol";
import { CeitnotGovernor }        from "../src/governance/CeitnotGovernor.sol";
import { MockERC20 }           from "./mocks/MockERC20.sol";

/**
 * @title  GovernanceTest
 * @notice Phase 7 — Governance contracts test suite.
 *         Covers CeitnotToken, VeCeitnot (lock/withdraw/revenue), and CeitnotGovernor
 *         (propose → vote → queue → execute full cycle).
 *
 *  Actor layout:
 *    address(this) = DEPLOYER — initial minter & VeCeitnot admin, handing off to timelock in setUp
 *    alice         = 2 M CEITNOT — primary voter / proposer
 *    bob           = 1 M CEITNOT — beneficiary of governance minting in full-cycle test
 */
contract GovernanceTest is Test {
    // ── contracts ────────────────────────────────────────────────────────────
    CeitnotToken           public govToken;
    VeCeitnot              public veLock;
    CeitnotGovernor        public governor;
    TimelockController  public timelock;
    MockERC20           public revenueToken;

    // ── actors ────────────────────────────────────────────────────────────────
    address public alice = address(0xA11CE);
    address public bob   = address(0xB0B);

    // ── constants ─────────────────────────────────────────────────────────────
    uint256 constant WAD             = 1e18;
    uint256 constant ONE_MILLION     = 1_000_000 * WAD;
    uint256 constant TWO_MILLION     = 2_000_000 * WAD;
    uint256 constant PROPOSAL_THRESH = 100_000  * WAD;
    uint256 constant MAX_LOCK        = 4 * 365 days;  // 4 years
    uint256 constant EPOCH           = 1 weeks;

    // ── setUp ─────────────────────────────────────────────────────────────────
    function setUp() public {
        // Anchor block.timestamp to a realistic value (avoids clock()-1 underflow)
        vm.warp(1_700_000_000);

        revenueToken = new MockERC20("Revenue", "REV", 18);

        // 1. CeitnotToken — minter = address(this)
        govToken = new CeitnotToken(address(this));

        // 2. VeCeitnot — admin = address(this) initially
        veLock = new VeCeitnot(address(govToken), address(this), address(revenueToken));

        // 3. TimelockController — minDelay 48h, no initial proposers,
        //    open executor (address(0) gets EXECUTOR_ROLE → anyone can execute)
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(48 hours, proposers, executors, address(this));

        // 4. CeitnotGovernor
        governor = new CeitnotGovernor(IVotes(address(veLock)), timelock);

        // 5. Grant Governor the PROPOSER + CANCELLER roles on the timelock
        timelock.grantRole(timelock.PROPOSER_ROLE(),   address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(),  address(governor));

        // 6. Mint tokens to test actors while address(this) is still minter
        govToken.mint(alice, TWO_MILLION);
        govToken.mint(bob,   ONE_MILLION);

        // 7. Hand off minter & admin control to the timelock
        govToken.setMinter(address(timelock));
        veLock.setAdmin(address(timelock));
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    /**
     * @dev Lock `amount` CEITNOT for alice at maximum lock duration, then
     *      vm.warp(+1 second) so getPastVotes works at the lock timestamp.
     */
    function _aliceLockMaxAndWarp(uint256 amount) internal {
        uint256 unlock = (block.timestamp + MAX_LOCK) / EPOCH * EPOCH;
        vm.startPrank(alice);
        govToken.approve(address(veLock), amount);
        veLock.lock(amount, unlock);
        vm.stopPrank();
        vm.warp(block.timestamp + 1);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // CeitnotToken
    // ══════════════════════════════════════════════════════════════════════════

    /// Supply cap constant is correct.
    function test_token_supplyCap() public view {
        assertEq(govToken.SUPPLY_CAP(), 100_000_000 * WAD);
    }

    /// EIP-6372 clock uses block.timestamp.
    function test_token_clockModeIsTimestamp() public view {
        assertEq(govToken.CLOCK_MODE(), "mode=timestamp");
        assertEq(govToken.clock(), uint48(block.timestamp));
    }

    /// Constructor mints were received by alice and bob.
    function test_token_initialBalances() public view {
        assertEq(govToken.balanceOf(alice), TWO_MILLION);
        assertEq(govToken.balanceOf(bob),   ONE_MILLION);
    }

    /// Non-minter cannot mint.
    function test_token_mintByNonMinter_reverts() public {
        vm.prank(alice);
        vm.expectRevert(CeitnotToken.Token__Unauthorized.selector);
        govToken.mint(alice, WAD);
    }

    /// Minting beyond the supply cap reverts.
    function test_token_mintExceedsCap_reverts() public {
        CeitnotToken fresh = new CeitnotToken(address(this));
        fresh.mint(alice, 99_999_999 * WAD);
        vm.expectRevert(CeitnotToken.Token__SupplyCapExceeded.selector);
        fresh.mint(alice, 2 * WAD); // would push totalSupply to 100_000_001e18
    }

    /// Non-minter cannot change the minter.
    function test_token_setMinterByNonMinter_reverts() public {
        vm.prank(alice);
        vm.expectRevert(CeitnotToken.Token__Unauthorized.selector);
        govToken.setMinter(alice);
    }

    /// Minter role cannot be transferred to address(0).
    function test_token_setMinterZeroAddress_reverts() public {
        CeitnotToken fresh = new CeitnotToken(address(this));
        vm.expectRevert(CeitnotToken.Token__ZeroAddress.selector);
        fresh.setMinter(address(0));
    }

    /// Constructor rejects zero minter.
    function test_token_constructorZeroMinter_reverts() public {
        vm.expectRevert(CeitnotToken.Token__ZeroAddress.selector);
        new CeitnotToken(address(0));
    }

    // ══════════════════════════════════════════════════════════════════════════
    // VeCeitnot — lock mechanics
    // ══════════════════════════════════════════════════════════════════════════

    /// Lock stores amount and unlockTime; totalLocked is updated.
    function test_VeCeitnot_lock_succeeds() public {
        uint256 amount = ONE_MILLION;
        uint256 unlock = (block.timestamp + MAX_LOCK) / EPOCH * EPOCH;

        vm.startPrank(alice);
        govToken.approve(address(veLock), amount);
        veLock.lock(amount, unlock);
        vm.stopPrank();

        (uint128 locked, uint48 unlockTime) = veLock.locks(alice);
        assertEq(locked, amount);
        assertEq(unlockTime, unlock);
        assertEq(veLock.totalLocked(), amount);
    }

    /// Locking zero reverts.
    function test_VeCeitnot_lock_zeroAmount_reverts() public {
        uint256 unlock = (block.timestamp + MAX_LOCK) / EPOCH * EPOCH;
        vm.prank(alice);
        vm.expectRevert(VeCeitnot.VeCeitnot__ZeroAmount.selector);
        veLock.lock(0, unlock);
    }

    /// A second lock from the same user reverts.
    function test_VeCeitnot_lock_existingLock_reverts() public {
        _aliceLockMaxAndWarp(ONE_MILLION);

        uint256 unlock = (block.timestamp + MAX_LOCK) / EPOCH * EPOCH;
        vm.startPrank(alice);
        govToken.approve(address(veLock), ONE_MILLION);
        vm.expectRevert(VeCeitnot.VeCeitnot__LockExists.selector);
        veLock.lock(ONE_MILLION, unlock);
        vm.stopPrank();
    }

    /// Voting power is non-zero after a lock and a block advance.
    function test_VeCeitnot_votingPower_nonZeroAfterLock() public {
        _aliceLockMaxAndWarp(ONE_MILLION);
        uint256 vp = veLock.getPastVotes(alice, block.timestamp - 1);
        assertGt(vp, 0);
        assertGt(veLock.getVotes(alice), 0);
    }

    /// increaseAmount adds to the existing lock.
    function test_VeCeitnot_increaseAmount_succeeds() public {
        _aliceLockMaxAndWarp(ONE_MILLION);

        uint256 extra = 500_000 * WAD;
        vm.startPrank(alice);
        govToken.approve(address(veLock), extra);
        veLock.increaseAmount(extra);
        vm.stopPrank();

        (uint128 locked,) = veLock.locks(alice);
        assertEq(locked, ONE_MILLION + extra);
        assertEq(veLock.totalLocked(), ONE_MILLION + extra);
    }

    /// extendLock increases the unlock time.
    function test_VeCeitnot_extendLock_succeeds() public {
        uint256 amount  = ONE_MILLION;
        // Initial lock for 1 year
        uint256 unlock1 = (block.timestamp + 365 days) / EPOCH * EPOCH;

        vm.startPrank(alice);
        govToken.approve(address(veLock), amount);
        veLock.lock(amount, unlock1);
        vm.stopPrank();
        vm.warp(block.timestamp + 1);

        // Extend to 2 years from current time (still within MAX_LOCK)
        uint256 unlock2 = (block.timestamp + 2 * 365 days) / EPOCH * EPOCH;

        vm.prank(alice);
        veLock.extendLock(unlock2);

        (, uint48 updated) = veLock.locks(alice);
        assertEq(updated, uint48(unlock2));
    }

    /// Withdraw succeeds after lock expiry and returns tokens.
    function test_VeCeitnot_withdraw_afterExpiry() public {
        uint256 amount = ONE_MILLION;
        // Short lock: 2 epochs from now
        uint256 unlock = (block.timestamp + 2 * EPOCH) / EPOCH * EPOCH;

        vm.startPrank(alice);
        govToken.approve(address(veLock), amount);
        veLock.lock(amount, unlock);
        vm.stopPrank();

        vm.warp(unlock + 1);

        uint256 before = govToken.balanceOf(alice);
        vm.prank(alice);
        veLock.withdraw();

        assertEq(govToken.balanceOf(alice), before + amount);
        assertEq(veLock.totalLocked(), 0);
        (uint128 locked,) = veLock.locks(alice);
        assertEq(locked, 0);
    }

    /// Withdraw before expiry reverts.
    function test_VeCeitnot_withdraw_beforeExpiry_reverts() public {
        _aliceLockMaxAndWarp(ONE_MILLION);
        vm.prank(alice);
        vm.expectRevert(VeCeitnot.VeCeitnot__LockNotExpired.selector);
        veLock.withdraw();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // VeCeitnot — revenue distribution
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * @dev Use a fresh VeCeitnot instance (admin = address(this)) so that the
     *      test contract can call distributeRevenue without going through
     *      governance.
     */
    function test_VeCeitnot_revenue_distributeAndClaim() public {
        VeCeitnot ve2 = new VeCeitnot(address(govToken), address(this), address(revenueToken));

        uint256 lockAmt = ONE_MILLION;
        uint256 revAmt  = 1_000 * WAD;
        uint256 unlock  = (block.timestamp + MAX_LOCK) / EPOCH * EPOCH;

        // Alice locks into ve2
        vm.startPrank(alice);
        govToken.approve(address(ve2), lockAmt);
        ve2.lock(lockAmt, unlock);
        vm.stopPrank();

        // Distribute revenue — address(this) is admin & pre-approves ve2
        revenueToken.mint(address(this), revAmt);
        revenueToken.approve(address(ve2), revAmt);
        ve2.distributeRevenue(revAmt);

        // Alice holds 100% of totalLocked → earns the full revAmt
        assertEq(ve2.pendingRevenue(alice), revAmt);

        // Claim
        vm.prank(alice);
        ve2.claimRevenue();

        assertEq(revenueToken.balanceOf(alice), revAmt);
        assertEq(ve2.pendingRevenue(alice), 0);
    }

    /// Non-admin cannot distribute revenue.
    function test_VeCeitnot_revenue_nonAdmin_reverts() public {
        VeCeitnot ve2 = new VeCeitnot(address(govToken), address(this), address(revenueToken));
        uint256 unlock = (block.timestamp + MAX_LOCK) / EPOCH * EPOCH;

        vm.startPrank(alice);
        govToken.approve(address(ve2), ONE_MILLION);
        ve2.lock(ONE_MILLION, unlock);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(VeCeitnot.VeCeitnot__Unauthorized.selector);
        ve2.distributeRevenue(100 * WAD);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // CeitnotGovernor — parameters & configuration
    // ══════════════════════════════════════════════════════════════════════════

    function test_governor_parameters() public view {
        assertEq(governor.votingDelay(),       1 days);
        assertEq(governor.votingPeriod(),      7 days);
        assertEq(governor.proposalThreshold(), PROPOSAL_THRESH);
        assertEq(address(governor.timelock()), address(timelock));
        assertEq(governor.name(),              "CeitnotGovernor");
    }

    function test_governor_quorumFraction() public view {
        assertEq(governor.quorumNumerator(),   4);
        assertEq(governor.quorumDenominator(), 100);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // CeitnotGovernor — proposal access control
    // ══════════════════════════════════════════════════════════════════════════

    /// Bob has tokens but no VeCeitnot → 0 votes → below proposalThreshold → revert.
    function test_governor_propose_belowThreshold_reverts() public {
        address[] memory targets   = new address[](1);
        targets[0] = address(0x1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        calldatas[0] = "";

        vm.prank(bob);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "Bob proposal");
    }

    // ══════════════════════════════════════════════════════════════════════════
    // CeitnotGovernor — full governance lifecycle
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Full cycle: Propose → (Active) → Vote → (Succeeded) →
     *         Queue → (Queued) → Execute → verify on-chain effect.
     *
     *         The proposal mints 1000 CEITNOT to bob via the timelock (which is the
     *         token minter after setUp).
     */
    function test_governor_fullCycle_proposeVoteQueueExecute() public {
        // ─── 1. Alice locks 2M CEITNOT for max duration ────────────────────────
        _aliceLockMaxAndWarp(TWO_MILLION);

        // ─── 2. Build proposal: mint 1000 CEITNOT to bob via timelock ──────────
        address[] memory targets   = new address[](1);
        targets[0] = address(govToken);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("mint(address,uint256)", bob, 1_000 * WAD);
        string  memory desc     = "Governance: mint 1000 CEITNOT to bob";
        bytes32 descHash        = keccak256(bytes(desc));

        // ─── 3. Propose (requires votingPower at clock()-1 >= 100K) ─────────
        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);

        // Immediately after propose: Pending (voteStart not yet reached)
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // ─── 4. Fast-forward past voting delay (1 day) ──────────────────────
        vm.warp(block.timestamp + 1 days + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // ─── 5. Alice votes For ──────────────────────────────────────────────
        vm.prank(alice);
        governor.castVote(proposalId, 1); // 1 = For

        // ─── 6. Fast-forward past voting period (7 days) ────────────────────
        vm.warp(block.timestamp + 7 days + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // ─── 7. Queue in timelock ────────────────────────────────────────────
        governor.queue(targets, values, calldatas, descHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // ─── 8. Fast-forward past timelock delay (48 h) ─────────────────────
        vm.warp(block.timestamp + 48 hours + 1);

        // ─── 9. Execute and verify on-chain effect ───────────────────────────
        uint256 bobBefore = govToken.balanceOf(bob);
        governor.execute(targets, values, calldatas, descHash);

        assertEq(govToken.balanceOf(bob), bobBefore + 1_000 * WAD);
    }

    /**
     * @notice Proposal is Defeated when the entire voting window passes with
     *         zero votes cast (quorum not reached).
     */
    function test_governor_proposalDefeated_whenNoVotes() public {
        _aliceLockMaxAndWarp(TWO_MILLION);

        address[] memory targets   = new address[](1);
        targets[0] = address(0x1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        calldatas[0] = "";

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "No vote proposal");

        // Let the entire voting window expire without any votes
        vm.warp(block.timestamp + 1 days + 7 days + 2);

        // forVotes = 0 < quorum(4% of 2M) = 80K → Defeated
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }
}
