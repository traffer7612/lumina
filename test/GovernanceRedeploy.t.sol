// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";

import { CeitnotToken } from "../src/governance/CeitnotToken.sol";
import { VeCeitnot } from "../src/governance/VeCeitnot.sol";
import { CeitnotGovernor } from "../src/governance/CeitnotGovernor.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract GovernanceRedeployTest is Test {
    CeitnotToken public govToken;
    VeCeitnot public veLock;
    CeitnotGovernor public governor;
    TimelockController public timelock;
    MockERC20 public revenueToken;
    MockERC20 public nextRevenueToken;

    address public alice = address(0xA11CE);
    address public bob   = address(0xB0B);

    uint256 constant WAD         = 1e18;
    uint256 constant TWO_MILLION = 2_000_000 * WAD;
    uint256 constant MAX_LOCK    = 4 * 365 days;
    uint256 constant EPOCH       = 1 weeks;

    function setUp() public {
        vm.warp(1_700_000_000);

        revenueToken = new MockERC20("Revenue", "REV", 18);
        nextRevenueToken = new MockERC20("RevenueV2", "REV2", 18);

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(48 hours, proposers, executors, address(this));

        // Fresh governance stack bound to an existing timelock.
        govToken = new CeitnotToken(address(this));
        veLock = new VeCeitnot(address(govToken), address(this), address(revenueToken));
        governor = new CeitnotGovernor(IVotes(address(veLock)), timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        govToken.mint(alice, TWO_MILLION);

        // Critical hand-off required for timelock-executed governance actions.
        govToken.setMinter(address(timelock));
        veLock.setAdmin(address(timelock));
    }

    function _aliceLockMaxAndWarp(uint256 amount) internal {
        uint256 unlock = (block.timestamp + MAX_LOCK) / EPOCH * EPOCH;
        vm.startPrank(alice);
        govToken.approve(address(veLock), amount);
        veLock.lock(amount, unlock);
        vm.stopPrank();
        vm.warp(block.timestamp + 1);
    }

    function test_redeploy_fullTimelockBatch_executesWithoutBreaking() public {
        _aliceLockMaxAndWarp(TWO_MILLION);

        address[] memory targets = new address[](2);
        targets[0] = address(govToken);
        targets[1] = address(veLock);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](2);

        uint256 mintAmount = 1_500 * WAD;
        calldatas[0] = abi.encodeWithSignature("mint(address,uint256)", bob, mintAmount);
        calldatas[1] = abi.encodeWithSignature("setRevenueToken(address)", address(nextRevenueToken));
        string memory desc = "Governance redeploy sanity: mint + revenue token update";
        bytes32 descHash = keccak256(bytes(desc));

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);

        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.warp(block.timestamp + 7 days + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        governor.queue(targets, values, calldatas, descHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        vm.warp(block.timestamp + 48 hours + 1);

        uint256 bobBefore = govToken.balanceOf(bob);
        governor.execute(targets, values, calldatas, descHash);

        assertEq(govToken.balanceOf(bob), bobBefore + mintAmount);
        assertEq(veLock.revenueToken(), address(nextRevenueToken));
        assertEq(govToken.minter(), address(timelock));
        assertEq(veLock.admin(), address(timelock));
        assertEq(address(governor.timelock()), address(timelock));
    }
}
