// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title  Multicall
 * @author Sanzhik(traffer7612)
 * @notice Abstract base that adds a delegatecall-based multicall entrypoint.
 *         Because each sub-call uses `delegatecall`, `msg.sender` is preserved
 *         throughout the batch — so engine auth checks see the original caller.
 *         Safe for UUPS-proxy deployments: `address(this)` resolves to the proxy,
 *         which delegates back into the same implementation.
 * @dev    Phase 10 — DX & Composability.
 */
abstract contract Multicall {
    /**
     * @notice Execute multiple calls in a single transaction, preserving msg.sender.
     * @param  data   Array of ABI-encoded calldata for each sub-call.
     * @return results Array of raw return data from each sub-call.
     */
    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i; i < data.length; ++i) {
            (bool ok, bytes memory result) = address(this).delegatecall(data[i]);
            if (!ok) {
                // Bubble up the revert reason
                assembly {
                    revert(add(result, 0x20), mload(result))
                }
            }
            results[i] = result;
        }
    }
}
