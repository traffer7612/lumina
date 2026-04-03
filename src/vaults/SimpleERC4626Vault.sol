// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/**
 * @title SimpleERC4626Vault
 * @notice Minimal ERC-4626 vault: 1 underlying ERC-20 → vault shares. Uses OpenZeppelin only.
 * @dev After deploy, seed with a small first deposit to mitigate ERC-4626 share inflation (OZ docs).
 */
contract SimpleERC4626Vault is ERC4626 {
    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) ERC4626(asset_) {}
}
