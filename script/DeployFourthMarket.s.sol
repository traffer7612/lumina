// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script }  from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { CeitnotMarketRegistry } from "../src/CeitnotMarketRegistry.sol";
import { MockERC20 }          from "../test/mocks/MockERC20.sol";
import { MockVault4626 }      from "../test/mocks/MockVault4626.sol";
import { MockOracle }         from "../test/mocks/MockOracle.sol";

/**
 * @title  DeployFourthMarket
 * @notice Deploys TYT + aTYT vault + oracle and registers as a NEW market
 *         (replaces the old isolated Market #2).
 *         isIsolated = false this time.
 *
 * Usage:
 *   forge script script/DeployFourthMarket.s.sol:DeployFourthMarket \
 *     --rpc-url https://ethereum-sepolia.publicnode.com \
 *     --broadcast --private-key $DEPLOYER_PRIVATE_KEY
 */
contract DeployFourthMarket is Script {
    address constant REGISTRY = 0x05a585117DF7a0b909F611cC40aFd3b04dCf7A12;

    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;

        // 1. Deactivate old Market #2
        CeitnotMarketRegistry(REGISTRY).deactivateMarket(2);

        // 2. Mock TYT token
        MockERC20 lyt = new MockERC20("Test Yield Token", "TYT", 18);

        // 3. ERC-4626 vault: TYT -> aTYT
        MockVault4626 vault = new MockVault4626(address(lyt), "Test YT Vault", "aTYT");

        // 4. Mock oracle: TYT = $150
        MockOracle oracle = new MockOracle();
        oracle.setPrice(150e18);

        // 5. Register market — NOT isolated
        uint256 marketId = CeitnotMarketRegistry(REGISTRY).addMarket(
            address(vault),
            address(oracle),
            uint16(7500),   // LTV 75%
            uint16(8200),   // Liquidation threshold 82%
            uint16(600),    // Liquidation penalty 6%
            0, 0,           // no supply/borrow caps
            false, 0        // NOT isolated
        );

        // 6. Mint test TYT to deployer
        lyt.mint(deployer, 100_000 * 1e18);

        vm.stopBroadcast();

        console.log("=== NEW LYT MARKET DEPLOYED ===");
        console.log("");
        console.log("Old Market #2: DEACTIVATED");
        console.log("");
        console.log("TYT (mock):       %s", address(lyt));
        console.log("VAULT (aTYT):     %s", address(vault));
        console.log("ORACLE (TYT):     %s", address(oracle));
        console.log("MARKET ID:        %s", marketId);
        console.log("");
        console.log("LTV: 75%%  |  Liq Threshold: 82%%  |  Liq Penalty: 6%%");
        console.log("Isolated: false");
    }
}
