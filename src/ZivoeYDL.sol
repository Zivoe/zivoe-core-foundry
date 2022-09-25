// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "./libraries/ZivoeMath.sol";
import "./libraries/ZivoeCalc.sol";

import "./libraries/OpenZeppelin/IERC20.sol";
import "./libraries/OpenZeppelin/Ownable.sol";
import "./libraries/OpenZeppelin/SafeERC20.sol";

import { IZivoeRewards, IERC20Mintable, IZivoeGlobals } from "./misc/InterfacesAggregated.sol";

contract ZivoeYDL is Ownable {
    using SafeERC20 for IERC20;
    using ZivoeMath for uint256;
    using ZivoeCalc for uint256;
    // ---------------------
    //    State Variables
    // ---------------------

    struct Recipients {
        //this struct takes up doudble the storage per item that it needs to store the two exact same items
        address[] recipients;
        uint256[] proportion;
    }

    Recipients protocolRecipients; /// @dev Tracks the distributions for protocol earnings.
    Recipients residualRecipients; /// @dev Tracks the distributions for residual earnings.

    address public immutable GBL; /// @dev The ZivoeGlobals contract.

    address public distributedAsset; /// @dev The "stablecoin" that will be distributed via YDL.

    bool public unlocked; /// @dev Prevents contract from supporting functionality until unlocked.

    uint256 public emaSTT; /// @dev weighted moving average for senior tranche size, a.k.a. zSTT.totalSupply()
    uint256 public emaJTT; /// @dev Weighted moving average for junior tranche size, a.k.a. zJTT.totalSupply()
    uint256 public emaYield; /// @dev Weighted moving average for yield distributions.
    uint256 public lastPayDay;

    uint256 public numDistributions; /// @dev # of calls to distributeYield() starts at 0, computed on current index for moving averages
    uint256 public lastDistribution; /// @dev Used for timelock constraint to call distributeYield()
    uint256 public yieldTimeUnit = 30 days; /// @dev The period between yield distributions.
    uint256 public retrospectionTime = 6; /// @dev The historical period to track shortfall in units of yieldTime.
    uint256 private constant WAD = 1 ether;
    uint256 private constant BIPS = 10000;

    // Governable vars
    uint256 public targetAPY = uint256(5 ether) / uint256(100); /// @dev The target senior yield in wei, per token.
    uint256 public targetRatio = 3 * WAD; /// @dev The target ratio of junior tranche yield relative to senior.
    uint256 public protocolFee;

    uint256 public r_ZVE_resid = uint256(90 ether) / uint256(100);
    uint256 public r_RET_resid = uint256(10 ether) / uint256(100);

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

    function setTargetAPY(uint256 _targetAPY) external onlyOwner {
        targetAPY = _targetAPY;
    }

    function setTargetRatio(uint256 _targetRatio) external onlyOwner {
        targetRatio = _targetRatio;
    }

    function setProtocolFee(uint256 _protocolFee) external onlyOwner {
        protocolFee = _protocolFee;
    }

    /// @notice Updates the distributed asset for this particular contract.
    function setDistributedAsset(address _distributedAsset) external onlyOwner {
        require(
            IZivoeGlobals(GBL).stablecoinWhitelist(_distributedAsset),
            "ZivoeYDL::setDistributedAsset() !IZivoeGlobals(GBL).stablecoinWhitelist(_distributedAsset)"
        );
        IERC20(distributedAsset).safeTransfer(
            IZivoeGlobals(GBL).DAO(),
            IERC20(distributedAsset).balanceOf(address(this))
        );
        distributedAsset = _distributedAsset;
    }

    /// @notice Recovers any extraneous ERC-20 asset held within this contract.
    function recoverAsset(address asset) external onlyOwner {
        require(asset != distributedAsset, "ZivoeYDL::recoverAsset() asset == distributedAsset");
        IERC20(asset).safeTransfer(
            IZivoeGlobals(GBL).DAO(),
            IERC20(asset).balanceOf(address(this))
        );
    }

    /// @notice Unlocks this contract for distributions, initializes values.
    function unlock() external {
        require(
            _msgSender() == IZivoeGlobals(GBL).ITO(),
            "ZivoeYDL::unlock() _msgSender() != IZivoeGlobals(GBL).ITO()"
        );

        unlocked = true;
        lastDistribution = block.timestamp;

        emaSTT = IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();
        emaJTT = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply();

        // TODO: Discuss initial parameters.

        address[] memory protocolRecipientAcc = new address[](2);
        uint256[] memory protocolRecipientAmt = new uint256[](2);

        protocolRecipientAcc[0] = address(IZivoeGlobals(GBL).stZVE());
        protocolRecipientAmt[0] = 66 ether / 100;
        protocolRecipientAcc[1] = address(IZivoeGlobals(GBL).DAO());
        protocolRecipientAmt[1] = 100 ether - protocolRecipientAmt[0];

        protocolRecipients = Recipients(protocolRecipientAcc, protocolRecipientAmt);

        address[] memory residualRecipientAcc = new address[](3);
        uint256[] memory residualRecipientAmt = new uint256[](3);

        residualRecipientAcc[0] = address(IZivoeGlobals(GBL).stZVE());
        residualRecipientAmt[0] = 90 ether / 100;
        residualRecipientAcc[1] = address(IZivoeGlobals(GBL).stSTT());
        residualRecipientAmt[1] = 5 ether / 100;
        residualRecipientAcc[2] = address(IZivoeGlobals(GBL).stJTT());
        residualRecipientAmt[2] = 5 ether / 100;

        residualRecipients = Recipients(residualRecipientAcc, residualRecipientAmt);
    }

    function updateProtocolRecipients(address[] memory recipients, uint256[] memory proportions)
        external
        onlyOwner
    {
        require(recipients.length == proportions.length && recipients.length > 0);
        uint256 proportionTotal;
        for (uint256 i = 0; i < recipients.length; i++) {
            proportionTotal += proportions[i];
        }
        require(proportionTotal == 10000);
        protocolRecipients = Recipients(recipients, proportions);
    }

    function updateResidualRecipients(address[] memory recipients, uint256[] memory proportions)
        external
        onlyOwner
    {
        require(recipients.length == proportions.length && recipients.length > 0);
        uint256 proportionTotal;
        for (uint256 i = 0; i < recipients.length; i++) {
            proportionTotal += proportions[i];
        }
        require(proportionTotal == 10000);
        residualRecipients = Recipients(recipients, proportions);
    }

    /// @return protocol Protocol earnings.
    /// @return senior Senior tranche earnings.
    /// @return junior Junior tranche earnings.
    /// @return residual Residual earnings.
    /// @dev yield segmented with lust and prececision of a famous pioneering 16th century amateur surgeon
    function johnTheYieldRipper(uint256 seniorSupp, uint256 juniorSupp)
        internal
        view
        returns (
            uint256[] memory protocol,
            uint256 senior,
            uint256 junior,
            uint256[] memory residual
        )
    {
        uint256 earnings = IERC20(distributedAsset).balanceOf(address(this));

        // Handle accounting for protocol earnings.
        protocol = new uint256[](protocolRecipients.recipients.length);
        uint256 protocolEarnings = (protocolFee * earnings) / WAD;
        for (uint256 i = 0; i < protocolRecipients.recipients.length; i++) {
            protocol[i] = (protocolRecipients.proportion[i] * protocolEarnings) / BIPS;
        }
        earnings = earnings.zSub(protocolEarnings);
        uint256 _seniorRate = YieldCalc.rateSenior(
            earnings,
            emaYield,
            seniorSupp,
            juniorSupp,
            targetRatio,
            targetAPY,
            retrospectionTime,
            emaSTT,
            emaJTT,
            yieldTimeUnit
        );
        uint256 _juniorRate = YieldCalc.rateJunior(
            targetRatio,
            _seniorRate,
            seniorSupp,
            juniorSupp
        );
        senior = (earnings * _seniorRate) / WAD;
        junior = (earnings * _juniorRate) / WAD;
        uint256 residualEarnings = earnings.zSub(senior + junior);
        residual = new uint256[](residualRecipients.recipients.length);
        for (uint256 i = 0; i < residualRecipients.recipients.length; i++) {
            residual[i] = (residualRecipients.proportion[i] * residualEarnings) / BIPS;
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
        ) = johnTheYieldRipper(seniorSupp, juniorSupp);

        numDistributions += 1;

        // Standardize "_seniorTranche" value to wei, irregardless of IERC20(distributionAsset).decimals()
        //this 100% should not be done here and should be done in the tranche code, you are asking for severe fuckups otherwise, having the tranche tokens inherit garbage design decisions from somethng like tether is a massve fuckup waiting to happen. it also reduces total ops and codebase size to do it once at mint

        emaYield = YieldCalc.ema(
            emaYield,
            _seniorTranche + _juniorTranche,
            retrospectionTime,
            numDistributions
        );

        emaJTT = YieldCalc.ema(emaJTT, juniorSupp, retrospectionTime, numDistributions);
        emaSTT = YieldCalc.ema(emaSTT, seniorSupp, retrospectionTime, numDistributions);

        lastDistribution = block.timestamp;

        // Distribute protocol earnings.
        for (uint256 i = 0; i < protocolRecipients.recipients.length; i++) {
            address _recipient = protocolRecipients.recipients[i];
            if (
                _recipient == IZivoeGlobals(GBL).stSTT() || _recipient == IZivoeGlobals(GBL).stJTT()
            ) {
                IERC20(distributedAsset).approve(_recipient, _protocol[i]);
                IZivoeRewards(_recipient).depositReward(distributedAsset, _protocol[i]);
            } else if (_recipient == IZivoeGlobals(GBL).stZVE()) {
                paySplitZVEVest(_protocol[i]);
            } else {
                IERC20(distributedAsset).safeTransfer(_recipient, _protocol[i]);
            }
        }
        // Distribute senior and junior tranche earnings.
        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stSTT(), _seniorTranche);
        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stJTT(), _juniorTranche);
        IZivoeRewards(IZivoeGlobals(GBL).stSTT()).depositReward(distributedAsset, _seniorTranche);
        IZivoeRewards(IZivoeGlobals(GBL).stJTT()).depositReward(distributedAsset, _juniorTranche);

        // Distribute residual earnings.
        for (uint256 i = 0; i < residualRecipients.recipients.length; i++) {
            if (_residual[i] > 0) {
                address _recipient = residualRecipients.recipients[i];
                if (
                    _recipient == IZivoeGlobals(GBL).stSTT() ||
                    _recipient == IZivoeGlobals(GBL).stJTT()
                ) {
                    IERC20(distributedAsset).approve(_recipient, _residual[i]);
                    IZivoeRewards(_recipient).depositReward(distributedAsset, _residual[i]);
                } else if (_recipient == IZivoeGlobals(GBL).stZVE()) {
                    //what was here before was very very wrong
                    paySplitZVEVest(_residual[i]);
                } else {
                    IERC20(distributedAsset).safeTransfer(_recipient, _residual[i]);
                }
            }
        }
    }

    /// @dev modularization of4 the repeated task of dividing up payments to ZVE holders between vesting and normal stakers
    /// @param _distrib - balance to distribute to ZVE holders
    function paySplitZVEVest(uint256 _distrib) internal {
        uint256 ZVEshare = (IERC20(IZivoeGlobals(GBL).stZVE()).totalSupply() * _distrib).zDiv(
            IERC20(IZivoeGlobals(GBL).stZVE()).totalSupply() +
                IERC20(IZivoeGlobals(GBL).vestZVE()).totalSupply()
        );
        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).stZVE(), ZVEshare);
        IERC20(distributedAsset).approve(IZivoeGlobals(GBL).vestZVE(), _distrib.zSub(ZVEshare));
        IZivoeRewards(IZivoeGlobals(GBL).stZVE()).depositReward(distributedAsset, ZVEshare);

        IZivoeRewards(IZivoeGlobals(GBL).vestZVE()).depositReward(
            distributedAsset,
            _distrib - ZVEshare
        );
    }

    /// @notice gives asset to junior and senior, divided up by nominal rate(same as normal with no retrospective shortfall adjustment) for surprise rewards,
    /// @param asset - token contract address
    /// @param _rewardout - amount to send
    function rewardTrancheStakers(address asset, uint256 _rewardout) public {
        require(unlocked, "ZivoeYDL:rewardTrancheStakers() !unlocked");
        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();
        uint256 _seniorRate = YieldCalc.rateSeniorNominal(targetRatio, seniorSupp, juniorSupp);
        uint256 _toSenior = (_rewardout * _seniorRate) / WAD;
        uint256 _toJunior = _rewardout.zSub(_toSenior);
        IERC20(asset).safeTransferFrom(msg.sender, address(this), _rewardout);
        bool _weok = IERC20(asset).approve(IZivoeGlobals(GBL).stSTT(), _toSenior);
        IZivoeRewards(IZivoeGlobals(GBL).stSTT()).depositReward(asset, _toSenior);
        _weok = _weok && IERC20(asset).approve(IZivoeGlobals(GBL).stJTT(), _toJunior);
        IZivoeRewards(IZivoeGlobals(GBL).stJTT()).depositReward(asset, _toJunior);
        require(_weok, "rewardToTrancheStakers:: failure");
    }

    /// @notice gives distributed asset to junior and senior, divided up by nominal rate(same as normal with no retrospective shortfall adjustment) for surprise rewards,
    ///         manual interventions, and to simplify governance proposals by making use of accounting here.
    /// @param amount - amount to send
    function supplementYield(uint256 amount) external {
        rewardTrancheStakers(distributedAsset, amount);
    }

    /// @notice Returns total circulating supply of zSTT and zJTT, accounting for defaults via markdowns.
    /// @return zSTTSupplyAdjusted zSTT.totalSupply() adjusted for defaults.
    /// @return zJTTSupplyAdjusted zJTT.totalSupply() adjusted for defaults.
    function adjustedSupplies()
        public
        view
        returns (uint256 zSTTSupplyAdjusted, uint256 zJTTSupplyAdjusted)
    {
        uint256 zSTTSupply = IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();
        uint256 zJTTSupply = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply();
        zJTTSupplyAdjusted = zJTTSupply.zSub(IZivoeGlobals(GBL).defaults());
        zSTTSupplyAdjusted = (zSTTSupply + zJTTSupply).zSub(
            IZivoeGlobals(GBL).defaults().zSub(zJTTSupplyAdjusted)
        );
    }
}
