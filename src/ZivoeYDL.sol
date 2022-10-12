// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "./libraries/ZivoeMath.sol";

import "./libraries/OpenZeppelin/IERC20.sol";
import "./libraries/OpenZeppelin/Ownable.sol";
import "./libraries/OpenZeppelin/SafeERC20.sol";

import { IZivoeRewards, IERC20Mintable, IZivoeGlobals } from "./misc/InterfacesAggregated.sol";

/// @dev    This contract manages the accounting for distributing yield across multiple contracts.
///         This contract has the following responsibilities:
///           - Handles accounting methods and historical tracking for future yield distribution.
///           - Allows governable params to be updated for modifying accounting practices.
contract ZivoeYDL is Ownable {

    using SafeERC20 for IERC20;
    using ZivoeMath for uint256;

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
    uint256 public emaSTT;                  /// @dev Weighted moving average for senior tranche size, a.k.a. zSTT.totalSupply()
    uint256 public emaJTT;                  /// @dev Weighted moving average for junior tranche size, a.k.a. zJTT.totalSupply()
    uint256 public emaYield;                /// @dev Weighted moving average for yield distributions.

    // Indexing.
    uint256 public numDistributions;        /// @dev # of calls to distributeYield() starts at 0, computed on current index for moving averages
    uint256 public lastDistribution;        /// @dev Used for timelock constraint to call distributeYield()

    // Accounting vars (governable).
    uint256 public targetAPYBIPS = 800;             /// @dev The target annualized yield for senior tranche.
    uint256 public targetRatioBIPS = 16250;         /// @dev The target ratio of junior to senior tranche.
    uint256 public protocolEarningsRateBIPS = 2000; /// @dev The protocol earnings rate.

    // Accounting vars (fixed).
    uint256 public daysBetweenDistributions = 30;   /// @dev Number of days between yield distributions.
    uint256 public retrospectiveDistributions = 6;  /// @dev The # of distributions to track historical (weighted) performance.

    uint256 private constant BIPS = 10000;
    uint256 private constant WAD = 10 ** 18;
    uint256 private constant RAY = 10 ** 27;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initialize the ZivoeYDL.sol contract.
    /// @param _GBL The ZivoeGlobals contract.
    /// @param _distributedAsset The "stablecoin" that will be distributed via YDL.
    constructor(address _GBL, address _distributedAsset) {
        GBL = _GBL;
        distributedAsset = _distributedAsset;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during setDistributedAsset().
    /// @param  asset The asset recovered from this contract (migrated to DAO).
    /// @param  amount The amount recovered.
    event AssetRecovered(address asset, uint256 amount);

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
    event UpdatedDistributedAsset(address oldAsset, address newAsset);

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

    /// @notice Emitted during supplementYield().
    /// @param  senior The amount of yield supplemented to the senior tranche.
    /// @param  junior The amount of yield supplemented to the junior tranche.
    event YieldSupplemented(uint256 senior, uint256 junior);



    // ---------------
    //    Functions
    // ---------------

    // TODO: Consider range-bound limitations for these setters.

    function setTargetAPYBIPS(uint _targetAPYBIPS) external onlyOwner {
        emit UpdatedTargetAPYBIPS(targetAPYBIPS, _targetAPYBIPS);
        targetAPYBIPS = _targetAPYBIPS;
    }

    function setTargetRatioBIPS(uint _targetRatioBIPS) external onlyOwner {
        emit UpdatedTargetRatioBIPS(targetRatioBIPS, _targetRatioBIPS);
        targetRatioBIPS = _targetRatioBIPS;
    }

    function setProtocolEarningsRateBIPS(uint _protocolEarningsRateBIPS) external onlyOwner {
        emit UpdatedProtocolEarningsRateBIPS(protocolEarningsRateBIPS, _protocolEarningsRateBIPS);
        protocolEarningsRateBIPS = _protocolEarningsRateBIPS;
    }


    /// @notice Updates the distributed asset for this particular contract.
    function setDistributedAsset(address _distributedAsset) external onlyOwner {
        require(
            IZivoeGlobals(GBL).stablecoinWhitelist(_distributedAsset),
            "ZivoeYDL::setDistributedAsset() !IZivoeGlobals(GBL).stablecoinWhitelist(_distributedAsset)"
        );
        emit UpdatedDistributedAsset(distributedAsset, _distributedAsset);
        IERC20(distributedAsset).safeTransfer(IZivoeGlobals(GBL).DAO(), IERC20(distributedAsset).balanceOf(address(this)));
        distributedAsset = _distributedAsset;
    }

    /// @notice Recovers any extraneous ERC-20 asset held within this contract.
    function recoverAsset(address asset) external onlyOwner {
        require(asset != distributedAsset, "ZivoeYDL::recoverAsset() asset == distributedAsset");
        emit AssetRecovered(asset, IERC20(asset).balanceOf(address(this)));
        IERC20(asset).safeTransfer(IZivoeGlobals(GBL).DAO(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Unlocks this contract for distributions, initializes values.
    function unlock() external {
        require(_msgSender() == IZivoeGlobals(GBL).ITO(), "ZivoeYDL::unlock() _msgSender() != IZivoeGlobals(GBL).ITO()");

        unlocked = true;
        lastDistribution = block.timestamp;

        emaSTT = IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();
        emaJTT = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply();

        address[] memory protocolRecipientAcc = new address[](1);
        uint256[] memory protocolRecipientAmt = new uint256[](1);

        protocolRecipientAcc[0] = address(IZivoeGlobals(GBL).DAO());
        protocolRecipientAmt[0] = 10000;

        protocolRecipients = Recipients(protocolRecipientAcc, protocolRecipientAmt);

        address[] memory residualRecipientAcc = new address[](3);
        uint256[] memory residualRecipientAmt = new uint256[](3);

        residualRecipientAcc[0] = address(IZivoeGlobals(GBL).stJTT());
        residualRecipientAmt[0] = 3333;
        residualRecipientAcc[1] = address(IZivoeGlobals(GBL).stSTT());
        residualRecipientAmt[1] = 3333;
        residualRecipientAcc[2] = address(IZivoeGlobals(GBL).DAO());
        residualRecipientAmt[2] = 3334;

        residualRecipients = Recipients(residualRecipientAcc, residualRecipientAmt);
    }

    function updateProtocolRecipients(address[] memory recipients, uint256[] memory proportions) external onlyOwner {
        require(recipients.length == proportions.length && recipients.length > 0);
        uint256 proportionTotal;
        for (uint i = 0; i < recipients.length; i++) {
            proportionTotal += proportions[i];
        }
        require(proportionTotal == BIPS);
        emit UpdatedProtocolRecipients(recipients, proportions);
        protocolRecipients = Recipients(recipients, proportions);
    }

    function updateResidualRecipients(address[] memory recipients, uint256[] memory proportions) external onlyOwner {
        require(recipients.length == proportions.length && recipients.length > 0);
        uint256 proportionTotal;
        for (uint i = 0; i < recipients.length; i++) {
            proportionTotal += proportions[i];
        }
        require(proportionTotal == BIPS);
        emit UpdatedResidualRecipients(recipients, proportions);
        residualRecipients = Recipients(recipients, proportions);
    }

    /// @return protocol Protocol earnings.
    /// @return senior Senior tranche earnings.
    /// @return junior Junior tranche earnings.
    /// @return residual Residual earnings.
    function earningsTrancheuse(
        uint256 seniorTrancheSize, 
        uint256 juniorTrancheSize
    ) internal view returns (
        uint256[] memory protocol, 
        uint256 senior,
        uint256 junior,
        uint256[] memory residual
    ) {

        uint256 earnings = IERC20(distributedAsset).balanceOf(address(this));

        // Handle accounting for protocol earnings.
        protocol = new uint256[](protocolRecipients.recipients.length);
        uint protocolEarnings = protocolEarningsRateBIPS * earnings / BIPS;
        for (uint i = 0; i < protocolRecipients.recipients.length; i++) {
            protocol[i] = protocolRecipients.proportion[i] * protocolEarnings / BIPS;
        }

        earnings = earnings.zSub(protocolEarnings);

        // Standardize "earnings" value to wei, irregardless of IERC20(distributionAsset).decimals()
        
        uint256 _convertedEarnings = earnings;

        if (IERC20Mintable(distributedAsset).decimals() < 18) {
            _convertedEarnings *= 10 ** (18 - IERC20Mintable(distributedAsset).decimals());
        }
        else if (IERC20Mintable(distributedAsset).decimals() > 18) {
            _convertedEarnings *= 10 ** (IERC20Mintable(distributedAsset).decimals() - 18);
        }

        uint256 _seniorRate = rateSenior_RAY(
            _convertedEarnings,
            seniorTrancheSize,
            juniorTrancheSize,
            targetAPYBIPS,
            targetRatioBIPS,
            daysBetweenDistributions,
            retrospectiveDistributions
        );
        
        uint256 _juniorRate = rateJunior_RAY(
            seniorTrancheSize,
            juniorTrancheSize,
            _seniorRate,
            targetRatioBIPS
        );

        senior = (earnings * _seniorRate) / RAY;
        junior = (earnings * _juniorRate) / RAY;
        
        // Handle accounting for residual earnings.
        residual = new uint256[](residualRecipients.recipients.length);
        uint residualEarnings = earnings.zSub(senior + junior);
        for (uint i = 0; i < residualRecipients.recipients.length; i++) {
            residual[i] = residualRecipients.proportion[i] * residualEarnings / BIPS;
        }

    }

    /// @notice Distributes available yield within this contract to appropriate entities
    function distributeYield() external {

        require(
            block.timestamp >= lastDistribution + daysBetweenDistributions * 86400, 
            "ZivoeYDL::distributeYield() block.timestamp < lastDistribution + daysBetweenDistributions * 86400"
        );
        require(unlocked, "ZivoeYDL::distributeYield() !unlocked"); 

        (uint256 seniorSupp, uint256 juniorSupp) = IZivoeGlobals(GBL).adjustedSupplies();

        (
            uint256[] memory _protocol,
            uint256 _seniorTranche,
            uint256 _juniorTranche,
            uint256[] memory _residual
        ) = earningsTrancheuse(seniorSupp, juniorSupp);

        emit YieldDistributed(_protocol, _seniorTranche, _juniorTranche, _residual);

        numDistributions += 1;
        
        // Standardize "_seniorTranche" value to wei, irregardless of IERC20(distributionAsset).decimals()

        uint256 _convertedSeniorTranche = _seniorTranche;

        if (IERC20Mintable(distributedAsset).decimals() < 18) {
            _convertedSeniorTranche *= 10 ** (18 - IERC20Mintable(distributedAsset).decimals());
        }
        else if (IERC20Mintable(distributedAsset).decimals() > 18) {
            _convertedSeniorTranche *= 10 ** (IERC20Mintable(distributedAsset).decimals() - 18);
        }

        emaYield = ema(
            emaYield,
            _convertedSeniorTranche,
            retrospectiveDistributions,
            numDistributions
        );

        emaSTT = ema(
            emaSTT,
            seniorSupp,
            retrospectiveDistributions,
            numDistributions
        );

        emaJTT = ema(
            emaJTT,
            juniorSupp,
            retrospectiveDistributions,
            numDistributions
        );

        lastDistribution = block.timestamp;

        // Distribute protocol earnings.
        for (uint i = 0; i < protocolRecipients.recipients.length; i++) {
            address _recipient = protocolRecipients.recipients[i];
            if (_recipient == IZivoeGlobals(GBL).stSTT() ||_recipient == IZivoeGlobals(GBL).stJTT()) {
                IERC20(distributedAsset).approve(_recipient, _protocol[i]);
                IZivoeRewards(_recipient).depositReward(distributedAsset, _protocol[i]);
            }
            else if (_recipient == IZivoeGlobals(GBL).stZVE()) {
                uint256 splitBIPS = (
                    IERC20(IZivoeGlobals(GBL).stZVE()).totalSupply() * BIPS
                ) / (IERC20(IZivoeGlobals(GBL).stZVE()).totalSupply() + IERC20(IZivoeGlobals(GBL).vestZVE()).totalSupply());
                IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stZVE(), _protocol[i] * splitBIPS / BIPS);
                IERC20(distributedAsset).approve(IZivoeGlobals(GBL).vestZVE(), _protocol[i] * (BIPS - splitBIPS) / BIPS);
                IZivoeRewards(IZivoeGlobals(GBL).stZVE()).depositReward(distributedAsset, _protocol[i] * splitBIPS / BIPS);
                IZivoeRewards(IZivoeGlobals(GBL).vestZVE()).depositReward(distributedAsset, _protocol[i] * (BIPS - splitBIPS) / BIPS);
            }
            else {
                IERC20(distributedAsset).safeTransfer(_recipient, _protocol[i]);
            }
        }

        // Distribute senior and junior tranche earnings.
        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stSTT(), _seniorTranche);
        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stJTT(), _juniorTranche);
        IZivoeRewards(IZivoeGlobals(GBL).stSTT()).depositReward(distributedAsset, _seniorTranche);
        IZivoeRewards(IZivoeGlobals(GBL).stJTT()).depositReward(distributedAsset, _juniorTranche);

        // Distribute residual earnings.
        for (uint i = 0; i < residualRecipients.recipients.length; i++) {
            if (_residual[i] > 0) {
                address _recipient = residualRecipients.recipients[i];
                if (_recipient == IZivoeGlobals(GBL).stSTT() ||_recipient == IZivoeGlobals(GBL).stJTT()) {
                    IERC20(distributedAsset).approve(_recipient, _residual[i]);
                    IZivoeRewards(_recipient).depositReward(distributedAsset, _residual[i]);
                }
                else if (_recipient == IZivoeGlobals(GBL).stZVE()) {
                    uint256 splitBIPS = (
                        IERC20(IZivoeGlobals(GBL).stZVE()).totalSupply() * BIPS
                    ) / (IERC20(IZivoeGlobals(GBL).stZVE()).totalSupply() + IERC20(IZivoeGlobals(GBL).vestZVE()).totalSupply());
                    IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stZVE(), _residual[i] * splitBIPS / BIPS);
                    IERC20(distributedAsset).approve(IZivoeGlobals(GBL).vestZVE(), _residual[i] * (BIPS - splitBIPS) / BIPS);
                    IZivoeRewards(IZivoeGlobals(GBL).stZVE()).depositReward(distributedAsset, _residual[i] * splitBIPS / BIPS);
                    IZivoeRewards(IZivoeGlobals(GBL).vestZVE()).depositReward(distributedAsset, _residual[i] * (BIPS - splitBIPS) / BIPS);
                }
                else {
                    IERC20(distributedAsset).safeTransfer(_recipient, _residual[i]);
                }
            }
        }

    }

    /// @notice gives asset to junior and senior, divided up by nominal rate(same as normal with no retrospective shortfall adjustment) for surprise rewards, 
    ///         manual interventions, and to simplify governance proposals by making use of accounting here. 
    /// @param amount - amount to send
    function supplementYield(uint256 amount) external {

        require(unlocked, "ZivoeYDL::supplementYield() !unlocked");

        (uint256 seniorSupp,) = IZivoeGlobals(GBL).adjustedSupplies();
    
        uint256 seniorRate = seniorRateNominal_RAY(amount, seniorSupp, targetAPYBIPS, daysBetweenDistributions);
        uint256 toSenior = (amount * seniorRate) / RAY;
        uint256 toJunior = amount.zSub(toSenior);

        emit YieldSupplemented(toSenior, toJunior);

        IERC20(distributedAsset).safeTransferFrom(msg.sender, address(this), amount);

        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stSTT(), toSenior);
        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stJTT(), toJunior);
        IZivoeRewards(IZivoeGlobals(GBL).stSTT()).depositReward(distributedAsset, toSenior);
        IZivoeRewards(IZivoeGlobals(GBL).stJTT()).depositReward(distributedAsset, toJunior);

    }

    // ----------
    //    Math
    // ----------

    /**
        @notice     Calculates amount of annual yield required to meet target rate for both tranches.
        @param      sSTT = total supply of senior tranche token     (units = wei)
        @param      sJTT = total supply of junior tranche token     (units = wei)
        @param      Y    = target annual yield for senior tranche   (units = BIPS)
        @param      Q    = multiple of Y                            (units = BIPS)
        @param      T    = # of days between distributions          (units = integer)
            
        @dev        (Y * (sSTT + sJTT * Q / BIPS) * T / BIPS) / (365^2)
    */
    function yieldTarget(
        uint256 sSTT,
        uint256 sJTT,
        uint256 Y,
        uint256 Q,
        uint256 T
    ) public pure returns (uint256) {
        return (Y * (sSTT + sJTT * Q / BIPS) * T / BIPS) / (365^2);
    }

    /**
        @notice     Calculates % of yield attributable to senior tranche.
        @param      sSTT = total supply of senior tranche token    (units = wei)
        @param      sJTT = total supply of junior tranche token    (units = wei)
        @param      Y    = target annual yield for senior tranche  (units = BIPS)
        @param      Q    = multiple of Y                           (units = BIPS)
        @param      T    = # of days between distributions         (units = integer)
        @param      R    = # of distributions for retrospection    (units = integer)
    */
    function rateSenior_RAY(
        uint256 postFeeYield,
        uint256 sSTT,
        uint256 sJTT,
        uint256 Y,
        uint256 Q,
        uint256 T,
        uint256 R
    ) public view returns (uint256) {

        uint256 yT = yieldTarget(emaSTT, emaJTT, Y, Q, T);

        // CASE #1 => Shortfall.
        if (yT > postFeeYield) {
            return seniorRateShortfall_RAY(sSTT, sJTT, Q);
        }

        // CASE #2 => Excess, and historical under-performance.
        else if (yT >= emaYield && emaYield != 0) {
            return seniorRateCatchup_RAY(postFeeYield, yT, sSTT, sJTT, R, Q);
        }

        // CASE #3 => Excess, and out-performance.
        else {
            return seniorRateNominal_RAY(postFeeYield, sSTT, Y, T);
        }
    }

    /**
        @notice     Calculates % of yield attributable to senior tranche during excess but historical under-performance.
        @param      postFeeYield = yield distributable after fees  (units = wei)
        @param      yT   = yield distributable after fees          (units = wei)
        @param      sSTT = total supply of senior tranche token    (units = wei)
        @param      sJTT = total supply of junior tranche token    (units = wei)
        @param      R    = # of distributions for retrospection    (units = integer)
        @param      Q    = multiple of Y                           (units = BIPS)
    */
    function seniorRateCatchup_RAY(
        uint256 postFeeYield,
        uint256 yT,
        uint256 sSTT,
        uint256 sJTT,
        uint256 R,
        uint256 Q
    ) public view returns (uint256) {
        return ((R + 1) * yT * RAY * WAD).zSub(R * emaYield * RAY * WAD).zDiv(
                postFeeYield * (WAD + (Q * sJTT * WAD / BIPS).zDiv(sSTT))
            ).min(RAY);
    }

    /**
        @notice     Calculates % of yield attributable to junior tranche.
        @param      sSTT = total supply of senior tranche token    (units = wei)
        @param      sJTT = total supply of junior tranche token    (units = wei)
        @param      Y    = % of yield attributable to seniors      (units = RAY)
        @param      Q    = senior to junior tranche target ratio   (units = BIPS)
    */
    function rateJunior_RAY(
        uint256 sSTT,
        uint256 sJTT,
        uint256 Y,
        uint256 Q
    ) public pure returns (uint256) {
        if (Y > RAY) {
           return 0;
        }
        else {
            return (Q * sJTT * Y / BIPS).zDiv(sSTT).min(RAY - Y); 
        }
        
    }

    /**
        @notice     Calculates proportion of yield attributed to senior tranche (no extenuating circumstances).
        @dev        Precision of this return value is in RAY (10**27 greater than actual value).
        @param      sSTT = total supply of senior tranche token    (units = wei)
        @param      Y    = target annual yield for senior tranche  (units = BIPS)
        @param      T    = # of days between distributions         (units = integer)
            
        @dev                 Y  * sSTT * T
                       ------------------------  *  RAY
                       (365 ^ 2) * postFeeYield
    */
    function seniorRateNominal_RAY(
        uint256 postFeeYield,
        uint256 sSTT,
        uint256 Y,
        uint256 T
    ) public pure returns (uint256) {
        // NOTE: THIS WILL REVERT IF postFeeYield == 0 ?? ISSUE ??
        return ((RAY * Y * (sSTT) * T / BIPS) / (365^2)).zDiv(postFeeYield).min(RAY);
    }

    /**
        @notice     Calculates proportion of yield attributed to senior tranche (shortfall occurence).
        @dev        Precision of this return value is in RAY (10**27 greater than actual value).
        @param      sSTT = total supply of senior tranche token    (units = wei)
        @param      sJTT = total supply of junior tranche token    (units = wei)
        @param      Q    = senior to junior tranche target ratio   (units = integer)
            
        @dev                   WAD
                       -------------------------  *  RAY
                                 Q * sJTT * WAD      
                        WAD  +   --------------
                                      sSTT
    */
    function seniorRateShortfall_RAY(
        uint256 sSTT,
        uint256 sJTT,
        uint256 Q
    ) public pure returns (uint256) {
        return (WAD * RAY).zDiv(WAD + (Q * sJTT * WAD / BIPS).zDiv(sSTT)).min(RAY);
    }

    /**
        @notice Returns a given value's EMA based on prior and new values.
        @param  avg = The current value (likely an average).
        @param  newval = The next value to add to "avg".
        @param  N = Number of steps we are averaging over (nominally, it is infinite).
        @param  t = Number of time steps total that have occurred, only used when t < N.
        @dev    Exponentially weighted moving average, written in float arithmatic as:
        
                                     newval - avg_n
                avg_{n+1} = avg_n + ----------------    
                                        min(N,t)
    */
    
    function ema(
        uint256 avg,
        uint256 newval,
        uint256 N,
        uint256 t
    ) public pure returns (uint256 nextavg) {
        if (N < t) {
            t = N; //use the count if we are still in the first window
        }
        uint256 _diff = (WAD * (newval.zSub(avg))).zDiv(t); //if newval>avg
        if (_diff == 0) { //if newval - avg < t
            _diff = (WAD * (avg.zSub(newval))).zDiv(t);   /// abg > newval
            nextavg = ((avg * WAD).zSub(_diff)).zDiv(WAD); /// newval < avg
        } else {
            nextavg = (avg * WAD + _diff).zDiv(WAD); // if newval > avg
        }
    }

}
