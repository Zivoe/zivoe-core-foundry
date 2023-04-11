// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "./libraries/FloorMath.sol";

/// @notice  This contract facilitates mathematics, intended solely for the YDL.
contract ZivoeMath {

    using FloorMath for uint256;

    // ---------------------
    //    State Variables
    // ---------------------

    uint256 private constant BIPS = 10000;
    uint256 private constant WAD = 10 ** 18;
    uint256 private constant RAY = 10 ** 27;



    // ----------
    //    Math
    // ----------

    /**
        @notice     Calculates the current EMA (exponential moving average).
        @dev        M * cV + (1 - M) * bV, where our smoothing factor M = 2 / (N + 1)
        @param      bV  = The base value (typically an EMA from prior calculations).
        @param      cV  = The current value, which is factored into bV.
        @param      N   = Number of steps to average over.
        @return     eV  = EMA-based value given prior and current conditions.
    */
    function ema(uint256 bV, uint256 cV, uint256 N) public pure returns (uint256 eV) {
        uint256 M = (WAD * 2).zDiv(N + 1);
        eV = ((M * cV) + (WAD - M) * bV).zDiv(WAD);
    }

    /**
        @notice     Calculates proportion of yield attributable to junior tranche.
        @dev        (Q * eJTT * sP / BIPS).zDiv(eSTT).min(RAY - sP)
        @param      eSTT = ema-based supply of zSTT                     (units = WEI)
        @param      eJTT = ema-based supply of zJTT                     (units = WEI)
        @param      sP   = Proportion of yield attributable to seniors  (units = RAY)
        @param      Q    = senior to junior tranche target ratio        (units = BIPS)
        @return     jP   = Yield attributable to junior tranche in RAY.
        @dev        Precision of return value, jP, is in RAY (10**27).
        @dev        The return value for this equation MUST never exceed RAY (10**27).
    */
    function juniorProportion(uint256 eSTT, uint256 eJTT, uint256 sP, uint256 Q) public pure returns (uint256 jP) {
        if (sP <= RAY) { jP = (Q * eJTT * sP / BIPS).zDiv(eSTT).min(RAY - sP); }
    }

    /**
        @notice     Calculates proportion of yield distributble which is attributable to the senior tranche.
        @param      yD   = yield distributable                      (units = WEI)
        @param      yT   = ema-based yield target                   (units = WEI)
        @param      eSTT = ema-based supply of zSTT                 (units = WEI)
        @param      eJTT = ema-based supply of zJTT                 (units = WEI)
        @param      Y    = target annual yield for senior tranche   (units = BIPS)
        @param      Q    = multiple of Y                            (units = BIPS)
        @param      T    = # of days between distributions          (units = integer)
        @return     sP   = Proportion of yD attributable to senior tranche.
        @dev        Precision of return value, sP, is in RAY (10**27).
    */
    function seniorProportion(
        uint256 yD, uint256 yT, uint256 eSTT, uint256 eJTT, uint256 Y, uint256 Q, uint256 T
    ) public pure returns (uint256 sP) {
        // Shortfall of yield.
        if (yD < yT) { sP = seniorProportionShortfall(eSTT, eJTT, Q); } 
        // Excess yield and historical out-performance.
        else { sP = seniorProportionBase(yD, eSTT, Y, T); }
    }

    /**
        @notice     Calculates proportion of yield attributed to senior tranche (no extenuating circumstances).
        @dev          Y  * eSTT * T
                    ----------------- *  RAY
                        (365) * yD
        @param      yD   = yield distributable                      (units = WEI)
        @param      eSTT = ema-based supply of zSTT                 (units = WEI)
        @param      Y    = target annual yield for senior tranche   (units = BIPS)
        @param      T    = # of days between distributions          (units = integer)
        @return     sPB  = Proportion of yield attributed to senior tranche in RAY.
        @dev        Precision of return value, sRB, is in RAY (10**27).
    */
    function seniorProportionBase(uint256 yD, uint256 eSTT, uint256 Y, uint256 T) public pure returns (uint256 sPB) {
        sPB = ((RAY * Y * (eSTT) * T / BIPS) / 365).zDiv(yD).min(RAY);
    }

    /**
        @notice     Calculates proportion of yield attributable to senior tranche during historical under-performance.
        TODO        @dev EQUATION HERE
        @param      yD   = yield distributable                      (units = WEI)
        @param      yT   = yieldTarget() return parameter           (units = WEI)
        @param      yA   = emaYield                                 (units = WEI)
        @param      eSTT = ema-based supply of zSTT                 (units = WEI)
        @param      eJTT = ema-based supply of zJTT                 (units = WEI)
        @param      R    = # of distributions for retrospection     (units = integer)
        @param      Q    = multiple of Y                            (units = BIPS)
        @return     sPC  = Proportion of yD attributable to senior tranche in RAY.
        @dev        Precision of return value, sPC, is in RAY (10**27).
    */
    function seniorProportionCatchup(
        uint256 yD, uint256 yT, uint256 yA, uint256 eSTT, uint256 eJTT, uint256 R, uint256 Q
    ) public pure returns (uint256 sPC) {
        sPC = ((R + 1) * yT * RAY * WAD).zSub(R * yA * RAY * WAD).zDiv(yD * (WAD + (Q * eJTT * WAD / BIPS).zDiv(eSTT))).min(RAY);
    }

    /**
        @notice     Calculates proportion of yield attributed to senior tranche (shortfall occurence).
        @dev                     WAD
                   --------------------------------  *  RAY
                             Q * eJTT * WAD / BIPS      
                    WAD  +   ---------------------
                                     eSTT
        @param      eSTT = ema-based supply of zSTT                 (units = WEI)
        @param      eJTT = ema-based supply of zJTT                 (units = WEI)
        @param      Q    = senior to junior tranche target ratio    (units = integer)
        @return     sPS  = Proportion of yield attributed to senior tranche in RAY.
        @dev        Precision of return value, sPS, is in RAY (10**27).
    */
    function seniorProportionShortfall(uint256 eSTT, uint256 eJTT, uint256 Q) public pure returns (uint256 sPS) {
        sPS = (WAD * RAY).zDiv(WAD + (Q * eJTT * WAD / BIPS).zDiv(eSTT)).min(RAY);
    }

    /**
        @notice     Calculates amount of annual yield required to meet target rate for both tranches.
        @dev        (Y * T * (eSTT + eJTT * Q / BIPS) / BIPS) / 365
        @param      eSTT = ema-based supply of zSTT                  (units = WEI)
        @param      eJTT = ema-based supply of zJTT                  (units = WEI)
        @param      Y    = target annual yield for senior tranche   (units = BIPS)
        @param      Q    = multiple of Y                            (units = BIPS)
        @param      T    = # of days between distributions          (units = integer)
        @return     yT   = yield target for the senior and junior tranche combined.
        @dev        Precision of the return value, yT, is in WEI (10**18).
    */
    function yieldTarget(uint256 eSTT, uint256 eJTT, uint256 Y, uint256 Q, uint256 T) public pure returns (uint256 yT) {
        yT = (Y * T * (eSTT + eJTT * Q / BIPS) / BIPS) / 365;
    }

}
