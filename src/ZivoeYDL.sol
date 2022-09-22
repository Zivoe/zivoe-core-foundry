// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "./libraries/ZivoeMath.sol";

import "./libraries/OpenZeppelin/IERC20.sol";
import "./libraries/OpenZeppelin/Ownable.sol";
import "./libraries/OpenZeppelin/SafeERC20.sol";

import { IZivoeRewards, IERC20Mintable, IZivoeGlobals } from "./misc/InterfacesAggregated.sol";

contract ZivoeYDL is Ownable {

    using SafeERC20 for IERC20;
    using ZivoeMath for uint256;

    // ---------------------
    //    State Variables
    // ---------------------

    struct Recipients {//this struct takes up doudble the storage per item that it needs to store the two exact same items
        address[] recipients;
        uint256[] proportion;
    }

    Recipients protocolRecipients;          /// @dev Tracks the distributions for protocol earnings.
    Recipients residualRecipients;          /// @dev Tracks the distributions for residual earnings.

    address public immutable GBL;           /// @dev The ZivoeGlobals contract.

    address public distributedAsset;        /// @dev The "stablecoin" that will be distributed via YDL.
    
    bool public unlocked;                   /// @dev Prevents contract from supporting functionality until unlocked.

    // Weighted moving average.
    uint256 public emaSTT;                  /// @dev Weighted moving average for senior tranche size, a.k.a. zSTT.totalSupply()
    uint256 public emaJTT;                  /// @dev Weighted moving average for junior tranche size, a.k.a. zJTT.totalSupply()
    uint256 public emaYield;                /// @dev Weighted moving average for yield distributions.

    // Indexing.
    uint256 public numDistributions;        /// @dev # of calls to distributeYield() starts at 0, computed on current index for moving averages
    uint256 public lastDistribution;        /// @dev Used for timelock constraint to call distributeYield()

    // Accounting vars (governable).
    uint256 public targetAPYBIPS = 500;     /// @dev The target annualized yield for senior tranche.
    uint256 public targetRatioBIPS = 30000; /// @dev The target ratio of junior to senior tranche.
    uint256 public protocolFeeBIPS = 2000; /// @dev The protocol earnings rate.

    // Accounting vars (fixed).
    uint256 public yieldTimeUnit = 30 days; /// @dev The period between yield distributions.
    uint256 public retrospectionTime = 6;   /// @dev The historical period to track shortfall in yieldTimeUnit's.



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

    // TODO: Consider range-bound limitations for these setters.

    function setTargetAPYBIPS(uint _targetAPYBIPS) external onlyOwner {
        targetAPYBIPS = _targetAPYBIPS;
    }

    function setTargetRatioBIPS(uint _targetRatioBIPS) external onlyOwner {
        targetRatioBIPS = _targetRatioBIPS;
    }

    function setProtocolRateBIPS(uint _protocolFeeBIPS) external onlyOwner {
        protocolFeeBIPS = _protocolFeeBIPS;
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

    function updateProtocolRecipients(address[] memory recipients, uint256[] memory proportions) external onlyOwner {
        require(recipients.length == proportions.length && recipients.length > 0);
        uint256 proportionTotal;
        for (uint i = 0; i < recipients.length; i++) {
            proportionTotal += proportions[i];
        }
        require(proportionTotal == BIPS);
        protocolRecipients = Recipients(recipients, proportions);
    }

    function updateResidualRecipients(address[] memory recipients, uint256[] memory proportions) external onlyOwner {
        require(recipients.length == proportions.length && recipients.length > 0);
        uint256 proportionTotal;
        for (uint i = 0; i < recipients.length; i++) {
            proportionTotal += proportions[i];
        }
        require(proportionTotal == BIPS);
        residualRecipients = Recipients(recipients, proportions);
    }

    event Debug(string);
    event Debug(uint256);
    event Debug(uint256[]);
    event Debug(address[]);
    event Debug(uint256[7]);

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
        uint protocolEarnings = protocolFeeBIPS * earnings / BIPS;//chris: 8 bit math op here
        for (uint i = 0; i < protocolRecipients.recipients.length; i++) {
            protocol[i] = protocolRecipients.proportion[i] * protocolEarnings / BIPS;
        }

        emit Debug('protocolEarnings');
        emit Debug(protocolEarnings);

        earnings = earnings.zSub(protocolEarnings);

        emit Debug('earnings.zSub(protocolEarnings)');
        emit Debug(earnings);

        // Standardize "earnings" value to wei, irregardless of IERC20(distributionAsset).decimals()
        
        uint256 _convertedEarnings = earnings;

        if (IERC20Mintable(distributedAsset).decimals() < 18) { //chris:
            _convertedEarnings *= 10 ** (18 - IERC20Mintable(distributedAsset).decimals());
        }
        else if (IERC20Mintable(distributedAsset).decimals() > 18) {
            _convertedEarnings *= 10 ** (IERC20Mintable(distributedAsset).decimals() - 18);
        }

        uint256 _seniorRate = johnny_rateSenior_RAY(
            _convertedEarnings,
            seniorTrancheSize,
            juniorTrancheSize,
            targetAPYBIPS,
            targetRatioBIPS,
            yieldTimeUnit,
            retrospectionTime
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
            residual[i] = residualRecipients.proportion[i] * residualEarnings / BIPS;
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
        
        // Standardize "_seniorTranche" value to wei, irregardless of IERC20(distributionAsset).decimals()

        uint256 _convertedSeniorTranche = _seniorTranche;
//chris: literally waht the fuk is this, why is this not in a library given that it probably needs to be done in more than one place, and why the flipping fuck would we need to convert our own tranche. this should be done at the tranche level , our coins should aways be the same and not a sloppy cancer-ridden cousin fucking copy of whatever stablecoin hasnt depegged this month
        if (IERC20Mintable(distributedAsset).decimals() < 18) {
            _convertedSeniorTranche *= 10 ** (18 - IERC20Mintable(distributedAsset).decimals());
        }
        else if (IERC20Mintable(distributedAsset).decimals() > 18) {
            _convertedSeniorTranche *= 10 ** (IERC20Mintable(distributedAsset).decimals() - 18);
        }

        emaYield = ema(
            emaYield,
            _convertedSeniorTranche,
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

        (uint256 seniorSupp,) = adjustedSupplies();
    
        uint256 seniorRate = johnny_seniorRateNominal_RAY_v2(amount, seniorSupp, targetAPYBIPS, retrospectionTime); //why the fuck does this have a hard coded value, is this a gas savings hack or a fuckup
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
    uint256 private constant BIPS = 10000;
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
    */ //chris: stop using the same names for different variables, 
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
            emit Debug(WAD * postFeeYield * (WAD + (Q * sJTT * WAD / BIPS).zDiv(sSTT)));
            return ((R + 1) * yT * RAY * WAD).zSub(R * debuggingEMAYield * RAY * WAD).zDiv(
                postFeeYield * (WAD + (Q * sJTT * WAD / BIPS).zDiv(sSTT))
            );
            // ((((R + 1) * yT).zSub(R * emaYield)) * WAD).zDiv(
            //     postFeeYield * dLil(Q, sSTT, sJTT)
            // );
        }
        else {
            return ((R + 1) * yT * RAY * WAD).zSub(R * emaYield * RAY * WAD).zDiv(
                postFeeYield * (WAD + (Q * sJTT * WAD / BIPS).zDiv(sSTT))
            );
        }
    }

    /**
        @notice     Calculates % of yield attributable to junior tranche.
        @param      sSTT = total supply of senior tranche token    (units = wei)
        @param      sJTT = total supply of junior tranche token    (units = wei)
        @param      Y    = % of yield attributable to seniors      (units = RAY) chris: what does this mean, why 
        @param      Q    = senior to junior tranche target ratio   (units = BIPS)
    */
    function johnny_rateJunior_RAY(
        uint256 sSTT,
        uint256 sJTT,
        uint256 Y,
        uint256 Q
    ) public pure returns (uint256) {
        return (Q * sJTT * Y / BIPS).zDiv(sSTT).min(RAY - Y);//chris: this can revert
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

///    chris: we should be using one time unit, either days or seconds, for everything. 
    function johnny_seniorRateNominal_RAY_v2(
        uint256 postFeeYield,
        uint256 sSTT,
        uint256 Y,
        uint256 T
    ) public pure returns (uint256) {
        // NOTE: THIS WILL REVERT IF postFeeYield == 0 ?? ISSUE ??
        return (RAY * Y * (sSTT) * T / BIPS) / (365^2) / (postFeeYield);//chris: yes, this should be with zDiv
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
        return (WAD * RAY).zDiv(WAD + (Q * sJTT * WAD / BIPS).zDiv(sSTT));
    }//chris: this above is a collossal fuckup waiting to happen

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
