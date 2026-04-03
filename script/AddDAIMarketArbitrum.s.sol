// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AuraMarketRegistry } from "../src/AuraMarketRegistry.sol";
import { OracleRelay } from "../src/OracleRelay.sol";
import { SimpleERC4626Vault } from "../src/vaults/SimpleERC4626Vault.sol";

/**
 * @title  AddDAIMarketArbitrum
 * @notice Deploy SimpleERC4626Vault over canonical Arbitrum DAI,
 *         deploy OracleRelay(Chainlink DAI/USD), call addMarket on an existing registry.
 *
 * Required env:
 *   REGISTRY_ADDRESS — AuraMarketRegistry where msg.sender is `admin`
 *
 * Optional env:
 *   DAI_ADDRESS          — default canonical DAI on Arbitrum One
 *   CHAINLINK_DAI_USD    — default Chainlink DAI/USD on Arbitrum One
 *   DAI_SEED_WEI         — optional first `deposit` into vault (anti inflation); deployer must hold DAI
 *   LTV_BPS              — default 9000
 *   LIQ_THRESHOLD_BPS    — default 9300
 *   LIQ_PENALTY_BPS      — default 300
 *
 * Usage:
 *   REGISTRY_ADDRESS=0x... forge script script/AddDAIMarketArbitrum.s.sol:AddDAIMarketArbitrum \
 *     --rpc-url https://arb1.arbitrum.io/rpc --broadcast
 */
contract AddDAIMarketArbitrum is Script {
    /// @dev Canonical DAI on Arbitrum One
    address public constant DAI_ARB_DEFAULT = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    /// @dev Chainlink DAI / USD on Arbitrum One
    address public constant CHAINLINK_DAI_USD_ARB = 0xc5C8E77B397E531B8EC06BFb0048328B30E9eCfB;

    function run() external {
        address registryAddr = vm.envAddress("REGISTRY_ADDRESS");
        address dai = vm.envOr("DAI_ADDRESS", DAI_ARB_DEFAULT);
        address feed = vm.envOr("CHAINLINK_DAI_USD", CHAINLINK_DAI_USD_ARB);
        uint256 seed = vm.envOr("DAI_SEED_WEI", uint256(0));
        uint16 ltv = uint16(vm.envOr("LTV_BPS", uint256(9000)));
        uint16 liq = uint16(vm.envOr("LIQ_THRESHOLD_BPS", uint256(9300)));
        uint16 pen = uint16(vm.envOr("LIQ_PENALTY_BPS", uint256(300)));

        vm.startBroadcast();

        address deployer = msg.sender;

        SimpleERC4626Vault vault_ = new SimpleERC4626Vault(
            IERC20(dai),
            "Lumina DAI Vault",
            "lDAI"
        );
        address vault = address(vault_);

        OracleRelay oracle = new OracleRelay(feed, address(0), 0);

        if (seed > 0) {
            uint256 bal = IERC20(dai).balanceOf(deployer);
            require(bal >= seed, "AddDAI: insufficient DAI for DAI_SEED_WEI");
            require(IERC20(dai).approve(vault, seed), "AddDAI: approve failed");
            vault_.deposit(seed, deployer);
        }

        uint256 marketId = AuraMarketRegistry(registryAddr).addMarket(
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

        console.log("=== ADD DAI MARKET (Arbitrum) ===");
        console.log("REGISTRY:     %s", registryAddr);
        console.log("VAULT:        %s", vault);
        console.log("ORACLE:       %s", address(oracle));
        console.log("DAI asset:    %s", dai);
        console.log("CHAINLINK:    %s", feed);
        console.log("marketId:     %s", marketId);
        console.log("seed used:    %s", seed);
    }
}
