// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "./libraries/ZivoeMath.sol";

import "./libraries/OpenZeppelin/IERC20.sol";
import "./libraries/OpenZeppelin/Ownable.sol";
import "./libraries/OpenZeppelin/SafeERC20.sol";

import { IZivoeRewards, IZivoeGlobals } from "./misc/InterfacesAggregated.sol";

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

    Recipients protocolRecipients;  /// @dev Tracks the distributions for protocol earnings.
    Recipients residualRecipients;  /// @dev Tracks the distributions for residual earnings.

    address public immutable GBL;   /// @dev The ZivoeGlobals contract.

    address public distributedAsset;    /// @dev The "stablecoin" that will be distributed via YDL.
    
    bool public unlocked;           /// @dev Prevents contract from supporting functionality until unlocked.

    // Historical tracking.
    uint256 public emaSTT;          /// @dev Historical tracking for senior tranche size, a.k.a. zSTT.totalSupply()
    uint256 public emaJTT;          /// @dev Historical tracking for junior tranche size, a.k.a. zJTT.totalSupply()
    uint256 public emaYield;        /// @dev Historical tracking for yield distributions.

    // Indexing.
    uint256 public numDistributions;    /// @dev # of calls to distributeYield() starts at 0, computed on current index for moving averages
    uint256 public lastDistribution;        /// @dev Used for timelock constraint to call distributeYield()

    // Accounting vars.
    uint256 public targetAPYBIPS = 500;         /// @dev The target annualized yield for senior tranche.
    uint256 public targetRatioBIPS = 30000;     /// @dev The target ratio of junior to senior tranche.
    uint256 public retrospectionTime = 6;       /// @dev The historical period to track shortfall in units of yieldTime
    uint256 public protocolRateBIPS = 2000;     /// @dev The protocol earnings rate.
    uint256 public yieldTimeUnit = 30 days;     /// @dev The period between yield distributions.



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



    // ---------------
    //    Functions
    // ---------------

    // TODO: Add setters for other variables where appropriate.
    // TODO: Evaluate and discuss ramifications of having adjustable retrospectionTime.

    /// @notice Updates the retrospectionTime variable.
    function set_retrospectionTime(uint256 _retrospectionTime) external onlyOwner {
        retrospectionTime = _retrospectionTime;
    }

    /// @notice Updates the distributed asset for this particular contract.
    function setDistributedAsset(address _distributedAsset) external onlyOwner {
        require(
            IZivoeGlobals(GBL).stablecoinWhitelist(_distributedAsset),
            "ZivoeYDL::setDistributedAsset() !IZivoeGlobals(GBL).stablecoinWhitelist(_distributedAsset)"
        );
        IERC20(distributedAsset).safeTransfer(IZivoeGlobals(GBL).DAO(), IERC20(distributedAsset).balanceOf(address(this)));
        distributedAsset = _distributedAsset;
    }

    /// @notice Recovers any extraneous ERC-20 asset held within this contract.
    function recoverAsset(address asset) external onlyOwner {
        require(asset != distributedAsset, "ZivoeYDL::recoverAsset() asset == distributedAsset");
        IERC20(asset).safeTransfer(IZivoeGlobals(GBL).DAO(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Unlocks this contract for distributions, initializes values.
    function unlock() external {
        require(_msgSender() == IZivoeGlobals(GBL).ITO(), "ZivoeYDL::unlock() _msgSender() != IZivoeGlobals(GBL).ITO()");

        unlocked = true;
        lastDistribution = block.timestamp;

        emaSTT = IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();
        emaJTT = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply();

        // TODO: Discuss initial parameters.

        address[] memory protocolRecipientAcc = new address[](2);
        uint256[] memory protocolRecipientAmt = new uint256[](2);

        protocolRecipientAcc[0] = address(IZivoeGlobals(GBL).stSTT());  // TODO: Test with stZVE()
        protocolRecipientAmt[0] = 6666;
        protocolRecipientAcc[1] = address(IZivoeGlobals(GBL).DAO());
        protocolRecipientAmt[1] = 3334;

        protocolRecipients = Recipients(protocolRecipientAcc, protocolRecipientAmt);

        address[] memory residualRecipientAcc = new address[](3);
        uint256[] memory residualRecipientAmt = new uint256[](3);

        residualRecipientAcc[0] = address(IZivoeGlobals(GBL).stSTT());  // TODO: Test with stZVE()
        residualRecipientAmt[0] = 9000;
        residualRecipientAcc[1] = address(IZivoeGlobals(GBL).stSTT());
        residualRecipientAmt[1] = 500;
        residualRecipientAcc[2] = address(IZivoeGlobals(GBL).stJTT());
        residualRecipientAmt[2] = 500;

        residualRecipients = Recipients(residualRecipientAcc, residualRecipientAmt);
    }

    // TODO: Determine if ownership should be owner() or DAO() or TLC()
    function updateProtocolRecipients(address[] memory recipients, uint256[] memory proportions) external onlyOwner {
        require(recipients.length == proportions.length && recipients.length > 0);
        uint256 proportionTotal;
        for (uint i = 0; i < recipients.length; i++) {
            proportionTotal += proportions[i];
        }
        require(proportionTotal == 10000);
        protocolRecipients = Recipients(recipients, proportions);
    }

    function updateResidualRecipients(address[] memory recipients, uint256[] memory proportions) external onlyOwner {
        require(recipients.length == proportions.length && recipients.length > 0);
        uint256 proportionTotal;
        for (uint i = 0; i < recipients.length; i++) {
            proportionTotal += proportions[i];
        }
        require(proportionTotal == 10000);
        residualRecipients = Recipients(recipients, proportions);
    }

    event Debug(string);
    event Debug(uint256);
    event Debug(uint256[]);
    event Debug(address[]);
    event Debug(uint256[7]);

    // TODO: Switch to below return variable.
    /// @return protocol Protocol earnings.
    /// @return senior Senior tranche earnings.
    /// @return junior Junior tranche earnings.
    /// @return residual Residual earnings.
    function earningsTrancheuse(
        uint256 seniorTrancheSize, 
        uint256 juniorTrancheSize
    ) internal returns (
        uint256[] memory protocol, 
        uint256 senior,
        uint256 junior,
        uint256[] memory residual
    ) {

        uint256 earnings = IERC20(distributedAsset).balanceOf(address(this));

        emit Debug('earnings');
        emit Debug(earnings);

        // Handle accounting for protocol earnings.
        protocol = new uint256[](protocolRecipients.recipients.length);
        uint protocolEarnings = protocolRateBIPS * earnings / 10000;
        for (uint i = 0; i < protocolRecipients.recipients.length; i++) {
            protocol[i] = protocolRecipients.proportion[i] * protocolEarnings / 10000;
        }

        emit Debug('protocolEarnings');
        emit Debug(protocolEarnings);

        earnings = earnings.zSub(protocolEarnings);

        emit Debug('earnings.zSub(protocolEarnings)');
        emit Debug(earnings);

        // TODO: Ensure stablecoin precision for "earnings" is always converted to wei (10**18)
        //       in the event we switch stablecoin distributed from 10**18 => 10**6 precision.
        //       rateSenior() + rateJunior() are expecting WEI precision for "earnings" + "emaYield"

        uint256 _seniorRate = johnny_rateSenior_RAY(
            earnings,
            seniorTrancheSize,
            juniorTrancheSize,
            targetAPYBIPS,
            targetRatioBIPS,
            30,
            6
        );
        
        uint256 _juniorRate = johnny_rateJunior_RAY(
            seniorTrancheSize,
            juniorTrancheSize,
            _seniorRate,
            targetRatioBIPS
        );

        senior = (earnings * _seniorRate) / RAY;
        junior = (earnings * _juniorRate) / RAY;

        emit Debug('_seniorRate');
        emit Debug(_seniorRate);
        emit Debug('_juniorRate');
        emit Debug(_juniorRate);
        
        // Handle accounting for residual earnings.
        residual = new uint256[](residualRecipients.recipients.length);
        uint residualEarnings = earnings.zSub(senior + junior);
        for (uint i = 0; i < residualRecipients.recipients.length; i++) {
            residual[i] = residualRecipients.proportion[i] * residualEarnings / 10000;
        }

    }

    /// @notice Distributes available yield within this contract to appropriate entities
    function distributeYield() external {

        require(
            block.timestamp >= lastDistribution + yieldTimeUnit, 
            "ZivoeYDL::distributeYield() block.timestamp < lastDistribution + yieldTimeUnit"
        );
        require(unlocked, "ZivoeYDL::distributeYield() !unlocked"); 

        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();

        (
            uint256[] memory _protocol,
            uint256 _seniorTranche,
            uint256 _juniorTranche,
            uint256[] memory _residual
        ) = earningsTrancheuse(seniorSupp, juniorSupp);

        emit Debug("earnings information");
        emit Debug(_protocol);
        emit Debug(_seniorTranche);
        emit Debug(_juniorTranche);
        emit Debug(_residual);

        numDistributions += 1;
        
        // TODO: Ensure stablecoin precision for "emaYield" is always converted to wei (10**18)
        //       in the event we switch stablecoin distributed from 10**18 => 10**6 precision.

        emaYield = ema(
            emaYield, 
            _seniorTranche, 
            retrospectionTime, 
            numDistributions
        );

        emaSTT = ema(
            emaSTT,
            seniorSupp,
            retrospectionTime,
            numDistributions
        );

        emaJTT = ema(
            emaJTT,
            juniorSupp,
            retrospectionTime,
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
                    IERC20(IZivoeGlobals(GBL).stZVE()).totalSupply() * 10000
                ) / (IERC20(IZivoeGlobals(GBL).stZVE()).totalSupply() + IERC20(IZivoeGlobals(GBL).vestZVE()).totalSupply());
                IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stZVE(), _protocol[i] * splitBIPS / 10000);
                IERC20(distributedAsset).approve(IZivoeGlobals(GBL).vestZVE(), _protocol[i] * (10000 - splitBIPS) / 10000);
                IZivoeRewards(IZivoeGlobals(GBL).stZVE()).depositReward(distributedAsset, _protocol[i] * splitBIPS / 10000);
                IZivoeRewards(IZivoeGlobals(GBL).vestZVE()).depositReward(distributedAsset, _protocol[i] * (10000 - splitBIPS) / 10000);
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
                        IERC20(IZivoeGlobals(GBL).stZVE()).totalSupply() * 10000
                    ) / (IERC20(IZivoeGlobals(GBL).stZVE()).totalSupply() + IERC20(IZivoeGlobals(GBL).vestZVE()).totalSupply());
                    IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stZVE(), _residual[i] * splitBIPS / 10000);
                    IERC20(distributedAsset).approve(IZivoeGlobals(GBL).vestZVE(), _residual[i] * (10000 - splitBIPS) / 10000);
                    IZivoeRewards(IZivoeGlobals(GBL).stZVE()).depositReward(distributedAsset, _residual[i] * splitBIPS / 10000);
                    IZivoeRewards(IZivoeGlobals(GBL).vestZVE()).depositReward(distributedAsset, _residual[i] * (10000 - splitBIPS) / 10000);
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

        (uint256 seniorSupp,) = adjustedSupplies();
    
        uint256 seniorRate = johnny_seniorRateNominal_RAY_v2(amount, seniorSupp, targetAPYBIPS, 30);
        uint256 toSenior = (amount * seniorRate) / RAY;
        uint256 toJunior = amount.zSub(toSenior);

        IERC20(distributedAsset).safeTransferFrom(msg.sender, address(this), amount);

        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stSTT(), toSenior);
        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stJTT(), toJunior);
        IZivoeRewards(IZivoeGlobals(GBL).stSTT()).depositReward(distributedAsset, toSenior);
        IZivoeRewards(IZivoeGlobals(GBL).stJTT()).depositReward(distributedAsset, toJunior);

    }

    /// @notice Returns total circulating supply of zSTT and zJTT, accounting for defaults via markdowns.
    /// @return zSTTSupplyAdjusted zSTT.totalSupply() adjusted for defaults.
    /// @return zJTTSupplyAdjusted zJTT.totalSupply() adjusted for defaults.
    function adjustedSupplies() public view returns (uint256 zSTTSupplyAdjusted, uint256 zJTTSupplyAdjusted) {
        uint256 zSTTSupply = IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();
        uint256 zJTTSupply = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply();
        // TODO: Verify if statements below are accurate in certain default states.
        zJTTSupplyAdjusted = zJTTSupply.zSub(IZivoeGlobals(GBL).defaults());
        zSTTSupplyAdjusted = (zSTTSupply + zJTTSupply).zSub(
            IZivoeGlobals(GBL).defaults().zSub(zJTTSupplyAdjusted)
        );
    }

    // ----------
    //    Math
    // ----------

    uint256 private constant WAD = 10 ** 18;
    uint256 private constant RAY = 10 ** 27;

    /**
        @notice     Calculates amount of annual yield required to meet target rate for both tranches.
        @param      sSTT = total supply of senior tranche token     (units = wei)
        @param      sJTT = total supply of junior tranche token     (units = wei)
        @param      Y    = target annual yield for senior tranche   (units = BIPS)
        @param      Q    = multiple of Y                            (units = BIPS)
        @param      T    = # of days between distributions          (units = integer)
            
        @dev        (Y * (sSTT + sJTT * Q / 10000) * T / 10000) / (365^2)
    */
    function johnny_yieldTarget_v2(
        uint256 sSTT,
        uint256 sJTT,
        uint256 Y,
        uint256 Q,
        uint256 T
    ) public pure returns (uint256) {
        return (Y * (sSTT + sJTT * Q / 10000) * T / 10000) / (365^2);
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
    function johnny_rateSenior_RAY(
        uint256 postFeeYield,
        uint256 sSTT,
        uint256 sJTT,
        uint256 Y,
        uint256 Q,
        uint256 T,
        uint256 R
    ) public returns (uint256) {

        emit Debug('johnny_rateSenior_RAY() called');

        emit Debug('=> sSTT');
        emit Debug(sSTT);
        emit Debug('=> sJTT');
        emit Debug(sJTT);
        emit Debug('=> Y');
        emit Debug(Y);
        emit Debug('=> Q');
        emit Debug(Q);
        emit Debug('=> T');
        emit Debug(T);
        emit Debug('=> R');
        emit Debug(R);
        
        emit Debug('=> postFeeYield');
        emit Debug(postFeeYield);

        uint256 yT = johnny_yieldTarget_v2(emaSTT, emaJTT, Y, Q, T);

        emit Debug('=> yT');
        emit Debug(yT);

        emit Debug('=> emaYield');
        emit Debug(emaYield);

        // Comparison for if-else operators look at "absolute" yield generated
        // over a period, including:
        //  - yt:           Ideal yield generated (this distribution period)
        //  - postFeeYield: Actual yield generated (this distribution period)
        //  - emaYield:     Historical yield generated (ema, last 3-4 distribution periods)

        // Return of this function, however is a "portion" (i.e. a %) represented
        // in RAY precision, example:
        // 400000000000000000000000000 / 10**27 = 0.4

        // CASE #1 => Shortfall.
        if (yT > postFeeYield) {
            emit Debug('CASE #1 => Shortfall.');
            return johnny_seniorRateShortfall_RAY_v2(sSTT, sJTT, Q);
        }

        // CASE #2 => Excess, and historical under-performance.
        else if (yT >= emaYield && emaYield != 0) {
            emit Debug('CASE #2 => Excess & Under-Performance');
            return johnny_seniorRateCatchup_RAY_v2(postFeeYield, yT, sSTT, sJTT, R, Q, false, 0);
        }

        // CASE #3 => Excess, and out-performance.
        else {
            emit Debug('CASE #3 => Excess & Out-Performance');
            return johnny_seniorRateNominal_RAY_v2(postFeeYield, sSTT, Y, T);
        }
    }

    /**
        @notice     Calculates % of yield attributable to senior tranche during excess but historical under-performance.
        @param      postFeeYield = yield distributable after fees  (units = wei)
        @param      yT   = yield distributable after fees          (units = wei)
        @param      sSTT = total supply of senior tranche token    (units = wei)
        @param      sJTT = total supply of junior tranche token    (units = wei)
        @param      Q    = multiple of Y                           (units = BIPS)
        @param      R    = # of distributions for retrospection    (units = integer)
    */
    function johnny_seniorRateCatchup_RAY_v2(
        uint256 postFeeYield,
        uint256 yT,
        uint256 sSTT,
        uint256 sJTT,
        uint256 R,
        uint256 Q,
        bool debugging,
        uint256 debuggingEMAYield
    ) public returns (uint256) {
        if (debugging) {
            emit Debug('=> debuggingEMAYield');
            emit Debug(debuggingEMAYield);
            emit Debug('left numerator');
            emit Debug((R + 1) * yT * RAY * WAD);
            emit Debug('right numerator');
            emit Debug(R * debuggingEMAYield * RAY * WAD);
            emit Debug('numerator');
            emit Debug(((R + 1) * yT * RAY).zSub(R * debuggingEMAYield * RAY));
            emit Debug('denominator');
            emit Debug(WAD * postFeeYield * (WAD + (Q * sJTT * WAD / 10000).zDiv(sSTT)));
            return ((R + 1) * yT * RAY * WAD).zSub(R * debuggingEMAYield * RAY * WAD).zDiv(
                postFeeYield * (WAD + (Q * sJTT * WAD / 10000).zDiv(sSTT))
            );
            // ((((R + 1) * yT).zSub(R * emaYield)) * WAD).zDiv(
            //     postFeeYield * dLil(Q, sSTT, sJTT)
            // );
        }
        else {
            return ((R + 1) * yT * RAY * WAD).zSub(R * emaYield * RAY * WAD).zDiv(
                postFeeYield * (WAD + (Q * sJTT * WAD / 10000).zDiv(sSTT))
            );
        }
    }

    /**
        @notice     Calculates % of yield attributable to junior tranche.
        @param      sSTT = total supply of senior tranche token    (units = wei)
        @param      sJTT = total supply of junior tranche token    (units = wei)
        @param      Y    = % of yield attributable to seniors      (units = RAY)
        @param      Q    = senior to junior tranche target ratio   (units = BIPS)
    */
    function johnny_rateJunior_RAY(
        uint256 sSTT,
        uint256 sJTT,
        uint256 Y,
        uint256 Q
    ) public pure returns (uint256) {
        // TODO: Add a min(this, 1 * 10**27 - seniorRate).
        return (Q * sJTT * Y / 10000).zDiv(sSTT).min(10**27 - Y);
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
    function johnny_seniorRateNominal_RAY_v2(
        uint256 postFeeYield,
        uint256 sSTT,
        uint256 Y,
        uint256 T
    ) public pure returns (uint256) {
        // NOTE: THIS WILL REVERT IF postFeeYield == 0 ?? ISSUE ??
        return (RAY * Y * (sSTT) * T / 10000) / (365^2) / (postFeeYield);
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
    function johnny_seniorRateShortfall_RAY_v2(
        uint256 sSTT,
        uint256 sJTT,
        uint256 Q
    ) public pure returns (uint256) {
        return (WAD * RAY).zDiv(WAD + (Q * sJTT * WAD / 10000).zDiv(sSTT));
    }

    // avg = current average
    // newval = next value to add to average
    // N = number of time steps we are averaging over (nominally, it is actually infinite)
    // t = number of time steps total that  have occurred, only used when < N
    /// @dev exponentially weighted moving average, written in float arithmatic as:
    ///                      newval - avg_n
    /// avg_{n+1} = avg_n + ----------------    
    ///                         min(N,t)
    function ema(
        uint256 avg,
        uint256 newval,
        uint256 N,
        uint256 t
    ) public returns (uint256 nextavg) {
        emit Debug('ema() called');
        emit Debug('=> avg');
        emit Debug(avg);
        emit Debug('=> newval');
        emit Debug(newval);
        emit Debug('=> N');
        emit Debug(N);
        emit Debug('=> t');
        emit Debug(t);
        if (N < t) {
            t = N; //use the count if we are still in the first window
        }
        uint256 _diff = (WAD * (newval.zSub(avg))) / t; //if newval>avg
        emit Debug('_diff');
        emit Debug(_diff);
        if (_diff == 0) { //if newval - avg < t
            emit Debug('_diff == 0');
            _diff = (WAD * (avg.zSub(newval))) / t;   /// abg > newval
            emit Debug('_diff');
            emit Debug(_diff);
            nextavg = ((avg * WAD).zSub(_diff)) / WAD; /// newval < avg
            emit Debug('nextavg');
            emit Debug(nextavg);
        } else {
            emit Debug('_diff != 0');
            nextavg = (avg * WAD + _diff) / WAD; // if newval > avg
            emit Debug('nextavg');
            emit Debug(nextavg);
        }
    }


    // CHRISPY !!


    // function chrispy_yieldTarget(
    //     uint256 seniorSupp,
    //     uint256 juniorSupp,
    //     uint256 _targetRatio,
    //     uint256 targetRate,
    //     uint256 _yieldTimeUnit
    // ) public pure returns (uint256) {
    //     uint256 dBig = 365 days / _yieldTimeUnit;
    //     return targetRate * (seniorSupp + (_targetRatio * juniorSupp).zDiv(WAD)).zDiv(dBig*WAD);
    // }

    // function chrispy_rateSenior(
    //     uint256 postFeeYield,
    //     uint256 cumsumYield,
    //     uint256 seniorSupp,
    //     uint256 juniorSupp,
    //     uint256 _targetRatio,
    //     uint256 targetRate,
    //     uint256 _retrospectionTime,
    //     uint256 avgSeniorSupply,
    //     uint256 avgJuniorSupply
    // ) public view returns (uint256) {
    //     uint256 Y = chrispy_yieldTarget(
    //         avgSeniorSupply,
    //         avgJuniorSupply,
    //         _targetRatio,
    //         targetRate,
    //         yieldTimeUnit
    //     );
    //     if (Y > postFeeYield) {
    //         return chrispy_seniorRateNominal(_targetRatio, seniorSupp, juniorSupp);
    //     } else if (cumsumYield >= Y) {
    //         return Y;
    //     } else {
    //         return
    //             ((((_retrospectionTime + 1) * Y).zSub(_retrospectionTime * cumsumYield)) * WAD).zDiv(
    //                 postFeeYield * chrispy_dLil(_targetRatio, seniorSupp, juniorSupp)
    //             );
    //     }
    // }

    // function chrispy_rateJunior(
    //     uint256 _targetRatio,
    //     uint256 _rateSenior,
    //     uint256 seniorSupp,
    //     uint256 juniorSupp
    // ) public pure returns (uint256) {
    //     return (_targetRatio * juniorSupp * _rateSenior).zDiv(seniorSupp * WAD);
    // }

    // /// @dev rate that goes ot senior when ignoring corrections for past payouts and paying the junior 3x per capita
    // function chrispy_seniorRateNominal(
    //     uint256 _targetRatio,
    //     uint256 seniorSupp,
    //     uint256 juniorSupp
    // ) public pure returns (uint256) {
    //     return (WAD * WAD).zDiv(chrispy_dLil(_targetRatio, seniorSupp, juniorSupp));
    // }

    // function chrispy_dLil(
    //     uint256 _targetRatio,
    //     uint256 seniorSupp,
    //     uint256 juniorSupp
    // ) public pure returns (uint256) {
    //     //this is the rate when there is shortfall or we are dividing up some extra.
    //     //     q*m_j
    //     // 1 + ------
    //     //      m_s
    //     return WAD + (_targetRatio * juniorSupp).zDiv(seniorSupp);
    // }

}
