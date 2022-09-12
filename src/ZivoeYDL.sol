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
    uint256 public targetYield = uint256(1 ether) / uint256(20); /// @dev The target senior yield in wei, per token.
    uint256 public targetRatio = 3 * 10**18; /// @dev The target ratio of junior tranche yield relative to senior.

    // r = rate (% / ratio)
    uint256 public r_ZVE = uint256(5 ether) / uint256(100);
    uint256 public r_DAO = uint256(15 ether) / uint256(100);

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

    /// @notice Unlocks this contract for distributions, initializes lastDistribution.
    function unlock() external {
        require(_msgSender() == IZivoeGlobals(GBL).ITO(), "ZivoeYDL::unlock() _msgSender() != IZivoeGlobals(GBL).ITO()");
        unlocked = true;
        lastDistribution = block.timestamp;

        emaJuniorSupply = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply();
        emaSeniorSupply = IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();

        // TODO: Determine if avgRate needs to be updated here as well relative to starting values?
    }

    // TODO: Switch to below return variable.
    /// @dev  amounts[0] Protocol fees.
    /// @dev  amounts[1] Senior tranche distribution.
    /// @dev  amounts[2] Junior tranche distribution.
    /// @dev  amounts[3] Overage.

    /// @dev  amounts[0] payout to senior tranche stake
    /// @dev  amounts[1] payout to junior tranche stake
    /// @dev  amounts[2] payout to ZVE stakies
    /// @dev  amounts[3] payout to ZVE vesties
    /// @dev  amounts[4] payout to retained earnings
    function yieldTrancheuse() internal view returns (uint256[7] memory amounts) {

        // Total amount available for distribution.
        uint256 _yield = IERC20(FRAX).balanceOf(address(this));

        uint256 _toZVE = (r_ZVE * _yield) / WAD;
        amounts[4] = (r_DAO * _yield) / WAD; //_toDAO

        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();
        amounts[5] = seniorSupp;
        amounts[6] = juniorSupp;

        _yield = _yield.zSub(amounts[4] + _toZVE);

        uint256 _seniorRate = YieldTrancheuse.rateSenior(
            _yield,
            avgYield,
            seniorSupp,
            juniorSupp,
            targetRatio,
            targetYield,
            retrospectionTime,
            emaSeniorSupply,
            emaJuniorSupply
        );
        uint256 _juniorRate = YieldTrancheuse.rateJunior(
            targetRatio,
            _seniorRate,
            seniorSupp,
            juniorSupp
        );
        amounts[0] = (_yield * _seniorRate) / WAD;
        amounts[1] = (_yield * _juniorRate) / WAD;
        

        // TODO: Identify which wallets the overage should go to, or make this modular.
        uint256 _resid = _yield.zSub(amounts[0] + amounts[1]);
        amounts[4] = amounts[4] + (_resid * r_DAO_resid) / WAD;
        _toZVE += _resid - amounts[4];
        uint256 _ZVE_steaks = IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(IZivoeGlobals(GBL).stZVE());
        uint256 _vZVE_steaks = IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(IZivoeGlobals(GBL).vestZVE());
        uint256 _rvZVE = (WAD * _vZVE_steaks).zDiv(_ZVE_steaks + _vZVE_steaks);
        uint256 _tovestZVE = (_rvZVE * _toZVE) / WAD;
        uint256 _tostZVE = _toZVE.zSub(_tovestZVE);
        amounts[2] = _tostZVE;
        amounts[3] = _tovestZVE;
        //unrolling a loop saves on operations and declaration of the index var, incrementation gas cost is more expensive now because the default safemath
    }

    /// @notice Distributes available yield within this contract to appropriate entities
    function distributeYield() external {

        require(
            block.timestamp >= lastDistribution + yieldTimeUnit, 
            "ZivoeYDL::distributeYield() block.timestamp < lastDistribution + yieldTimeUnit"
        );
        require(unlocked, "ZivoeYDL::distributeYield() !unlocked"); 

        uint256[7] memory amounts = yieldTrancheuse();

        avgYield = YieldTrancheuse.ema(avgYield, amounts[0], retrospectionTime, numDistributions);

        emaSeniorSupply = YieldTrancheuse.ema(
            emaSeniorSupply,
            amounts[5],
            retrospectionTime,
            numDistributions
        );

        emaJuniorSupply = YieldTrancheuse.ema(
            emaJuniorSupply,
            amounts[6],
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

        uint256 seniorRate = YieldTrancheuse.seniorRateNominal(targetRatio, seniorSupp, juniorSupp);
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

}
