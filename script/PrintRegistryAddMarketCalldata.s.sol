// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";

import { AuraMarketRegistry } from "../src/AuraMarketRegistry.sol";

/**
 * @title PrintRegistryAddMarketCalldata
 * @notice Simulates only: prints calldata for `AuraMarketRegistry.addMarket` so you can paste into
 *         Governor `propose` (target = registry, value = 0, calldata = printed bytes). After vote,
 *         `queue` then Timelock `execute` as usual.
 *
 * Required env:
 *   VAULT_ADDRESS, ORACLE_ADDRESS
 *
 * Optional risk / caps (defaults match typical stable-ish deploy):
 *   LTV_BPS, LIQ_THRESHOLD_BPS, LIQ_PENALTY_BPS — default 9000, 9300, 300
 *   SUPPLY_CAP, BORROW_CAP — default 0, 0
 *   IS_ISOLATED — default false (0 = false, 1 = true)
 *   ISOLATED_BORROW_CAP — default 0
 *
 * Usage (no broadcast):
 *   VAULT_ADDRESS=0x... ORACLE_ADDRESS=0x... \\
 *     forge script script/PrintRegistryAddMarketCalldata.s.sol:PrintRegistryAddMarketCalldata \\
 *     --rpc-url https://arb1.arbitrum.io/rpc -vv
 */
contract PrintRegistryAddMarketCalldata is Script {
    function run() external {
        address vault = vm.envAddress("VAULT_ADDRESS");
        address oracle = vm.envAddress("ORACLE_ADDRESS");

        uint16 ltv = uint16(vm.envOr("LTV_BPS", uint256(9000)));
        uint16 liq = uint16(vm.envOr("LIQ_THRESHOLD_BPS", uint256(9300)));
        uint16 pen = uint16(vm.envOr("LIQ_PENALTY_BPS", uint256(300)));
        uint256 supplyCap = vm.envOr("SUPPLY_CAP", uint256(0));
        uint256 borrowCap = vm.envOr("BORROW_CAP", uint256(0));
        bool isolated = vm.envOr("IS_ISOLATED", uint256(0)) != 0;
        uint256 isoBorrow = vm.envOr("ISOLATED_BORROW_CAP", uint256(0));

        bytes memory data = abi.encodeCall(
            AuraMarketRegistry.addMarket,
            (vault, oracle, ltv, liq, pen, supplyCap, borrowCap, isolated, isoBorrow)
        );

        console.log("=== addMarket calldata for Governor / Timelock ===");
        console.log("target: REGISTRY_ADDRESS (AuraMarketRegistry)");
        console.log("value:  0");
        console.log("vault:  %s", vault);
        console.log("oracle: %s", oracle);
        console.log("ltv/liq/pen bps: %s / %s / %s", uint256(ltv), uint256(liq), uint256(pen));
        console.log("calldata (hex):");
        console.logBytes(data);
    }
}
