// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

library ZMath {
    /// @notice Subtraction routine that does not revert and returns a singleton, making it cheaper and more suitable for composition and use as an attribute. It returns the closest uint to the actual answer if the answer is not in uint256. IE it gives you 0 instead of reverting. It was made to be a cheaper version of openZepelins trySub. 
    function zSub(uint256 x, uint256 y) internal pure returns (uint256) {
        unchecked {
            if (y > x) return 0;
            return (x - y);
        }
    }
}


/// @dev   YieldDisector.sol calculator for yield disection
library YieldDisector {
    using ZMath for uint256;
    uint256 constant WAD = 1 ether;
    function YieldTarget(
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 targetRatio,
        uint256 targetRate,
        uint256 retrospectionTime
    ) internal pure returns (uint256) {
        uint256 dBig = 4 * retrospectionTime;
        return (targetRate * seniorSupp)/dBig + (targetRatio * targetRate * juniorSupp) / (WAD*dBig);
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
            return seniorRateNominal(targetRatio,seniorSupp, juniorSupp);
        } else if (cumsumYield >= retrospectionTime * Y) {
            return Y;
        } else {
            return
                (((retrospectionTime + 1) *
                Y ).zSub(cumsumYield))*WAD / (postFeeYield *
                dLil(targetRatio, seniorSupp, juniorSupp));
        }
    }

    function rateJunior(
        uint256 targetRatio,
        uint256 _rateSenior,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) internal pure returns (uint256) {
        return (targetRatio * juniorSupp * _rateSenior) / (seniorSupp*WAD+1);
    }

    function seniorRateNominal(
        uint256 targetRatio,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) internal pure returns (uint256) {
        ///this is the rate or senior for underflow and when we are operating in a passthrough manner and on the residuals
        return (WAD*WAD) / (dLil(targetRatio,seniorSupp,juniorSupp)+1);
    }

    function dLil(
        uint256 targetRatio,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) internal pure returns (uint256) {
        //this is the rate when there is shortfall or we are dividing up some extra.
        //     q*m_j
        // 1 + ------
        //      m_s
        return WAD +  (targetRatio * juniorSupp) / (seniorSupp+1);
    }
}
