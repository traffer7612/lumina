// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

interface IProposableAdmin {
    function admin() external view returns (address);
    function proposeAdmin(address newAdmin) external;
    function acceptAdmin() external;
}

interface ICeitnotOracleAdmin {
    function admin() external view returns (address);
    function setAdmin(address newAdmin) external;
}

interface IVeCeitnotAdmin {
    function admin() external view returns (address);
    function setAdmin(address newAdmin) external;
}

/**
 * @title TransferAdminEverywhere
 * @notice Admin rotation helper across the main protocol components on Arbitrum.
 *
 * Two-step admin transfers (propose/accept) are used by:
 *  - CeitnotEngine
 *  - CeitnotMarketRegistry
 *  - CeitnotPSM
 *  - CeitnotUSD (aUSD token)
 *  - CeitnotTreasury
 *
 * One-step admin transfer is used by:
 *  - VeCeitnot (setAdmin)
 *
 * Usage:
 *   MODE=propose forge script script/TransferAdminEverywhere.s.sol \
 *     --rpc-url <RPC> --broadcast --private-key <CURRENT_ADMIN_PK>
 *
 *   MODE=accept forge script script/TransferAdminEverywhere.s.sol \
 *     --rpc-url <RPC> --broadcast --private-key <NEW_ADMIN_PK>
 *
 * Required env vars:
 *  - ENGINE_PROXY, REGISTRY_ADDRESS, PSM_ADDRESS, AUSD_ADDRESS, TREASURY_ADDRESS, CEITNOT_VE_ADDRESS
 *  - TARGET_ADMIN_ADDRESS (the new admin EOA / Safe)
 *
 * Optional:
 *  - ORACLE_V2_ADDRESS (if you deployed OracleRelayV2 and want to rotate its admin too)
 */
