// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { CeitnotMarketRegistry } from "../src/CeitnotMarketRegistry.sol";
import { OracleRelay }        from "../src/OracleRelay.sol";
import { SimpleERC4626Vault } from "../src/vaults/SimpleERC4626Vault.sol";

/**
 * @title  AddWstETHMarketArbitrum
 * @notice Deploy OpenZeppelin-only SimpleERC4626Vault over canonical Arbitrum wstETH,
 *         deploy OracleRelay(Chainlink ETH/USD), call addMarket on an *existing* registry.
 *
 * Required env:
 *   REGISTRY_ADDRESS — CeitnotMarketRegistry where msg.sender is `admin`
 *
 * Optional env:
 *   WSTETH_ADDRESS        — default Lido wstETH on Arbitrum One
 *   CHAINLINK_ETH_USD     — default Chainlink ETH/USD on Arbitrum One
 *   WSTETH_SEED_WEI       — optional first `deposit` into vault (anti inflation); deployer must hold wstETH
 *   LTV_BPS               — default 8000
 *   LIQ_THRESHOLD_BPS     — default 8500
 *   LIQ_PENALTY_BPS       — default 500
 *
 * Usage:
 *   REGISTRY_ADDRESS=0x... forge script script/AddWstETHMarketArbitrum.s.sol:AddWstETHMarketArbitrum \
 *     --rpc-url https://arb1.arbitrum.io/rpc --broadcast
 *
 * Windows: run script/AddWstETHMarketArbitrum.ps1 (loads REGISTRY from frontend/.env if unset).
 */
contract AddWstETHMarketArbitrum is Script {
    /// @dev Canonical wrapped stETH (Lido) on Arbitrum One
    address public constant WSTETH_ARB_DEFAULT = 0x5979D7b546E38E414F7E9822514be443A4800529;
    /// @dev Chainlink ETH / USD on Arbitrum One (8 decimals on aggregator; OracleRelay normalizes to WAD)
    address public constant CHAINLINK_ETH_USD_ARB = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    function run() external {
        address registryAddr = vm.envAddress("REGISTRY_ADDRESS");
        address wsteth = vm.envOr("WSTETH_ADDRESS", WSTETH_ARB_DEFAULT);
        address feed   = vm.envOr("CHAINLINK_ETH_USD", CHAINLINK_ETH_USD_ARB);
        uint256 seed   = vm.envOr("WSTETH_SEED_WEI", uint256(0));
        uint16 ltv     = uint16(vm.envOr("LTV_BPS", uint256(8000)));
        uint16 liq     = uint16(vm.envOr("LIQ_THRESHOLD_BPS", uint256(8500)));
        uint16 pen     = uint16(vm.envOr("LIQ_PENALTY_BPS", uint256(500)));

        vm.startBroadcast();

        address deployer = msg.sender;

        SimpleERC4626Vault vault_ = new SimpleERC4626Vault(
            IERC20(wsteth),
            "Lumina wstETH Vault",
            "lwstETH"
        );
        address vault = address(vault_);

        OracleRelay oracle = new OracleRelay(feed, address(0), 0);

        if (seed > 0) {
            uint256 bal = IERC20(wsteth).balanceOf(deployer);
            require(bal >= seed, "AddWstETH: insufficient wstETH for WSTETH_SEED_WEI");
            require(IERC20(wsteth).approve(vault, seed), "AddWstETH: approve failed");
            vault_.deposit(seed, deployer);
        }

        uint256 marketId = CeitnotMarketRegistry(registryAddr).addMarket(
            vault,
            address(oracle),
            ltv,
            liq,
            pen,
            0,
            0,
            false,
            0
        );

        vm.stopBroadcast();

        console.log("=== ADD wstETH MARKET (Arbitrum) ===");
        console.log("REGISTRY:     %s", registryAddr);
        console.log("VAULT:        %s", vault);
        console.log("ORACLE:       %s", address(oracle));
        console.log("wstETH asset: %s", wsteth);
        console.log("CHAINLINK:    %s", feed);
        console.log("marketId:     %s", marketId);
        console.log("seed used:    %s", seed);
        console.log("");
        console.log("Optional: set in frontend/.env (reference, app reads markets from registry):");
        console.log("# VITE_WSTETH_VAULT=%s", vault);
        console.log("# VITE_WSTETH_ORACLE_RELAY=%s", address(oracle));
    }
}
