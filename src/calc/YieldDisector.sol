// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

library ZMath {
    function zDiv(uint256 x, uint256 y) internal pure returns (uint256) {
        unchecked {
            if (y == 0) return 0;
            if (y > x) return 0;// revert("zDiv:: overflow");
            return (x / y);
        }
    }

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
        uint256 dBig = 4 * retrospectionTime ;
        return targetRate * (seniorSupp + (targetRatio * juniorSupp).zDiv(WAD)).zDiv(dBig*WAD);
    }

    function rateSenior(
        uint256 postFeeYield,
        uint256 cumsumYield,
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 targetRatio,
        uint256 targetRate,
        uint256 retrospectionTime,
        uint256 avgSenorSupply,
        uint256 avgJuniorSupply
    ) internal pure returns (uint256) {
        uint256 Y = YieldTarget(
            avgSenorSupply,
            avgJuniorSupply,
            targetRatio,
            targetRate,
            retrospectionTime
        );
        if (Y > postFeeYield) {
            return seniorRateNominal(targetRatio, seniorSupp, juniorSupp);
        } else if (cumsumYield >= Y) {
            return Y;
        } else {
            return
                ((((retrospectionTime + 1) * Y).zSub(retrospectionTime * cumsumYield)) * WAD).zDiv(
                    postFeeYield * dLil(targetRatio, seniorSupp, juniorSupp)
                );
        }
    }

    function rateJunior(
        uint256 targetRatio,
        uint256 _rateSenior,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) internal pure returns (uint256) {
        return (targetRatio * juniorSupp * _rateSenior).zDiv(seniorSupp * WAD);
    }

    function seniorRateNominal(
        uint256 targetRatio,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) internal pure returns (uint256) {
        ///this is the rate or senior for underflow and when we are operating in a passthrough manner and on the residuals
        return (WAD * WAD).zDiv(dLil(targetRatio, seniorSupp, juniorSupp));
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
        return WAD + (targetRatio * juniorSupp).zDiv(seniorSupp);
    }

    function ma(
        uint256 avg,
        uint256 newval,
        uint256 N,
        uint256 t
    ) internal pure returns (uint256 nextavg) {
        if (N < t) {
            t = N;
        }
        uint256 _diff = (WAD * (newval.zSub(avg))) / t;
        if (_diff == 0) {
            _diff = (WAD * (avg.zSub(newval))) / t;
            nextavg = ((avg * WAD).zSub(_diff)) / WAD;
        } else {
            nextavg = (avg * WAD + _diff) / WAD;
        }
    }
}
