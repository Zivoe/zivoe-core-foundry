// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";

import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { IZivoeRewards, IZivoeRET, IZivoeGlobals } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract is modular and can facilitate distributions of assets held in escrow.
///         Distributions can be made on a preset schedule.
///         Assets can be held in escrow within this contract prior to distribution.
///         Assets can be converted to another asset prior to distribution.
///         Assets can be migrated to OCYLockers prior to distribution.
contract ZivoeYDL is Ownable {
    
    using SafeERC20 for IERC20;

    // E(t) = earnings between t-1 and t
    // This is just what's coming in (the profits, current FRAX bal).

    // P(t) = distributable earnings "payouts"
    // This is FRAX avail after the "fee"/"haricut".

    // r_dao = fraction per unit earnings allocated for DAO/treasury
    // 1/5 = 20% = "haircut fee"
    // on-chain value in basis points
    // GOVERNED (modifiable)
    // (restricted range, [1000, 6000])

    // E_dao = E(t)r_dao = payout at time t for DAO
    // the value of "haircut fee" in FRAX

    // :y = target annual yield for senior
    // in basis points
    // GOVERNED (modifiable)
    // ramifications of upper-bound = overage shrinks if uncapped

    // q = multiple of the senior yield that gives the junior yield
    // scalar
    // GOVERNED

    // r_s(t), r_j(t) are not tracked on-chain
    // = fraction of payout from time t-1 to t that go to
    // senior and junior tranche holders respectively
    
    // Y = target payout per unit time (result of above values)
    // intermediate value

    // P_s(t), P_j(t) = total payout of the junior and senior pools respectively, meet the target
    // intermediate value

    // t = time units since start, genesis of product
    // storing seconds there are (each period is nominal)

    // N = total nominal value of the fund, total supply of both tranche tokens
    // sum(zJTT.supply() + zSTT.supply())
    // avail on-chain already

    // n_s, n_j = supply of senior/junior tranche respectively
    // avail on-chain already

    // m_s, m_j = total staked supply of senior/junior tranche respectively
    // avail on-chain already

    // M = m_s, m_j = total supply that is staked (both junior+senior)
    // avail on-chain already

    // L = total asset units that have been displaced from the pool by loss
    // track this (TODO: figure out globally where to store this variable)

    // ~m_j, ~m_s = adjusted stakes accounting for reduction 
    // in staked hard assets due to loss
    // calculated/intermediate value

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;    /// @dev The ZivoeGlobals contract.

    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;

    address[] public wallets;

    bool public walletsSet;

    uint256 distributionInterval;
    uint256 nextYieldDistribution;

    
    uint256 public yieldDripPeriod   = 30 days;                      /// @dev parameter for release of yield 
    uint256 public yieldDelta        = 7 days;                       /// @dev length of one pay period for yield
    uint256 public yieldMemoryPeriod = 13 weeks;                     /// @dev retrospection period
    uint256 public targetYield       = uint256(1 ether)/uint256(20); /// @dev target yield in wei per token
    uint256 public targetRatio       = 3;                            /// @dev target junion/senior yield per token

    uint256 constant ONE = 1 ether; //think its more gas efficient to regexp this out so its not stored in mem will do later


    // -----------------
    //    Constructor
    // -----------------

    // TODO: Refactor governacne implementation.

    /// @notice Initialize the ZivoeYDL.sol contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor (
        address _GBL
    ) {
        GBL = _GBL;
    }
    


    // ---------
    // Functions
    // ---------

    // TODO: NatSpec
    function initialize() public {
        require(!walletsSet, "ZivoeYDL::initialize() walletsSet");
        require(IZivoeGlobals(GBL).stSTT() != address(0), "ZivoeYDL::initialize() IZivoeGlobals(GBL).stSTT() == address(0)");
        address[] memory _wallets = new address[](5);
        _wallets[0] = IZivoeGlobals(GBL).stSTT();
        _wallets[1] = IZivoeGlobals(GBL).stJTT();
        _wallets[2] = IZivoeGlobals(GBL).stZVE();
        _wallets[3] = IZivoeGlobals(GBL).vestZVE();
        _wallets[4] = IZivoeGlobals(GBL).RET();
        wallets = _wallets;
        nextYieldDistribution = block.timestamp + 30 days;
    }

    // TODO: NatSpec
    function forwardAssets() public {

        require(block.timestamp > nextYieldDistribution, "ZivoeYDL::forwardAssets() block.timestamp <= nextYieldDistribution");
        
        uint256[] memory amounts = getDistribution();

        for (uint256 i = 0; i < wallets.length; i++) {
            if (i == 4) {
                IERC20(FRAX).safeTransfer(wallets[i], amounts[i]);
            } 
            else {
                IERC20(FRAX).safeApprove(wallets[i], amounts[i]);
                IZivoeRewards(wallets[i]).depositReward(FRAX, amounts[i]);
            }
        }

        nextYieldDistribution = block.timestamp + 30 days;

        // FRAX => ZVE stakers ... 
        // stZVE totalSupply   ... 100,000
        // vestZVE totalSupply ...  50,000

        // 30,000 FRAX ...
        // 20,000 FRAX => stZVE
        // 10,000 FRAX => vestZVE
    }

    /// @notice Returns an average amount for all wallets.
    function getDistribution() public view returns(uint256[] memory amounts) {
        amounts = new uint256[](wallets.length);
        for (uint256 i = 0; i < wallets.length; i++) {
            amounts[i] = IERC20(FRAX).balanceOf(address(this)) / wallets.length;
        }
    }

    /// @notice Updates the yieldMemoryPeriod variable.
    function setYieldMemoryPeriod(uint256 _yieldMemoryPeriod) external onlyOwner {
        yieldMemoryPeriod = _yieldMemoryPeriod;
    }

    /// @notice Updates the yieldDripPeriod variable.
    function setYieldDripPeriod(uint256 _yieldDripPeriod) external onlyOwner {
        yieldDripPeriod = _yieldDripPeriod;
    }

    /// @notice Updates the yieldDelta variable.
    function setYieldDelta(uint256 _yieldDelta) external onlyOwner {
        yieldDelta = _yieldDelta;
    }

    /// @notice Updates the targetYield variable.
    function setTargetYield(uint256 _targetYield) external onlyOwner {
        targetYield = _targetYield;
    }

    /// @notice Updates the targetRatio variable.
    function setTargetRatio(uint256 _targetRatio) external onlyOwner {
        targetRatio = _targetRatio;
    }

    function yieldTarget(
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 targetRate
    ) public view returns (uint256) {
        return targetRate * (seniorSupp + targetRatio * juniorSupp) / (4 * yieldMemoryPeriod);
    }

    function rateSenior(
        uint256 postFeeYield,
        uint256 cumsumYield,
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 targetRate
    ) public view returns (uint256) {

        uint256 Y = yieldTarget(seniorSupp, juniorSupp, targetRate);

        if (Y > postFeeYield) {
            return seniorRateNominal(juniorSupp, seniorSupp);
        } else if (cumsumYield >= yieldMemoryPeriod * Y) {
            return Y;
        } else {
            return (yieldMemoryPeriod + 1) * Y - cumsumYield / postFeeYield * dLil(juniorSupp, seniorSupp);
        }
    }

    function rateJunior(
        uint256 _rateSenior,
        uint256 juniorSupp,
        uint256 seniorSupp
    ) public view returns (uint256) {
        return targetRatio * _rateSenior * juniorSupp / seniorSupp;
    }

    function seniorRateNominal(
        uint256 juniorSupp,
        uint256 seniorSupp
    ) public view returns (uint256) {
        ///this is the rate or senior for underflow and when we are operating in a passthrough manner and on the residuals
        return ONE * ONE / dLil(juniorSupp, seniorSupp);
    }

    function dLil(
        uint256 juniorSupp,
        uint256 seniorSupp
    ) public view returns (uint256) {
        //this is the rate when there is shortfall or we are dividing up some extra.
        //     q*m_j
        // 1 + ------
        //      m_s
        return ONE + ONE * targetRatio * juniorSupp / seniorSupp;
    }

}
