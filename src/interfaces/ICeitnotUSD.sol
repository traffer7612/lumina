// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  ICeitnotUSD
/// @notice Interface for the CeitnotUSD mintable/burnable CDP stablecoin.
interface ICeitnotUSD {
    // ------------------------------- Mint / Burn

    /// @notice Mint `amount` ceitUSD to `to`. Only callable by registered minters.
    function mint(address to, uint256 amount) external;

    /// @notice Burn `amount` ceitUSD from `from`. Only callable by registered minters.
    ///         Does NOT require allowance — minter is trusted to manage protocol debt.
    function burn(address from, uint256 amount) external;

    /// @notice Burn `amount` ceitUSD from `from` using the caller's allowance.
    ///         Callable by anyone who has been approved by `from`.
    function burnFrom(address from, uint256 amount) external;

    // ------------------------------- Minter management

    /// @notice Register a new minter. Only callable by admin.
    function addMinter(address minter) external;

    /// @notice Revoke minter status. Only callable by admin.
    function removeMinter(address minter) external;

    // ------------------------------- Debt ceiling

    /// @notice Set the global debt ceiling (max totalSupply). 0 = unlimited. Only admin.
    function setGlobalDebtCeiling(uint256 ceiling) external;

    // ------------------------------- EIP-2612 Permit

    /// @notice EIP-2612 gasless approval via signed message.
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8   v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Current permit nonce for `owner`.
    function nonces(address owner) external view returns (uint256);

    /// @notice EIP-712 domain separator.
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    // ------------------------------- View

    function totalSupply()       external view returns (uint256);
    function globalDebtCeiling() external view returns (uint256);
    function minters(address)    external view returns (bool);
    function admin()             external view returns (address);
    function balanceOf(address)  external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}
