// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

/// @dev    YieldMachete.sol calculator for yield disection
library YieldMachete {
    uint256 constant ONE = 1 ether; //think its more gas efficient to regexp this out so its not stored in mem will do later
    uint256 constant lookbackPeriod = 13; //replace this with whatever it is in global gov, regexp or args into where it is needed
    function YieldTarget(
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 targetRatio,
        uint256 targetRate,
        uint256 yieldDelta
    ) internal pure returns (uint256) {
        uint256 dBig = 4 * yieldDelta;
        return (targetRate * seniorSupp + targetRatio * targetRate * juniorSupp) / dBig;
    }

    function rateSenior(
        uint256 yieldBag,
        uint256 cumsumYield,
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 targetRatio,
        uint256 targetRate,
        uint256 yieldDelta
    ) internal pure returns (uint256) {
        uint256 Y = YieldTarget(seniorSupp, juniorSupp, targetRatio,targetRate, yieldDelta);
        if (Y > yieldBag) {
            return seniorRateNominal(targetRatio, juniorSupp, seniorSupp);
        } else if (cumsumYield >= lookbackPeriod * Y) {
            return Y;
        } else {
            return
                (lookbackPeriod + 1) *
                Y -
                (cumsumYield / yieldBag) *
                dLil(targetRatio, juniorSupp, seniorSupp);
        }
    }

    function rateJunior(
        uint256 targetRatio,
        uint256 _rateSenior,
        uint256 juniorSupp,
        uint256 seniorSupp
    ) internal pure returns (uint256) {
        return (targetRatio * juniorSupp * _rateSenior) / seniorSupp;
    }

    function seniorRateNominal(
        uint256 targetRatio,
        uint256 juniorSupp,
        uint256 seniorSupp
    ) internal pure returns (uint256){
        ///this is the rate or senior for underflow and when we are operating in a passthrough manner and on the residuals
        return (ONE*ONE) / (dLil(targetRatio, juniorSupp, seniorSupp));
    }
    function dLil(
        uint256 targetRatio,
        uint256 juniorSupp,
        uint256 seniorSupp
    ) internal pure returns (uint256) {
        //this is the rate when there is shortfall or we are dividing up some extra.
        //     q*m_j
        // 1 + ------
        //      m_s
        return ONE + (targetRatio * juniorSupp) / seniorSupp;
    }
}
