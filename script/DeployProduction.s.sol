// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { CeitnotEngine }         from "../src/CeitnotEngine.sol";
import { CeitnotProxy }          from "../src/CeitnotProxy.sol";
import { CeitnotMarketRegistry } from "../src/CeitnotMarketRegistry.sol";
import { OracleRelay }        from "../src/OracleRelay.sol";

/**
 * Production deploy: USDC as debt token, existing ERC-4626 vault, Chainlink oracle.
 * No mocks. After deploy, transfer USDC to the proxy so users can borrow.
 *
 * Required env:
 *   COLLATERAL_VAULT   - ERC-4626 vault address (e.g. stETH vault)
 *   USDC_ADDRESS      - USDC (or other stable) contract address
 *   CHAINLINK_FEED    - Chainlink aggregator for collateral price in USD
 *   FALLBACK_FEED     - Optional: RedStone or other fallback (address(0) to skip)
 */
contract DeployProduction is Script {
    function run() external returns (address proxy) {
        address collateralVault = vm.envOr("COLLATERAL_VAULT", address(0));
        address usdc            = vm.envOr("USDC_ADDRESS",     address(0));
        address chainlinkFeed   = vm.envOr("CHAINLINK_FEED",   address(0));
        address fallbackFeed    = vm.envOr("FALLBACK_FEED",    address(0));
        uint256 twapPeriod      = vm.envOr("TWAP_PERIOD",      uint256(0));

        require(collateralVault != address(0), "COLLATERAL_VAULT");
        require(usdc            != address(0), "USDC_ADDRESS");
        require(chainlinkFeed   != address(0), "CHAINLINK_FEED");

        vm.startBroadcast();

        OracleRelay oracle = new OracleRelay(chainlinkFeed, fallbackFeed, twapPeriod);

        // 1. Registry + first market
        CeitnotMarketRegistry registry = new CeitnotMarketRegistry(msg.sender);
        registry.addMarket(
            collateralVault,
            address(oracle),
            uint16(8000),
            uint16(8500),
            uint16(500),
            0, 0, false, 0
        );

        // 2. Engine
        CeitnotEngine implementation = new CeitnotEngine();
        bytes memory initData = abi.encodeCall(
            CeitnotEngine.initialize,
            (usdc, address(registry), uint256(1 days), uint256(2 days))
        );
        CeitnotProxy proxyContract = new CeitnotProxy(address(implementation), initData);
        proxy = address(proxyContract);
        registry.setEngine(proxy);

        vm.stopBroadcast();

        console.log("CEITNOT_ENGINE_ADDRESS=%s", proxy);
        console.log("CEITNOT_REGISTRY_ADDRESS=%s", address(registry));
        console.log("ORACLE_RELAY_ADDRESS=%s", address(oracle));
        console.log("Next: transfer USDC to the engine so users can borrow.");
    }
}
