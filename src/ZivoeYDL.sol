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

    address public immutable GBL; /// @dev The ZivoeGlobals contract.

    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e; ///has to be in globals or set by globals on init or construction, the latter being the better gas option
    
    bool unlocked = false; //this maybe is the best place to pack it there is 64 bits extra from above addresses

    // These are update on each forwardAssets() call.
    // Represents an EMA (exponential moving average).
    // These have initial values for testing purposes.
    // TODO: Ensure these reflect post-ITO (immediate) values.
    uint256 public avgJuniorSupply = 3 * 10**18;
    uint256 public avgSeniorSupply = 10**18;
    uint256 public avgYield = 10**18;               /// @dev Yield tracking, for overage.
    
    // # of calls to forwardAssets()
    // TODO: Determine proper initial value for this.
    uint256 public numPayDays = 1; //these are 1 so that they dont cause div by 0 errors

    // Used for timelock constraint to call forwardAssets()
    uint256 public lastPayDay;

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

    // ---------
    // Functions
    // ---------

    /// @notice Unlocks this contract for distributions, sets some initial variables.
    function unlock() external {
        require(_msgSender() == IZivoeGlobals(GBL).ITO(), "ZivoeYDL::unlock() _msgSender() != IZivoeGlobals(GBL).ITO()");
        unlocked = true;
        lastPayDay = block.timestamp;
    }

    // ----------------

    /// @dev  amounts[0] payout to senior tranche stake
    /// @dev  amounts[1] payout to junior tranche stake
    /// @dev  amounts[2] payout to ZVE stakies
    /// @dev  amounts[3] payout to ZVE vesties
    /// @dev  amounts[4] payout to retained earnings
    function yieldTrancheuse() internal view returns (uint256[7] memory amounts) {
        // TODO: Consider modularity for haricut fees.
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
            avgSeniorSupply,
            avgJuniorSupply
        );
        uint256 _juniorRate = YieldTrancheuse.rateJunior(
            targetRatio,
            _seniorRate,
            seniorSupp,
            juniorSupp
        );
        amounts[1] = (_yield * _juniorRate) / WAD;
        amounts[0] = (_yield * _seniorRate) / WAD;
        uint256 _resid = _yield.zSub(amounts[0] + amounts[1]);
        // TODO: Identify which wallets the overage should go to, or make this modular.
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

    function forwardAssets() external {
        require(block.timestamp >= (lastPayDay + yieldTimeUnit) || lastPayDay == 0, "ZivoeYDL:::not time yet");
        require(unlocked, "ZivoeYDL::forwardAssets() !unlocked");
        uint256[7] memory amounts = yieldTrancheuse();
        lastPayDay = block.timestamp;
        avgYield = YieldTrancheuse.ma(avgYield, amounts[0], retrospectionTime, numPayDays);
        avgSeniorSupply = YieldTrancheuse.ma(
            avgSeniorSupply,
            amounts[5],
            retrospectionTime,
            numPayDays
        );
        avgJuniorSupply = YieldTrancheuse.ma(
            avgJuniorSupply,
            amounts[6],
            retrospectionTime,
            numPayDays
        );
        ++numPayDays;
        bool _weok = true;
        _weok = _weok && IERC20(FRAX).approve(IZivoeGlobals(GBL).stSTT(), amounts[0]);
        IZivoeRewards(IZivoeGlobals(GBL).stSTT()).depositReward(FRAX, amounts[0]);

        _weok = _weok && IERC20(FRAX).approve(IZivoeGlobals(GBL).stJTT(), amounts[1]);
        IZivoeRewards(IZivoeGlobals(GBL).stJTT()).depositReward(FRAX, amounts[1]);

        _weok = _weok && IERC20(FRAX).approve(IZivoeGlobals(GBL).stZVE(), amounts[2]);
        IZivoeRewards(IZivoeGlobals(GBL).stZVE()).depositReward(FRAX, amounts[2]);

        _weok = _weok && IERC20(FRAX).approve(IZivoeGlobals(GBL).vestZVE(), amounts[3]);
        IZivoeRewards(IZivoeGlobals(GBL).vestZVE()).depositReward(FRAX, amounts[3]);

        _weok = _weok && IERC20(FRAX).transfer(IZivoeGlobals(GBL).DAO(), amounts[4]);
        require(_weok, "forwardAssets:: failure");
    }

    // ------------------------

    /// @notice gives asset to junior and senior, divided up by nominal rate(same as normal with no retrospective shortfall adjustment) for surprise rewards, 
    ///         manual interventions, and to simplify governance proposals by making use of accounting here. 
    /// @param asset - token contract address
    /// @param _payout - amount to send
    function passToTranchies(address asset, uint256 _payout) external {
        require(unlocked, "ZivoeYDL::passToTranchies() !unlocked");
        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();
        uint256 _seniorRate = YieldTrancheuse.seniorRateNominal(targetRatio, seniorSupp, juniorSupp);
        uint256 _toSenior = (_payout * _seniorRate) / WAD;
        uint256 _toJunior = _payout.zSub(_toSenior);
        IERC20(asset).safeTransferFrom(msg.sender, address(this), _payout);
        bool _weok = IERC20(FRAX).approve(IZivoeGlobals(GBL).stSTT(), _toSenior);
        IZivoeRewards(IZivoeGlobals(GBL).stSTT()).depositReward(asset, _toSenior);
        _weok = _weok && IERC20(FRAX).approve(IZivoeGlobals(GBL).stJTT(), _toJunior);
        IZivoeRewards(IZivoeGlobals(GBL).stJTT()).depositReward(asset, _toJunior);
        require(_weok, "passToTranchies:: failure");
    }

    /// @notice adjust supplies for accounted for defaulted funds
    function adjustedSupplies() internal view returns (uint256 _seniorSuppA, uint256 _juniorSuppA) {
        uint256 _seniorSupp = IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();
        uint256 _juniorSupp = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply();
        _juniorSuppA = _juniorSupp.zSub(IZivoeGlobals(GBL).defaults());
        // TODO: Verify if statement below is accurate in certain default states.
        _seniorSuppA = (_seniorSupp + _juniorSupp).zSub(IZivoeGlobals(GBL).defaults().zSub(_juniorSuppA));
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
