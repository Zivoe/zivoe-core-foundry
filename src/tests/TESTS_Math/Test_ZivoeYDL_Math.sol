// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../ZivoeYDL.sol";

contract Test_ZivoeYDL_Math is Utility {
    
    function setUp() public {
        setUpFundedDAO();
    }

    function test_ZivoeYDL_Math_yieldTarget_0() public {

        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 yieldTarget = YDL.yieldTarget(
            sSTT, 
            sJTT, 
            YDL.targetAPYBIPS(), 
            YDL.targetRatioBIPS(), 
            YDL.daysBetweenDistributions()
        );

        emit Debug('yieldTarget', yieldTarget);
    }

    function test_ZivoeYDL_Math_seniorRateNominal_RAY_0() public {

        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 seniorRateNominal_RAY = YDL.seniorRateNominal_RAY(
            100000 ether,
            sSTT,
            YDL.targetAPYBIPS(),
            YDL.daysBetweenDistributions()
        );

        emit Debug('a', seniorRateNominal_RAY);

        uint256 rateJunior_RAY = YDL.rateJunior_RAY(
            sSTT,
            sJTT,
            seniorRateNominal_RAY,    // RAY precision
            YDL.targetRatioBIPS()
        );

        emit Debug('rateJunior_RAY', rateJunior_RAY);
    }

    function test_ZivoeYDL_Math_seniorRateShortfall_RAY_0() public {

        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 seniorRateShortfall_RAY = YDL.seniorRateShortfall_RAY(
            sSTT,
            sJTT,
            YDL.targetRatioBIPS()
        );

        emit Debug('seniorRateShortfall_RAY', seniorRateShortfall_RAY);

        uint256 rateJunior_RAY = YDL.rateJunior_RAY(
            sSTT,
            sJTT,
            seniorRateShortfall_RAY,    // RAY precision
            YDL.targetRatioBIPS()
        );

        emit Debug('rateJunior_RAY', rateJunior_RAY);
    }

    function test_ZivoeYDL_Math_seniorRateCatchup_RAY_0() public {

        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 seniorRateCatchup_RAY = YDL.seniorRateCatchup_RAY(
            25000 ether,
            33500 ether, // NOTE: this is "yT" ... 
            sSTT,
            sJTT,
            YDL.retrospectiveDistributions(),
            YDL.targetRatioBIPS()
        );

        emit Debug('seniorRateCatchup_RAY', seniorRateCatchup_RAY);

        uint256 rateJunior_RAY = YDL.rateJunior_RAY(
            sSTT,
            sJTT,
            seniorRateCatchup_RAY,    // RAY precision
            YDL.targetRatioBIPS()
        );

        emit Debug('rateJunior_RAY', rateJunior_RAY);
    }

    function test_ZivoeYDL_Math_rateSenior_RAY_0() public {

        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 rateSenior = YDL.rateSenior_RAY(
            100000 ether,
            sSTT,
            sJTT,
            YDL.targetAPYBIPS(),
            YDL.targetRatioBIPS(),
            YDL.daysBetweenDistributions(),
            YDL.retrospectiveDistributions()
        );

        emit Debug('rateSenior', rateSenior);

        uint256 rateJunior_RAY = YDL.rateJunior_RAY(
            sSTT,
            sJTT,
            rateSenior,    // RAY precision
            YDL.targetRatioBIPS()
        );

        emit Debug('rateJunior_RAY', rateJunior_RAY);
    }

    function test_ZivoeYDL_Math_rateJunior_RAY_0() public {

        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 rateJunior_RAY = YDL.rateJunior_RAY(
            sSTT,
            sJTT,
            326975476839237057220708446,    // RAY precision (0.3269 % => senior tranche)
            YDL.targetRatioBIPS()
        );

        emit Debug('rateJunior_RAY', rateJunior_RAY);
    }

    function test_ZivoeYDL_Math_rateJunior_RAY_1() public {

        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 rateJunior_RAY = YDL.rateJunior_RAY(
            sSTT,
            sJTT,
            0.30 * 10**27,
            YDL.targetRatioBIPS()
        );

        emit Debug('rateJunior_RAY', rateJunior_RAY);

        rateJunior_RAY = YDL.rateJunior_RAY(
            sSTT,
            sJTT,
            0.40 * 10**27,
            YDL.targetRatioBIPS()
        );

        emit Debug('rateJunior_RAY', rateJunior_RAY);

        rateJunior_RAY = YDL.rateJunior_RAY(
            sSTT,
            sJTT,
            0.50 * 10**27,
            YDL.targetRatioBIPS()
        );

        emit Debug('rateJunior_RAY', rateJunior_RAY);
    }

    // Miscellaneous tests, unrelated.

    function test_gas_1() public pure returns (bool bob) {
        bob = ((address(5) == address(0)) || (address(34343434) == address(0)));
    }

    function test_gas_2() public pure returns (bool bob) {
        bob = ((uint160(address(5))) | (uint160(address(34343434))) == 0);
    }

    function test_gas_3() public pure returns (bool bob) {
        bob = ((uint160(address(5)) == 0) || (uint160(address(34343434)) == 0));
    }

    function test_gas_4() public pure returns (bool bob) {
        bob = ((uint160(address(5)) | uint160(address(34343434))) == 0);
    }

    function test_gas_5() public pure returns (bool bob) {
        bob = ((uint160(address(5)) * uint160(address(34343434))) == 0);
    }
}
