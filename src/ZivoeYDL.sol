// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "./libraries/FloorMath.sol";

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface YDL_IZivoeRewards {
    /// @notice Deposits a reward to this contract for distribution.
    /// @param  _rewardsToken The asset that's being distributed.
    /// @param  reward The amount of the _rewardsToken to deposit.
    function depositReward(address _rewardsToken, uint256 reward) external;
}

interface YDL_IZivoeGlobals {
    /// @notice Returns the address of the Timelock contract.
    function TLC() external view returns (address);

    /// @notice Returns the address of the ZivoeITO contract.
    function ITO() external view returns (address);

    /// @notice Returns the address of the ZivoeDAO contract.
    function DAO() external view returns (address);

    /// @notice Returns the address of the ZivoeTrancheToken ($zSTT) contract.
    function zSTT() external view returns (address);

    /// @notice Returns the address of the ZivoeTrancheToken ($zJTT) contract.
    function zJTT() external view returns (address);

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param amount The amount of a given "asset".
    /// @param asset The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount The above amount standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);

    /// @notice Returns total circulating supply of zSTT and zJTT, accounting for defaults via markdowns.
    /// @return zSTTSupply zSTT.totalSupply() adjusted for defaults.
    /// @return zJTTSupply zJTT.totalSupply() adjusted for defaults.
    function adjustedSupplies() external view returns (uint256 zSTTSupply, uint256 zJTTSupply);

    /// @notice This function will verify if a given stablecoin has been whitelisted for use throughout system (ZVE, YDL).
    /// @param stablecoin address of the stablecoin to verify acceptance for.
    /// @return whitelisted Will equal "true" if stabeloin is acceptable, and "false" if not.
    function stablecoinWhitelist(address stablecoin) external view returns (bool whitelisted);
    
    /// @notice Returns the address of the ZivoeRewards ($zSTT) contract.
    function stSTT() external view returns (address);

    /// @notice Returns the address of the ZivoeRewards ($zJTT) contract.
    function stJTT() external view returns (address);

    /// @notice Returns the address of the ZivoeRewards ($ZVE) contract.
    function stZVE() external view returns (address);

    /// @notice Returns the address of the ZivoeRewardsVesting ($ZVE) vesting contract.
    function vestZVE() external view returns (address);
}

