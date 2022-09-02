// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

/// @dev    YieldDisector.sol calculator for yield disection
library YieldDisector {
    uint256 constant WEI = 1 ether;
    function YieldTarget(
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 targetRatio,
        uint256 targetRate,
        uint256 retrospectionTime
    ) internal pure returns (uint256) {
        uint256 dBig = 4 * retrospectionTime;
        return (targetRate * seniorSupp + targetRatio * targetRate * juniorSupp) / dBig;
    }

    function rateSenior(
        uint256 postFeeYield,
        uint256 cumsumYield,
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 targetRatio,
        uint256 targetRate,
        uint256 retrospectionTime
    ) internal pure returns (uint256) {
        uint256 Y = YieldTarget(seniorSupp, juniorSupp, targetRatio, targetRate,retrospectionTime);
        if (Y > postFeeYield) {
            return seniorRateNominal(targetRatio, juniorSupp, seniorSupp);
        } else if (cumsumYield >= retrospectionTime * Y) {
            return Y;
        } else {
            return
                (retrospectionTime + 1) *
                Y -
                (cumsumYield / postFeeYield) *
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
    ) internal pure returns (uint256) {
        ///this is the rate or senior for underflow and when we are operating in a passthrough manner and on the residuals
        return (WEI * WEI) / (dLil(targetRatio, juniorSupp, seniorSupp));
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
        return WEI + (WEI * (targetRatio * juniorSupp)) / seniorSupp;
    }
}
