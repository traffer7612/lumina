// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ICeitnotEngine } from "./interfaces/ICeitnotEngine.sol";

/**
 * @title CeitnotVault4626
 * @author Sanzhik(traffer7612)
 * @notice ERC-4626 view adapter for CeitnotEngine: exposes totalAssets / convertTo* using
 *         engine's total collateral (in underlying). Enables 4626-compatible integrators
 *         to read engine state without holding a position.
 * @dev This contract is view-only; deposits/withdrawals go through the Engine directly.
 *      Use this for aggregators and frontends that expect totalAssets() and convertToAssets.
 */
contract CeitnotVault4626 {
    address public immutable ENGINE;

    error Vault4626__ZeroAddress();

    constructor(address engine_) {
        if (engine_ == address(0)) revert Vault4626__ZeroAddress();
        ENGINE = engine_;
    }

    /// @notice Engine address (alias for ENGINE for external API)
    function engine() external view returns (address) {
        return ENGINE;
    }

    /// @notice Underlying asset = collateral vault's asset (from engine)
    function asset() external view returns (address) {
        return ICeitnotEngine(ENGINE).asset();
    }

    /// @notice Total underlying assets (collateral) in the engine
    function totalAssets() external view returns (uint256) {
        return ICeitnotEngine(ENGINE).totalCollateralAssets();
    }

    /// @notice Convert shares (collateral vault shares) to underlying assets
    function convertToAssets(uint256 shares) external view returns (uint256) {
        address collateralVault = ICeitnotEngine(ENGINE).asset();
        return IERC4626View(collateralVault).convertToAssets(shares);
    }

    /// @notice Convert underlying assets to collateral vault shares
    function convertToShares(uint256 assets) external view returns (uint256) {
        address collateralVault = ICeitnotEngine(ENGINE).asset();
        return IERC4626View(collateralVault).convertToShares(assets);
    }
}

interface IERC4626View {
    function convertToAssets(uint256 shares) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
}
