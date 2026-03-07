// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title  IERC2612
 * @notice Minimal EIP-2612 permit interface used by AuraRouter when the
 *         collateral vault token supports gasless approvals.
 */
interface IERC2612 {
    /// @notice EIP-2612 permit — gasless approval via secp256k1 signature.
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8   v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Current nonce for `owner` (must be included in the signed digest).
    function nonces(address owner) external view returns (uint256);

    /// @notice EIP-712 domain separator.
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
