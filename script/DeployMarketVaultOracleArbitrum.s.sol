// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { OracleRelay } from "../src/OracleRelay.sol";
import { SimpleERC4626Vault } from "../src/vaults/SimpleERC4626Vault.sol";

/**
 * @title DeployMarketVaultOracleArbitrum
 * @notice Deploys ONLY SimpleERC4626Vault + OracleRelay. Does NOT call registry.addMarket.
 *
 * When `CeitnotMarketRegistry.admin()` is the Timelock, `addMarket` must be executed via
 * Governor → queue → Timelock delay → execute. Use this script first to get VAULT + ORACLE
 * addresses, then `PrintRegistryAddMarketCalldata.s.sol` (or your Governance UI) to build the proposal.
 *
 * Required env:
 *   ASSET_ADDRESS          — underlying ERC-20 (e.g. USDC, USDT, WBTC, WETH on Arbitrum)
 *   CHAINLINK_PRIMARY_FEED — Chainlink aggregator (e.g. USDC/USD, BTC/USD)
 *   VAULT_NAME             — e.g. "Ceitnot USDC Vault"
 *   VAULT_SYMBOL           — e.g. "lUSDC"
 *
 * Optional:
 *   SEED_RAW — optional first deposit (raw token units); deployer must hold the asset
 *
 * Usage:
 *   ASSET_ADDRESS=0x... CHAINLINK_PRIMARY_FEED=0x... VAULT_NAME="..." VAULT_SYMBOL="..." \\
 *     forge script script/DeployMarketVaultOracleArbitrum.s.sol:DeployMarketVaultOracleArbitrum \\
 *     --rpc-url https://arb1.arbitrum.io/rpc --broadcast -vvv
 */
contract DeployMarketVaultOracleArbitrum is Script {
    using SafeERC20 for IERC20;

    function run() external {
        address assetAddr = vm.envAddress("ASSET_ADDRESS");
        address feed = vm.envAddress("CHAINLINK_PRIMARY_FEED");
        string memory vName = vm.envString("VAULT_NAME");
        string memory vSymbol = vm.envString("VAULT_SYMBOL");
        uint256 seed = vm.envOr("SEED_RAW", uint256(0));

        IERC20 asset = IERC20(assetAddr);

        vm.startBroadcast();
        address deployer = msg.sender;

        SimpleERC4626Vault vault_ = new SimpleERC4626Vault(asset, vName, vSymbol);
        address vault = address(vault_);
        OracleRelay oracle = new OracleRelay(feed, address(0), 0);

        if (seed > 0) {
            require(asset.balanceOf(deployer) >= seed, "DeployMarketVault: insufficient asset for SEED_RAW");
            asset.forceApprove(vault, seed);
            vault_.deposit(seed, deployer);
        }

        vm.stopBroadcast();

        console.log("=== VAULT + ORACLE (no addMarket) ===");
        console.log("VAULT:  %s", vault);
        console.log("ORACLE: %s", address(oracle));
        console.log("ASSET:  %s", assetAddr);
        console.log("FEED:   %s", feed);
        console.log("seed:   %s", seed);
        console.log("Next: run PrintRegistryAddMarketCalldata with VAULT_ADDRESS / ORACLE_ADDRESS, then Governor propose -> queue -> execute on REGISTRY.addMarket(...).");
    }
}
