// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";
import "./calc/YieldTrancheuse.sol";
import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { IZivoeRewards, IZivoeGlobals } from "./interfaces/InterfacesAggregated.sol";

///         Assets can be held in escrow within this contract prior to distribution.
contract ZivoeYDL is Ownable {

    using SafeERC20 for IERC20;
    using ZMath for uint256;

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

    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    
    bool public unlocked;           /// @dev Prevents contract from supporting functionality until unlocked.

    // TODO: Determine proper initial value for everything below (remaining after refactor).

    /// @dev These have initial values for testing purposes.
    uint256 public emaJuniorSupply = 3 * 10**18;
    uint256 public emaSeniorSupply = 10**18;

    uint256 public avgYield = 10**18;               /// @dev Yield tracking, for overage.
    
    uint256 public numDistributions = 1;    /// @dev # of calls to distributeYield()
    uint256 public lastDistribution;        /// @dev Used for timelock constraint to call distributeYield()

    uint256 public yieldTimeUnit = 7 days; /// @dev The period between yield distributions.
    uint256 public retrospectionTime = 13; /// @dev The historical period to track shortfall in units of yieldTime.
    
    // TODO: Evaluate to what extent modifying retrospectionTime affects this and avgYield.
    uint256 public targetYield = uint256(5 ether) / uint256(100); /// @dev The target senior yield in wei, per token.
    uint256 public targetRatio = 3 * 10**18; /// @dev The target ratio of junior tranche yield relative to senior.

    // r = rate (% / ratio)
    uint256 public r_ZVE = uint256(5 ether) / uint256(100);
    uint256 public r_DAO = uint256(15 ether) / uint256(100);

    uint256 public protocolRate = uint256(20 ether) / uint256(100);

    // resid = residual = overage = performance bonus
    uint256 public r_ZVE_resid = uint256(90 ether) / uint256(100);
    uint256 public r_DAO_resid = uint256(10 ether) / uint256(100);

    uint256 private constant WAD = 1 ether;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initialize the ZivoeYDL.sol contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address _GBL) {
        GBL = _GBL;
    }



    // ---------------
    //    Functions
    // ---------------

    /// @notice Unlocks this contract for distributions, initializes values.
    function unlock() external {
        require(_msgSender() == IZivoeGlobals(GBL).ITO(), "ZivoeYDL::unlock() _msgSender() != IZivoeGlobals(GBL).ITO()");
        unlocked = true;
        lastDistribution = block.timestamp;

        // TODO: Determine if avgRate needs to be updated here as well relative to starting values?
        // avgRate = ??

        emaJuniorSupply = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply();
        emaSeniorSupply = IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();

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

        uint256 earnings = IERC20(FRAX).balanceOf(address(this));

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

        // uint256 _seniorRate = YieldTrancheuse.rateSenior(
        uint256 _seniorRate = rateSenior(
            earnings,
            avgYield,
            seniorTrancheSize,
            juniorTrancheSize,
            targetRatio,
            targetYield,
            retrospectionTime,
            emaSeniorSupply,
            emaJuniorSupply
        );
        // uint256 _juniorRate = YieldTrancheuse.rateJunior(
        uint256 _juniorRate = rateJunior(
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

        // avgYield = YieldTrancheuse.ema(avgYield, amounts[0], retrospectionTime, numDistributions);
        avgYield = ema(avgYield, amounts[0], retrospectionTime, numDistributions);

        // emaSeniorSupply = YieldTrancheuse.ema(
        emaSeniorSupply = ema(
            emaSeniorSupply,
            seniorSupp,
            retrospectionTime,
            numDistributions
        );

        // emaJuniorSupply = YieldTrancheuse.ema(
        emaJuniorSupply = ema(
            emaJuniorSupply,
            juniorSupp,
            retrospectionTime,
            numDistributions
        );

        numDistributions += 1;
        lastDistribution = block.timestamp;

        IERC20(FRAX).approve(IZivoeGlobals(GBL).stSTT(), amounts[0]);
        IERC20(FRAX).approve(IZivoeGlobals(GBL).stJTT(), amounts[1]);
        IERC20(FRAX).approve(IZivoeGlobals(GBL).stZVE(), amounts[2]);
        IERC20(FRAX).approve(IZivoeGlobals(GBL).vestZVE(), amounts[3]);
        IZivoeRewards(IZivoeGlobals(GBL).stSTT()).depositReward(FRAX, amounts[0]);
        IZivoeRewards(IZivoeGlobals(GBL).stJTT()).depositReward(FRAX, amounts[1]);
        IZivoeRewards(IZivoeGlobals(GBL).stZVE()).depositReward(FRAX, amounts[2]);
        IZivoeRewards(IZivoeGlobals(GBL).vestZVE()).depositReward(FRAX, amounts[3]);
        IERC20(FRAX).transfer(IZivoeGlobals(GBL).DAO(), amounts[4]);

    }

    // ------------------------

    /// @notice gives asset to junior and senior, divided up by nominal rate(same as normal with no retrospective shortfall adjustment) for surprise rewards, 
    ///         manual interventions, and to simplify governance proposals by making use of accounting here. 
    /// @param asset - token contract address
    /// @param payout - amount to send
    function passToTranchies(address asset, uint256 payout) external {

        require(unlocked, "ZivoeYDL::passToTranchies() !unlocked");

        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();

        // uint256 seniorRate = YieldTrancheuse.seniorRateNominal(targetRatio, seniorSupp, juniorSupp);
        uint256 seniorRate = seniorRateNominal(targetRatio, seniorSupp, juniorSupp);
        uint256 toSenior = (payout * seniorRate) / WAD;
        uint256 toJunior = payout.zSub(toSenior);

        IERC20(asset).safeTransferFrom(msg.sender, address(this), payout);

        IERC20(FRAX).approve(IZivoeGlobals(GBL).stSTT(), toSenior);
        IERC20(FRAX).approve(IZivoeGlobals(GBL).stJTT(), toJunior);
        IZivoeRewards(IZivoeGlobals(GBL).stSTT()).depositReward(asset, toSenior);
        IZivoeRewards(IZivoeGlobals(GBL).stJTT()).depositReward(asset, toJunior);

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

    // @dev return 0 of div would result in val < 1 or divide by 0
    function zDiv(uint256 x, uint256 y) internal pure returns (uint256) {
        unchecked {
            if (y == 0) return 0;
            if (y > x) return 0;
            return (x / y);
        }
    }

    /// @dev  Subtraction routine that does not revert and returns a singleton, 
    ///         making it cheaper and more suitable for composition and use as an attribute. 
    ///         It returns the closest uint to the actual answer if the answer is not in uint256. 
    ///         IE it gives you 0 instead of reverting. It was made to be a cheaper version of openZepelins trySub.
    function zSub(uint256 x, uint256 y) internal pure returns (uint256) {
        unchecked {
            if (y > x) return 0;
            return (x - y);
        }
    }

    function yieldTarget(
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 _targetRatio,
        uint256 targetRate,
        uint256 _retrospectionTime
    ) internal returns (uint256) {
        emit Debug('yieldTarget() called');
        emit Debug('=> seniorSupp');
        emit Debug(seniorSupp);
        emit Debug('=> juniorSupp');
        emit Debug(juniorSupp);
        emit Debug('=> _targetRatio');
        emit Debug(_targetRatio);
        emit Debug('=> targetRate');
        emit Debug(targetRate);
        emit Debug('=> _retrospectionTime');
        emit Debug(_retrospectionTime);
        uint256 dBig = 4 * _retrospectionTime;
        return targetRate * (seniorSupp + (_targetRatio * juniorSupp).zDiv(WAD)).zDiv(dBig*WAD);
    }

    function rateSenior(
        uint256 postFeeYield,
        uint256 cumsumYield,
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 _targetRatio,
        uint256 targetRate,
        uint256 _retrospectionTime,
        uint256 avgSeniorSupply,
        uint256 avgJuniorSupply
    ) internal returns (uint256) {
        emit Debug('rateSenior() called');
        emit Debug('=> postFeeYield');
        emit Debug(postFeeYield);
        emit Debug('=> cumsumYield');
        emit Debug(cumsumYield);
        emit Debug('=> seniorSupp');
        emit Debug(seniorSupp);
        emit Debug('=> juniorSupp');
        emit Debug(juniorSupp);
        emit Debug('=> _targetRatio');
        emit Debug(_targetRatio);
        emit Debug('=> targetRate');
        emit Debug(targetRate);
        emit Debug('=> _retrospectionTime');
        emit Debug(_retrospectionTime);
        emit Debug('=> avgSeniorSupply');
        emit Debug(avgSeniorSupply);
        emit Debug('=> avgJuniorSupply');
        emit Debug(avgJuniorSupply);
        uint256 Y = yieldTarget(
            avgSeniorSupply,
            avgJuniorSupply,
            _targetRatio,
            targetRate,
            _retrospectionTime
        );
        emit Debug('Y');
        emit Debug(Y);
        if (Y > postFeeYield) {
            emit Debug('Y > postFeeYield');
            return seniorRateNominal(_targetRatio, seniorSupp, juniorSupp);
        } else if (cumsumYield >= Y) {
            emit Debug('cumsumYield >= Y');
            return Y;
        } else {
            emit Debug('else');
            return
                ((((_retrospectionTime + 1) * Y).zSub(_retrospectionTime * cumsumYield)) * WAD).zDiv(
                    postFeeYield * dLil(_targetRatio, seniorSupp, juniorSupp)
                );
        }
    }

    function rateJunior(
        uint256 _targetRatio,
        uint256 _rateSenior,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) internal returns (uint256) {
        emit Debug('rateJunior() called');
        emit Debug('=> _targetRatio');
        emit Debug(_targetRatio);
        emit Debug('=> _rateSenior');
        emit Debug(_rateSenior);
        emit Debug('=> seniorSupp');
        emit Debug(seniorSupp);
        emit Debug('=> juniorSupp');
        emit Debug(juniorSupp);
        return (_targetRatio * juniorSupp * _rateSenior).zDiv(seniorSupp * WAD);
    }

    /// @dev rate that goes ot senior when ignoring corrections for past payouts and paying the junior 3x per capita
    function seniorRateNominal(
        uint256 _targetRatio,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) internal returns (uint256) {
        emit Debug('rateJunior() called');
        emit Debug('=> _targetRatio');
        emit Debug(_targetRatio);
        emit Debug('=> seniorSupp');
        emit Debug(seniorSupp);
        emit Debug('=> juniorSupp');
        emit Debug(juniorSupp);
        return (WAD * WAD).zDiv(dLil(_targetRatio, seniorSupp, juniorSupp));
    }

    function dLil(
        uint256 _targetRatio,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) internal returns (uint256) {
        emit Debug('rateJunior() called');
        emit Debug('=> _targetRatio');
        emit Debug(_targetRatio);
        emit Debug('=> seniorSupp');
        emit Debug(seniorSupp);
        emit Debug('=> juniorSupp');
        emit Debug(juniorSupp);
        //this is the rate when there is shortfall or we are dividing up some extra.
        //     q*m_j
        // 1 + ------
        //      m_s
        return WAD + (_targetRatio * juniorSupp).zDiv(seniorSupp);
    }

    // avg = current average
    // newval = next value to add to average
    // N = number of time steps we are averaging over
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
    ) internal returns (uint256 nextavg) {
        emit Debug('rateJunior() called');
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
