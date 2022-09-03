// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";
import "./calc/YieldDisector.sol";

import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { SafeMath } from "./OpenZeppelin/SafeMath.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { IZivoeRewards, IZivoeRET, IZivoeGlobals } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract is modular and can facilitate distributions of assets held in escrow.
///         Distributions can be made on a preset schedule.
///         Assets can be held in escrow within this contract prior to distribution.
contract ZivoeYDL is Ownable {
    using SafeERC20 for IERC20;
    using ZMath for uint256;
    address public immutable GBL; /// @dev The ZivoeGlobals contract.

    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e; ///has to be in globals or set by globals on init or construction, the latter being the better gas option
    address public stSTT;
    address public stJTT;
    address public stZVE;
    address public vestZVE;
    address public RET;
    address public STT;
    address public JTT;
    address public ZVE;
    bool walletsSet; //this maybe is the best place to pack it there is 64 bits extra from above addresses

    uint256 public avgJuniorSupply = 3*10**18;
    uint256 public avgSeniorSupply = 10**18;
    uint256 public avgYield = 10**18; //so it doesnt start at 0
    uint256 public numPayDays = 1; //these are 1 so that they dont cause div by 0 errors
    uint256 public lastPayDay;
    uint256 public yieldTimeUnit = 7 days; /// @dev The period between yield distributions.
    uint256 public retrospectionTime = 13; /// @dev The historical period to track shortfall in units of yieldTime.
    uint256 public targetRatio = 3 * 10**18; /// @dev The target ratio of junior tranche yield relative to senior,
    uint256 defaultedFunds = 0;
    uint256 public targetYield = uint256(1 ether) / uint256(20); /// @dev The target senior yield in wei, per token.
    uint256 public r_ZVE = uint256(5 ether) / uint256(100);
    uint256 public r_RET = uint256(15 ether) / uint256(100);
    uint256 public r_ZVE_resid = uint256(90 ether) / uint256(100);
    uint256 public r_RET_resid = uint256(10 ether) / uint256(100);
    uint256 private WAD = 1 ether;

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

    /// @notice Initialize the receiving parties after ZivoeGlobals is launched and initialized
    function initialize() public {
        require(!walletsSet, "ZivoeYDL::initialize() wallets were set");
        stSTT = IZivoeGlobals(GBL).stSTT();
        stJTT = IZivoeGlobals(GBL).stJTT();
        stZVE = IZivoeGlobals(GBL).stZVE();
        vestZVE = IZivoeGlobals(GBL).vestZVE();
        STT = IZivoeGlobals(GBL).zSTT();
        JTT = IZivoeGlobals(GBL).zJTT();
        ZVE = IZivoeGlobals(GBL).ZVE();
        RET = IZivoeGlobals(GBL).RET();
        if (
            (stSTT == address(0)) ||
            (stJTT == address(0)) ||
            (stZVE == address(0)) ||
            (vestZVE == address(0)) ||
            (RET == address(0))
        ) {
            revert("ZivoeYDL::initialize(): failed, one wallet is 0");
        }
        walletsSet = true;
        lastPayDay = block.timestamp;
    }

    /// @dev  amounts[0] payout to senior tranche stake
    /// @dev  amounts[1]  payout to junior tranche stake
    /// @dev  amounts[2] payout to ZVE stakies
    /// @dev  amounts[3] payout to ZVE vesties
    /// @dev  amounts[4] payout to retained earnings
    function yieldDisect() internal view returns (uint256[7] memory amounts) {
        uint256 _yield = IERC20(FRAX).balanceOf(address(this));
        uint256 _toZVE = (r_ZVE * _yield) / WAD;
        amounts[4] = (r_RET * _yield) / WAD; //_toRET
        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();
        amounts[5] = seniorSupp;
        amounts[6] = juniorSupp;
        _yield = _yield.zSub(amounts[4] + _toZVE);
        uint256 _seniorRate = YieldDisector.rateSenior(
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
        uint256 _juniorRate = YieldDisector.rateJunior(
            targetRatio,
            _seniorRate,
            seniorSupp,
            juniorSupp
        );
        amounts[1] = (_yield * _juniorRate) / WAD;
        amounts[0] = (_yield * _seniorRate) / WAD;
        uint256 _resid = _yield.zSub(amounts[0] + amounts[1]);
        amounts[4] = amounts[4] + (_resid * r_RET_resid) / WAD;
        _toZVE += _resid - amounts[4];
        uint256 _ZVE_steaks = IERC20(ZVE).balanceOf(stZVE);
        uint256 _vZVE_steaks = IERC20(ZVE).balanceOf(vestZVE);
        uint256 _rvZVE = (WAD * _vZVE_steaks).zDiv(_ZVE_steaks + _vZVE_steaks);
        uint256 _tovestZVE = (_rvZVE * _toZVE) / WAD;
        uint256 _tostZVE = _toZVE.zSub(_tovestZVE);
        amounts[2] = _tostZVE;
        amounts[3] = _tovestZVE;
        //unrolling a loop saves on operations and declaration of the index var, incrementation gas cost is more expensive now because the default safemath
    }

    function forwardAssets() public {
        require(block.timestamp > (lastPayDay + yieldTimeUnit), "ZivoeYDL:::not time yet");
        require(walletsSet, "ZivoeYDL:::must call initialize()");
        uint256[7] memory amounts = yieldDisect();

        IERC20(FRAX).approve(stSTT, amounts[0]);
        IZivoeRewards(stSTT).depositReward(FRAX, amounts[0]);

        IERC20(FRAX).approve(stJTT, amounts[1]);
        IZivoeRewards(stJTT).depositReward(FRAX, amounts[1]);

        IERC20(FRAX).approve(stZVE, amounts[2]);
        IZivoeRewards(stZVE).depositReward(FRAX, amounts[2]);

        IERC20(FRAX).approve(vestZVE, amounts[3]);
        IZivoeRewards(vestZVE).depositReward(FRAX, amounts[3]);

        IERC20(FRAX).transfer(RET, amounts[4]);
        lastPayDay = block.timestamp;
        avgYield = YieldDisector.ma(avgYield, amounts[0], retrospectionTime, numPayDays);
        avgSeniorSupply = YieldDisector.ma(
            avgSeniorSupply,
            amounts[5],
            retrospectionTime,
            numPayDays
        );
        avgJuniorSupply = YieldDisector.ma(
            avgJuniorSupply,
            amounts[6],
            retrospectionTime,
            numPayDays
        );
        ++numPayDays; //check which incrementation op to use here, there are 3
    }

    ///@notice divides up by nominal rate
    ///this is dumb and i dont know hoiw this ended up here but i think that maybe its good to have in case of an emergency manual tranchie payday. it divides up the coinage into naive rate, IE it involves no accounting for the targets, only appropriate relative portions according to the target ratio
    ///the use of the accounting for the relative payouts might be helpful in some reward situations or emergencies, manual interventions, and to simplify governance proposals by making use of accounting here when trying to make up for past shortfalls or somethng that the stuff above didnt handle right
    function passToTranchies(address asset, uint256 _yield) public {
        //probably going to want to check that asset is supported, there doesnt seem to be an appropriate data structure in there that isnt going to cost an arm and a leg to call on. calling in a map to a struct is bad news. mapping to a bool doesnt pack in memory. probably better to do nothing IF AND ONLY IF the rewards contract can allow a trapped balance to be freed to the peoples by adding the asset retroactively
        //safe approval or not, i think the current safeapprove is just as bad as this approve due to the comments you can read on it. but there is a better one for increase of approval val rather than initialization
        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();
        uint256 _seniorRate = YieldDisector.seniorRateNominal(targetRatio, seniorSupp, juniorSupp);
        //uint256 _toJunior    = (_yield*_juniorRate)/WAD;
        uint256 _toSenior = (_yield * _seniorRate) / WAD;
        uint256 _toJunior = _yield.zSub(_toSenior);
        IERC20(asset).safeTransferFrom(msg.sender, address(this), _yield);
        IERC20(FRAX).approve(stSTT, _toSenior);
        IZivoeRewards(stSTT).depositReward(asset, _toSenior);
        IERC20(FRAX).approve(stJTT, _toJunior);
        IZivoeRewards(stJTT).depositReward(asset, _toJunior);
    }

    /// @notice call when a default occurs, increments accounted-for defaulted funds by _default
    function registerDefault(uint256 _default) public onlyOwner {
        defaultedFunds += _default;
    }

    /// @notice call when a default occurs, increments accounted-for defaulted funds by _default
    function resolveDefault(uint256 _default) public onlyOwner {
        defaultedFunds -= _default;
    }

    /// @notice adjust supplies for accounted for defaulted funds
    function adjustedSupplies() internal view returns (uint256 _seniorSuppA, uint256 _juniorSuppA) {
        uint256 _seniorSupp = IERC20(STT).balanceOf(stSTT);
        uint256 _juniorSupp = IERC20(JTT).balanceOf(stJTT);
        _juniorSuppA = _juniorSupp.zSub(defaultedFunds);
        _seniorSuppA = (_seniorSupp + _juniorSupp).zSub(defaultedFunds.zSub(_juniorSuppA));
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

    /// @notice Pass through mechanism to accept capital from external actor, specifically to
    ///         forward this to a ZivoeRewards.sol contract ($ZVE/$zSTT/$zJTT).
    function passThrough(
        address asset,
        uint256 amount,
        address multi
    ) public {
        IERC20(asset).safeApprove(multi, amount);
        IZivoeRewards(multi).depositReward(asset, amount);
    }
}