/// @notice  This contract manages the accounting for distributing yield across multiple contracts.
///          This contract has the following responsibilities:
///            - Escrows yield in between distribution periods.
///            - Manages accounting for yield distribution.
///            - Supports modification of certain state variables for governance purposes.
///            - Tracks historical values using EMA (exponential moving average) on 30-day basis.
contract ZivoeYDL is Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using FloorMath for uint256;

    // ---------------------
    //    State Variables
    // ---------------------

    struct Recipients {
        address[] recipients;
        uint256[] proportion;
    }

    Recipients protocolRecipients;          /// @dev Tracks the distributions for protocol earnings.
    Recipients residualRecipients;          /// @dev Tracks the distributions for residual earnings.

    address public immutable GBL;           /// @dev The ZivoeGlobals contract.

    address public distributedAsset;        /// @dev The "stablecoin" that will be distributed via YDL.
    
    bool public unlocked;                   /// @dev Prevents contract from supporting functionality until unlocked.

    // Weighted moving averages.
    uint256 public emaSTT;                  /// @dev Weighted moving average for senior tranche size, a.k.a. zSTT.totalSupply().
    uint256 public emaJTT;                  /// @dev Weighted moving average for junior tranche size, a.k.a. zJTT.totalSupply().
    uint256 public emaYield;                /// @dev Weighted moving average for yield distributions.

    // Indexing.
    uint256 public numDistributions;        /// @dev # of calls to distributeYield() starts at 0, computed on current index for moving averages.
    uint256 public lastDistribution;        /// @dev Used for timelock constraint to call distributeYield().

    // Accounting vars (governable).
    uint256 public targetAPYBIPS = 800;             /// @dev The target annualized yield for senior tranche.
    uint256 public targetRatioBIPS = 16250;         /// @dev The target ratio of junior to senior tranche.
    uint256 public protocolEarningsRateBIPS = 2000; /// @dev The protocol earnings rate.

    // Accounting vars (constant).
    uint256 public constant daysBetweenDistributions = 30;   /// @dev Number of days between yield distributions.
    uint256 public constant retrospectiveDistributions = 6;  /// @dev The # of distributions to track historical (weighted) performance.

    uint256 private constant BIPS = 10000;
    uint256 private constant WAD = 10 ** 18;
    uint256 private constant RAY = 10 ** 27;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initialize the ZivoeYDL contract.
    /// @param _GBL The ZivoeGlobals contract.
    /// @param _distributedAsset The "stablecoin" that will be distributed via YDL.
    constructor(address _GBL, address _distributedAsset) {
        GBL = _GBL;
        distributedAsset = _distributedAsset;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during recoverAsset().
    /// @param  asset The asset recovered from this contract (migrated to DAO).
    /// @param  amount The amount recovered.
    event AssetRecovered(address indexed asset, uint256 amount);

    /// @notice Emitted during setTargetAPYBIPS().
    /// @param  oldValue The old value of targetAPYBIPS.
    /// @param  newValue The new value of targetAPYBIPS.
    event UpdatedTargetAPYBIPS(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during setTargetRatioBIPS().
    /// @param  oldValue The old value of targetRatioBIPS.
    /// @param  newValue The new value of targetRatioBIPS.
    event UpdatedTargetRatioBIPS(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during setProtocolEarningsRateBIPS().
    /// @param  oldValue The old value of protocolEarningsRateBIPS.
    /// @param  newValue The new value of protocolEarningsRateBIPS.
    event UpdatedProtocolEarningsRateBIPS(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during setDistributedAsset().
    /// @param  oldAsset The old asset of distributedAsset.
    /// @param  newAsset The new asset of distributedAsset.
    event UpdatedDistributedAsset(address indexed oldAsset, address indexed newAsset);

    /// @notice Emitted during updateProtocolRecipients().
    /// @param  recipients The new recipients to receive protocol earnings.
    /// @param  proportion The proportion distributed across recipients.
    event UpdatedProtocolRecipients(address[] recipients, uint256[] proportion);

    /// @notice Emitted during updateResidualRecipients().
    /// @param  recipients The new recipients to receive residual earnings.
    /// @param  proportion The proportion distributed across recipients.
    event UpdatedResidualRecipients(address[] recipients, uint256[] proportion);

    /// @notice Emitted during distributeYield().
    /// @param  protocol The amount of earnings distributed to protocol earnings recipients.
    /// @param  senior The amount of earnings distributed to the senior tranche.
    /// @param  junior The amount of earnings distributed to the junior tranche.
    /// @param  residual The amount of earnings distributed to residual earnings recipients.
    event YieldDistributed(uint256[] protocol, uint256 senior, uint256 junior, uint256[] residual);

    /// @notice Emitted during distributeYield().
    /// @param  asset The "asset" being distributed.
    /// @param  recipient The recipient of the distribution.
    /// @param  amount The amount distributed.
    event YieldDistributedSingle(address indexed asset, address indexed recipient, uint256 amount);

    /// @notice Emitted during supplementYield().
    /// @param  senior The amount of yield supplemented to the senior tranche.
    /// @param  junior The amount of yield supplemented to the junior tranche.
    event YieldSupplemented(uint256 senior, uint256 junior);



    // ---------------
    //    Functions
    // ---------------

    /// @notice Updates the state variable "targetAPYBIPS".
    /// @param _targetAPYBIPS The new value for targetAPYBIPS.
    function setTargetAPYBIPS(uint256 _targetAPYBIPS) external {
        require(_msgSender() == YDL_IZivoeGlobals(GBL).TLC(), "ZivoeYDL::setTargetAPYBIPS() _msgSender() != TLC()");

        emit UpdatedTargetAPYBIPS(targetAPYBIPS, _targetAPYBIPS);
        targetAPYBIPS = _targetAPYBIPS;
    }

    /// @notice Updates the state variable "targetRatioBIPS".
    /// @param _targetRatioBIPS The new value for targetRatioBIPS.
    function setTargetRatioBIPS(uint256 _targetRatioBIPS) external {
        require(_msgSender() == YDL_IZivoeGlobals(GBL).TLC(), "ZivoeYDL::setTargetRatioBIPS() _msgSender() != TLC()");

        emit UpdatedTargetRatioBIPS(targetRatioBIPS, _targetRatioBIPS);
        targetRatioBIPS = _targetRatioBIPS;
    }

    /// @notice Updates the state variable "protocolEarningsRateBIPS".
    /// @param _protocolEarningsRateBIPS The new value for protocolEarningsRateBIPS.
    function setProtocolEarningsRateBIPS(uint256 _protocolEarningsRateBIPS) external {
        require(_msgSender() == YDL_IZivoeGlobals(GBL).TLC(), "ZivoeYDL::setProtocolEarningsRateBIPS() _msgSender() != TLC()");
        require(_protocolEarningsRateBIPS <= 3000, "ZivoeYDL::setProtocolEarningsRateBIPS() _protocolEarningsRateBIPS > 3000");

        emit UpdatedProtocolEarningsRateBIPS(protocolEarningsRateBIPS, _protocolEarningsRateBIPS);
        protocolEarningsRateBIPS = _protocolEarningsRateBIPS;
    }

    /// @notice Updates the distributed asset for this particular contract.
    /// @param _distributedAsset The new value for distributedAsset.
    function setDistributedAsset(address _distributedAsset) external nonReentrant {
        require(_distributedAsset != distributedAsset, "ZivoeYDL::setDistributedAsset() _distributedAsset == distributedAsset");
        require(_msgSender() == YDL_IZivoeGlobals(GBL).TLC(), "ZivoeYDL::setDistributedAsset() _msgSender() != TLC()");
        require(
            YDL_IZivoeGlobals(GBL).stablecoinWhitelist(_distributedAsset),
            "ZivoeYDL::setDistributedAsset() !YDL_IZivoeGlobals(GBL).stablecoinWhitelist(_distributedAsset)"
        );

        emit UpdatedDistributedAsset(distributedAsset, _distributedAsset);
        // if (IERC20(distributedAsset).balanceOf(address(this)) > 0) {
        //     IERC20(distributedAsset).safeTransfer(YDL_IZivoeGlobals(GBL).DAO(), IERC20(distributedAsset).balanceOf(address(this)));
        // }
        distributedAsset = _distributedAsset;
    }

    /// @notice Recovers any extraneous ERC-20 asset held within this contract.
    /// @param asset The ERC20 asset to recoever.
    function recoverAsset(address asset) external {
        require(unlocked, "ZivoeYDL::recoverAsset() !unlocked");
        require(asset != distributedAsset, "ZivoeYDL::recoverAsset() asset == distributedAsset");

        emit AssetRecovered(asset, IERC20(asset).balanceOf(address(this)));
        IERC20(asset).safeTransfer(YDL_IZivoeGlobals(GBL).DAO(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Unlocks this contract for distributions, initializes values.
    function unlock() external {
        require(_msgSender() == YDL_IZivoeGlobals(GBL).ITO(), "ZivoeYDL::unlock() _msgSender() != YDL_IZivoeGlobals(GBL).ITO()");

        unlocked = true;
        lastDistribution = block.timestamp;

        emaSTT = IERC20(YDL_IZivoeGlobals(GBL).zSTT()).totalSupply();
        emaJTT = IERC20(YDL_IZivoeGlobals(GBL).zJTT()).totalSupply();

        address[] memory protocolRecipientAcc = new address[](2);
        uint256[] memory protocolRecipientAmt = new uint256[](2);

        protocolRecipientAcc[0] = address(YDL_IZivoeGlobals(GBL).stZVE());
        protocolRecipientAmt[0] = 7500;
        protocolRecipientAcc[1] = address(YDL_IZivoeGlobals(GBL).DAO());
        protocolRecipientAmt[1] = 2500;

        protocolRecipients = Recipients(protocolRecipientAcc, protocolRecipientAmt);

        address[] memory residualRecipientAcc = new address[](4);
        uint256[] memory residualRecipientAmt = new uint256[](4);

        residualRecipientAcc[0] = address(YDL_IZivoeGlobals(GBL).stJTT());
        residualRecipientAmt[0] = 2500;
        residualRecipientAcc[1] = address(YDL_IZivoeGlobals(GBL).stSTT());
        residualRecipientAmt[1] = 500;
        residualRecipientAcc[2] = address(YDL_IZivoeGlobals(GBL).stZVE());
        residualRecipientAmt[2] = 4500;
        residualRecipientAcc[3] = address(YDL_IZivoeGlobals(GBL).DAO());
        residualRecipientAmt[3] = 2500;

        residualRecipients = Recipients(residualRecipientAcc, residualRecipientAmt);
    }

    /// @notice Updates the protocolRecipients state variable which tracks the distributions for protocol earnings.
    /// @param recipients An array of addresses to which protocol earnings will be distributed.
    /// @param proportions An array of ratios relative to the recipients - in BIPS. Sum should equal to 10000.
    function updateProtocolRecipients(address[] memory recipients, uint256[] memory proportions) external {
        require(_msgSender() == YDL_IZivoeGlobals(GBL).TLC(), "ZivoeYDL::updateProtocolRecipients() _msgSender() != TLC()");
        require(
            recipients.length == proportions.length && recipients.length > 0, 
            "ZivoeYDL::updateProtocolRecipients() recipients.length != proportions.length || recipients.length == 0"
        );
        require(unlocked, "ZivoeYDL::updateProtocolRecipients() !unlocked");

        uint256 proportionTotal;
        for (uint256 i = 0; i < recipients.length; i++) {
            proportionTotal += proportions[i];
            require(proportions[i] > 0, "ZivoeYDL::updateProtocolRecipients() proportions[i] == 0");
        }

        require(proportionTotal == BIPS, "ZivoeYDL::updateProtocolRecipients() proportionTotal != BIPS (10,000)");

        emit UpdatedProtocolRecipients(recipients, proportions);
        protocolRecipients = Recipients(recipients, proportions);
    }

    /// @notice Updates the residualRecipients state variable which tracks the distribution for residual earnings.
    /// @param recipients An array of addresses to which residual earnings will be distributed.
    /// @param proportions An array of ratios relative to the recipients - in BIPS. Sum should equal to 10000.
    function updateResidualRecipients(address[] memory recipients, uint256[] memory proportions) external {
        require(_msgSender() == YDL_IZivoeGlobals(GBL).TLC(), "ZivoeYDL::updateResidualRecipients() _msgSender() != TLC()");
        require(
            recipients.length == proportions.length && recipients.length > 0, 
            "ZivoeYDL::updateResidualRecipients() recipients.length != proportions.length || recipients.length == 0"
        );
        require(unlocked, "ZivoeYDL::updateResidualRecipients() !unlocked");

        uint256 proportionTotal;
        for (uint256 i = 0; i < recipients.length; i++) {
            proportionTotal += proportions[i];
            require(proportions[i] > 0, "ZivoeYDL::updateResidualRecipients() proportions[i] == 0");
        }

        require(proportionTotal == BIPS, "ZivoeYDL::updateResidualRecipients() proportionTotal != BIPS (10,000)");

        emit UpdatedResidualRecipients(recipients, proportions);
        residualRecipients = Recipients(recipients, proportions);
    }

    /// @notice Will return the split of ongoing protocol earnings for a given senior and junior tranche size.
    /// @return protocol Protocol earnings.
    /// @return senior Senior tranche earnings.
    /// @return junior Junior tranche earnings.
    /// @return residual Residual earnings.
    function earningsTrancheuse() public view returns (
        uint256[] memory protocol, uint256 senior, uint256 junior, uint256[] memory residual
    ) {

        uint256 earnings = IERC20(distributedAsset).balanceOf(address(this));

        // Handle accounting for protocol earnings.
        protocol = new uint256[](protocolRecipients.recipients.length);
        uint256 protocolEarnings = protocolEarningsRateBIPS * earnings / BIPS;
        for (uint256 i = 0; i < protocolRecipients.recipients.length; i++) {
            protocol[i] = protocolRecipients.proportion[i] * protocolEarnings / BIPS;
        }

        earnings = earnings.zSub(protocolEarnings);

        uint256 _seniorProportion = seniorProportion(
            YDL_IZivoeGlobals(GBL).standardize(earnings, distributedAsset),
            yieldTarget(emaSTT, emaJTT, targetAPYBIPS, targetRatioBIPS, daysBetweenDistributions), emaYield,
            emaSTT, emaJTT,
            targetAPYBIPS, targetRatioBIPS, daysBetweenDistributions, retrospectiveDistributions
        );
        
        uint256 _juniorProportion = juniorProportion(emaSTT, emaJTT, _seniorProportion, targetRatioBIPS);

        // NOTE: Invariant, _seniorProportion + _juniorRate == RAY
        assert(_seniorProportion + _juniorProportion == RAY);

        senior = (earnings * _seniorProportion) / RAY;
        junior = (earnings * _juniorProportion) / RAY;
        
        // Handle accounting for residual earnings.
        residual = new uint256[](residualRecipients.recipients.length);
        uint256 residualEarnings = earnings.zSub(senior + junior);
        for (uint256 i = 0; i < residualRecipients.recipients.length; i++) {
            residual[i] = residualRecipients.proportion[i] * residualEarnings / BIPS;
        }

    }

    /// @notice Distributes available yield within this contract to appropriate entities.
    function distributeYield() external nonReentrant {
        require(unlocked, "ZivoeYDL::distributeYield() !unlocked"); 
        require(
            block.timestamp >= lastDistribution + daysBetweenDistributions * 86400, 
            "ZivoeYDL::distributeYield() block.timestamp < lastDistribution + daysBetweenDistributions * 86400"
        );

        (
            uint256[] memory _protocol, uint256 _seniorTranche, uint256 _juniorTranche, uint256[] memory _residual
        ) = earningsTrancheuse();

        emit YieldDistributed(_protocol, _seniorTranche, _juniorTranche, _residual);

        numDistributions += 1;
        lastDistribution = block.timestamp;
        
        if (numDistributions == 1) { emaYield = _seniorTranche + _juniorTranche; }
        else {
            emaYield = ema(
                emaYield, YDL_IZivoeGlobals(GBL).standardize(_seniorTranche + _juniorTranche, distributedAsset),
                retrospectiveDistributions, numDistributions
            );
        }
        
        (uint256 asSTT, uint256 asJTT) = YDL_IZivoeGlobals(GBL).adjustedSupplies();
        emaJTT = ema(emaJTT, asSTT, retrospectiveDistributions, numDistributions);
        emaSTT = ema(emaSTT, asJTT, retrospectiveDistributions, numDistributions);

        // Distribute protocol earnings.
        for (uint256 i = 0; i < protocolRecipients.recipients.length; i++) {
            address _recipient = protocolRecipients.recipients[i];
            if (_recipient == YDL_IZivoeGlobals(GBL).stSTT() ||_recipient == YDL_IZivoeGlobals(GBL).stJTT()) {
                IERC20(distributedAsset).safeApprove(_recipient, _protocol[i]);
                YDL_IZivoeRewards(_recipient).depositReward(distributedAsset, _protocol[i]);
                emit YieldDistributedSingle(distributedAsset, _recipient, _protocol[i]);
            }
            else if (_recipient == YDL_IZivoeGlobals(GBL).stZVE()) {
                uint256 splitBIPS = (
                    IERC20(YDL_IZivoeGlobals(GBL).stZVE()).totalSupply() * BIPS
                ) / (IERC20(YDL_IZivoeGlobals(GBL).stZVE()).totalSupply() + IERC20(YDL_IZivoeGlobals(GBL).vestZVE()).totalSupply());
                IERC20(distributedAsset).safeApprove(YDL_IZivoeGlobals(GBL).stZVE(), _protocol[i] * splitBIPS / BIPS);
                IERC20(distributedAsset).safeApprove(YDL_IZivoeGlobals(GBL).vestZVE(), _protocol[i] * (BIPS - splitBIPS) / BIPS);
                YDL_IZivoeRewards(YDL_IZivoeGlobals(GBL).stZVE()).depositReward(distributedAsset, _protocol[i] * splitBIPS / BIPS);
                YDL_IZivoeRewards(YDL_IZivoeGlobals(GBL).vestZVE()).depositReward(distributedAsset, _protocol[i] * (BIPS - splitBIPS) / BIPS);
                emit YieldDistributedSingle(distributedAsset, YDL_IZivoeGlobals(GBL).stZVE(), _protocol[i] * splitBIPS / BIPS);
                emit YieldDistributedSingle(distributedAsset, YDL_IZivoeGlobals(GBL).vestZVE(), _protocol[i] * (BIPS - splitBIPS) / BIPS);
            }
            else {
                IERC20(distributedAsset).safeTransfer(_recipient, _protocol[i]);
                emit YieldDistributedSingle(distributedAsset, _recipient, _protocol[i]);
            }
        }

        // Distribute senior and junior tranche earnings.
        IERC20(distributedAsset).safeApprove(YDL_IZivoeGlobals(GBL).stSTT(), _seniorTranche);
        IERC20(distributedAsset).safeApprove(YDL_IZivoeGlobals(GBL).stJTT(), _juniorTranche);
        YDL_IZivoeRewards(YDL_IZivoeGlobals(GBL).stSTT()).depositReward(distributedAsset, _seniorTranche);
        YDL_IZivoeRewards(YDL_IZivoeGlobals(GBL).stJTT()).depositReward(distributedAsset, _juniorTranche);
        emit YieldDistributedSingle(distributedAsset, YDL_IZivoeGlobals(GBL).stSTT(), _seniorTranche);
        emit YieldDistributedSingle(distributedAsset, YDL_IZivoeGlobals(GBL).stJTT(), _juniorTranche);

        // Distribute residual earnings.
        for (uint256 i = 0; i < residualRecipients.recipients.length; i++) {
            if (_residual[i] > 0) {
                address _recipient = residualRecipients.recipients[i];
                if (_recipient == YDL_IZivoeGlobals(GBL).stSTT() ||_recipient == YDL_IZivoeGlobals(GBL).stJTT()) {
                    IERC20(distributedAsset).safeApprove(_recipient, _residual[i]);
                    YDL_IZivoeRewards(_recipient).depositReward(distributedAsset, _residual[i]);
                    emit YieldDistributedSingle(distributedAsset, _recipient, _protocol[i]);
                }
                else if (_recipient == YDL_IZivoeGlobals(GBL).stZVE()) {
                    uint256 splitBIPS = (
                        IERC20(YDL_IZivoeGlobals(GBL).stZVE()).totalSupply() * BIPS
                    ) / (IERC20(YDL_IZivoeGlobals(GBL).stZVE()).totalSupply() + IERC20(YDL_IZivoeGlobals(GBL).vestZVE()).totalSupply());
                    IERC20(distributedAsset).safeApprove(YDL_IZivoeGlobals(GBL).stZVE(), _residual[i] * splitBIPS / BIPS);
                    IERC20(distributedAsset).safeApprove(YDL_IZivoeGlobals(GBL).vestZVE(), _residual[i] * (BIPS - splitBIPS) / BIPS);
                    YDL_IZivoeRewards(YDL_IZivoeGlobals(GBL).stZVE()).depositReward(distributedAsset, _residual[i] * splitBIPS / BIPS);
                    YDL_IZivoeRewards(YDL_IZivoeGlobals(GBL).vestZVE()).depositReward(distributedAsset, _residual[i] * (BIPS - splitBIPS) / BIPS);
                    emit YieldDistributedSingle(distributedAsset, YDL_IZivoeGlobals(GBL).stZVE(), _residual[i] * splitBIPS / BIPS);
                    emit YieldDistributedSingle(distributedAsset, YDL_IZivoeGlobals(GBL).vestZVE(), _residual[i] * (BIPS - splitBIPS) / BIPS);
                }
                else {
                    IERC20(distributedAsset).safeTransfer(_recipient, _residual[i]);
                    emit YieldDistributedSingle(distributedAsset, _recipient, _residual[i]);
                }
            }
        }

    }

    /// @notice Supplies yield directly to each tranche, divided up by nominal rate (same as normal with no retrospective
    ///         shortfall adjustment) for surprise rewards, manual interventions, and to simplify governance proposals by 
    ////        making use of accounting here. 
    /// @param amount Amount of distributedAsset() to supply.
    function supplementYield(uint256 amount) external {

        require(unlocked, "ZivoeYDL::supplementYield() !unlocked");

        // TODO: Consider emaSTT here ...
        (uint256 seniorSupp,) = YDL_IZivoeGlobals(GBL).adjustedSupplies();
    
        uint256 seniorRate = seniorRateBase(amount, seniorSupp, targetAPYBIPS, daysBetweenDistributions);
        uint256 toSenior = (amount * seniorRate) / RAY;
        uint256 toJunior = amount.zSub(toSenior);

        emit YieldSupplemented(toSenior, toJunior);

        IERC20(distributedAsset).safeTransferFrom(msg.sender, address(this), amount);

        IERC20(distributedAsset).safeApprove(YDL_IZivoeGlobals(GBL).stSTT(), toSenior);
        IERC20(distributedAsset).safeApprove(YDL_IZivoeGlobals(GBL).stJTT(), toJunior);
        YDL_IZivoeRewards(YDL_IZivoeGlobals(GBL).stSTT()).depositReward(distributedAsset, toSenior);
        YDL_IZivoeRewards(YDL_IZivoeGlobals(GBL).stJTT()).depositReward(distributedAsset, toJunior);
    }

    /// @notice View distribution information for protocol and residual earnings recipients.
    /// @return protocolEarningsRecipients The destinations for protocol earnings distributions.
    /// @return protocolEarningsProportion The proportions for protocol earnings distributions.
    /// @return residualEarningsRecipients The destinations for residual earnings distributions.
    /// @return residualEarningsProportion The proportions for residual earnings distributions.
    function viewDistributions() external view returns (
        address[] memory protocolEarningsRecipients, uint256[] memory protocolEarningsProportion, 
        address[] memory residualEarningsRecipients, uint256[] memory residualEarningsProportion
    ) {
        return (protocolRecipients.recipients, protocolRecipients.proportion, residualRecipients.recipients, residualRecipients.proportion);
    }

    // ----------
    //    Math
    // ----------

    /**
        @notice     Calculates amount of annual yield required to meet target rate for both tranches.
        @param      eSTT = ema-based supply of zSTT                  (units = WEI)
        @param      eJTT = ema-based supply of zJTT                  (units = WEI)
        @param      Y    = target annual yield for senior tranche   (units = BIPS)
        @param      Q    = multiple of Y                            (units = BIPS)
        @param      T    = # of days between distributions          (units = integer)
        @return     yT   = yield target for the senior and junior tranche combined.
        @dev        (Y * T * (eSTT + eJTT * Q / BIPS) / BIPS) / 365
        @dev        Precision of the return value is in WEI.
    */
    function yieldTarget(uint256 eSTT, uint256 eJTT, uint256 Y, uint256 Q, uint256 T) public pure returns (uint256 yT) {
        yT = (Y * T * (eSTT + eJTT * Q / BIPS) / BIPS) / 365;
    }

    /**
        @notice     Calculates proportion of yield distributble which is attributable to the senior tranche.
        @param      yD   = yield distributable                      (units = WEI)
        @param      yT   = ema-based yield target                   (units = WEI)
        @param      yA   = ema-based average yield distribution     (units = WEI)
        @param      eSTT = ema-based supply of zSTT                 (units = WEI)
        @param      eJTT = ema-based supply of zJTT                 (units = WEI)
        @param      Y    = target annual yield for senior tranche   (units = BIPS)
        @param      Q    = multiple of Y                            (units = BIPS)
        @param      T    = # of days between distributions          (units = integer)
        @param      R    = # of distributions for retrospection     (units = integer)
        @return     sP   = Proportion of yD attributable to senior tranche
        @dev        Precision of return value, sP, is in RAY (10**27).
    */
    function seniorProportion(
        uint256 yD, uint256 yT, uint256 yA, uint256 eSTT, uint256 eJTT, uint256 Y, uint256 Q, uint256 T, uint256 R
    ) public pure returns (uint256 sP) {
        // CASE #1 => Shortfall.
        if (yD < yT) { sP = seniorProportionShortfall(eSTT, eJTT, Q); }
        // CASE #2 => Excess, and historical under-performance.
        else if (yT >= yA && yA != 0) { sP = seniorProportionCatchup(yD, yA, yT, eSTT, eJTT, R, Q); }
        // CASE #3 => Excess, and out-performance.
        else { sP = seniorRateBase(yD, eSTT, Y, T); }
    }

    /**
        @notice     Calculates proportion of yield attributable to senior tranche during historical under-performance.
        @param      yD   = yield distributable                      (units = WEI)
        @param      yA   = emaYield                                 (units = WEI)
        @param      yT   = yieldTarget() return parameter           (units = WEI)
        @param      eSTT = ema-based supply of zSTT                 (units = WEI)
        @param      eJTT = ema-based supply of zJTT                 (units = WEI)
        @param      R    = # of distributions for retrospection     (units = integer)
        @param      Q    = multiple of Y                            (units = BIPS)
        @return     sPC  = Proportion of yD attributable to senior tranche
    */
    function seniorProportionCatchup(
        uint256 yD,
        uint256 yA,
        uint256 yT,
        uint256 eSTT,
        uint256 eJTT,
        uint256 R,
        uint256 Q
    ) public pure returns (uint256 sPC) {
        sPC = ((R + 1) * yT * RAY * WAD)
                .zSub(R * yA * RAY * WAD)
                .zDiv(yD * (WAD + (Q * eJTT * WAD / BIPS).zDiv(eSTT)))
                .min(RAY);
    }

    /**
        @notice     Calculates proportion of yield attributable to junior tranche.
        @param      eSTT = ema-based supply of zSTT                     (units = WEI)
        @param      eJTT = ema-based supply of zJTT                     (units = WEI)
        @param      Y    = Proportion of yield attributable to seniors  (units = RAY)
        @param      Q    = senior to junior tranche target ratio        (units = BIPS)
        @return     jP   = Yield attributable to junior tranche in RAY.
    */
    function juniorProportion(uint256 eSTT, uint256 eJTT, uint256 Y, uint256 Q) public pure returns (uint256 jP) {
        if (Y <= RAY) { jP = (Q * eJTT * Y / BIPS).zDiv(eSTT).min(RAY - Y); }
    }

    /**
        @notice     Calculates proportion of yield attributed to senior tranche (no extenuating circumstances).
        @dev        Precision of this return value is in RAY (10**27 greater than actual value).
        @dev              Y  * eSTT * T
                       ------------------ *  RAY
                           (365) * yD
        @param      yD   = yield distributable                      (units = WEI)
        @param      eSTT = ema-based supply of zSTT                 (units = WEI)
        @param      Y    = target annual yield for senior tranche   (units = BIPS)
        @param      T    = # of days between distributions          (units = integer)
        @return     sRB  = Proportion of yield attributed to senior tranche (in RAY).
        TODO: Consider if sSTT needs to be emaSTT here ...
    */
    function seniorRateBase(uint256 yD, uint256 eSTT, uint256 Y, uint256 T) public pure returns (uint256 sRB) {
        // TODO: Refer to below note.
        // NOTE: THIS WILL REVERT IF postFeeYield == 0 ?? ISSUE ??
        sRB = ((RAY * Y * (eSTT) * T / BIPS) / 365).zDiv(yD).min(RAY);
    }

    /**
        @notice     Calculates proportion of yield attributed to senior tranche (shortfall occurence).
        @dev        Precision of this return value is in RAY (10**27 greater than actual value).
        @dev                   WAD
                       -------------------------  *  RAY
                                 Q * eJTT * WAD      
                        WAD  +   --------------
                                      eSTT
        @param      eSTT = ema-based supply of zSTT                 (units = WEI)
        @param      eJTT = ema-based supply of zJTT                 (units = WEI)
        @param      Q    = senior to junior tranche target ratio    (units = integer)
        @return     sPS  = Proportion of yield attributed to senior tranche (in RAY).
        TODO: Consider if sSTT and sJTT need to be emaSTT and emaJTT here ...
    */
    function seniorProportionShortfall(uint256 eSTT, uint256 eJTT, uint256 Q) public pure returns (uint256 sPS) {
        sPS = (WAD * RAY).zDiv(WAD + (Q * eJTT * WAD / BIPS).zDiv(eSTT)).min(RAY);
    }

    /**
        @notice Returns a given value's EMA based on prior and new values.
        @dev    Exponentially weighted moving average, written in float arithmatic as:
                                     newval - avg_n
                avg_{n+1} = avg_n + ----------------    
                                        min(N,t)
        @param  avg = The current value (likely an average).
        @param  newval = The next value to add to "avg".
        @param  N = Number of steps we are averaging over (nominally, it is infinite).
        @param  t = Number of time steps total that have occurred, only used when t < N.
        @return nextavg New EMA based on prior and new values.
    */
    function ema(uint256 avg, uint256 newval, uint256 N, uint256 t) public pure returns (uint256 nextavg) {
        if (N < t) { t = N; }  /// @dev Use the count if we are still in the first window.
        uint256 _diff = (WAD * (newval.zSub(avg))).zDiv(t); // newval > avg.
        if (_diff == 0) { // newval - avg < t.
            _diff = (WAD * (avg.zSub(newval))).zDiv(t);   // abg > newval.
            nextavg = ((avg * WAD).zSub(_diff)).zDiv(WAD); // newval < avg.
        } else { nextavg = (avg * WAD + _diff).zDiv(WAD); }  // newval > avg.
    }

}
