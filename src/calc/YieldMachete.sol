// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

/// @dev    YieldMachete.sol is intended to be a template for new .sol files.
library YieldMachete {
    uint256 constant ONE = 1 ether;
    uint256 constant lookbackPeriod =13; //replace this with whatever it is in global gov
    function YieldTarget(
        uint256 rateNow,
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 targetRatio,
        uint256 yieldDelta
    ) internal pure returns (uint256) {
        uint256 dBig = 4 * yieldDelta;
        return (targetRatio * seniorSupp + targetRatio * juniorSupp) / dBig;
    }

    function rateSenior(
        uint256 yieldBag,
        uint256 cumsumYield,
        uint256 yield,
        uint256 rateNow,
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 targetRatio,
        uint256 yieldDelta
    ) internal pure returns (uint256) {
        uint256 Y = YieldTarget(rateNow, seniorSupp, juniorSupp, targetRatio, yieldDelta);
        if (Y > yieldBag) {
            return ONE * (dLil(targetRatio, juniorSupp, seniorSupp) / ONE);
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

    function dLil(
        uint256 targetRatio,
        uint256 juniorSupp,
        uint256 seniorSupp
    ) internal pure returns (uint256) {
        //this is the rate when there is shortfall or we are dividing up some extra.
        //     q*m_j
        // 1 + ------
        //      m_s
        return ONE + (targetRatio * ONE * juniorSupp) / seniorSupp;
    }

    function rateJunior(
        uint256 _rateSenior,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) internal pure returns (uint256) {
        return (ONE * juniorSupp * _rateSenior) / seniorSupp;
    }
}
