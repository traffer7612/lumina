// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console2 } from "forge-std/Script.sol";
import { CeitnotEngine } from "../src/CeitnotEngine.sol";

/**
 * @title DeployEngineImpl
 * @notice Deploys a **new** CeitnotEngine implementation (no init — for UUPS `upgradeToAndCall`).
 *
 * After broadcast:
 *   1. Copy printed `NEW_IMPLEMENTATION` into env.
 *   2. If admin is Safe: `DRY_RUN=true forge script script/UpgradeEngine.s.sol ...` and submit printed calldata.
 *   3. If admin is EOA: `forge script script/UpgradeEngine.s.sol ...` with broadcast wallet.
 */
contract DeployEngineImpl is Script {
    function run() external returns (address impl) {
        vm.startBroadcast();
        impl = address(new CeitnotEngine());
        vm.stopBroadcast();
        console2.log("NEW_IMPLEMENTATION (set env then run UpgradeEngine):");
        console2.logAddress(impl);
    }
}
