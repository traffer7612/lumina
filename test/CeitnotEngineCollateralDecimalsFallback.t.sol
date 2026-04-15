// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";

import { CeitnotEngine } from "../src/CeitnotEngine.sol";
import { CeitnotProxy } from "../src/CeitnotProxy.sol";
import { CeitnotMarketRegistry } from "../src/CeitnotMarketRegistry.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockOracle } from "./mocks/MockOracle.sol";

/// @dev No ERC20 metadata interface (no decimals()).
contract MockAssetNoMetadata {}

/// @dev ERC4626-like vault share token with 6 share decimals and 1:1 share->asset conversion.
///      `asset()` points to a token without metadata; engine must fallback to vault share decimals.
contract MockVaultShares6NoAssetMetadata is MockERC20 {
    address internal immutable _asset;

    constructor(address asset_) MockERC20("Mock Vault Shares", "mVS", 6) {
        _asset = asset_;
    }

    function asset() external view returns (address) {
        return _asset;
    }

    function totalAssets() external view returns (uint256) {
        return totalSupply;
    }

    function convertToAssets(uint256 shares) external pure returns (uint256) {
        return shares;
    }

    function convertToShares(uint256 assets) external pure returns (uint256) {
        return assets;
    }
}

contract CeitnotEngineCollateralDecimalsFallbackTest is Test {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant MARKET_ID = 0;

    CeitnotEngine public engine;
    CeitnotMarketRegistry public registry;
    MockERC20 public ausd;
    MockOracle public oracle;
    MockAssetNoMetadata public assetNoMetadata;
    MockVaultShares6NoAssetMetadata public vault;

    address public alice = address(0xA11CE);

    function setUp() public {
        ausd = new MockERC20("aUSD", "aUSD", 18);
        oracle = new MockOracle();
        assetNoMetadata = new MockAssetNoMetadata();
        vault = new MockVaultShares6NoAssetMetadata(address(assetNoMetadata));

        registry = new CeitnotMarketRegistry(address(this));
        registry.addMarket(
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

        CeitnotEngine impl = new CeitnotEngine();
        bytes memory initData = abi.encodeCall(
            CeitnotEngine.initialize,
            (address(ausd), address(registry), uint256(1 days), uint256(2 days))
        );
        CeitnotProxy proxy = new CeitnotProxy(address(impl), initData);
        engine = CeitnotEngine(address(proxy));
        registry.setEngine(address(engine));

        ausd.mint(address(engine), 10_000_000 * WAD);

        vault.mint(alice, 4 * 1e6);
        vm.startPrank(alice);
        vault.approve(address(engine), type(uint256).max);
        engine.depositCollateral(alice, MARKET_ID, vault.balanceOf(alice));
        vm.stopPrank();
    }

    function test_getPositionCollateralValue_fallsBackToVaultDecimalsWhenAssetMetadataMissing() public view {
        uint256 cv = engine.getPositionCollateralValue(alice, MARKET_ID);
        // 4 units of 6-dec collateral at 1:1 oracle should scale to ~4e18 debt units.
        assertGt(cv, 3 * WAD);
        assertLt(cv, 5 * WAD);
    }

    function test_borrow_succeeds_whenAssetMetadataMissing() public {
        vm.roll(block.number + 1);
        vm.prank(alice);
        engine.borrow(alice, MARKET_ID, 2 * WAD);
        assertGt(engine.getPositionDebt(alice, MARKET_ID), 0);
    }
}
