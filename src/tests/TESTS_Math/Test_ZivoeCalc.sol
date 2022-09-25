pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../libraries/ZivoeCalc.sol";

contract Test_ZivoeYieldCalc_Math is Utility {
    uint256 juniorRatio = 3 * WAD;
    uint256 targetRate = (5 * WAD) / 100;

    function setUp() public {
        setUpFundedDAO();
    }

    function test_yieldTarget_0() public {
        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();
        uint256 yieldTarget1 = YieldCalc.yieldTarget(
            sSTT,
            sJTT,
            juniorRatio,
            targetRate,
            29 days //
        );
        uint256 yieldTarget = YieldCalc.yieldTarget(
            sSTT,
            sJTT,
            juniorRatio,
            targetRate,
            30 days //
        );
        assert(yieldTarget1 < yieldTarget);
        assert(yieldTarget / 30 > 0);
        withinDiff(yieldTarget1, yieldTarget, yieldTarget / 29);
        emit Debug("yieldTarget", yieldTarget);
    }

    function test_yieldTarget_1() public {
        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 yieldTarget = YieldCalc.yieldTarget(
            sSTT,
            sJTT,
            juniorRatio,
            targetRate,
            YDL.yieldTimeUnit()
        );
        uint256 _year = (365 days) / YDL.yieldTimeUnit();
        uint256 rperS = (yieldTarget * WAD) / YDL.yieldTimeUnit();
        withinDiff(
            yieldTarget * _year,
            ((sSTT + (juniorRatio * sJTT) / WAD) * targetRate) / WAD,
            (rperS * (5 days)) / WAD
        );

        emit Debug("yieldTarget for year", yieldTarget * _year);
    }

    function test_yieldTarget_3() public {
        uint256 sSTT = 6000000 * WAD;
        uint256 sJTT = 2000000 * WAD;
        uint256 yieldTarget1 = YieldCalc.yieldTarget(
            sSTT,
            sJTT,
            juniorRatio,
            targetRate,
            1 days //
        );
        uint256 yieldTarget = YieldCalc.yieldTarget(
            sSTT,
            sJTT,
            juniorRatio,
            targetRate,
            2 days //
        );
        uint256 yieldTarget3 = YieldCalc.yieldTarget(
            sSTT,
            sJTT,
            juniorRatio,
            targetRate,
            3 days //
        );
        withinDiff(yieldTarget1 + yieldTarget, yieldTarget3, yieldTarget / 10000000);
        emit Debug("yieldTarget", yieldTarget);
    }
}
