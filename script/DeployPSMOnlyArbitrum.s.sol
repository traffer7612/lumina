// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { CeitnotPSM } from "../src/CeitnotPSM.sol";
import { CeitnotUSD } from "../src/CeitnotUSD.sol";

/**
 * @title  DeployPSMOnlyArbitrum
 * @notice Deploy a fresh `CeitnotPSM` (decimals-aware) on Arbitrum; optionally `addMinter` and seed USDC.
 *
 * Env (required unless noted):
 *   CEITUSD_ADDRESS    - CeitnotUSD (or legacy `AUSD_ADDRESS`)
 *   PSM_ADMIN_ADDRESS  - usually Timelock (who controls fees / liquidity withdrawal)
 *
 * Optional:
 *   PSM_PEGGED_TOKEN   - default native USDC 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
 *   PSM_TIN_BPS        - default 10
 *   PSM_TOUT_BPS       - default 10
 *   PSM_USDC_SEED      - raw pegged units to transfer from deployer into PSM (6 for USDC); 0 = skip
 *   PSM_TRY_ADD_MINTER - "true"/"false" (default true). If deployer is not ceitUSD admin, set false and
 *                        add minter via governance separately.
 *
 * Usage:
 *   forge script script/DeployPSMOnlyArbitrum.s.sol:DeployPSMOnlyArbitrum \
 *     --rpc-url https://arb1.arbitrum.io/rpc --broadcast --private-key $PK
 */
contract DeployPSMOnlyArbitrum is Script {
    address internal constant ARBITRUM_NATIVE_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    function run() external {
        address ceitusdAddr = vm.envOr("CEITUSD_ADDRESS", vm.envOr("AUSD_ADDRESS", address(0)));
        require(ceitusdAddr != address(0), "DeployPSMOnlyArbitrum: CEITUSD_ADDRESS (or AUSD_ADDRESS) required");
        address pegged = vm.envOr("PSM_PEGGED_TOKEN", ARBITRUM_NATIVE_USDC);
        address psmAdmin = vm.envAddress("PSM_ADMIN_ADDRESS");
        uint16 tinBps = uint16(vm.envOr("PSM_TIN_BPS", uint256(10)));
        uint16 toutBps = uint16(vm.envOr("PSM_TOUT_BPS", uint256(10)));
        uint256 seed = vm.envOr("PSM_USDC_SEED", uint256(0));
        bool tryAddMinter = _envBool("PSM_TRY_ADD_MINTER", true);

        vm.startBroadcast();
        CeitnotPSM psm = new CeitnotPSM(ceitusdAddr, pegged, psmAdmin, tinBps, toutBps);
        console.log("CeitnotPSM:", address(psm));
        console.log("peggedToken:", pegged);
        console.log("admin:", psmAdmin);

        if (tryAddMinter) {
            try CeitnotUSD(ceitusdAddr).addMinter(address(psm)) {
                console.log("ceitUSD.addMinter(psm) OK");
            } catch {
                console.log("ceitUSD.addMinter(psm) FAILED - run as ceitUSD admin or via Timelock proposal");
            }
        }

        if (seed > 0) {
            address deployer = msg.sender;
            require(IERC20(pegged).balanceOf(deployer) >= seed, "DeployPSMOnlyArbitrum: insufficient pegged balance");
            require(IERC20(pegged).transfer(address(psm), seed), "DeployPSMOnlyArbitrum: seed transfer failed");
            console.log("PSM_USDC_SEED:", seed);
        }

        vm.stopBroadcast();
    }

    function _envBool(string memory name, bool defaultVal) internal view returns (bool) {
        try vm.envBool(name) returns (bool v) {
            return v;
        } catch {
            return defaultVal;
        }
    }
}
