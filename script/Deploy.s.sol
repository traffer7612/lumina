// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { CeitnotEngine }         from "../src/CeitnotEngine.sol";
import { CeitnotProxy }          from "../src/CeitnotProxy.sol";
import { CeitnotMarketRegistry } from "../src/CeitnotMarketRegistry.sol";
import { MockERC20 }          from "../test/mocks/MockERC20.sol";
import { MockVault4626 }      from "../test/mocks/MockVault4626.sol";
import { MockOracle }         from "../test/mocks/MockOracle.sol";

contract DeployScript is Script {
    function run() external returns (address proxy) {
        vm.startBroadcast();

        MockERC20     assetToken      = new MockERC20("Wrapped stETH", "wstETH", 18);
        MockERC20     debtToken       = new MockERC20("USD Coin", "USDC", 18);
        MockVault4626 collateralVault = new MockVault4626(address(assetToken), "Ceitnot wstETH Vault", "wstETH");
        MockOracle    oracle          = new MockOracle();

        // 1. Deploy registry and register the first market (wstETH, 80% LTV, 85% LT, 5% pen)
        CeitnotMarketRegistry registry = new CeitnotMarketRegistry(msg.sender);
        registry.addMarket(
            address(collateralVault),
            address(oracle),
            uint16(8000),
            uint16(8500),
            uint16(500),
            0, 0, false, 0
        );

        // 2. Deploy engine (implementation + proxy)
        CeitnotEngine implementation = new CeitnotEngine();
        bytes memory initData = abi.encodeCall(
            CeitnotEngine.initialize,
            (
                address(debtToken),
                address(registry),
                uint256(1 days),
                uint256(2 days)
            )
        );
        CeitnotProxy proxyContract = new CeitnotProxy(address(implementation), initData);
        proxy = address(proxyContract);

        // 3. Allow engine to update market risk params after timelock
        registry.setEngine(proxy);

        debtToken.mint(proxy, 1_000_000 * 1e18);
        assetToken.mint(msg.sender, 10_000 * 1e18);

        vm.stopBroadcast();

        console.log("CEITNOT_ENGINE_ADDRESS=%s", proxy);
        console.log("CEITNOT_REGISTRY_ADDRESS=%s", address(registry));
        console.log("CEITNOT_VAULT_4626_ADDRESS=%s", address(collateralVault));
        console.log("MOCK_ASSET_ADDRESS=%s", address(assetToken));
    }
}