contract TransferAdminEverywhere is Script {
    enum Mode { Propose, Accept, OneStep }

    function _mode() internal view returns (Mode m) {
        string memory s = vm.envOr("MODE", string("propose"));
        if (keccak256(bytes(s)) == keccak256(bytes("accept"))) return Mode.Accept;
        if (keccak256(bytes(s)) == keccak256(bytes("onestep"))) return Mode.OneStep;
        return Mode.Propose;
    }

    function run() external {
        Mode mode = _mode();

        address engineProxy = vm.envAddress("ENGINE_PROXY");
        address registryAddr = vm.envAddress("REGISTRY_ADDRESS");
        address psmAddr = vm.envAddress("PSM_ADDRESS");
        address ausdAddr = vm.envAddress("AUSD_ADDRESS");
        address treasuryAddr = vm.envAddress("TREASURY_ADDRESS");
        address VeCeitnotAddr = vm.envAddress("CEITNOT_VE_ADDRESS");
        address targetAdmin = vm.envAddress("TARGET_ADMIN_ADDRESS");

        address oracleV2 = vm.envOr("ORACLE_V2_ADDRESS", address(0));

        require(targetAdmin != address(0), "TransferAdminEverywhere: TARGET_ADMIN_ADDRESS required");
        require(engineProxy != address(0), "TransferAdminEverywhere: ENGINE_PROXY required");
        require(registryAddr != address(0), "TransferAdminEverywhere: REGISTRY_ADDRESS required");
        require(psmAddr != address(0), "TransferAdminEverywhere: PSM_ADDRESS required");
        require(ausdAddr != address(0), "TransferAdminEverywhere: AUSD_ADDRESS required");
        require(treasuryAddr != address(0), "TransferAdminEverywhere: TREASURY_ADDRESS required");
        require(VeCeitnotAddr != address(0), "TransferAdminEverywhere: CEITNOT_VE_ADDRESS required");

        console.log("Mode: %s", mode == Mode.Propose ? "propose" : "accept");
        console.log("Target admin: %s", targetAdmin);

        IProposableAdmin engine = IProposableAdmin(engineProxy);
        IProposableAdmin registry = IProposableAdmin(registryAddr);
        IProposableAdmin psm = IProposableAdmin(psmAddr);
        IProposableAdmin ausd = IProposableAdmin(ausdAddr);
        IProposableAdmin treasury = IProposableAdmin(treasuryAddr);
        IVeCeitnotAdmin VeCeitnot = IVeCeitnotAdmin(VeCeitnotAddr);

        console.log("Current engine admin:   %s", engine.admin());
        console.log("Current registry admin: %s", registry.admin());
        console.log("Current PSM admin:      %s", psm.admin());
        console.log("Current aUSD admin:     %s", ausd.admin());
        console.log("Current treasury admin: %s", treasury.admin());
        console.log("Current VeCeitnot admin:   %s", VeCeitnot.admin());

        if (oracleV2 != address(0)) {
            ICeitnotOracleAdmin oracle = ICeitnotOracleAdmin(oracleV2);
            console.log("Current oracleV2 admin: %s", oracle.admin());
        }

        bytes memory acceptData = abi.encodeWithSignature("acceptAdmin()");
        bytes memory setVeData = abi.encodeWithSignature("setAdmin(address)", targetAdmin);

        if (mode == Mode.Propose) {
            vm.startBroadcast();
            // proposeAdmin: must be called by CURRENT admin.
            engine.proposeAdmin(targetAdmin);
            registry.proposeAdmin(targetAdmin);
            psm.proposeAdmin(targetAdmin);
            ausd.proposeAdmin(targetAdmin);
            treasury.proposeAdmin(targetAdmin);
            vm.stopBroadcast();

            console.log("\nNext step (run as NEW admin signer):");
            console.log("1) engine.acceptAdmin()      target=%s data=%s", engineProxy, bytesToHex(acceptData));
            console.log("2) registry.acceptAdmin()    target=%s data=%s", registryAddr, bytesToHex(acceptData));
            console.log("3) psm.acceptAdmin()         target=%s data=%s", psmAddr, bytesToHex(acceptData));
            console.log("4) aUSD.acceptAdmin()        target=%s data=%s", ausdAddr, bytesToHex(acceptData));
            console.log("5) treasury.acceptAdmin()    target=%s data=%s", treasuryAddr, bytesToHex(acceptData));
            console.log("\nNext step (run as CURRENT admin signer, one-step):");
            console.log("6) VeCeitnot.setAdmin(new)      target=%s data=%s", VeCeitnotAddr, bytesToHex(setVeData));
        } else {
            if (mode == Mode.Accept) {
                vm.startBroadcast();
                // acceptAdmin: must be called by NEW admin.
                engine.acceptAdmin();
                registry.acceptAdmin();
                psm.acceptAdmin();
                ausd.acceptAdmin();
                treasury.acceptAdmin();
                vm.stopBroadcast();

                console.log("\nacceptAdmin() calls completed.");
            } else if (mode == Mode.OneStep) {
                vm.startBroadcast();
                // one-step admin setters require CURRENT admin signature
                VeCeitnot.setAdmin(targetAdmin);
                if (oracleV2 != address(0)) {
                    ICeitnotOracleAdmin oracle = ICeitnotOracleAdmin(oracleV2);
                    oracle.setAdmin(targetAdmin);
                }
                vm.stopBroadcast();

                console.log("\nOne-step admin updates completed (VeCeitnot/optional oracleV2).");
            } else {
                revert("TransferAdminEverywhere: unknown mode");
            }
        }
    }

    function bytesToHex(bytes memory data) internal pure returns (string memory) {
        bytes16 hexSymbols = "0123456789abcdef";
        bytes memory result = new bytes(2 + data.length * 2);
        result[0] = "0";
        result[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            result[2 + i * 2] = hexSymbols[uint8(data[i] >> 4)];
            result[3 + i * 2] = hexSymbols[uint8(data[i] & 0x0f)];
        }
        return string(result);
    }
}

