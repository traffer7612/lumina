// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { CeitnotStorage }            from "./CeitnotStorage.sol";
import { FixedPoint }             from "./FixedPoint.sol";
import { InterestRateModel }      from "./InterestRateModel.sol";
import { IERC4626 }               from "./interfaces/IERC4626.sol";
import { IOracleRelay }           from "./interfaces/IOracleRelay.sol";
import { IMarketRegistry }        from "./interfaces/IMarketRegistry.sol";
import { IERC3156FlashBorrower }  from "./interfaces/IERC3156FlashBorrower.sol";
import { IERC3156FlashLender }    from "./interfaces/IERC3156FlashLender.sol";
import { ICeitnotUSD }               from "./interfaces/ICeitnotUSD.sol";
import { Multicall }              from "./Multicall.sol";
import { IERC20Metadata }         from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title CeitnotEngine
 * @author Sanzhik(traffer7612)
 * @notice Autonomous Yield-Backed Credit Engine: deposit ERC-4626 yield-bearing collateral,
 *         borrow stablecoin; yield is programmatically applied to principal (Yield Siphon).
 * @dev Phase 2: multi-market. Uses EIP-7201 namespaced storage; UUPS upgradeable.
 *      Each market has its own collateral vault, oracle, and risk params (held in CeitnotMarketRegistry).
 *      Debt is a single token across all markets; health factor is aggregated cross-collateral.
 */
