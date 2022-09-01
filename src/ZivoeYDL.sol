// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";
import "./calc/YieldDisector.sol";

import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { IZivoeRewards, IZivoeRET, IZivoeGlobals } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract is modular and can facilitate distributions of assets held in escrow.
///         Distributions can be made on a preset schedule.
///         Assets can be held in escrow within this contract prior to distribution.
contract ZivoeYDL is Ownable {
    
    using SafeERC20 for IERC20;
    address public immutable GBL;    /// @dev The ZivoeGlobals contract.
    address public immutable STT;  
    address public immutable JTT; 
    address public immutable ZVE; 
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e; ///has to be in globals or set by globals on init or construction, the latter being the better gas option
    bool walletsSet;
    address private stSTT;
    address private stJTT;
    address private stZVE;
    address private vestZVE;
    address private RET;
    
    uint256 public cumsumYield;
    uint256 public lastPayDay; 
    uint256 public yieldTimeUnit     = 7 days;/// @dev The period between yield distributions.
    uint256 public retrospectionTime = 13;/// @dev The historical period to track shortfall in units of yieldTime.
    uint256 public targetRatio       = 3*10**18;/// @dev The target ratio of junior tranche yield relative to senior,
    
    uint256 public targetYield       = uint256(1 ether)/uint256(20);/// @dev The target yield in wei, per token.
    uint256 public r_ZVE             = uint256(5 ether)/uint256(100);
    uint256 public r_RET             = uint256(15 ether)/uint256(100);
    uint256 public r_ZVE_resid       = uint256(90 ether)/uint256(100);
    uint256 public r_RET_resid       = uint256(10 ether)/uint256(100);



    // -----------------
    //    Constructor
    // -----------------


    /// @notice Initialize the ZivoeYDL.sol contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor (
        address _GBL
    ) {
        GBL = _GBL;
        STT = IZivoeGlobals(_GBL).STT();
        JTT = IZivoeGlobals(_GBL).JTT();
        ZVE = IZivoeGlobals(_GBL).ZVE();
    }
    


    // ---------
    // Functions
    // ---------

    /// @notice Initialize the receiving parties after ZivoeGlobals is launched and initialized
    function initialize() public {
        if ((uint160(stSTT)*uint160(stJTT)*uint160(stZVE)*uint160(vestZVE)*uint160(RET) !=0) or !walletsSet){
            revert("ZivoeYDL::initialize() walletsSet"));
        }///this is cheaper than using a require and  
        stSTT      = IZivoeGlobals(GBL).stSTT();
        stJTT      = IZivoeGlobals(GBL).stJTT();
        stZVE      = IZivoeGlobals(GBL).stZVE();
        vestZVE    = IZivoeGlobals(GBL).vestZVE();
        RET        = IZivoeGlobals(GBL).RET();
        walletsSet = true;
        lastPayDay = block.timestamp();
    }

    function yieldDisect() internal view returns(uint256[5] memory amounts) {
        uint256 _yield       = IERC20(FRAX).balanceOf(address(this));
        uint256 _toZVE       = (r_ZVE*_yield)/(1 ether);
        uint256 _toRET       = (r_RET*_yield)/(1 ether);
        _yield               = _yield- _toRET - _toZVE;
        uint256 _seniorRate  = YieldDisector.rateSenior( _yield, cumsumYield, IERC20(STT).balanceOf(stSTT), IERC20(JTT).balanceOf(stJTT), targetRatio, targetRate, retrospectionTime) ;
        uint256 _juniorRate  = YieldDisector.rateJunior( targetRatio, _seniorRate, IERC20(JTT).balanceOf(stJTT), IERC20(STT).balanceOf(stSTT) );
        uint256 _toJunior    = (_yield*_juniorRate)/(1 ether);
        uint256 _toSenior    = (_yield*_seniorRate)/(1 ether);
        uint256 _resid       = _yield - _toSenior - _toJunior;
        _toRET               = _toRET + _resid*r_RET_resid;
        _toZVE               = _resid - _toRET;
        uint256 _ZVE_steaks  = IERC20(ZVE).balanceOf(stZVE);
        uint256 _vZVE_steaks = IERC20(ZVE).balanceOf(vestZVE);
        uint256 _rvZVE       = ((1 ether)*_vZVE_steaks)/(_ZVE_steaks+_vZVE_steaks);
        uint256 _tovestZVE   = (_rvZVE*_toZVE)/(1 ether);
        uint256 _tostZVE     = _toZVE - _tovestZVE;
        amounts[0]
        amounts[1]
        amounts[2]
        amounts[3]
        amounts[4]
        //unrolling a loop saves on operations and declaration of the index var, incrementation gas cost is more expensive now because the default safemath 
    }
    

    function payDay() public {
        uint256[5] memory amounts = yieldDisector();
        IZivoeRewards(stSTT).depositReward(FRAX,amounts[0]);
        IZivoeRewards(stJTT).depositReward(FRAX,amounts[1]);
        IZivoeRewards(stZVE).depositReward(FRAX,amounts[2]);
        IZivoeRewards(vestZVE).depositReward(FRAX,amounts[3]);
        //IZivoeRewards(stSTT).depositReward(FRAX,amounts[4]);

    }

    ///@notice divides up by nominal rate
    ///this is dumb and i dont know hoiw this ended up here but i think that maybe its good to have in case of an emergency manual tranchie payday. it divides up the coinage into naive rate, IE it involves no accounting for the targets, only appropriate relative portions according to the target ratio
    ///the use of the accounting for the relative payouts might be helpful in some reward situations or emergencies, manual interventions, and to simplify governance proposals by making use of accounting here when trying to make up for past shortfalls or somethng that the stuff above didnt handle right 
    function passAssets(address asset, uint256 _yield) public {
        //probably going to want to check that asset is supported, there doesnt seem to be an appropriate data structure in there that isnt going to cost an arm and a leg to call on. calling in a map to a struct is bad news. mapping to a bool doesnt pack in memory. probably better to do nothing IF AND ONLY IF the rewards contract can allow a trapped balance to be freed to the peoples by adding the asset retroactively
        IERC20(asset).approve(address(this),amount);
        //safe approval or not, i think the current safeapprove is just as bad as this approve due to the comments you can read on it. but there is a better one for increase of approval val rather than initialization
       _seniorRate = YieldDisector.seniorRateNominal(  targetRatio,  IERC20(JTT).balanceOf(stJTT), IERC20(STT).balanceOf(stSTT)) ;  
       _juniorRate = YieldDisector.rateJunior( targetRatio, _seniorRate, IERC20(JTT).balanceOf(stJTT), IERC20(STT).balanceOf(stSTT) );
        //uint256 _toJunior    = (_yield*_juniorRate)/(1 ether);
        uint256 _toSenior    = (_yield*_seniorRate)/(1 ether);
        _toJunior = _yield - _toSenior;
        IERC20(asset).safeTransferFrom(msg.sender,address(this),_yield);
        IZivoeRewards(stSTT).depositReward(asset,_toSenior);
        IZivoeRewards(stJTT).depositReward(asset,_toJunior);
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
