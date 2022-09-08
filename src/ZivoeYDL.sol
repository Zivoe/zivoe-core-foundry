// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";
import "./calc/YieldTrancheus.sol";
import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { IZivoeRewards, IZivoeRET, IZivoeGlobals } from "./interfaces/InterfacesAggregated.sol";

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

    // TODO: Consider migrating this to globals (and proper incrementer/decrementer).
    uint256 defaultedFunds = 0;

    // r = rate (% / ratio)
    uint256 public r_ZVE = uint256(5 ether) / uint256(100);
    uint256 public r_RET = uint256(15 ether) / uint256(100);

    // resid = residual = overage = performance bonus
    uint256 public r_ZVE_resid = uint256(90 ether) / uint256(100);
    uint256 public r_RET_resid = uint256(10 ether) / uint256(100);

    uint256 private constant WAD = 1 ether;

    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initialize the ZivoeYDL.sol contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address _GBL) {
        require(_GBL != address(0));
        GBL = _GBL;
    }

    /// @param _default default ammount registered now
    /// @param defaultedFunds - total defaulted funds in pool after event
    /// @notice - announce registration of and  accounting for defaulted funds
    event DefaultRegistered(uint256 _default, uint256 defaultedFunds);

    /// @param _default defaulted funds resolved now
    /// @param defaultedFunds - total defaulted funds in pool after event
    /// @notice - announce resolution of defaulted funds, the inverse of default
    event DefaultResolved(uint256 _default, uint256 defaultedFunds);

    // ---------
    // Functions
    // ---------

    /// @notice Initialize the receiving parties after ZivoeGlobals is launched and initialized
    function initialize() external {
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
        } //supposed to be cheaper than require
        walletsSet = true;
        lastPayDay = block.timestamp;
    }

    // ----------------

    /// @dev  amounts[0] payout to senior tranche stake
    /// @dev  amounts[1] payout to junior tranche stake
    /// @dev  amounts[2] payout to ZVE stakies
    /// @dev  amounts[3] payout to ZVE vesties
    /// @dev  amounts[4] payout to retained earnings
    function yieldTrancheus() internal view returns (uint256[7] memory amounts) {
        // TODO: Consider modularity for haricut fees.
        uint256 _yield = IERC20(FRAX).balanceOf(address(this));
        uint256 _toZVE = (r_ZVE * _yield) / WAD;
        amounts[4] = (r_RET * _yield) / WAD; //_toRET
        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();
        amounts[5] = seniorSupp;
        amounts[6] = juniorSupp;
        _yield = _yield.zSub(amounts[4] + _toZVE);
        uint256 _seniorRate = YieldTrancheus.rateSenior(
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
        uint256 _juniorRate = YieldTrancheus.rateJunior(
            targetRatio,
            _seniorRate,
            seniorSupp,
            juniorSupp
        );
        amounts[1] = (_yield * _juniorRate) / WAD;
        amounts[0] = (_yield * _seniorRate) / WAD;
        uint256 _resid = _yield.zSub(amounts[0] + amounts[1]);
        // TODO: Identify which wallets the overage should go to, or make this modular.
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

    function forwardAssets() external {
        require(block.timestamp >= (lastPayDay + yieldTimeUnit), "ZivoeYDL:::not time yet");
        require(walletsSet, "ZivoeYDL:::must call initialize()");
        uint256[7] memory amounts = yieldTrancheus();
        lastPayDay = block.timestamp;
        avgYield = YieldTrancheus.ma(avgYield, amounts[0], retrospectionTime, numPayDays);
        avgSeniorSupply = YieldTrancheus.ma(
            avgSeniorSupply,
            amounts[5],
            retrospectionTime,
            numPayDays
        );
        avgJuniorSupply = YieldTrancheus.ma(
            avgJuniorSupply,
            amounts[6],
            retrospectionTime,
            numPayDays
        );
        ++numPayDays;
        bool _weok = true;
        _weok = _weok && IERC20(FRAX).approve(stSTT, amounts[0]);
        IZivoeRewards(stSTT).depositReward(FRAX, amounts[0]);

        _weok = _weok && IERC20(FRAX).approve(stJTT, amounts[1]);
        IZivoeRewards(stJTT).depositReward(FRAX, amounts[1]);

        _weok = _weok && IERC20(FRAX).approve(stZVE, amounts[2]);
        IZivoeRewards(stZVE).depositReward(FRAX, amounts[2]);

        _weok = _weok && IERC20(FRAX).approve(vestZVE, amounts[3]);
        IZivoeRewards(vestZVE).depositReward(FRAX, amounts[3]);

        _weok = _weok && IERC20(FRAX).transfer(RET, amounts[4]);
        require(_weok, "forwardAssets:: failure");
    }

    // ------------------------

    /// @notice gives asset to junior and senior, divided up by nominal rate(same as normal with no retrospective shortfall adjustment) for surprise rewards, 
    ///         manual interventions, and to simplify governance proposals by making use of accounting here. 
    /// @param asset - token contract address
    /// @param _payout - amount to send
    function passToTranchies(address asset, uint256 _payout) external {
        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();
        uint256 _seniorRate = YieldTrancheus.seniorRateNominal(targetRatio, seniorSupp, juniorSupp);
        uint256 _toSenior = (_payout * _seniorRate) / WAD;
        uint256 _toJunior = _payout.zSub(_toSenior);
        IERC20(asset).safeTransferFrom(msg.sender, address(this), _payout);
        bool _weok = IERC20(FRAX).approve(stSTT, _toSenior);
        IZivoeRewards(stSTT).depositReward(asset, _toSenior);
        _weok = _weok && IERC20(FRAX).approve(stJTT, _toJunior);
        IZivoeRewards(stJTT).depositReward(asset, _toJunior);
        require(_weok, "passToTranchies:: failure");
    }

    /// @notice adjust supplies for accounted for defaulted funds
    function adjustedSupplies() internal view returns (uint256 _seniorSuppA, uint256 _juniorSuppA) {
        uint256 _seniorSupp = IERC20(STT).totalSupply();
        uint256 _juniorSupp = IERC20(JTT).totalSupply();
        _juniorSuppA = _juniorSupp.zSub(defaultedFunds);
        _seniorSuppA = (_seniorSupp + _juniorSupp).zSub(defaultedFunds.zSub(_juniorSuppA));
    }

    /// @notice call when a default occurs, increments accounted-for defaulted funds by _default
    function registerDefault(uint256 _default) external onlyOwner {
        defaultedFunds += _default;
        emit DefaultRegistered(_default, defaultedFunds);
    }

    /// @notice call when a default occurs, increments accounted-for defaulted funds by _default
    function resolveDefault(uint256 _default) external onlyOwner {
        defaultedFunds -= _default;
        emit DefaultResolved(_default, defaultedFunds);
    }

    /// @notice Updates the r_ZVE variable.
    function set_r_ZVE(uint256 _r_ZVE) external onlyOwner {
        r_ZVE = _r_ZVE;
    }

    /// @notice Updates the r_ZVE_resid variable.
    function set_r_ZVE_resid(uint256 _r_ZVE_resid) external onlyOwner {
        r_ZVE_resid = _r_ZVE_resid;
    }

    /// @notice Updates the r_RET variable.
    function set_r_RET(uint256 _r_RET) external onlyOwner {
        r_RET = _r_RET;
    }

    /// @notice Updates the r_RET_resid variable.
    function set_r_RET_resid(uint256 _r_RET_resid) external onlyOwner {
        r_RET_resid = _r_RET_resid;
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
    ) external {
        IERC20(asset).safeApprove(multi, amount);
        IZivoeRewards(multi).depositReward(asset, amount);
    }
}
