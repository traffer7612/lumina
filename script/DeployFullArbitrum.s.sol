// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script }  from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { CeitnotEngine }         from "../src/CeitnotEngine.sol";
import { CeitnotProxy }          from "../src/CeitnotProxy.sol";
import { CeitnotMarketRegistry } from "../src/CeitnotMarketRegistry.sol";
import { OracleRelay }        from "../src/OracleRelay.sol";
import { CeitnotUSD }            from "../src/CeitnotUSD.sol";
import { CeitnotPSM }            from "../src/CeitnotPSM.sol";
import { CeitnotRouter }         from "../src/CeitnotRouter.sol";
import { CeitnotTreasury }       from "../src/CeitnotTreasury.sol";
import { CeitnotToken }          from "../src/governance/CeitnotToken.sol";
import { VeCeitnot }             from "../src/governance/VeCeitnot.sol";
import { CeitnotGovernor }       from "../src/governance/CeitnotGovernor.sol";
import { MockERC20 }          from "../test/mocks/MockERC20.sol";
import { MockVault4626 }      from "../test/mocks/MockVault4626.sol";

import { IVotes }             from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title  DeployFullArbitrum
 * @notice Full Lumina CDP stack on **Arbitrum One** (chainId 42161):
 *         - Fresh **mock** wstETH + ERC-4626 vault (Lido bridge token 0x5979… fails registry `convertToAssets(1e18)` probe)
 *         - **Real** native USDC + Chainlink **ETH/USD** for oracle pricing
 *         - aUSD, engine (proxy), PSM, router, treasury, CEITNOT + VeCeitnot + governor + timelock
 *
 * Optional env:
 *   PSM_USDC_SEED — raw USDC units (6 decimals on Arbitrum native USDC) to `transfer` from deployer into PSM for swapOut liquidity; 0 = skip
 *   GOVERNANCE_TOKEN_MINT — WAD minted to deployer (default 10M * 1e18)
 *   ENGINE_HEARTBEAT / ENGINE_TIMELOCK — passed to `CeitnotEngine.initialize` (defaults 1h / 2d)
 *
 * Prerequisites:
 *   - Deployer wallet has **ETH on Arbitrum** for gas
 *   - If `PSM_USDC_SEED` > 0, deployer must hold enough **native USDC**
 *
 * Usage:
 *   forge script script/DeployFullArbitrum.s.sol:DeployFullArbitrum \
 *     --rpc-url https://arb1.arbitrum.io/rpc --broadcast --private-key $PK
 */
contract DeployFullArbitrum is Script {
    /// @dev Chainlink ETH / USD on Arbitrum One (8 decimals on aggregator)
    address public constant CHAINLINK_ETH_USD_ARB = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    /// @dev Native USDC on Arbitrum One (6 decimals)
    address public constant ARBITRUM_NATIVE_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    function run() external {
        uint256 psmUsdcSeed   = vm.envOr("PSM_USDC_SEED", uint256(0));
        uint256 govMint       = vm.envOr("GOVERNANCE_TOKEN_MINT", uint256(10_000_000 * 1e18));
        uint256 heartbeat     = vm.envOr("ENGINE_HEARTBEAT", uint256(1 hours));
        uint256 timelockDelay = vm.envOr("ENGINE_TIMELOCK", uint256(2 days));

        vm.startBroadcast();

        address deployer = msg.sender;

        MockERC20     wstETH = new MockERC20("Wrapped stETH", "wstETH", 18);
        MockVault4626 vault  = new MockVault4626(address(wstETH), "Ceitnot wstETH Vault", "aWstETH");
        OracleRelay   oracle = new OracleRelay(CHAINLINK_ETH_USD_ARB, address(0), 0);

        CeitnotUSD ausd = new CeitnotUSD(deployer);

        CeitnotMarketRegistry registry = new CeitnotMarketRegistry(deployer);
        uint256 marketId = registry.addMarket(
            address(vault),
            address(oracle),
            uint16(8000),
            uint16(8500),
            uint16(500),
            0,
            0,
            false,
            0
        );

        CeitnotEngine implementation = new CeitnotEngine();
        bytes memory initData = abi.encodeCall(
            CeitnotEngine.initialize,
            (address(ausd), address(registry), heartbeat, timelockDelay)
        );
        CeitnotProxy proxyContract = new CeitnotProxy(address(implementation), initData);
        address engine = address(proxyContract);

        registry.setEngine(engine);
        CeitnotEngine(engine).setMintableDebtToken(true);
        ausd.addMinter(engine);

        CeitnotPSM psm = new CeitnotPSM(address(ausd), ARBITRUM_NATIVE_USDC, deployer, uint16(10), uint16(10));
        ausd.addMinter(address(psm));

        if (psmUsdcSeed > 0) {
            uint256 bal = IERC20(ARBITRUM_NATIVE_USDC).balanceOf(deployer);
            require(bal >= psmUsdcSeed, "DeployFullArbitrum: insufficient USDC for PSM_USDC_SEED");
            require(IERC20(ARBITRUM_NATIVE_USDC).transfer(address(psm), psmUsdcSeed), "DeployFullArbitrum: USDC transfer failed");
        }

        CeitnotRouter   router   = new CeitnotRouter(engine, address(ausd));
        CeitnotTreasury treasury = new CeitnotTreasury(deployer);

        CeitnotToken govToken = new CeitnotToken(deployer);
        govToken.mint(deployer, govMint);

        VeCeitnot veLock = new VeCeitnot(address(govToken), deployer, address(ausd));

        address[] memory proposers = new address[](1);
        proposers[0] = deployer;
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        TimelockController timelock = new TimelockController(1 days, proposers, executors, deployer);
        CeitnotGovernor governor = new CeitnotGovernor(IVotes(address(veLock)), timelock);

        wstETH.mint(deployer, 100_000 * 1e18);

        vm.stopBroadcast();

        console.log("=== FULL STACK - ARBITRUM ONE (CDP) ===");
        console.log("");
        console.log("--- Core ---");
        console.log("ENGINE (proxy):     %s", engine);
        console.log("REGISTRY:           %s", address(registry));
        console.log("ORACLE:             %s", address(oracle));
        console.log("VAULT (mock aWst):  %s", address(vault));
        console.log("MOCK wstETH:        %s", address(wstETH));
        console.log("");
        console.log("--- CDP ---");
        console.log("AUSD:               %s", address(ausd));
        console.log("PSM:                %s", address(psm));
        console.log("USDC (native Arb):  %s", ARBITRUM_NATIVE_USDC);
        console.log("");
        console.log("--- DX ---");
        console.log("ROUTER:             %s", address(router));
        console.log("TREASURY:           %s", address(treasury));
        console.log("");
        console.log("--- Governance ---");
        console.log("CEITNOT_TOKEN:         %s", address(govToken));
        console.log("CEITNOT_VE:            %s", address(veLock));
        console.log("GOVERNOR:           %s", address(governor));
        console.log("TIMELOCK:           %s", address(timelock));
        console.log("");
        console.log("CHAINLINK_ETH_USD:  %s", CHAINLINK_ETH_USD_ARB);
        console.log("Market ID:          %s", marketId);
        console.log("PSM_USDC_SEED used: %s", psmUsdcSeed);
        console.log("");
        console.log("Next: point frontend to chain 42161 + addresses above; fund PSM with USDC if seed was 0;");
        console.log("      PSM/UI: native USDC is 6 decimals; verify swaps / UI before prod use.");
    }
}
