// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script }  from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AuraEngine }         from "../src/AuraEngine.sol";
import { AuraProxy }          from "../src/AuraProxy.sol";
import { AuraMarketRegistry } from "../src/AuraMarketRegistry.sol";
import { OracleRelay }        from "../src/OracleRelay.sol";
import { AuraUSD }            from "../src/AuraUSD.sol";
import { AuraPSM }            from "../src/AuraPSM.sol";
import { AuraRouter }         from "../src/AuraRouter.sol";
import { AuraTreasury }       from "../src/AuraTreasury.sol";
import { AuraToken }          from "../src/governance/AuraToken.sol";
import { VeAura }             from "../src/governance/VeAura.sol";
import { AuraGovernor }       from "../src/governance/AuraGovernor.sol";

import { IVotes }             from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title  DeployFullProduction
 * @notice Full Lumina stack on a live chain (e.g. Arbitrum One): CDP (aUSD), PSM, governance, router, treasury.
 *
 * Required env:
 *   COLLATERAL_VAULT  — ERC-4626 collateral (e.g. Arbitrum wstETH)
 *   USDC_ADDRESS        — peg asset for PSM (native USDC on Arbitrum has 6 decimals)
 *   CHAINLINK_FEED      — primary Chainlink aggregator compatible with OracleRelay
 *
 * Optional env:
 *   FALLBACK_FEED       — secondary feed for OracleRelay (default: address(0))
 *   TWAP_PERIOD         — OracleRelay TWAP (default: 0 = spot only)
 *   PSM_USDC_SEED       — raw amount of USDC to transfer from deployer to PSM for swapOut liquidity (default: 0 = skip)
 *   GOVERNANCE_TOKEN_MINT — WAD amount to mint to deployer for AuraToken (default: 10_000_000e18)
 *   ENGINE_HEARTBEAT    — engine oracle heartbeat seconds (default: 3600)
 *   ENGINE_TIMELOCK     — engine param timelock seconds (default: 172800 = 2 days)
 *   TIN_BPS / TOUT_BPS  — PSM fees in bps (default: 10 each = 0.1%)
 *
 * @dev PSM reads pegged-token `decimals()` at deploy and scales vs 18-decimal aUSD (prod-safe for native USDC 6).
 *
 * Usage (Arbitrum example):
 *   forge script script/DeployFullProduction.s.sol:DeployFullProduction \
 *     --rpc-url https://arb1.arbitrum.io/rpc --broadcast --private-key $PK
 */
contract DeployFullProduction is Script {
    function run() external {
        address collateralVault = vm.envAddress("COLLATERAL_VAULT");
        address usdc            = vm.envAddress("USDC_ADDRESS");
        address chainlinkFeed   = vm.envAddress("CHAINLINK_FEED");
        address fallbackFeed    = vm.envOr("FALLBACK_FEED", address(0));
        uint256 twapPeriod      = vm.envOr("TWAP_PERIOD", uint256(0));
        uint256 psmUsdcSeed     = vm.envOr("PSM_USDC_SEED", uint256(0));
        uint256 govMint         = vm.envOr("GOVERNANCE_TOKEN_MINT", uint256(10_000_000 * 1e18));
        uint256 heartbeat       = vm.envOr("ENGINE_HEARTBEAT", uint256(1 hours));
        uint256 timelockDelay   = vm.envOr("ENGINE_TIMELOCK", uint256(2 days));
        uint16  tinBps          = uint16(vm.envOr("TIN_BPS", uint256(10)));
        uint16  toutBps         = uint16(vm.envOr("TOUT_BPS", uint256(10)));

        require(collateralVault != address(0) && usdc != address(0) && chainlinkFeed != address(0), "required env");

        vm.startBroadcast();

        address deployer = msg.sender;

        OracleRelay oracle = new OracleRelay(chainlinkFeed, fallbackFeed, twapPeriod);

        AuraUSD ausd = new AuraUSD(deployer);

        AuraMarketRegistry registry = new AuraMarketRegistry(deployer);
        uint256 marketId = registry.addMarket(
            collateralVault,
            address(oracle),
            uint16(8000),
            uint16(8500),
            uint16(500),
            0,
            0,
            false,
            0
        );

        AuraEngine implementation = new AuraEngine();
        bytes memory initData = abi.encodeCall(
            AuraEngine.initialize,
            (address(ausd), address(registry), heartbeat, timelockDelay)
        );
        AuraProxy proxyContract = new AuraProxy(address(implementation), initData);
        address engine = address(proxyContract);

        registry.setEngine(engine);

        AuraEngine(engine).setMintableDebtToken(true);
        ausd.addMinter(engine);

        AuraPSM psm = new AuraPSM(address(ausd), usdc, deployer, tinBps, toutBps);
        ausd.addMinter(address(psm));

        if (psmUsdcSeed > 0) {
            uint256 bal = IERC20(usdc).balanceOf(deployer);
            require(bal >= psmUsdcSeed, "DeployFullProduction: insufficient USDC for PSM_USDC_SEED");
            require(IERC20(usdc).transfer(address(psm), psmUsdcSeed), "DeployFullProduction: USDC transfer failed");
        }

        AuraRouter   router   = new AuraRouter(engine, address(ausd));
        AuraTreasury treasury = new AuraTreasury(deployer);

        AuraToken auraToken = new AuraToken(deployer);
        auraToken.mint(deployer, govMint);

        VeAura veAura = new VeAura(address(auraToken), deployer, address(ausd));

        address[] memory proposers = new address[](1);
        proposers[0] = deployer;
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        TimelockController timelock = new TimelockController(1 days, proposers, executors, deployer);

        AuraGovernor governor = new AuraGovernor(IVotes(address(veAura)), timelock);

        vm.stopBroadcast();

        console.log("=== FULL PRODUCTION STACK (CDP) ===");
        console.log("");
        console.log("--- Core ---");
        console.log("ENGINE (proxy):     %s", engine);
        console.log("REGISTRY:           %s", address(registry));
        console.log("ORACLE:             %s", address(oracle));
        console.log("COLLATERAL_VAULT:  %s", collateralVault);
        console.log("");
        console.log("--- CDP ---");
        console.log("AUSD:               %s", address(ausd));
        console.log("PSM:                %s", address(psm));
        console.log("USDC (pegged):      %s", usdc);
        console.log("");
        console.log("--- DX ---");
        console.log("ROUTER:             %s", address(router));
        console.log("TREASURY:           %s", address(treasury));
        console.log("");
        console.log("--- Governance ---");
        console.log("AURA_TOKEN:         %s", address(auraToken));
        console.log("VE_AURA:            %s", address(veAura));
        console.log("GOVERNOR:           %s", address(governor));
        console.log("TIMELOCK:           %s", address(timelock));
        console.log("");
        console.log("CDP: ENABLED | Market ID: %s", marketId);
        console.log("Next: wire frontend/backend .env; fund PSM with USDC if PSM_USDC_SEED was 0;");
        console.log("      transfer protocol roles to multisig / timelock as needed.");
    }
}
