// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { CeitnotEngine } from "../src/CeitnotEngine.sol";
import { CeitnotProxy } from "../src/CeitnotProxy.sol";
import { CeitnotMarketRegistry } from "../src/CeitnotMarketRegistry.sol";
import { SimpleERC4626Vault } from "../src/vaults/SimpleERC4626Vault.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockOracle } from "./mocks/MockOracle.sol";

/// @notice Regression: 6-decimal underlying collateral value must match 18-decimal debt for LTV / borrow.
contract CeitnotEngineCollateralScalingTest is Test {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant MARKET_ID = 0;

    CeitnotEngine public engine;
    CeitnotMarketRegistry public registry;
    MockERC20 public usdc;
    MockERC20 public ausd;
    SimpleERC4626Vault public vault;
    MockOracle public oracle;

    address public alice = address(0xA11CE);

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        ausd = new MockERC20("aUSD", "aUSD", 18);
        vault = new SimpleERC4626Vault(IERC20(address(usdc)), "Ceitnot USDC Vault", "cUSDC");
        oracle = new MockOracle();

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

        // ERC4626 first deposit (avoid inflation edge)
        usdc.mint(address(this), 10_000_000);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(1_000_000, address(this));

        usdc.mint(alice, 500 * 1e6);
        vm.startPrank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(100 * 1e6, alice);
        vault.approve(address(engine), type(uint256).max);
        engine.depositCollateral(alice, MARKET_ID, vault.balanceOf(alice));
        vm.stopPrank();
    }

    function test_getPositionCollateralValue_scalesUSDCtoDebtDecimals() public view {
        uint256 cv = engine.getPositionCollateralValue(alice, MARKET_ID);
        // ~100 USDC face at 1:1 oracle → ~100e18 debt units (tiny rounding from vault math OK)
        assertGt(cv, 99 * WAD);
        assertLt(cv, 101 * WAD);
    }

    function test_borrow_smallAmount_succeedsAgainstUSDCcollateral() public {
        vm.roll(block.number + 1);
        vm.prank(alice);
        engine.borrow(alice, MARKET_ID, 10 * WAD);
        assertGt(engine.getPositionDebt(alice, MARKET_ID), 0);
    }
}
