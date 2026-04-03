// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script }  from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { CeitnotMarketRegistry } from "../src/CeitnotMarketRegistry.sol";
import { MockERC20 }          from "../test/mocks/MockERC20.sol";
import { MockVault4626 }      from "../test/mocks/MockVault4626.sol";
import { MockOracle }         from "../test/mocks/MockOracle.sol";

/**
 * @title  DeployThirdMarket
 * @notice Deploys a new mock collateral asset + ERC-4626 vault + oracle
 *         and registers it as a new market in the existing Sepolia registry.
 *
 * Asset:  Lumina Yield Token (LYT)
 * Vault:  Lumina LYT Vault (aLYT)
 *
 * Usage:
 *   forge script script/DeployThirdMarket.s.sol:DeployThirdMarket \
 *     --rpc-url https://ethereum-sepolia.publicnode.com \
 *     --broadcast --private-key $DEPLOYER_PRIVATE_KEY
 */
contract DeployThirdMarket is Script {
    /// @dev Existing registry on Sepolia (from DeployFullSepolia)
    address constant REGISTRY = 0x05a585117DF7a0b909F611cC40aFd3b04dCf7A12;

    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;

        // 1. Mock underlying asset: Lumina Yield Token (LYT)
        MockERC20 lyt = new MockERC20("Lumina Yield Token", "LYT", 18);

        // 2. ERC-4626 vault over LYT → aLYT
        MockVault4626 vault = new MockVault4626(address(lyt), "Lumina LYT Vault", "aLYT");

        // 3. Mock oracle: LYT = $150 (150e18 in WAD)
        MockOracle oracle = new MockOracle();
        oracle.setPrice(150e18);

        // 4. Register market in existing registry
        CeitnotMarketRegistry registry = CeitnotMarketRegistry(REGISTRY);
        uint256 marketId = registry.addMarket(
            address(vault),
            address(oracle),
            uint16(7500),   // LTV 75%
            uint16(8200),   // Liquidation threshold 82%
            uint16(600),    // Liquidation penalty 6%
            0, 0,           // no supply/borrow caps (test only)
            true,           // isIsolated
            100_000e18      // isolatedBorrowCap (test limit)
        );

        // 5. Mint test LYT to deployer so they can deposit
        lyt.mint(deployer, 100_000 * 1e18);

        vm.stopBroadcast();

        console.log("=== THIRD MARKET DEPLOYED ===");
        console.log("");
        console.log("LYT (mock):       %s", address(lyt));
        console.log("VAULT (aLYT):     %s", address(vault));
        console.log("ORACLE (LYT):     %s", address(oracle));
        console.log("REGISTRY:         %s", address(registry));
        console.log("MARKET ID:        %s", marketId);
        console.log("");
        console.log("LTV: 75%%  |  Liq Threshold: 82%%  |  Liq Penalty: 6%%");
        console.log("Isolated: true   |  Isolated Borrow Cap: 100_000 LYT");
    }
}

