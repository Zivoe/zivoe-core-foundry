// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "./ZivoeMath.sol";

import "./libraries/FloorMath.sol";

import "../lib/openzeppelin-contracts/contracts/utils/Context.sol";
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

    /// @notice Returns true if an address is whitelisted as a keeper.
    /// @return keeper Equals "true" if address is a keeper, "false" if not.
    function isKeeper(address) external view returns (bool keeper);

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  amount The amount of a given "asset".
    /// @param  asset The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount The above amount standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);

    /// @notice Returns total circulating supply of zSTT and zJTT, accounting for defaults via markdowns.
    /// @return zSTTSupply zSTT.totalSupply() adjusted for defaults.
    /// @return zJTTSupply zJTT.totalSupply() adjusted for defaults.
    function adjustedSupplies() external view returns (uint256 zSTTSupply, uint256 zJTTSupply);

    /// @notice This function will verify if a given stablecoin has been whitelisted for use throughout system (ZVE, YDL).
    /// @param  stablecoin address of the stablecoin to verify acceptance for.
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
///            - Facilitates arbitrary swaps from non-distributeAsset tokens to distributedAsset tokens.
contract ZivoeYDL is Context, ReentrancyGuard {

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

    // Indexing.
    uint256 public numDistributions;        /// @dev # of calls to distributeYield() starts at 0, computed on current index for moving averages.
    uint256 public lastDistribution;        /// @dev Used for timelock constraint to call distributeYield().

    // Accounting vars (governable).
    uint256 public targetAPYBIPS = 800;                 /// @dev The target annualized yield for senior tranche.
    uint256 public targetRatioBIPS = 16250;             /// @dev The target ratio of junior to senior tranche.
    uint256 public protocolEarningsRateBIPS = 2000;     /// @dev The protocol earnings rate.

    // Accounting vars (constant).
    uint256 public constant daysBetweenDistributions = 30;   /// @dev Number of days between yield distributions.
    uint256 public constant retrospectiveDistributions = 6;  /// @dev The # of distributions to track historical (weighted) performance.

    uint256 private constant BIPS = 10000;
    uint256 private constant RAY = 10 ** 27;

    ZivoeMath public MATH;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initialize the ZivoeYDL contract.
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _distributedAsset The "stablecoin" that will be distributed via YDL.
    constructor(address _GBL, address _distributedAsset) {
        GBL = _GBL;
        distributedAsset = _distributedAsset;
        MATH = new ZivoeMath();
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during returnAsset().
    /// @param  asset The asset returned.
    /// @param  amount The amount of "asset" returned to DAO.
    event AssetReturned(address indexed asset, uint256 amount);

    /// @notice Emitted during setDistributedAsset().
    /// @param  oldAsset The old asset of distributedAsset.
    /// @param  newAsset The new asset of distributedAsset.
    event UpdatedDistributedAsset(address indexed oldAsset, address indexed newAsset);

    /// @notice Emitted during setProtocolEarningsRateBIPS().
    /// @param  oldValue The old value of protocolEarningsRateBIPS.
    /// @param  newValue The new value of protocolEarningsRateBIPS.
    event UpdatedProtocolEarningsRateBIPS(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during updateRecipients().
    /// @param  recipients The new recipients to receive protocol earnings.
    /// @param  proportion The proportion distributed across recipients.
    event UpdatedProtocolRecipients(address[] recipients, uint256[] proportion);

    /// @notice Emitted during updateRecipients().
    /// @param  recipients The new recipients to receive residual earnings.
    /// @param  proportion The proportion distributed across recipients.
    event UpdatedResidualRecipients(address[] recipients, uint256[] proportion);

    /// @notice Emitted during setTargetAPYBIPS().
    /// @param  oldValue The old value of targetAPYBIPS.
    /// @param  newValue The new value of targetAPYBIPS.
    event UpdatedTargetAPYBIPS(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during setTargetRatioBIPS().
    /// @param  oldValue The old value of targetRatioBIPS.
    /// @param  newValue The new value of targetRatioBIPS.
    event UpdatedTargetRatioBIPS(uint256 oldValue, uint256 newValue);

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



    // ---------------
    //    Functions
    // ---------------

    /// @notice Updates the state variable "targetAPYBIPS".
    /// @param  _targetAPYBIPS The new value for targetAPYBIPS.
    function setTargetAPYBIPS(uint256 _targetAPYBIPS) external {
        require(_msgSender() == YDL_IZivoeGlobals(GBL).TLC(), "ZivoeYDL::setTargetAPYBIPS() _msgSender() != TLC()");
        emit UpdatedTargetAPYBIPS(targetAPYBIPS, _targetAPYBIPS);
        targetAPYBIPS = _targetAPYBIPS;
    }

    /// @notice Updates the state variable "targetRatioBIPS".
    /// @param  _targetRatioBIPS The new value for targetRatioBIPS.
    function setTargetRatioBIPS(uint256 _targetRatioBIPS) external {
        require(_msgSender() == YDL_IZivoeGlobals(GBL).TLC(), "ZivoeYDL::setTargetRatioBIPS() _msgSender() != TLC()");
        emit UpdatedTargetRatioBIPS(targetRatioBIPS, _targetRatioBIPS);
        targetRatioBIPS = _targetRatioBIPS;
    }

    /// @notice Updates the state variable "protocolEarningsRateBIPS".
    /// @param  _protocolEarningsRateBIPS The new value for protocolEarningsRateBIPS.
    function setProtocolEarningsRateBIPS(uint256 _protocolEarningsRateBIPS) external {
        require(_msgSender() == YDL_IZivoeGlobals(GBL).TLC(), "ZivoeYDL::setProtocolEarningsRateBIPS() _msgSender() != TLC()");
        require(_protocolEarningsRateBIPS <= 3000, "ZivoeYDL::setProtocolEarningsRateBIPS() _protocolEarningsRateBIPS > 3000");
        emit UpdatedProtocolEarningsRateBIPS(protocolEarningsRateBIPS, _protocolEarningsRateBIPS);
        protocolEarningsRateBIPS = _protocolEarningsRateBIPS;
    }

    /// @notice Updates the distributed asset for this particular contract.
    /// @param  _distributedAsset The new value for distributedAsset.
    function setDistributedAsset(address _distributedAsset) external nonReentrant {
        require(_distributedAsset != distributedAsset, "ZivoeYDL::setDistributedAsset() _distributedAsset == distributedAsset");
        require(_msgSender() == YDL_IZivoeGlobals(GBL).TLC(), "ZivoeYDL::setDistributedAsset() _msgSender() != TLC()");
        require(
            YDL_IZivoeGlobals(GBL).stablecoinWhitelist(_distributedAsset),
            "ZivoeYDL::setDistributedAsset() !YDL_IZivoeGlobals(GBL).stablecoinWhitelist(_distributedAsset)"
        );
        emit UpdatedDistributedAsset(distributedAsset, _distributedAsset);
        distributedAsset = _distributedAsset;
    }

    /// @notice Unlocks this contract for distributions, initializes values.
    function unlock() external {
        require(_msgSender() == YDL_IZivoeGlobals(GBL).ITO(), "ZivoeYDL::unlock() _msgSender() != YDL_IZivoeGlobals(GBL).ITO()");

        unlocked = true;
        lastDistribution = block.timestamp + 30 days;

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

    /// @notice Updates the protocolRecipients or residualRecipients.
    /// @param  recipients An array of addresses to which protocol earnings will be distributed.
    /// @param  proportions An array of ratios relative to the recipients - in BIPS. Sum should equal to 10000.
    function updateRecipients(address[] memory recipients, uint256[] memory proportions, bool protocol) external {
        require(_msgSender() == YDL_IZivoeGlobals(GBL).TLC(), "ZivoeYDL::updateRecipients() _msgSender() != TLC()");
        require(
            recipients.length == proportions.length && recipients.length > 0, 
            "ZivoeYDL::updateRecipients() recipients.length != proportions.length || recipients.length == 0"
        );
        require(unlocked, "ZivoeYDL::updateRecipients() !unlocked");

        uint256 proportionTotal;
        for (uint256 i = 0; i < recipients.length; i++) {
            proportionTotal += proportions[i];
            require(proportions[i] > 0, "ZivoeYDL::updateRecipients() proportions[i] == 0");
        }

        require(proportionTotal == BIPS, "ZivoeYDL::updateRecipients() proportionTotal != BIPS (10,000)");
        if (protocol) {
            emit UpdatedProtocolRecipients(recipients, proportions);
            protocolRecipients = Recipients(recipients, proportions);
        }
        else {
            emit UpdatedResidualRecipients(recipients, proportions);
            residualRecipients = Recipients(recipients, proportions);
        }
    }

    /// @notice Returns an asset to DAO if not distributedAsset().
    function returnAsset(address asset) external {
        require(asset != distributedAsset, "ZivoeYDL::returnAsset asset == distributedAsset");
        emit AssetReturned(asset, IERC20(asset).balanceOf(address(this)));
        IERC20(asset).safeTransfer(YDL_IZivoeGlobals(GBL).DAO(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Distributes available yield within this contract to appropriate entities.
    function distributeYield() external nonReentrant {
        require(unlocked, "ZivoeYDL::distributeYield() !unlocked"); 
        require(
            block.timestamp >= lastDistribution + daysBetweenDistributions * 86400, 
            "ZivoeYDL::distributeYield() block.timestamp < lastDistribution + daysBetweenDistributions * 86400"
        );

        // Calculate protocol earnings.
        uint256 earnings = IERC20(distributedAsset).balanceOf(address(this));
        uint256 protocolEarnings = protocolEarningsRateBIPS * earnings / BIPS;
        uint256 postFeeYield = earnings.zSub(protocolEarnings);

        // Update timeline.
        numDistributions += 1;
        lastDistribution = block.timestamp;

        // Calculate yield distribution (trancheuse = "slicer" in French).
        (
            uint256[] memory _protocol, uint256 _seniorTranche, uint256 _juniorTranche, uint256[] memory _residual
        ) = earningsTrancheuse(protocolEarnings, postFeeYield); 

        emit YieldDistributed(_protocol, _seniorTranche, _juniorTranche, _residual);
        
        // Update ema-based supply values.
        (uint256 aSTT, uint256 aJTT) = YDL_IZivoeGlobals(GBL).adjustedSupplies();
        emaSTT = MATH.ema(emaSTT, aSTT, retrospectiveDistributions.min(numDistributions));
        emaJTT = MATH.ema(emaJTT, aJTT, retrospectiveDistributions.min(numDistributions));

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



    // ----------
    //    Math
    // ----------

    /// @notice Calculates the distribution of yield ("earnings") for the four primary groups.
    /// @param  yP Yield for the protocol.
    /// @param  yD Yield for the remaining three groups.
    /// @return protocol Protocol earnings.
    /// @return senior Senior tranche earnings.
    /// @return junior Junior tranche earnings.
    /// @return residual Residual earnings.
    function earningsTrancheuse(uint256 yP, uint256 yD) public view returns (
        uint256[] memory protocol, uint256 senior, uint256 junior, uint256[] memory residual
    ) {
        protocol = new uint256[](protocolRecipients.recipients.length);
        residual = new uint256[](residualRecipients.recipients.length);
        
        // Accounting for protocol earnings.
        for (uint256 i = 0; i < protocolRecipients.recipients.length; i++) {
            protocol[i] = protocolRecipients.proportion[i] * yP / BIPS;
        }

        // Accounting for senior and junior earnings.
        uint256 _seniorProportion = MATH.seniorProportion(
            YDL_IZivoeGlobals(GBL).standardize(yD, distributedAsset),
            MATH.yieldTarget(emaSTT, emaJTT, targetAPYBIPS, targetRatioBIPS, daysBetweenDistributions),
            emaSTT, emaJTT, targetAPYBIPS, targetRatioBIPS, daysBetweenDistributions
        );
        senior = (yD * _seniorProportion) / RAY;
        junior = (yD * MATH.juniorProportion(emaSTT, emaJTT, _seniorProportion, targetRatioBIPS)) / RAY;
        
        // Handle accounting for residual earnings.
        yD = yD.zSub(senior + junior);
        for (uint256 i = 0; i < residualRecipients.recipients.length; i++) {
            residual[i] = residualRecipients.proportion[i] * yD / BIPS;
        }
    }

}