contract CeitnotEngine is Multicall {
    // ------------------------------- Custom errors
    error Ceitnot__Paused();
    error Ceitnot__EmergencyShutdown();
    error Ceitnot__ZeroAmount();
    error Ceitnot__InsufficientCollateral();
    error Ceitnot__ExceedsLTV();
    error Ceitnot__HealthFactorBelowOne();
    error Ceitnot__HealthFactorAboveOne();
    error Ceitnot__SameBlockInteraction();
    error Ceitnot__HeartbeatNotElapsed();
    error Ceitnot__HarvestTooSmall();
    error Ceitnot__Unauthorized();
    error Ceitnot__TimelockNotElapsed();
    error Ceitnot__InvalidParams();
    error Ceitnot__Reentrancy();
    error Ceitnot__AlreadyInitialized();
    error Ceitnot__NotContract();
    error Ceitnot__MarketNotFound();
    error Ceitnot__MarketFrozen();
    error Ceitnot__MarketInactive();
    error Ceitnot__SupplyCapExceeded();
    error Ceitnot__BorrowCapExceeded();
    error Ceitnot__IsolationViolation();
    error Ceitnot__InsufficientReserves();
    error Ceitnot__CloseFactorExceeded();
    error Ceitnot__AuctionNotStarted();
    error Ceitnot__AuctionAlreadyActive();
    error Ceitnot__InsufficientProtocolCollateral();
    // ---- Phase 6: Flash Loans
    error Ceitnot__FlashLoanUnsupportedToken();
    error Ceitnot__FlashLoanExceedsBalance();
    error Ceitnot__FlashLoanCallbackFailed();
    // ---- Phase 9: CDP
    error Ceitnot__DebtCeilingExceeded();

    // ------------------------------- Events
    event CollateralDeposited(address indexed user, uint256 indexed marketId, uint256 shares);
    event CollateralWithdrawn(address indexed user, uint256 indexed marketId, uint256 shares);
    event Borrowed(address indexed user, uint256 indexed marketId, uint256 amount);
    event Repaid(address indexed user, uint256 indexed marketId, uint256 amount);
    event YieldHarvested(uint256 indexed marketId, uint256 yieldUnderlying, uint256 yieldAppliedToDebt, uint256 protocolYield, uint256 newScale);
    event OriginationFeeCharged(address indexed user, uint256 indexed marketId, uint256 fee);
    event Liquidated(address indexed user, address indexed liquidator, uint256 indexed marketId, uint256 repayAmount, uint256 collateralSeized);
    event InterestAccrued(uint256 indexed marketId, uint256 interestAccrued, uint256 reservesAccrued, uint256 newBorrowIndex);
    event ReservesWithdrawn(uint256 indexed marketId, address indexed to, uint256 amount);
    event LiquidationInitiated(address indexed user, uint256 indexed marketId, uint256 timestamp);
    event BadDebtRealized(address indexed user, uint256 indexed marketId, uint256 badDebtAmount);
    event ProtocolCollateralWithdrawn(uint256 indexed marketId, address indexed to, uint256 shares);
    event EngineParamUpdated(string param, uint256 value);
    event MarketParamProposed(uint256 indexed marketId, bytes32 paramId, uint256 value);
    event MarketParamExecuted(uint256 indexed marketId, bytes32 paramId, uint256 value);
    event EmergencyShutdownSet(bool status);
    event PausedSet(bool status);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event AdminProposed(address indexed currentAdmin, address indexed pendingAdmin);
    event GuardianSet(address indexed guardian, bool status);
    event KeeperSet(address indexed keeper, bool status);
    // ---- Phase 6: Flash Loans
    event FlashLoan(address indexed receiver, address indexed token, uint256 amount, uint256 fee);
    event FlashLoanFeeUpdated(uint16 feeBps);
    event FlashLoanReservesWithdrawn(address indexed to, uint256 amount);
    // ---- Phase 9: CDP
    event MintableDebtTokenSet(bool enabled);
    // ---- Phase 10: DX & Composability
    event DelegateSet(address indexed user, address indexed delegate, bool approved);
    event DepositAndBorrowed(address indexed user, uint256 indexed marketId, uint256 shares, uint256 borrowed);
    event RepaidAndWithdrawn(address indexed user, uint256 indexed marketId, uint256 repaid, uint256 shares);

    /// @notice EIP-1967 UUPS upgrade interface version
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /// @dev EIP-1967 implementation slot
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // ------------------------------- Constructor
    /// @dev Locks the implementation contract from being initialized directly.
    constructor() {
        CeitnotStorage.getStorage().initializationVersion = type(uint256).max;
    }

    // ------------------------------- Initializer
    /// @notice Initializer (replaces constructor for proxy). Call once from proxy.
    /// @param debtToken_       Single stablecoin / debt token used across all markets
    /// @param marketRegistry_  CeitnotMarketRegistry address
    /// @param heartbeat_       Min seconds between harvests (engine-wide default)
    /// @param timelockDelay_   Delay for critical param changes (seconds)
    function initialize(
        address debtToken_,
        address marketRegistry_,
        uint256 heartbeat_,
        uint256 timelockDelay_
    ) external {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        if ($.initializationVersion != 0) revert Ceitnot__AlreadyInitialized();
        if (debtToken_ == address(0) || marketRegistry_ == address(0)) revert Ceitnot__InvalidParams();

        $.debtToken           = debtToken_;
        $.marketRegistry      = marketRegistry_;
        $.heartbeat           = heartbeat_;
        $.constantTimelockDelay = timelockDelay_;
        $.admin               = msg.sender;
        $.initializationVersion = 1;
        $.reentrancyStatus    = 1;
    }

    // ------------------------------- UUPS
    /// @notice Upgrade proxy to new implementation. Only admin.
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable {
        if (CeitnotStorage.getStorage().admin != msg.sender) revert Ceitnot__Unauthorized();
        if (newImplementation == address(0)) revert Ceitnot__InvalidParams();
        if (newImplementation.code.length == 0) revert Ceitnot__NotContract();
        assembly { sstore(IMPLEMENTATION_SLOT, newImplementation) }
        if (data.length > 0) {
            (bool ok, ) = newImplementation.delegatecall(data);
            if (!ok) revert Ceitnot__InvalidParams();
        }
    }

    // ------------------------------- Access modifiers
    modifier onlyAdmin() { _onlyAdmin(); _; }
    function _onlyAdmin() internal view {
        if (CeitnotStorage.getStorage().admin != msg.sender) revert Ceitnot__Unauthorized();
    }

    modifier onlyAdminOrGuardian() { _onlyAdminOrGuardian(); _; }
    function _onlyAdminOrGuardian() internal view {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        if ($.admin != msg.sender && !$.guardians[msg.sender]) revert Ceitnot__Unauthorized();
    }

    modifier whenNotPaused()   { if (CeitnotStorage.getStorage().paused)             revert Ceitnot__Paused();             _; }
    modifier whenNotShutdown() { if (CeitnotStorage.getStorage().emergencyShutdown)  revert Ceitnot__EmergencyShutdown(); _; }

    modifier nonReentrant() {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        if ($.reentrancyStatus == 2) revert Ceitnot__Reentrancy();
        $.reentrancyStatus = 2;
        _;
        $.reentrancyStatus = 1;
    }

    /// @dev Per-user per-market same-block protection.
    modifier noSameBlock(address user, uint256 marketId) {
        CeitnotStorage.MarketPosition storage pos = CeitnotStorage.getStorage().positions[user][marketId];
        if (pos.lastInteractionBlock == block.number) revert Ceitnot__SameBlockInteraction();
        pos.lastInteractionBlock = block.number;
        _;
    }

    // ------------------------------- Governance
    function setPaused(bool paused_) external onlyAdminOrGuardian {
        CeitnotStorage.getStorage().paused = paused_;
        emit PausedSet(paused_);
    }

    function setEmergencyShutdown(bool shutdown_) external onlyAdminOrGuardian {
        CeitnotStorage.getStorage().emergencyShutdown = shutdown_;
        emit EmergencyShutdownSet(shutdown_);
    }

    function setMinHarvestYieldDebt(uint256 value) external onlyAdmin {
        CeitnotStorage.getStorage().minHarvestYieldDebt = value;
        emit EngineParamUpdated("minHarvestYieldDebt", value);
    }

    function setHeartbeat(uint256 value) external onlyAdmin {
        CeitnotStorage.getStorage().heartbeat = value;
        emit EngineParamUpdated("heartbeat", value);
    }

    /// @notice Propose engine-level timelocked param (heartbeat, minHarvestYieldDebt).
    function proposeParam(bytes32 paramId, uint256 value) external onlyAdmin {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        $.timelockDeadline[paramId]   = block.timestamp + $.constantTimelockDelay;
        $.pendingParamValue[paramId]  = value;
    }

    /// @notice Execute engine-level timelocked param after delay.
    function executeParam(bytes32 paramId) external onlyAdmin {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        if (block.timestamp < $.timelockDeadline[paramId]) revert Ceitnot__TimelockNotElapsed();
        uint256 value = $.pendingParamValue[paramId];
        delete $.timelockDeadline[paramId];
        delete $.pendingParamValue[paramId];
        if (paramId == keccak256("heartbeat")) {
            $.heartbeat = value;
            emit EngineParamUpdated("heartbeat", value);
        } else if (paramId == keccak256("minHarvestYieldDebt")) {
            $.minHarvestYieldDebt = value;
            emit EngineParamUpdated("minHarvestYieldDebt", value);
        } else {
            revert Ceitnot__InvalidParams();
        }
    }

    /// @notice Propose a per-market risk param change (ltvBps, liquidationThresholdBps, liquidationPenaltyBps).
    /// @param marketId  Target market
    /// @param paramId   keccak256("ltvBps") | keccak256("liquidationThresholdBps") | keccak256("liquidationPenaltyBps")
    /// @param value     New value
    function proposeMarketParam(uint256 marketId, bytes32 paramId, uint256 value) external onlyAdmin {
        if (!IMarketRegistry(CeitnotStorage.getStorage().marketRegistry).marketExists(marketId))
            revert Ceitnot__MarketNotFound();
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        bytes32 key = keccak256(abi.encode(marketId, paramId));
        $.timelockDeadline[key]             = block.timestamp + $.constantTimelockDelay;
        $.pendingMarketParamValue[key]       = value;
        emit MarketParamProposed(marketId, paramId, value);
    }

    /// @notice Execute a per-market risk param change after timelock has elapsed.
    function executeMarketParam(uint256 marketId, bytes32 paramId) external onlyAdmin {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        bytes32 key = keccak256(abi.encode(marketId, paramId));
        if (block.timestamp < $.timelockDeadline[key]) revert Ceitnot__TimelockNotElapsed();
        uint256 value = $.pendingMarketParamValue[key];
        delete $.timelockDeadline[key];
        delete $.pendingMarketParamValue[key];

        IMarketRegistry reg = IMarketRegistry($.marketRegistry);
        IMarketRegistry.MarketConfig memory cfg = reg.getMarket(marketId);

        uint16 newLtv   = cfg.ltvBps;
        uint16 newLt    = cfg.liquidationThresholdBps;
        uint16 newPen   = cfg.liquidationPenaltyBps;

        if (paramId == keccak256("ltvBps")) {
            if (value > 10_000 || value > cfg.liquidationThresholdBps) revert Ceitnot__InvalidParams();
            newLtv = uint16(value);
        } else if (paramId == keccak256("liquidationThresholdBps")) {
            if (value < cfg.ltvBps || value > 10_000) revert Ceitnot__InvalidParams();
            newLt = uint16(value);
        } else if (paramId == keccak256("liquidationPenaltyBps")) {
            newPen = uint16(value);
        } else {
            revert Ceitnot__InvalidParams();
        }
        reg.updateMarketRiskParams(marketId, newLtv, newLt, newPen);
        emit MarketParamExecuted(marketId, paramId, value);
    }

    function proposeAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert Ceitnot__InvalidParams();
        CeitnotStorage.getStorage().pendingAdmin = newAdmin;
        emit AdminProposed(msg.sender, newAdmin);
    }

    function acceptAdmin() external {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        if (msg.sender != $.pendingAdmin) revert Ceitnot__Unauthorized();
        address oldAdmin = $.admin;
        $.admin = msg.sender;
        $.pendingAdmin = address(0);
        emit AdminTransferred(oldAdmin, msg.sender);
    }

    function setGuardian(address guardian, bool status) external onlyAdmin {
        CeitnotStorage.getStorage().guardians[guardian] = status;
        emit GuardianSet(guardian, status);
    }

    function setKeeper(address keeper, bool status) external onlyAdmin {
        CeitnotStorage.getStorage().keepers[keeper] = status;
        emit KeeperSet(keeper, status);
    }

    // ---- Phase 10: Delegate / Operator management
    /**
     * @notice Approve or revoke `delegate` to act on behalf of msg.sender.
     *         Delegates can call borrow, repay, withdrawCollateral, depositAndBorrow,
     *         and repayAndWithdraw on behalf of the authorising user.
     * @param delegate Address to authorise (e.g. CeitnotRouter).
     * @param approved True = grant access; false = revoke.
     */
    function setDelegate(address delegate, bool approved) external {
        CeitnotStorage.getStorage().delegates[msg.sender][delegate] = approved;
        emit DelegateSet(msg.sender, delegate, approved);
    }

    /// @notice Returns true if `delegate` is authorised to act for `user`.
    function isDelegate(address user, address delegate) external view returns (bool) {
        return CeitnotStorage.getStorage().delegates[user][delegate];
    }

    /// @dev Auth helper — passes if msg.sender is the user or an approved delegate.
    function _authorizedFor(address user) internal view {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        if (msg.sender != user && !$.delegates[user][msg.sender]) revert Ceitnot__Unauthorized();
    }

    // ---- Phase 9: CDP mode
    /**
     * @notice Enable or disable CDP mint/burn mode for the debt token.
     *         When enabled: `borrow` mints aUSD directly to the user (no pre-funded balance needed);
     *                       `repay` and `liquidate` burn aUSD from the user (user must approve first).
     *         When disabled (default): legacy transfer-based behaviour — engine must hold debtToken.
     * @param enabled True to enable CDP mode; false to revert to transfer mode.
     */
    function setMintableDebtToken(bool enabled) external onlyAdmin {
        CeitnotStorage.getStorage().mintableDebtToken = enabled;
        emit MintableDebtTokenSet(enabled);
    }

    /**
     * @notice Initiate a Dutch Auction liquidation for an unhealthy position.
     *         Must be called before `liquidate` when `dutchAuctionEnabled` is true.
     *         Anyone can call; sets the auction start timestamp.
     * @param user     Position owner
     * @param marketId Market with the unhealthy position
     */
    function initiateLiquidation(
        address user,
        uint256 marketId
    ) external whenNotPaused whenNotShutdown nonReentrant {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        _getMarketCfg($.marketRegistry, marketId); // validate market
        _accrueInterest($, marketId);
        _settlePosition($, user, marketId);

        if (_healthFactor($, user) >= CeitnotStorage.WAD) revert Ceitnot__HealthFactorAboveOne();

        CeitnotStorage.MarketPosition storage pos = $.positions[user][marketId];
        if (pos.auctionStartTime != 0) revert Ceitnot__AuctionAlreadyActive();
        pos.auctionStartTime = block.timestamp;
        emit LiquidationInitiated(user, marketId, block.timestamp);
    }

    /**
     * @notice Withdraw vault shares accumulated as protocol liquidation fees.
     * @param marketId Source market
     * @param shares   Amount of vault shares to withdraw
     * @param to       Recipient address
     */
    function withdrawProtocolCollateral(
        uint256 marketId,
        uint256 shares,
        address to
    ) external onlyAdmin {
        if (shares == 0) revert Ceitnot__ZeroAmount();
        if (to == address(0)) revert Ceitnot__InvalidParams();
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        IMarketRegistry.MarketConfig memory cfg = _getMarketCfg($.marketRegistry, marketId);
        CeitnotStorage.MarketState storage ms = $.marketStates[marketId];
        if (ms.protocolCollateralReserves < shares) revert Ceitnot__InsufficientProtocolCollateral();
        unchecked { ms.protocolCollateralReserves -= shares; }
        bool ok = IERC4626(cfg.vault).transfer(to, shares);
        if (!ok) revert Ceitnot__InvalidParams();
        emit ProtocolCollateralWithdrawn(marketId, to, shares);
    }

    /**
     * @notice Accrue interest for a market without other side effects.
     *         Useful for keepers and accurate state snapshots.
     * @param marketId Target market
     */
    function accrueInterest(uint256 marketId) external nonReentrant {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        if (!IMarketRegistry($.marketRegistry).marketExists(marketId)) revert Ceitnot__MarketNotFound();
        _accrueInterest($, marketId);
    }

    /**
     * @notice Withdraw accumulated protocol reserves for a market to a treasury address.
     * @param marketId Target market
     * @param amount   Amount of debt token to withdraw (WAD)
     * @param to       Recipient address
     */
    function withdrawReserves(uint256 marketId, uint256 amount, address to) external onlyAdmin {
        if (amount == 0) revert Ceitnot__ZeroAmount();
        if (to == address(0)) revert Ceitnot__InvalidParams();
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        CeitnotStorage.MarketState storage ms = $.marketStates[marketId];
        if (ms.totalReserves < amount) revert Ceitnot__InsufficientReserves();
        unchecked { ms.totalReserves -= amount; }
        _transferOut($.debtToken, to, amount);
        emit ReservesWithdrawn(marketId, to, amount);
    }

    // ------------------------------- Core: Deposit / Withdraw
    /**
     * @notice Deposit ERC-4626 vault shares as collateral into a specific market.
     *         Shares are pulled from the caller (msg.sender), not from `user`.
     *         No authorization check — anyone can deposit on behalf of a user.
     * @param user     Beneficiary of the position.
     * @param marketId Target market (must be active and not frozen).
     * @param shares   Amount of vault shares to deposit.
     */
    function depositCollateral(
        address user,
        uint256 marketId,
        uint256 shares
    ) external whenNotPaused whenNotShutdown noSameBlock(user, marketId) nonReentrant {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        IMarketRegistry.MarketConfig memory cfg = _requireActiveMarket($.marketRegistry, marketId);
        _accrueInterest($, marketId);
        _depositCollateralCore($, cfg, user, marketId, shares);
    }

    /**
     * @notice Withdraw collateral shares from a market. Reverts if cross-collateral HF < 1.
     *         Caller must be the position owner or an approved delegate.
     *         Shares are sent to `user` (position owner), not the caller.
     * @param user     Position owner.
     * @param marketId Source market.
     * @param shares   Amount of shares to withdraw.
     */
    function withdrawCollateral(
        address user,
        uint256 marketId,
        uint256 shares
    ) external whenNotPaused noSameBlock(user, marketId) nonReentrant {
        _authorizedFor(user);
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        IMarketRegistry.MarketConfig memory cfg = _getMarketCfg($.marketRegistry, marketId);
        _accrueInterest($, marketId);
        _withdrawCollateralCore($, cfg, user, marketId, shares);
    }

    // ------------------------------- Core: Borrow / Repay
    /**
     * @notice Borrow debt token against collateral in a specific market.
     *         Caller must be the position owner or an approved delegate.
     *         Borrowed tokens are sent to `user` (position owner), not the caller.
     * @param user     Position owner.
     * @param marketId Source market (determines per-market LTV check).
     * @param amount   Amount of debt token to borrow.
     */
    function borrow(
        address user,
        uint256 marketId,
        uint256 amount
    ) external whenNotPaused whenNotShutdown noSameBlock(user, marketId) nonReentrant {
        _authorizedFor(user);
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        IMarketRegistry.MarketConfig memory cfg = _requireActiveMarket($.marketRegistry, marketId);
        _accrueInterest($, marketId);
        _borrowCore($, cfg, user, marketId, amount);
    }

    /**
     * @notice Repay debt in a specific market.
     *         Caller must be the position owner or an approved delegate.
     *         Debt tokens are recovered from `user` (position owner), not the caller.
     * @param user     Position owner.
     * @param marketId Target market.
     * @param amount   Amount of debt token to repay.
     */
    function repay(
        address user,
        uint256 marketId,
        uint256 amount
    ) external whenNotPaused noSameBlock(user, marketId) nonReentrant {
        _authorizedFor(user);
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        _getMarketCfg($.marketRegistry, marketId); // ensures market exists
        _accrueInterest($, marketId);
        _repayCore($, user, marketId, amount);
    }

    // ------------------------------- Core: Compound convenience functions (Phase 10)

    /**
     * @notice Deposit collateral and borrow in one transaction with a single same-block check.
     *         Vault shares are pulled from the caller (msg.sender); borrowed tokens go to `user`.
     *         Caller must be the position owner or an approved delegate.
     * @param user         Position owner.
     * @param marketId     Target market.
     * @param shares       Vault shares to deposit.
     * @param borrowAmount Amount of debt token to borrow.
     */
    function depositAndBorrow(
        address user,
        uint256 marketId,
        uint256 shares,
        uint256 borrowAmount
    ) external whenNotPaused whenNotShutdown noSameBlock(user, marketId) nonReentrant {
        _authorizedFor(user);
        if (shares == 0 || borrowAmount == 0) revert Ceitnot__ZeroAmount();
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        IMarketRegistry.MarketConfig memory cfg = _requireActiveMarket($.marketRegistry, marketId);
        _accrueInterest($, marketId);
        _depositCollateralCore($, cfg, user, marketId, shares);
        _borrowCore($, cfg, user, marketId, borrowAmount);
        emit DepositAndBorrowed(user, marketId, shares, borrowAmount);
    }

    /**
     * @notice Repay debt and withdraw collateral in one transaction with a single same-block check.
     *         Debt tokens are recovered from `user`; withdrawn vault shares go to `user`.
     *         Caller must be the position owner or an approved delegate.
     *         Pass 0 for either amount to skip that half of the operation.
     * @param user           Position owner.
     * @param marketId       Target market.
     * @param repayAmount    Amount of debt token to repay (0 = skip).
     * @param withdrawShares Vault shares to withdraw (0 = skip).
     */
    function repayAndWithdraw(
        address user,
        uint256 marketId,
        uint256 repayAmount,
        uint256 withdrawShares
    ) external whenNotPaused noSameBlock(user, marketId) nonReentrant {
        _authorizedFor(user);
        if (repayAmount == 0 && withdrawShares == 0) revert Ceitnot__ZeroAmount();
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        IMarketRegistry.MarketConfig memory cfg = _getMarketCfg($.marketRegistry, marketId);
        _accrueInterest($, marketId);
        if (repayAmount > 0)    _repayCore($, user, marketId, repayAmount);
        if (withdrawShares > 0) _withdrawCollateralCore($, cfg, user, marketId, withdrawShares);
        emit RepaidAndWithdrawn(user, marketId, repayAmount, withdrawShares);
    }

    // ------------------------------- Yield Siphon
    /**
     * @notice Harvest yield accrued by a market's collateral vault and apply it to reduce debt (O(1)).
     * @param marketId Target market
     * @return yieldApplied Amount of debt effectively reduced by yield
     */
    function harvestYield(
        uint256 marketId
    ) external whenNotPaused whenNotShutdown nonReentrant returns (uint256 yieldApplied) {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        IMarketRegistry.MarketConfig memory cfg = _getMarketCfg($.marketRegistry, marketId);
        CeitnotStorage.MarketState storage ms = $.marketStates[marketId];

        if (ms.globalDebtScale == 0) revert Ceitnot__MarketNotFound(); // market never had a deposit
        _accrueInterest($, marketId);
        if (block.timestamp < ms.lastHarvestTimestamp + $.heartbeat) revert Ceitnot__HeartbeatNotElapsed();

        uint256 totalShares = ms.totalCollateralShares;
        uint256 currentPrice = IERC4626(cfg.vault).convertToAssets(CeitnotStorage.WAD);

        if (totalShares == 0 || currentPrice <= ms.lastHarvestPricePerShare) {
            ms.lastHarvestPricePerShare = currentPrice;
            ms.lastHarvestTimestamp     = block.timestamp;
            return 0;
        }

        uint256 yieldUnderlying;
        unchecked {
            yieldUnderlying = (totalShares * (currentPrice - ms.lastHarvestPricePerShare)) / CeitnotStorage.WAD;
        }

        (uint256 price, ) = IOracleRelay(cfg.oracle).getLatestPrice();
        if (price == 0) {
            ms.lastHarvestPricePerShare = currentPrice;
            ms.lastHarvestTimestamp     = block.timestamp;
            return 0;
        }

        uint256 yieldDebt = _collateralDebtValue(yieldUnderlying, price, cfg.vault);
        if ($.minHarvestYieldDebt != 0 && yieldDebt < $.minHarvestYieldDebt) revert Ceitnot__HarvestTooSmall();

        uint256 totalDebtNow = (ms.totalPrincipalDebt * _effectiveScale(ms)) / CeitnotStorage.RAY;
        if (totalDebtNow == 0) {
            ms.lastHarvestPricePerShare = currentPrice;
            ms.lastHarvestTimestamp     = block.timestamp;
            return 0;
        }
        if (yieldDebt > totalDebtNow) yieldDebt = totalDebtNow;

        // ---- 5.1 Yield Fee
        uint256 protocolYield;
        if (cfg.yieldFeeBps > 0) {
            protocolYield = (yieldDebt * cfg.yieldFeeBps) / 10_000;
            ms.totalReserves += protocolYield;
        }
        uint256 yieldAppliedToDebt = yieldDebt - protocolYield;

        ms.globalDebtScale          = FixedPoint.scaleAfterYield(ms.globalDebtScale, totalDebtNow, yieldAppliedToDebt);
        ms.lastHarvestPricePerShare  = currentPrice;
        ms.lastHarvestTimestamp      = block.timestamp;

        emit YieldHarvested(marketId, yieldUnderlying, yieldAppliedToDebt, protocolYield, ms.globalDebtScale);
        return yieldAppliedToDebt;
    }

    // ------------------------------- Liquidation
    /**
     * @notice Liquidate an unhealthy position in a specific market.
     *         Integrates close factor, Dutch auction, protocol fee, and bad debt socialization.
     * @param user        Unhealthy position owner
     * @param marketId    Market to liquidate in
     * @param repayAmount Amount of debt to repay (capped by close factor unless HF < fullLiquidationThreshold)
     */
    function liquidate(
        address user,
        uint256 marketId,
        uint256 repayAmount
    ) external whenNotPaused whenNotShutdown noSameBlock(user, marketId) nonReentrant {
        if (repayAmount == 0) revert Ceitnot__ZeroAmount();
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        IMarketRegistry.MarketConfig memory cfg = _getMarketCfg($.marketRegistry, marketId);
        _accrueInterest($, marketId);
        _settlePosition($, user, marketId);

        // HF check
        uint256 hf = _healthFactor($, user);
        if (hf >= CeitnotStorage.WAD) revert Ceitnot__HealthFactorAboveOne();

        CeitnotStorage.MarketPosition storage pos = $.positions[user][marketId];
        CeitnotStorage.MarketState    storage ms  = $.marketStates[marketId];

        uint256 debt = _currentDebtInMarket($, user, marketId);

        // ---- 4.1 Close Factor
        if (cfg.closeFactorBps > 0) {
            bool fullLiqAllowed = cfg.fullLiquidationThresholdBps > 0
                && hf < (uint256(cfg.fullLiquidationThresholdBps) * CeitnotStorage.WAD / 10_000);
            if (!fullLiqAllowed) {
                uint256 maxRepay = (debt * cfg.closeFactorBps) / 10_000;
                if (repayAmount > maxRepay) revert Ceitnot__CloseFactorExceeded();
            }
        }
        if (repayAmount > debt) repayAmount = debt;

        uint256 valuePerShare = _collateralValuePerShare(cfg);
        if (valuePerShare == 0) revert Ceitnot__InvalidParams();

        // ---- 4.2 Dutch Auction penalty
        uint256 effectivePenaltyBps;
        if (cfg.dutchAuctionEnabled) {
            if (pos.auctionStartTime == 0) revert Ceitnot__AuctionNotStarted();
            uint256 elapsed = block.timestamp - pos.auctionStartTime;
            if (cfg.auctionDuration == 0 || elapsed >= cfg.auctionDuration) {
                effectivePenaltyBps = cfg.liquidationPenaltyBps;
            } else {
                effectivePenaltyBps = (elapsed * cfg.liquidationPenaltyBps) / cfg.auctionDuration;
            }
        } else {
            effectivePenaltyBps = cfg.liquidationPenaltyBps;
        }

        uint256 collateralToSeize = (repayAmount * (10_000 + effectivePenaltyBps) * CeitnotStorage.WAD)
            / (10_000 * valuePerShare);
        if (collateralToSeize > pos.collateralShares) collateralToSeize = pos.collateralShares;

        // ---- 4.3 Protocol Liquidation Fee
        uint256 protocolFeeShares;
        if (cfg.protocolLiquidationFeeBps > 0 && collateralToSeize > 0) {
            protocolFeeShares = (collateralToSeize * cfg.protocolLiquidationFeeBps) / 10_000;
            ms.protocolCollateralReserves += protocolFeeShares;
        }
        uint256 liquidatorShares = collateralToSeize - protocolFeeShares;

        // Update state
        unchecked {
            pos.principalDebt        -= repayAmount;
            pos.collateralShares      -= collateralToSeize;
            ms.totalPrincipalDebt    -= repayAmount;
            ms.totalCollateralShares -= collateralToSeize;
        }

        // Reset auction if position closed
        if (pos.collateralShares == 0 && pos.principalDebt == 0) {
            pos.auctionStartTime = 0;
        }

        // ---- 4.4 Bad Debt Socialization
        if (pos.collateralShares == 0 && pos.principalDebt > 0) {
            uint256 badDebt = pos.principalDebt;
            uint256 covered = badDebt <= ms.totalReserves ? badDebt : ms.totalReserves;
            unchecked {
                ms.totalReserves     -= covered;
                ms.totalPrincipalDebt = ms.totalPrincipalDebt > badDebt
                    ? ms.totalPrincipalDebt - badDebt : 0;
                pos.principalDebt = 0;
            }
            emit BadDebtRealized(user, marketId, badDebt);
        }

        _tryExitMarket($, user, marketId);

        _recoverDebtToken($, msg.sender, repayAmount);
        if (liquidatorShares > 0) {
            bool ok = IERC4626(cfg.vault).transfer(msg.sender, liquidatorShares);
            if (!ok) revert Ceitnot__InvalidParams();
        }
        emit Liquidated(user, msg.sender, marketId, repayAmount, liquidatorShares);
    }

    // ------------------------------- View
    /// @notice Current debt for a user in a specific market.
    function getPositionDebt(address user, uint256 marketId) external view returns (uint256) {
        return _currentDebtInMarket(CeitnotStorage.getStorage(), user, marketId);
    }

    /// @notice Collateral shares held by a user in a specific market.
    function getPositionCollateralShares(address user, uint256 marketId) external view returns (uint256) {
        return CeitnotStorage.getStorage().positions[user][marketId].collateralShares;
    }

    /// @notice Cross-collateral health factor (WAD). < 1e18 = liquidatable.
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(CeitnotStorage.getStorage(), user);
    }

    /// @notice Total effective debt in a market (principal * effectiveScale / RAY).
    function totalDebt(uint256 marketId) external view returns (uint256) {
        CeitnotStorage.MarketState storage ms = CeitnotStorage.getStorage().marketStates[marketId];
        if (ms.globalDebtScale == 0) return 0;
        return (ms.totalPrincipalDebt * _effectiveScale(ms)) / CeitnotStorage.RAY;
    }

    /// @notice Total collateral in underlying assets for a market.
    function totalCollateralAssets(uint256 marketId) external view returns (uint256) {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        IMarketRegistry.MarketConfig memory cfg = _getMarketCfg($.marketRegistry, marketId);
        return IERC4626(cfg.vault).convertToAssets($.marketStates[marketId].totalCollateralShares);
    }

    /// @notice Debt token address.
    function debtToken() external view returns (address) {
        return CeitnotStorage.getStorage().debtToken;
    }

    /// @notice Market registry address.
    function marketRegistry() external view returns (address) {
        return CeitnotStorage.getStorage().marketRegistry;
    }

    /// @notice Fetch market config from registry.
    function getMarket(uint256 marketId) external view returns (IMarketRegistry.MarketConfig memory) {
        return _getMarketCfg(CeitnotStorage.getStorage().marketRegistry, marketId);
    }

    /// @notice Collateral value (in debt-token units) for a user's position in one market.
    function getPositionCollateralValue(address user, uint256 marketId) external view returns (uint256) {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        IMarketRegistry.MarketConfig memory cfg = _getMarketCfg($.marketRegistry, marketId);
        uint256 assets = IERC4626(cfg.vault).convertToAssets($.positions[user][marketId].collateralShares);
        (uint256 price, ) = IOracleRelay(cfg.oracle).getLatestPrice();
        return _collateralDebtValue(assets, price, cfg.vault);
    }

    /// @notice List of market IDs where a user has an active position.
    function getUserMarkets(address user) external view returns (uint256[] memory) {
        return CeitnotStorage.getStorage().userMarketIds[user];
    }

    /// @notice Current borrow index for a market (RAY; RAY = uninitialized/no interest).
    function getMarketBorrowIndex(uint256 marketId) external view returns (uint256) {
        uint256 idx = CeitnotStorage.getStorage().marketStates[marketId].borrowIndex;
        return idx == 0 ? CeitnotStorage.RAY : idx;
    }

    /// @notice Total accumulated protocol reserves for a market (WAD).
    function getMarketTotalReserves(uint256 marketId) external view returns (uint256) {
        return CeitnotStorage.getStorage().marketStates[marketId].totalReserves;
    }

    /// @notice Vault shares accumulated as protocol liquidation fee for a market.
    function getProtocolCollateralReserves(uint256 marketId) external view returns (uint256) {
        return CeitnotStorage.getStorage().marketStates[marketId].protocolCollateralReserves;
    }

    /// @notice Raw total collateral shares deposited into a market (WAD).
    ///         Equals the sum of all user `collateralShares` for this market.
    function getMarketTotalCollateralShares(uint256 marketId) external view returns (uint256) {
        return CeitnotStorage.getStorage().marketStates[marketId].totalCollateralShares;
    }

    /// @notice Raw total principal debt in a market (WAD, before scale adjustment).
    ///         Use `totalDebt(marketId)` for the effective (scaled) value.
    function getMarketTotalPrincipalDebt(uint256 marketId) external view returns (uint256) {
        return CeitnotStorage.getStorage().marketStates[marketId].totalPrincipalDebt;
    }

    /// @notice Current global debt scale for a market (RAY). Starts at RAY and decreases
    ///         as yield is harvested. Returns RAY when the market has had no interactions.
    function getGlobalDebtScale(uint256 marketId) external view returns (uint256) {
        uint256 scale = CeitnotStorage.getStorage().marketStates[marketId].globalDebtScale;
        return scale == 0 ? CeitnotStorage.RAY : scale;
    }

    /// @notice Returns the engine admin address.
    function admin() external view returns (address) {
        return CeitnotStorage.getStorage().admin;
    }

    /// @notice Returns true if the engine is paused (deposits, borrows, liquidations blocked).
    function paused() external view returns (bool) {
        return CeitnotStorage.getStorage().paused;
    }

    /// @notice Returns true if the engine is in emergency shutdown (only repay/withdraw allowed).
    function emergencyShutdown() external view returns (bool) {
        return CeitnotStorage.getStorage().emergencyShutdown;
    }

    // ------------------------------- Phase 6: Flash Loans (EIP-3156)

    /// @notice Set the flash loan fee. Admin only. Max 10_000 bps (100%).
    function setFlashLoanFee(uint16 feeBps) external onlyAdmin {
        if (feeBps > 10_000) revert Ceitnot__InvalidParams();
        CeitnotStorage.getStorage().flashLoanFeeBps = feeBps;
        emit FlashLoanFeeUpdated(feeBps);
    }

    /// @notice Maximum amount available for flash loan of `token`.
    ///         Returns 0 for any token other than the debt token.
    ///         In CDP mode: headroom under the global debt ceiling (unlimited if no ceiling).
    function maxFlashLoan(address token) external view returns (uint256) {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        if (token != $.debtToken) return 0;
        if ($.mintableDebtToken) {
            uint256 ceiling_ = ICeitnotUSD($.debtToken).globalDebtCeiling();
            if (ceiling_ == 0) return type(uint256).max;
            uint256 supply   = ICeitnotUSD($.debtToken).totalSupply();
            return supply >= ceiling_ ? 0 : ceiling_ - supply;
        }
        (bool ok, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(0x70a08231, address(this)) // balanceOf(address)
        );
        uint256 bal = (ok && data.length >= 32) ? abi.decode(data, (uint256)) : 0;
        uint256 reserves = $.flashLoanReserves;
        return bal > reserves ? bal - reserves : 0;
    }

    /// @notice Fee charged for a flash loan of `amount` of `token`.
    ///         Reverts for unsupported tokens.
    function flashFee(address token, uint256 amount) external view returns (uint256) {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        if (token != $.debtToken) revert Ceitnot__FlashLoanUnsupportedToken();
        return (amount * $.flashLoanFeeBps) / 10_000;
    }

    /// @notice Accumulated flash loan fee reserves (engine-wide).
    function getFlashLoanReserves() external view returns (uint256) {
        return CeitnotStorage.getStorage().flashLoanReserves;
    }

    /**
     * @notice EIP-3156 flash loan. Lends `amount` of `token` (must be debtToken) to `receiver`,
     *         calls `onFlashLoan`, then pulls back `amount + fee`.
     * @dev    Uses `nonReentrant` — receiver cannot re-enter engine functions during callback.
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external whenNotPaused whenNotShutdown nonReentrant returns (bool) {
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        if (token != $.debtToken)  revert Ceitnot__FlashLoanUnsupportedToken();
        if (amount == 0)           revert Ceitnot__ZeroAmount();

        // Check available liquidity
        if ($.mintableDebtToken) {
            // CDP mode: CeitnotUSD.mint enforces global debt ceiling; no pre-funded balance needed.
            uint256 ceiling_ = ICeitnotUSD(token).globalDebtCeiling();
            if (ceiling_ != 0) {
                uint256 supply = ICeitnotUSD(token).totalSupply();
                if (supply + amount > ceiling_) revert Ceitnot__FlashLoanExceedsBalance();
            }
        } else {
            (bool ok, bytes memory balData) = token.staticcall(
                abi.encodeWithSelector(0x70a08231, address(this))
            );
            uint256 bal = (ok && balData.length >= 32) ? abi.decode(balData, (uint256)) : 0;
            uint256 available = bal > $.flashLoanReserves ? bal - $.flashLoanReserves : 0;
            if (amount > available) revert Ceitnot__FlashLoanExceedsBalance();
        }

        uint256 fee = (amount * $.flashLoanFeeBps) / 10_000;

        // 1. Send (or mint) tokens
        _lendDebtToken($, address(receiver), amount);

        // 2. Callback
        bytes32 result = receiver.onFlashLoan(msg.sender, token, amount, fee, data);
        if (result != keccak256("ERC3156FlashBorrower.onFlashLoan"))
            revert Ceitnot__FlashLoanCallbackFailed();

        // 3. Pull back (or burn) principal + fee
        _recoverDebtToken($, address(receiver), amount + fee);

        // 4. Accrue fee to reserves
        if (fee > 0) {
            unchecked { $.flashLoanReserves += fee; }
        }

        emit FlashLoan(address(receiver), token, amount, fee);
        return true;
    }

    /**
     * @notice Withdraw accumulated flash loan fee reserves. Admin only.
     * @param to     Recipient address (e.g. CeitnotTreasury)
     * @param amount Amount of debt token to withdraw
     */
    function withdrawFlashLoanReserves(address to, uint256 amount) external onlyAdmin {
        if (to == address(0)) revert Ceitnot__InvalidParams();
        if (amount == 0)      revert Ceitnot__ZeroAmount();
        CeitnotStorage.EngineStorage storage $ = CeitnotStorage.getStorage();
        if (amount > $.flashLoanReserves) revert Ceitnot__InsufficientReserves();
        unchecked { $.flashLoanReserves -= amount; }
        _transferOut($.debtToken, to, amount);
        emit FlashLoanReservesWithdrawn(to, amount);
    }

    // ------------------------------- Internal: core operation helpers (Phase 10)

    /**
     * @dev Deposit core logic — shared by depositCollateral and depositAndBorrow.
     *      Vault shares are pulled from msg.sender.
     */
    function _depositCollateralCore(
        CeitnotStorage.EngineStorage storage $,
        IMarketRegistry.MarketConfig memory cfg,
        address user,
        uint256 marketId,
        uint256 shares
    ) internal {
        if (shares == 0) revert Ceitnot__ZeroAmount();

        CeitnotStorage.MarketState storage ms = $.marketStates[marketId];
        if (cfg.supplyCap != 0 && ms.totalCollateralShares + shares > cfg.supplyCap)
            revert Ceitnot__SupplyCapExceeded();

        _checkIsolationOnDeposit($, user, marketId, cfg.isIsolated);

        bool ok = IERC4626(cfg.vault).transferFrom(msg.sender, address(this), shares);
        if (!ok) revert Ceitnot__InvalidParams();

        CeitnotStorage.MarketPosition storage pos = $.positions[user][marketId];
        if (!$.userInMarket[user][marketId]) {
            $.userInMarket[user][marketId] = true;
            $.userMarketIds[user].push(marketId);
        }
        pos.collateralShares     += shares;
        ms.totalCollateralShares += shares;

        if (ms.globalDebtScale == 0) {
            ms.globalDebtScale = CeitnotStorage.RAY;
            try IERC4626(cfg.vault).convertToAssets(CeitnotStorage.WAD) returns (uint256 p) {
                ms.lastHarvestPricePerShare = p;
            } catch {
                ms.lastHarvestPricePerShare = CeitnotStorage.WAD;
            }
            ms.lastHarvestTimestamp = block.timestamp;
        }
        emit CollateralDeposited(user, marketId, shares);
    }

    /**
     * @dev Borrow core logic — shared by borrow and depositAndBorrow.
     *      Borrowed tokens are sent to `user`.
     */
    function _borrowCore(
        CeitnotStorage.EngineStorage storage $,
        IMarketRegistry.MarketConfig memory cfg,
        address user,
        uint256 marketId,
        uint256 amount
    ) internal {
        if (amount == 0) revert Ceitnot__ZeroAmount();
        _settlePosition($, user, marketId);

        CeitnotStorage.MarketState    storage ms  = $.marketStates[marketId];
        CeitnotStorage.MarketPosition storage pos = $.positions[user][marketId];

        if (cfg.isIsolated && cfg.isolatedBorrowCap != 0) {
            uint256 currentIsolatedDebt = (ms.totalPrincipalDebt * _effectiveScale(ms)) / CeitnotStorage.RAY;
            if (currentIsolatedDebt + amount > cfg.isolatedBorrowCap)
                revert Ceitnot__BorrowCapExceeded();
        }

        uint256 originationFee;
        if (cfg.originationFeeBps > 0) {
            originationFee = (amount * cfg.originationFeeBps) / 10_000;
        }
        uint256 totalDebtAdded = amount + originationFee;

        if (cfg.borrowCap != 0 && ms.totalPrincipalDebt + totalDebtAdded > cfg.borrowCap)
            revert Ceitnot__BorrowCapExceeded();

        pos.principalDebt     += totalDebtAdded;
        pos.scaleAtLastUpdate  = _effectiveScale(ms);
        ms.totalPrincipalDebt += totalDebtAdded;

        if (originationFee > 0) {
            ms.totalReserves += originationFee;
            emit OriginationFeeCharged(user, marketId, originationFee);
        }

        if ($.mintableDebtToken && cfg.debtCeiling != 0 &&
                ms.totalPrincipalDebt > cfg.debtCeiling)
            revert Ceitnot__DebtCeilingExceeded();

        _requireLtv($, user, marketId, cfg);
        _lendDebtToken($, user, amount);
        emit Borrowed(user, marketId, amount);
    }

    /**
     * @dev Repay core logic — shared by repay and repayAndWithdraw.
     *      Debt tokens are recovered from `user` (requires user's approval to engine in CDP mode).
     */
    function _repayCore(
        CeitnotStorage.EngineStorage storage $,
        address user,
        uint256 marketId,
        uint256 amount
    ) internal {
        if (amount == 0) revert Ceitnot__ZeroAmount();
        _settlePosition($, user, marketId);
        CeitnotStorage.MarketPosition storage pos = $.positions[user][marketId];
        uint256 debt = pos.principalDebt;
        if (amount > debt) amount = debt;
        unchecked {
            pos.principalDebt                           -= amount;
            $.marketStates[marketId].totalPrincipalDebt -= amount;
        }
        _tryExitMarket($, user, marketId);
        _recoverDebtToken($, user, amount);
        emit Repaid(user, marketId, amount);
    }

    /**
     * @dev Withdraw collateral core logic — shared by withdrawCollateral and repayAndWithdraw.
     *      Vault shares are transferred to `user` (position owner).
     */
    function _withdrawCollateralCore(
        CeitnotStorage.EngineStorage storage $,
        IMarketRegistry.MarketConfig memory cfg,
        address user,
        uint256 marketId,
        uint256 shares
    ) internal {
        if (shares == 0) revert Ceitnot__ZeroAmount();
        CeitnotStorage.MarketPosition storage pos = $.positions[user][marketId];
        if (pos.collateralShares < shares) revert Ceitnot__InsufficientCollateral();
        _settlePosition($, user, marketId);
        pos.collateralShares                          -= shares;
        $.marketStates[marketId].totalCollateralShares -= shares;
        _tryExitMarket($, user, marketId);
        _requireHealthy($, user);
        bool ok = IERC4626(cfg.vault).transfer(user, shares);
        if (!ok) revert Ceitnot__InvalidParams();
        emit CollateralWithdrawn(user, marketId, shares);
    }

    // ------------------------------- Internal: market helpers
    function _requireActiveMarket(
        address registry,
        uint256 marketId
    ) internal view returns (IMarketRegistry.MarketConfig memory cfg) {
        cfg = _getMarketCfg(registry, marketId);
        if (!cfg.isActive)  revert Ceitnot__MarketInactive();
        if (cfg.isFrozen)   revert Ceitnot__MarketFrozen();
    }

    function _getMarketCfg(
        address registry,
        uint256 marketId
    ) internal view returns (IMarketRegistry.MarketConfig memory) {
        if (!IMarketRegistry(registry).marketExists(marketId)) revert Ceitnot__MarketNotFound();
        return IMarketRegistry(registry).getMarket(marketId);
    }

    // ------------------------------- Internal: isolation mode
    function _checkIsolationOnDeposit(
        CeitnotStorage.EngineStorage storage $,
        address user,
        uint256 marketId,
        bool    isIsolated
    ) internal {
        if (isIsolated) {
            // User must not have other active markets
            uint256[] storage mids = $.userMarketIds[user];
            for (uint256 i = 0; i < mids.length; i++) {
                if (mids[i] != marketId) {
                    CeitnotStorage.MarketPosition storage p = $.positions[user][mids[i]];
                    if (p.collateralShares > 0 || p.principalDebt > 0) revert Ceitnot__IsolationViolation();
                }
            }
            $.userInIsolation[user]   = true;
            $.userIsolatedMarket[user] = marketId;
        } else {
            // User must not be in isolation mode (unless entering their own isolated market)
            if ($.userInIsolation[user] && $.userIsolatedMarket[user] != marketId)
                revert Ceitnot__IsolationViolation();
        }
    }

    /// @dev Remove market from user tracking when position fully zeroed.
    function _tryExitMarket(
        CeitnotStorage.EngineStorage storage $,
        address user,
        uint256 marketId
    ) internal {
        CeitnotStorage.MarketPosition storage pos = $.positions[user][marketId];
        if (pos.collateralShares == 0 && pos.principalDebt == 0) {
            $.userInMarket[user][marketId] = false;
            // Remove from array (swap-and-pop)
            uint256[] storage mids = $.userMarketIds[user];
            uint256 len = mids.length;
            for (uint256 i = 0; i < len; i++) {
                if (mids[i] == marketId) {
                    mids[i] = mids[len - 1];
                    mids.pop();
                    break;
                }
            }
            // Clear isolation if this was the isolated market
            if ($.userInIsolation[user] && $.userIsolatedMarket[user] == marketId) {
                $.userInIsolation[user]    = false;
                $.userIsolatedMarket[user] = 0;
            }
        }
    }

    // ------------------------------- Internal: settle & health
    function _settlePosition(
        CeitnotStorage.EngineStorage storage $,
        address user,
        uint256 marketId
    ) internal {
        CeitnotStorage.MarketPosition storage pos = $.positions[user][marketId];
        CeitnotStorage.MarketState    storage ms  = $.marketStates[marketId];
        uint256 scale   = _effectiveScale(ms);
        uint256 scaleAt = pos.scaleAtLastUpdate == 0 ? CeitnotStorage.RAY : pos.scaleAtLastUpdate;
        uint256 oldPrincipal = pos.principalDebt;
        uint256 currentDebt  = FixedPoint.currentDebt(oldPrincipal, scale, scaleAt);
        pos.principalDebt     = currentDebt;
        pos.scaleAtLastUpdate = scale;
        uint256 total = ms.totalPrincipalDebt;
        ms.totalPrincipalDebt = oldPrincipal > total ? currentDebt : total - oldPrincipal + currentDebt;
    }

    function _currentDebtInMarket(
        CeitnotStorage.EngineStorage storage $,
        address user,
        uint256 marketId
    ) internal view returns (uint256) {
        CeitnotStorage.MarketPosition storage pos = $.positions[user][marketId];
        if (pos.scaleAtLastUpdate == 0 && pos.principalDebt == 0) return 0;
        CeitnotStorage.MarketState storage ms = $.marketStates[marketId];
        uint256 scale   = _effectiveScale(ms);
        uint256 scaleAt = pos.scaleAtLastUpdate == 0 ? CeitnotStorage.RAY : pos.scaleAtLastUpdate;
        return FixedPoint.currentDebt(pos.principalDebt, scale, scaleAt);
    }

    /// @dev Cross-collateral health factor:
    ///      HF = Σ(collateralValue_i * liquidationThreshold_i / 10000) / Σ(debt_i)
    function _healthFactor(
        CeitnotStorage.EngineStorage storage $,
        address user
    ) internal view returns (uint256) {
        uint256[] storage mids = $.userMarketIds[user];
        uint256 totalWeightedCollateral;
        uint256 totalUserDebt;
        uint256 len = mids.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 mid = mids[i];
            CeitnotStorage.MarketPosition storage pos = $.positions[user][mid];
            if (pos.collateralShares == 0 && pos.principalDebt == 0) continue;
            IMarketRegistry.MarketConfig memory cfg = IMarketRegistry($.marketRegistry).getMarket(mid);
            uint256 assets = IERC4626(cfg.vault).convertToAssets(pos.collateralShares);
            (uint256 price, ) = IOracleRelay(cfg.oracle).getLatestPrice();
            uint256 collateralValue = _collateralDebtValue(assets, price, cfg.vault);
            totalWeightedCollateral += (collateralValue * cfg.liquidationThresholdBps) / 10_000;
            totalUserDebt           += _currentDebtInMarket($, user, mid);
        }
        if (totalUserDebt == 0) return type(uint256).max;
        return (totalWeightedCollateral * CeitnotStorage.WAD) / totalUserDebt;
    }

    function _requireHealthy(CeitnotStorage.EngineStorage storage $, address user) internal view {
        if (_healthFactor($, user) < CeitnotStorage.WAD) revert Ceitnot__HealthFactorBelowOne();
    }

    function _requireLtv(
        CeitnotStorage.EngineStorage storage $,
        address user,
        uint256 marketId,
        IMarketRegistry.MarketConfig memory cfg
    ) internal view {
        uint256 debt = _currentDebtInMarket($, user, marketId);
        if (debt == 0) return;
        CeitnotStorage.MarketPosition storage pos = $.positions[user][marketId];
        uint256 assets = IERC4626(cfg.vault).convertToAssets(pos.collateralShares);
        (uint256 price, ) = IOracleRelay(cfg.oracle).getLatestPrice();
        uint256 collateralValue = _collateralDebtValue(assets, price, cfg.vault);
        if ((debt * 10_000) > (collateralValue * cfg.ltvBps)) revert Ceitnot__ExceedsLTV();
    }

    /// @dev Debt token uses 18 decimals (CeitnotUSD). Oracle price is WAD per USD. `assets` is underlying raw
    ///      (e.g. USDC 6 decimals). Scale so LTV/HF compare like-with-like against principal debt.
    function _collateralDebtValue(
        uint256 assetsRaw,
        uint256 priceWad,
        address vault
    ) internal view returns (uint256) {
        uint256 v = (assetsRaw * priceWad) / CeitnotStorage.WAD;
        uint8 ad  = _underlyingAssetDecimals(vault);
        if (ad < 18) {
            unchecked {
                v *= 10 ** (18 - uint256(ad));
            }
        } else if (ad > 18) {
            v /= 10 ** (uint256(ad) - 18);
        }
        return v;
    }

    function _underlyingAssetDecimals(address vault) internal view returns (uint8) {
        try IERC4626(vault).asset() returns (address asset) {
            try IERC20Metadata(asset).decimals() returns (uint8 d) {
                return d;
            } catch {
                return _vaultShareDecimals(vault);
            }
        } catch {
            return _vaultShareDecimals(vault);
        }
    }

    function _vaultShareDecimals(address vault) internal view returns (uint8) {
        try IERC20Metadata(vault).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }

    function _collateralValuePerShare(
        IMarketRegistry.MarketConfig memory cfg
    ) internal view returns (uint256) {
        IERC4626 v = IERC4626(cfg.vault);
        uint256 oneShare = 10 ** uint256(_vaultShareDecimals(cfg.vault));
        uint256 assetsPerShare = v.convertToAssets(oneShare);
        (uint256 price, ) = IOracleRelay(cfg.oracle).getLatestPrice();
        return _collateralDebtValue(assetsPerShare, price, cfg.vault);
    }

    // ------------------------------- Internal: interest accrual

    /**
     * @dev Returns the effective combined scale for a market:
     *      effectiveScale = globalDebtScale * borrowIndex / RAY
     *      Falls back to RAY if either component is uninitialized (== 0).
     */
    function _effectiveScale(
        CeitnotStorage.MarketState storage ms
    ) internal view returns (uint256) {
        uint256 gds = ms.globalDebtScale == 0 ? CeitnotStorage.RAY : ms.globalDebtScale;
        uint256 bi  = ms.borrowIndex     == 0 ? CeitnotStorage.RAY : ms.borrowIndex;
        return (gds * bi) / CeitnotStorage.RAY;
    }

    /**
     * @dev Accrue interest for a market up to the current block timestamp.
     *      Must be called before any state mutation in a market.
     *      - Initialises borrowIndex / lastAccrualTimestamp on first call.
     *      - Skips when deltaT == 0 or IRM rates are all zero.
     */
    function _accrueInterest(
        CeitnotStorage.EngineStorage storage $,
        uint256 marketId
    ) internal {
        CeitnotStorage.MarketState storage ms = $.marketStates[marketId];

        // Initialise on first touch
        if (ms.borrowIndex == 0) {
            ms.borrowIndex          = CeitnotStorage.RAY;
            ms.lastAccrualTimestamp = block.timestamp;
            return;
        }

        uint256 deltaT = block.timestamp - ms.lastAccrualTimestamp;
        if (deltaT == 0) return;

        ms.lastAccrualTimestamp = block.timestamp;

        // Read IRM params from registry
        IMarketRegistry.MarketConfig memory cfg =
            IMarketRegistry($.marketRegistry).getMarket(marketId);

        // Skip computation if no IRM configured
        if (cfg.baseRate == 0 && cfg.slope1 == 0 && cfg.slope2 == 0) return;

        uint256 utilization = InterestRateModel.getUtilizationRate(
            ms.totalPrincipalDebt,
            cfg.borrowCap
        );
        uint256 ratePerSec = InterestRateModel.getBorrowRate(
            utilization,
            cfg.baseRate,
            cfg.slope1,
            cfg.slope2,
            cfg.kink
        );
        if (ratePerSec == 0) return;

        // borrowIndex grows: newIndex = oldIndex * (1 + rate * deltaT)
        // Using: newIndex = oldIndex + oldIndex * rate * deltaT / RAY
        uint256 interestFactor = (ratePerSec * deltaT); // RAY * seconds
        uint256 indexDelta     = (ms.borrowIndex * interestFactor) / CeitnotStorage.RAY;
        uint256 newBorrowIndex = ms.borrowIndex + indexDelta;

        // Compute gross interest on total debt (WAD)
        uint256 effectiveDebt = (ms.totalPrincipalDebt * ms.borrowIndex) / CeitnotStorage.RAY;
        uint256 interestAccrued = (effectiveDebt * interestFactor) / CeitnotStorage.RAY;

        // Reserve accrual
        uint256 reservesAccrued;
        if (cfg.reserveFactorBps > 0 && interestAccrued > 0) {
            reservesAccrued = (interestAccrued * cfg.reserveFactorBps) / 10_000;
            ms.totalReserves += reservesAccrued;
        }

        ms.borrowIndex = newBorrowIndex;

        emit InterestAccrued(marketId, interestAccrued, reservesAccrued, newBorrowIndex);
    }

    function _transferIn(address token, address from, uint256 amount) internal {
        (bool ok, bytes memory ret) = token.call(abi.encodeWithSelector(0x23b872dd, from, address(this), amount));
        if (!ok || (ret.length != 0 && !abi.decode(ret, (bool)))) revert Ceitnot__InvalidParams();
    }

    function _transferOut(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory ret) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        if (!ok || (ret.length != 0 && !abi.decode(ret, (bool)))) revert Ceitnot__InvalidParams();
    }

    // ------------------------------- Phase 9: CDP helpers

    /**
     * @dev Lend `amount` of debtToken to `to`.
     *      CDP mode  → mint ceitUSD directly to recipient.
     *      Legacy mode → ERC-20 transfer from engine balance.
     */
    function _lendDebtToken(
        CeitnotStorage.EngineStorage storage $,
        address to,
        uint256 amount
    ) internal {
        if ($.mintableDebtToken) {
            ICeitnotUSD($.debtToken).mint(to, amount);
        } else {
            _transferOut($.debtToken, to, amount);
        }
    }

    /**
     * @dev Recover `amount` of debtToken from `from`.
     *      CDP mode  → burnFrom (requires prior approve from `from` to this contract).
     *      Legacy mode → transferFrom into engine balance.
     */
    function _recoverDebtToken(
        CeitnotStorage.EngineStorage storage $,
        address from,
        uint256 amount
    ) internal {
        if ($.mintableDebtToken) {
            ICeitnotUSD($.debtToken).burnFrom(from, amount);
        } else {
            _transferIn($.debtToken, from, amount);
        }
    }
}
