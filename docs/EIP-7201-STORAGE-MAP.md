# EIP-7201 Storage Map — Ceitnot Engine

## Storage root slot

The engine uses a **fixed** EIP-7201-style namespaced root (see `ENGINE_STORAGE_SLOT` in `src/CeitnotStorage.sol`). On-chain value:

`0x183a6125c38840424c4a85fa12bab2ab606c4b6d0e7cc73c0c06ba5300eab500`

Call `CeitnotStorage.getStorageSlot()` to verify. Do **not** change this literal in production code without a migration plan — it anchors all proxy storage for `CeitnotEngine`.

## Layout (from root slot)

| Slot offset | Type | Name | Description |
|-------------|------|------|-------------|
| 0 | address | collateralVault | ERC-4626 vault used as collateral |
| 1 | address | debtToken | Borrowed token (e.g. stablecoin) |
| 2 | address | oracleRelay | Price feed (Chainlink + fallback) |
| 3 | uint256 | totalCollateralShares | Sum of all position collateral shares (WAD) |
| 4 | uint256 | totalPrincipalDebt | Sum of all position principals (WAD) |
| 5 | uint256 | globalDebtScale | Debt scale for yield siphon (RAY) |
| 6 | uint256 | lastHarvestPricePerShare | Vault assets per 1e18 share at last harvest (WAD) |
| 7 | uint256 | lastHarvestTimestamp | Last harvest time |
| 8 | uint16 | ltvBps | Max LTV (e.g. 8000 = 80%) |
| 9 | uint16 | liquidationThresholdBps | Liquidation threshold (bps) |
| 10 | uint16 | liquidationPenaltyBps | Liquidation penalty (bps) |
| 11 | bool | paused | Circuit breaker: pause all actions |
| 12 | bool | emergencyShutdown | Emergency shutdown flag |
| 13 | uint256 | heartbeat | Min seconds between harvests |
| 14 | uint256 | minHarvestYieldDebt | Min yield (debt token) to run harvest |
| 15 | uint256 | twapPeriod | TWAP window (0 = spot only) |
| 16 | mapping(address => Position) | positions | Per-user position (see below) |
| 17 | mapping(address => bool) | allowedBorrowers | Optional allowlist |
| 18 | uint256 | constantTimelockDelay | Timelock delay for param changes |
| 19 | mapping(bytes32 => uint256) | timelockDeadline | paramId => execution deadline |
| 20 | address | admin | Admin / upgrade authority |
| 21 | mapping(bytes32 => uint256) | pendingParamValue | paramId => value to apply |

## Position struct (mapping value)

| Offset | Type | Name | Description |
|--------|------|------|-------------|
| 0 | uint256 | collateralShares | Collateral in vault shares (WAD) |
| 1 | uint256 | principalDebt | Debt principal at scaleAtLastUpdate (WAD) |
| 2 | uint256 | scaleAtLastUpdate | globalDebtScale at last update (RAY) |
| 3 | uint256 | lastInteractionBlock | Last block of interaction (flash-loan guard) |

## Mapping slots

- **positions[key]:** `keccak256(abi.encode(key, baseSlot + 16))`
- **allowedBorrowers[key]:** `keccak256(abi.encode(key, baseSlot + 17))`
- **timelockDeadline[key]:** `keccak256(abi.encode(key, baseSlot + 19))`
- **pendingParamValue[key]:** `keccak256(abi.encode(key, baseSlot + 21))`

## Constants

- **WAD:** 1e18  
- **RAY:** 1e27  

All scaling and index math use these units to avoid precision loss over time.
