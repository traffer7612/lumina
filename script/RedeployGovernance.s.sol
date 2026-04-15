// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { CeitnotToken } from "../src/governance/CeitnotToken.sol";
import { VeCeitnot } from "../src/governance/VeCeitnot.sol";
import { CeitnotGovernor } from "../src/governance/CeitnotGovernor.sol";

import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title RedeployGovernance
 * @notice Deploy a fresh governance stack (CeitnotToken + VeCeitnot + CeitnotGovernor)
 *         and bind it to an existing TimelockController.
 *
 * Required env:
 *   EXISTING_TIMELOCK        - TimelockController address that should execute governance payloads
 *   REVENUE_TOKEN            - Revenue token for VeCeitnot (typically CeitnotUSD)
 *
 * Optional env:
 *   GOVERNANCE_TOKEN_MINT    - Initial CEITNOT mint to deployer (default: 10_000_000e18)
 *   GRANT_GOVERNOR_ROLES     - Grant PROPOSER + CANCELLER on timelock to new governor (default: true)
 *   HANDOFF_TO_TIMELOCK      - Transfer CeitnotToken minter and VeCeitnot admin to timelock (default: true)
 *
 * Usage:
 *   forge script script/RedeployGovernance.s.sol:RedeployGovernance \
 *     --rpc-url <RPC> --broadcast --private-key <PK>
 */
contract RedeployGovernance is Script {
    function run() external {
        address timelockAddr = vm.envAddress("EXISTING_TIMELOCK");
        address revenueToken = vm.envAddress("REVENUE_TOKEN");
        uint256 initialMint = vm.envOr("GOVERNANCE_TOKEN_MINT", uint256(10_000_000 * 1e18));
        bool grantGovernorRoles = vm.envOr("GRANT_GOVERNOR_ROLES", true);
        bool handoffToTimelock = vm.envOr("HANDOFF_TO_TIMELOCK", true);

        require(timelockAddr != address(0), "RedeployGovernance: EXISTING_TIMELOCK required");
        require(revenueToken != address(0), "RedeployGovernance: REVENUE_TOKEN required");

        vm.startBroadcast();

        address deployer = msg.sender;
        TimelockController timelock = TimelockController(payable(timelockAddr));

        CeitnotToken govToken = new CeitnotToken(deployer);
        if (initialMint > 0) {
            govToken.mint(deployer, initialMint);
        }

        VeCeitnot veLock = new VeCeitnot(address(govToken), deployer, revenueToken);
        CeitnotGovernor governor = new CeitnotGovernor(IVotes(address(veLock)), timelock);

        if (grantGovernorRoles) {
            timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
            timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        }

        if (handoffToTimelock) {
            govToken.setMinter(address(timelock));
            veLock.setAdmin(address(timelock));
        }

        vm.stopBroadcast();

        console.log("=== GOVERNANCE REDEPLOY ===");
        console.log("TIMELOCK:              %s", timelockAddr);
        console.log("CEITNOT_TOKEN:         %s", address(govToken));
        console.log("CEITNOT_VE:            %s", address(veLock));
        console.log("GOVERNOR:              %s", address(governor));
        console.log("REVENUE_TOKEN:         %s", revenueToken);
        console.log("GOVERNANCE_TOKEN_MINT: %s", initialMint);
        console.log("GRANT_GOVERNOR_ROLES:  %s", grantGovernorRoles ? "true" : "false");
        console.log("HANDOFF_TO_TIMELOCK:   %s", handoffToTimelock ? "true" : "false");
    }
}
