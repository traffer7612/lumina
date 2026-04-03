// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script }  from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { CeitnotMarketRegistry } from "../src/CeitnotMarketRegistry.sol";
import { MockERC20 }          from "../test/mocks/MockERC20.sol";
import { MockVault4626 }      from "../test/mocks/MockVault4626.sol";
import { MockOracle }         from "../test/mocks/MockOracle.sol";

/**
 * @title  DeploySecondMarket
 * @notice Deploys MockRETH + aRETH vault + oracle and registers as Market #1
 *         in the existing CeitnotMarketRegistry on Sepolia.
 *
 * Usage:
 *   forge script script/DeploySecondMarket.s.sol:DeploySecondMarket \
 *     --rpc-url https://ethereum-sepolia.publicnode.com \
 *     --broadcast --private-key $DEPLOYER_PRIVATE_KEY
 */
contract DeploySecondMarket is Script {
    // Existing registry on Sepolia (from DeployFullSepolia)
    address constant REGISTRY = 0x05a585117DF7a0b909F611cC40aFd3b04dCf7A12;

    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;

        // 1. Mock rETH token
        MockERC20 rETH = new MockERC20("Rocket Pool ETH", "rETH", 18);

        // 2. ERC-4626 vault wrapping rETH → aRETH
        MockVault4626 vault = new MockVault4626(address(rETH), "Ceitnot rETH Vault", "aRETH");

        // 3. Mock oracle: rETH = $2200 (2200e18 in WAD)
        MockOracle oracle = new MockOracle();
        oracle.setPrice(2200e18);

        // 4. Register market in existing registry
        CeitnotMarketRegistry registry = CeitnotMarketRegistry(REGISTRY);
        uint256 marketId = registry.addMarket(
            address(vault),
            address(oracle),
            uint16(7500),   // LTV 75%
            uint16(8200),   // Liquidation threshold 82%
            uint16(600),    // Liquidation penalty 6%
            0, 0,           // no supply/borrow caps
            false, 0        // not isolated
        );

        // 5. Mint test rETH to deployer
        rETH.mint(deployer, 100_000 * 1e18);

        vm.stopBroadcast();

        console.log("=== SECOND MARKET DEPLOYED ===");
        console.log("");
        console.log("RETH (mock):     %s", address(rETH));
        console.log("VAULT (aRETH):   %s", address(vault));
        console.log("ORACLE (rETH):   %s", address(oracle));
        console.log("MARKET ID:       %s", marketId);
        console.log("");
        console.log("LTV: 75%  |  Liq Threshold: 82%  |  Liq Penalty: 6%");
    }
}
