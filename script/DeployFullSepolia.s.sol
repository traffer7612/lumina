// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script }  from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

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

import { IVotes }              from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { TimelockController }  from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title  DeployFullSepolia
 * @notice Full-stack Sepolia deploy:
 *         - Mock wstETH + Mock USDC + Real Chainlink ETH/USD oracle
 *         - CeitnotEngine (CDP mode) → borrow mints ceitUSD, repay burns ceitUSD
 *         - CeitnotUSD + CeitnotPSM (ceitUSD ↔ USDC 1:1)
 *         - CeitnotToken (10M initial to deployer) + VeCeitnot
 *         - TimelockController + CeitnotGovernor
 *         - CeitnotTreasury + CeitnotRouter
 *
 * Usage:
 *   forge script script/DeployFullSepolia.s.sol:DeployFullSepolia \
 *     --rpc-url https://ethereum-sepolia.publicnode.com \
 *     --broadcast --private-key $DEPLOYER_PRIVATE_KEY
 */
contract DeployFullSepolia is Script {
    address constant CHAINLINK_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;

        // ===================== 1. Mock tokens + Vault + Oracle =====================
        MockERC20     wstETH = new MockERC20("Wrapped stETH", "wstETH", 18);
        MockERC20     usdc   = new MockERC20("USD Coin", "USDC", 18);
        MockVault4626 vault  = new MockVault4626(address(wstETH), "Ceitnot wstETH Vault", "aWstETH");
        OracleRelay   oracle = new OracleRelay(CHAINLINK_ETH_USD, address(0), 0);

        // ===================== 2. CeitnotUSD (ceitUSD stablecoin) =====================
        CeitnotUSD ausd = new CeitnotUSD(deployer);

        // ===================== 3. Registry + Market =====================
        CeitnotMarketRegistry registry = new CeitnotMarketRegistry(deployer);
        uint256 marketId = registry.addMarket(
            address(vault),
            address(oracle),
            uint16(8000),   // LTV 80%
            uint16(8500),   // Liquidation threshold 85%
            uint16(500),    // Liquidation penalty 5%
            0, 0,           // no supply/borrow caps
            false, 0        // not isolated
        );

        // ===================== 4. Engine + Proxy (CDP mode with ceitUSD) =====================
        CeitnotEngine implementation = new CeitnotEngine();
        bytes memory initData = abi.encodeCall(
            CeitnotEngine.initialize,
            (address(ausd), address(registry), 1 hours, 2 days)
        );
        CeitnotProxy proxyContract = new CeitnotProxy(address(implementation), initData);
        address engine = address(proxyContract);

        // Wire up
        registry.setEngine(engine);

        // Enable CDP mode: borrow mints ceitUSD, repay burns ceitUSD
        CeitnotEngine(engine).setMintableDebtToken(true);

        // Register engine as ceitUSD minter
        ausd.addMinter(engine);

        // ===================== 5. PSM (ceitUSD ↔ USDC) =====================
        CeitnotPSM psm = new CeitnotPSM(
            address(ausd),
            address(usdc),
            deployer,
            uint16(10),   // tinBps  0.1% fee on swapIn
            uint16(10)    // toutBps 0.1% fee on swapOut
        );
        // Register PSM as ceitUSD minter
        ausd.addMinter(address(psm));
        // Mint USDC to PSM for swapOut liquidity
        usdc.mint(address(psm), 1_000_000 * 1e18);

        // ===================== 6. Router =====================
        CeitnotRouter router = new CeitnotRouter(engine, address(ausd));

        // ===================== 7. Treasury =====================
        CeitnotTreasury treasury = new CeitnotTreasury(deployer);

        // ===================== 8. CeitnotToken (governance) =====================
        CeitnotToken govToken = new CeitnotToken(deployer);
        // Mint 10M CEITNOT to deployer (for testing governance)
        govToken.mint(deployer, 10_000_000 * 1e18);

        // ===================== 9. VeCeitnot (vote-escrow) =====================
        VeCeitnot veLock = new VeCeitnot(
            address(govToken),
            deployer,
            address(ausd)     // revenue token = ceitUSD
        );

        // ===================== 10. TimelockController + Governor =====================
        address[] memory proposers = new address[](1);
        proposers[0] = deployer;  // initially deployer can propose
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute after delay

        TimelockController timelock = new TimelockController(
            1 days,       // minDelay
            proposers,
            executors,
            deployer      // admin (deployer initially, transfer to governor later)
        );

        CeitnotGovernor governor = new CeitnotGovernor(
            IVotes(address(veLock)),
            timelock
        );
        // Wire Governor to Timelock and hand governance controls to Timelock.
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        govToken.setMinter(address(timelock));
        veLock.setAdmin(address(timelock));

        // ===================== 11. Mint test tokens to deployer =====================
        wstETH.mint(deployer, 100_000 * 1e18);
        usdc.mint(deployer, 100_000 * 1e18);

        vm.stopBroadcast();

        // ===================== Print all addresses =====================
        console.log("=== FULL STACK DEPLOYED ===");
        console.log("");
        console.log("--- Core ---");
        console.log("ENGINE (proxy):     %s", engine);
        console.log("REGISTRY:           %s", address(registry));
        console.log("ORACLE:             %s", address(oracle));
        console.log("VAULT (wstETH):     %s", address(vault));
        console.log("ASSET (wstETH):     %s", address(wstETH));
        console.log("");
        console.log("--- CDP ---");
        console.log("CEITUSD:            %s", address(ausd));
        console.log("PSM:                %s", address(psm));
        console.log("USDC (mock):        %s", address(usdc));
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
        console.log("--- Chainlink ---");
        console.log("CHAINLINK_ETH_USD:  %s", CHAINLINK_ETH_USD);
        console.log("");
        console.log("CDP MODE: ENABLED (borrow mints ceitUSD, repay burns ceitUSD)");
        console.log("Market ID: %s", marketId);
    }
}
