// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;
///@dev specialized math functions that always return uint and never revert. using these make some of the codes shorter. trySub etc from openzeppelin would have been okay but these tryX math functions return tupples to include information about the success of the function, which would have resulted in significant waste for our purposes.
import "../libraries/ZivoeMath.sol";

library ZivoeCalc {
    function toWei(uint256 _earnings, uint8 decimals)
        internal
        pure
        returns (uint256 _convertedEarnings)
    {
        if (decimals < 18) {
            //chris:
            _convertedEarnings = _earnings * (10**(18 - decimals));
        } else if (decimals > 18) {
            _convertedEarnings = _earnings * (10**(decimals - 18));
        }
    }
}

library YieldCalc {
    using ZivoeMath for uint256;
    uint256 constant WAD = 1 ether;

    function yieldTarget(
        uint256 seniorSupp,
        uint256 juniorSupp,
        uint256 targetRatio,
        uint256 targetRate,
        uint256 retrospectionTime,
        uint256 yieldTimeUnit
    ) internal pure returns (uint256) {
        return
            (retrospectionTime *
                yieldTimeUnit *
                targetRate *
                (WAD * seniorSupp + (targetRatio * juniorSupp))).zDiv(WAD * WAD * (365 days));
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
        uint256 avgJuniorSupply,
        uint256 yieldTimeUnit
    ) internal pure returns (uint256) {
        uint256 Y = yieldTarget(
            avgSenorSupply,
            avgJuniorSupply,
            targetRatio,
            targetRate,
            retrospectionTime,
            yieldTimeUnit
        );
        if (Y > postFeeYield) {
            return rateSeniorNominal(targetRatio, seniorSupp, juniorSupp);
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

    /// @dev rate that goes ot senior when ignoring corrections for past payouts and paying the junior 3x per capita
    function rateSeniorNominal(
        uint256 targetRatio,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) internal pure returns (uint256) {
        return (WAD * WAD).zDiv(dLil(targetRatio, seniorSupp, juniorSupp));
    }

    function dLil(
        uint256 targetRatio,
        uint256 seniorSupp,
        uint256 juniorSupp
    ) internal pure returns (uint256) {
        //     q*m_j
        // 1 + ------
        //      m_s
        return WAD + (targetRatio * juniorSupp).zDiv(seniorSupp);
    }

    // avg = current average
    // newval = next value to add to average
    // N = number of time steps we are averaging over
    // t = number of time steps total that  have occurred, only used when < N
    /// @dev exponentially weighted moving average, written in float arithmatic as:
    ///                      newval - avg_n
    /// avg_{n+1} = avg_n + ----------------
    ///                         min(N,t)
    function ema(
        uint256 avg,
        uint256 newval,
        uint256 N,
        uint256 t
    ) internal pure returns (uint256 nextavg) {
        if (N < t) {
            t = N; //use the count if we are still in the first window
        }
        uint256 _diff = (WAD * (newval.zSub(avg))).zDiv(t);
        if (_diff == 0) {
            _diff = (WAD * (avg.zSub(newval))).zDiv(t);
            nextavg = ((avg * WAD).zSub(_diff)).zDiv(WAD); /// newval < avg
        } else {
            nextavg = (avg * WAD + _diff).zDiv(WAD); // if newval > avg
        }
    }
}
