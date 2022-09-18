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

    Recipients protocolRecipients;
    Recipients residualRecipients;

    address public immutable GBL;   /// @dev The ZivoeGlobals contract.

    address public distributedAsset;    /// @dev The "stablecoin" that will be distributed via YDL.
    
    bool public unlocked;           /// @dev Prevents contract from supporting functionality until unlocked.

    // TODO: Determine proper initial value for everything below (remaining after refactor).

    /// @dev These have initial values for testing purposes.
    uint256 public emaJTT = 3 * 10**18;
    uint256 public emaSTT = 10**18;

    uint256 public emaYield;               /// @dev Yield tracking, for overage.
    ///CHRIS: this values are wrong, it should be changed to be consistent with 0 for numdistributions. IE, first round, it operates wihout any bullshit pretense(which i did have some here to reduce possible issues when rooting out bugs implementing it.     
    uint256 public numDistributions;    /// @dev # of calls to distributeYield() starts at 0, computed on current index for moving averages
    uint256 public lastDistribution;        /// @dev Used for timelock constraint to call distributeYield()
    //tCHRIS: his shit is wrong, the calculations are specced to be in days not seconds, so this is bound to put it off b y a lot. 
    uint256 public yieldTimeUnit = 7 days; /// @dev The period between yield distributions.
    uint256 public retrospectionTime = 13; /// @dev The historical period to track shortfall in units of yieldTime 
    
    // TODO: Evaluate to what extent modifying retrospectionTime affects this and emaYield.
    uint256 public targetYield = uint256(5 ether) / uint256(100); /// @dev The target senior yield in wei, per token.
    uint256 public targetRatio = 3 * 10**18; /// @dev The target ratio of junior tranche yield relative to senior.

    // r = rate (% / ratio)
    uint256 public r_ZVE = uint256(5 ether) / uint256(100);
    uint256 public r_DAO = uint256(15 ether) / uint256(100);

    uint256 public protocolRate = uint256(20 ether) / uint256(100);

    // resid = residual = overage = performance bonus
    uint256 public r_ZVE_resid = uint256(90 ether) / uint256(100);
    uint256 public r_DAO_resid = uint256(10 ether) / uint256(100);



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

        // TODO: Determine if avgRate needs to be updated here as well relative to starting values?
        // avgRate = ??.
        //CHRIS = no, should start with no information. average rate = current rate for first iter. i 

        emaJTT = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply();
        emaSTT = IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();

        address[] memory protocolRecipientAcc = new address[](2);
        uint256[] memory protocolRecipientAmt = new uint256[](2);

        protocolRecipientAcc[0] = address(IZivoeGlobals(GBL).stZVE());
        protocolRecipientAmt[0] = 6666;
        protocolRecipientAcc[1] = address(IZivoeGlobals(GBL).DAO());
        protocolRecipientAmt[1] = 3334;

        protocolRecipients = Recipients(protocolRecipientAcc, protocolRecipientAmt);

        address[] memory residualRecipientAcc = new address[](3);
        uint256[] memory residualRecipientAmt = new uint256[](3);

        residualRecipientAcc[0] = address(IZivoeGlobals(GBL).stZVE());
        residualRecipientAmt[0] = 9000;
        residualRecipientAcc[1] = address(IZivoeGlobals(GBL).stSTT());
        residualRecipientAmt[1] = 500;
        residualRecipientAcc[2] = address(IZivoeGlobals(GBL).stJTT());
        residualRecipientAmt[2] = 500;
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
    /// @return seniorTranche Senior tranche earnings.
    /// @return juniorTranche Junior tranche earnings.
    /// @return amounts Residual earnings.

    /// @dev  amounts[0] payout to senior tranche stake
    /// @dev  amounts[1] payout to junior tranche stake
    /// @dev  amounts[2] payout to ZVE stakies
    /// @dev  amounts[3] payout to ZVE vesties
    /// @dev  amounts[4] payout to retained earnings
    function earningsTrancheuse(
        uint256 seniorTrancheSize, 
        uint256 juniorTrancheSize
    ) internal returns (
        uint256[] memory protocol, 
        uint256 seniorTranche,
        uint256 juniorTranche,
        uint256[] memory residual,
        uint256[7] memory amounts
    ) {

        uint256 earnings = IERC20(distributedAsset).balanceOf(address(this));

        protocol = new uint256[](protocolRecipients.recipients.length);
        residual = new uint256[](residualRecipients.recipients.length);

        emit Debug('earnings');
        emit Debug(earnings);

        uint protocolEarnings = protocolRate * earnings / WAD;
        emit Debug(protocolRecipients.recipients);
        emit Debug(protocolRecipients.proportion);
        for (uint i = 0; i < protocolRecipients.recipients.length; i++) {
            protocol[i] = protocolRecipients.proportion[i] * protocolEarnings / 10000;
        }
        emit Debug('protocolEarnings');
        emit Debug(protocolEarnings);

        uint256 _toZVE = (r_ZVE * earnings) / WAD;
        amounts[4] = (r_DAO * earnings) / WAD; //_toDAO

        earnings = earnings.zSub(protocolEarnings);
        emit Debug('earnings.zSub(protocolEarnings)');
        emit Debug(earnings);

        // TODO: Ensure stablecoin precision for "earnings" is always converted to wei (10**18)
        //       in the event we switch stablecoin distributed from 10**18 => 10**6 precision.
        //       rateSenior() + rateJunior() are expecting WEI precision for "earnings" + "emaYield"

        uint256 _seniorRate = chrispy_rateSenior(
            earnings,
            emaYield,
            seniorTrancheSize,
            juniorTrancheSize,
            targetRatio,
            targetYield,
            retrospectionTime,
            emaSTT,
            emaJTT
        );
        
        uint256 _juniorRate = chrispy_rateJunior(
            targetRatio,
            _seniorRate,
            seniorTrancheSize,
            juniorTrancheSize
        );

        // TODO: Debug why these values are coming back as "1".
        emit Debug('_seniorRate');
        emit Debug(_seniorRate);
        emit Debug('_juniorRate');
        emit Debug(_juniorRate);
        amounts[0] = (earnings * _seniorRate) / WAD;
        amounts[1] = (earnings * _juniorRate) / WAD;

        seniorTranche = (earnings * _seniorRate) / WAD;
        juniorTranche = (earnings * _juniorRate) / WAD;
        emit Debug('seniorTranche');
        emit Debug(seniorTranche);
        emit Debug('juniorTranche');
        emit Debug(juniorTranche);
        

        // TODO: Identify which wallets the overage should go to, or make this modular.
        uint256 _resid = earnings.zSub(amounts[0] + amounts[1]);

        
        // Modular dispersions across residualRecipients.
        uint residualEarnings = earnings.zSub(amounts[0] + amounts[1]);
        for (uint i = 0; i < residualRecipients.recipients.length; i++) {
            residual[i] = residualRecipients.proportion[i] * residualEarnings / 10000;
        }

        amounts[4] = amounts[4] + (_resid * r_DAO_resid) / WAD;
        _toZVE += _resid - amounts[4];
        uint256 _ZVE_steaks = IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(IZivoeGlobals(GBL).stZVE());
        uint256 _vZVE_steaks = IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(IZivoeGlobals(GBL).vestZVE());
        uint256 _rvZVE = (WAD * _vZVE_steaks).zDiv(_ZVE_steaks + _vZVE_steaks);
        uint256 _tovestZVE = (_rvZVE * _toZVE) / WAD;
        uint256 _tostZVE = _toZVE.zSub(_tovestZVE);
        amounts[2] = _tostZVE;
        amounts[3] = _tovestZVE;
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
            uint256[] memory _a,
            uint256 _b,
            uint256 _c,
            uint256[] memory _d,
            uint256[7] memory amounts
        ) = earningsTrancheuse(seniorSupp, juniorSupp);

        emit Debug(_a);
        emit Debug(_b);
        emit Debug(_c);
        emit Debug(_d);
        emit Debug(amounts);

        numDistributions += 1;
        
        // TODO: Ensure stablecoin precision for "emaYield" is always converted to wei (10**18)
        //       in the event we switch stablecoin distributed from 10**18 => 10**6 precision.

        emaYield = ema(
            emaYield, 
            amounts[0], 
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

        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stSTT(), amounts[0]);
        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stJTT(), amounts[1]);
        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stZVE(), amounts[2]);
        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).vestZVE(), amounts[3]);
        IZivoeRewards(IZivoeGlobals(GBL).stSTT()).depositReward(distributedAsset, amounts[0]);
        IZivoeRewards(IZivoeGlobals(GBL).stJTT()).depositReward(distributedAsset, amounts[1]);
        IZivoeRewards(IZivoeGlobals(GBL).stZVE()).depositReward(distributedAsset, amounts[2]);
        IZivoeRewards(IZivoeGlobals(GBL).vestZVE()).depositReward(distributedAsset, amounts[3]);
        IERC20(distributedAsset).transfer(IZivoeGlobals(GBL).DAO(), amounts[4]);

    }

    // ------------------------

    /// @notice gives asset to junior and senior, divided up by nominal rate(same as normal with no retrospective shortfall adjustment) for surprise rewards, 
    ///         manual interventions, and to simplify governance proposals by making use of accounting here. 
    /// @param payout - amount to send
    function passToTranchies(uint256 payout) external {

        require(unlocked, "ZivoeYDL::passToTranchies() !unlocked");

        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();

        uint256 seniorRate = chrispy_seniorRateNominal(targetRatio, seniorSupp, juniorSupp);
        uint256 toSenior = (payout * seniorRate) / WAD;
        uint256 toJunior = payout.zSub(toSenior);

        IERC20(distributedAsset).safeTransferFrom(msg.sender, address(this), payout);

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

    /// @notice Updates the r_ZVE variable.
    function set_r_ZVE(uint256 _r_ZVE) external onlyOwner {
        r_ZVE = _r_ZVE;
    }

    /// @notice Updates the r_ZVE_resid variable.
    function set_r_ZVE_resid(uint256 _r_ZVE_resid) external onlyOwner {
        r_ZVE_resid = _r_ZVE_resid;
    }

    /// @notice Updates the r_DAO variable.
    function set_r_DAO(uint256 _r_DAO) external onlyOwner {
        r_DAO = _r_DAO;
    }

    /// @notice Updates the r_DAO_resid variable.
    function set_r_DAO_resid(uint256 _r_DAO_resid) external onlyOwner {
        r_DAO_resid = _r_DAO_resid;
    }

    /// @notice Updates the retrospectionTime variable.
    function set_retrospectionTime(uint256 _retrospectionTime) external onlyOwner {
        retrospectionTime = _retrospectionTime;
    }

    /// @notice Updates the yieldTimeUnit variable.
    function set_yieldTimeUnit(uint256 _yieldTimeUnit) external onlyOwner {
        yieldTimeUnit = _yieldTimeUnit;
    }

    /// @notice Updates the targetRatio variable.
    function set_targetRatio(uint256 _targetRatio) external onlyOwner {
        targetRatio = _targetRatio;
    }

    /// @notice Updates the targetYield variable.
    function set_targetYield(uint256 _targetYield) external onlyOwner {
        targetYield = _targetYield;
    }

    // ----------
    //    Math
    // ----------

    uint256 private constant WAD = 10 ** 18;
    uint256 private constant RAY = 10 ** 27;

    function chrispy_yieldTarget(
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 _targetRatio,
        uint256 targetRate,
        uint256 _yieldTimeUnit
    ) public pure returns (uint256) {
        uint256 dBig = 365 days / _yieldTimeUnit;
        return targetRate * (seniorSupp + (_targetRatio * juniorSupp).zDiv(WAD)).zDiv(dBig*WAD);
    }

    function chrispy_rateSenior(
        uint256 postFeeYield,
        uint256 cumsumYield,
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 _targetRatio,
        uint256 targetRate,
        uint256 _retrospectionTime,
        uint256 avgSeniorSupply,
        uint256 avgJuniorSupply
    ) public view returns (uint256) {
        uint256 Y = chrispy_yieldTarget(
            avgSeniorSupply,
            avgJuniorSupply,
            _targetRatio,
            targetRate,
            yieldTimeUnit
        );
        if (Y > postFeeYield) {
            return chrispy_seniorRateNominal(_targetRatio, seniorSupp, juniorSupp);
        } else if (cumsumYield >= Y) {
            return Y;
        } else {
            return
                ((((_retrospectionTime + 1) * Y).zSub(_retrospectionTime * cumsumYield)) * WAD).zDiv(
                    postFeeYield * chrispy_dLil(_targetRatio, seniorSupp, juniorSupp)
                );
        }
    }

    function chrispy_rateJunior(
        uint256 _targetRatio,
        uint256 _rateSenior,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) public pure returns (uint256) {
        return (_targetRatio * juniorSupp * _rateSenior).zDiv(seniorSupp * WAD);
    }

    /// @dev rate that goes ot senior when ignoring corrections for past payouts and paying the junior 3x per capita
    function chrispy_seniorRateNominal(
        uint256 _targetRatio,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) public pure returns (uint256) {
        return (WAD * WAD).zDiv(chrispy_dLil(_targetRatio, seniorSupp, juniorSupp));
    }

    function chrispy_dLil(
        uint256 _targetRatio,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) public pure returns (uint256) {
        //this is the rate when there is shortfall or we are dividing up some extra.
        //     q*m_j
        // 1 + ------
        //      m_s
        return WAD + (_targetRatio * juniorSupp).zDiv(seniorSupp);
    }

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
    function johnny_rateSenior(
        uint256 postFeeYield,
        uint256 sSTT,
        uint256 sJTT,
        uint256 Y,
        uint256 Q,
        uint256 T,
        uint256 R
    ) public returns (uint256) {

        emit Debug('johnny_rateSenior() called');

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
        else if (yT >= emaYield) {
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
            emit Debug('=> emaYield');
            emit Debug(emaYield);
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
        @param      Q    = senior to junior tranche target ratio   (units = integer)
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

}
