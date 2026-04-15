// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

interface IMockChainlinkV3Feed {
    function setAnswer(int256 a, uint256 ts) external;
}

/**
 * @title UpdateArbitrumSepoliaOracle
 * @notice Refreshes the mutable mock price feed used by DeployFullArbitrumSepolia.
 *
 * Required env:
 *   MOCK_CL_FEED_ADDRESS  - deployed mock feed address
 *
 * Optional env:
 *   MOCK_ETH_USD_8DEC     - new 8-decimal ETH/USD price (default: 3000e8)
 *   MOCK_FEED_TIMESTAMP   - custom timestamp (default: block.timestamp)
 *
 * Usage:
 *   forge script script/UpdateArbitrumSepoliaOracle.s.sol:UpdateArbitrumSepoliaOracle \
 *     --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
 *     --broadcast --private-key $DEPLOYER_PRIVATE_KEY
 */
contract UpdateArbitrumSepoliaOracle is Script {
    function run() external {
        address feed = vm.envAddress("MOCK_CL_FEED_ADDRESS");
        int256 price = int256(uint256(vm.envOr("MOCK_ETH_USD_8DEC", uint256(3000 * 1e8))));
        uint256 ts = vm.envOr("MOCK_FEED_TIMESTAMP", block.timestamp);

        vm.startBroadcast();
        IMockChainlinkV3Feed(feed).setAnswer(price, ts);
        vm.stopBroadcast();

        console.log("Updated MOCK CL FEED: %s", feed);
        console.log("New MOCK_ETH_USD_8DEC: %s", uint256(price));
        console.log("New timestamp: %s", ts);
    }
}
