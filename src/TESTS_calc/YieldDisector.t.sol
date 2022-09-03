// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

import "../calc/YieldDisector.sol";

contract calc_DisectorTest is Utility {
    //function setUp() public {
    //}
    uint256 targetRatio = uint256(3) * WAD;
    uint256 juniorSupply = 10000 ether;
    uint256 seniorSupply = 30000 ether;

    uint256 public cumsumYield = 1; //so it doesnt start at 0
    uint256 public numPayDays = 1; //these are 1 so that they dont cause div by 0 errors
    uint256 public yieldTimeUnit = 7 days; /// @dev The period between yield distributions.
    uint256 public retrospectionTime = 13; /// @dev The historical period to track shortfall in units of yieldTime.
    uint256 public targetYield = uint256(1 ether) / uint256(20); /// @dev The target senior yield in wei, per token.

    function test_sanity_1() public {
        assert(YieldDisector.dLil(targetRatio, seniorSupply, juniorSupply) > (1 ether));
    }

    function test_sanity_2() public {
        withinDiff(YieldDisector.dLil(targetRatio, seniorSupply, juniorSupply), (2 ether), 5000000);
    }

    function test_sanity_rateJunior2() public {
        assert(
            YieldDisector.seniorRateNominal(targetRatio,  seniorSupply, juniorSupply / 2) -
                ((1 ether) / 2) >
                5000000
        );
    }

    function test_yield_target() public {
        assert(
            (YieldDisector.YieldTarget(
                seniorSupply,
                juniorSupply,
                targetRatio,
                (1 ether) / 20,
                13
            ) > 1 ether)
        );
    }

    function test_sanity_rateJunior_2() public {
        withinDiff(
            YieldDisector.rateJunior(
                targetRatio,
                (1 ether) / 2,
                seniorSupply * WAD,
                juniorSupply * WAD
            ),
            (1 ether) / 2,
            5000000
        );
    }

    function test_sanity_rateJunior_inv() public {
        withinDiff(
            YieldDisector.rateJunior(
                targetRatio,
                (1 ether) / 2,
                juniorSupply * WAD,
                seniorSupply * WAD
            ),
            (9 ether) / 2,
            5000000
        );
    }

    function test_sanity_rateJunior() public {
        withinDiff(
            YieldDisector.rateJunior(targetRatio, (1 ether) / 2, seniorSupply, juniorSupply),
            (1 ether) / 2,
            5000000
        );
    }

    function test_sanity_senior_nominal_rate() public {
        withinDiff(
            YieldDisector.seniorRateNominal(targetRatio, seniorSupply, juniorSupply),
            uint256((1 ether) / uint256(2)),
            5000000
        );
    }
    function test_sanity_jun_sen() public{
        uint256 _yield=500 ether;
        uint256 _seniorRate = YieldDisector.seniorRateNominal(  targetRatio, seniorSupply, juniorSupply) ;
        //uint256 _toJunior    = (_yield*_juniorRate)/(1 ether);
        uint256 _toSenior   = (_yield*_seniorRate)/(1 ether);
        uint256 _toJunior   = _yield - _toSenior;
        assert(_toSenior+_toJunior==_yield);
        withinDiff(_toJunior,250 ether,1 ether/1000);
    }
function test_sanity_jun_se_0() public{
        uint256 _yield=0;
        uint256 _seniorRate = YieldDisector.seniorRateNominal(  targetRatio, seniorSupply, juniorSupply) ;
        //uint256 _toJunior    = (_yield*_juniorRate)/(1 ether);
        uint256 _toSenior   = (_yield*_seniorRate)/(1 ether);
        uint256 _toJunior   = _yield - _toSenior;
        assert(_toSenior==0);
    }
}
