// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

import "../calc/YieldTrancheuse.sol";

contract calc_TrancheuseTest is Utility {
    //function setUp() public view{
    //}
    uint256 targetRatio = uint256(3) * WAD;
    uint256 juniorSupply = 10000 ether;
    uint256 seniorSupply = 30000 ether;

    uint256 public cumsumYield = 1; //so it doesnt start at 0
    uint256 public numPayDays = 1; //these are 1 so that they dont cause div by 0 errors
    uint256 public yieldTimeUnit = 7 days; /// @dev The period between yield distributions.
    uint256 public retrospectionTime = 13; /// @dev The historical period to track shortfall in units of yieldTime.
    uint256 public targetYield = uint256(5 ether) / uint256(100); /// @dev The target senior yield in wei, per token.

    function test_sanity_1() public view {
        assert(YieldTrancheuse.dLil(targetRatio, seniorSupply, juniorSupply) > WAD);
    }

    function test_sanity_2() public {
        withinDiff(YieldTrancheuse.dLil(targetRatio, seniorSupply, juniorSupply), (2 ether), 5000000);
    }

    function test_sanity_rateJunior2() public view {
        assert(
            YieldTrancheuse.seniorRateNominal(targetRatio, seniorSupply, juniorSupply / 2) -
                (WAD / 2) >
                5000000
        );
    }

    function test_yield_target() public view {
        assert(
            (YieldTrancheuse.yieldTarget(seniorSupply, juniorSupply, targetRatio, WAD / 20, 13) >
                1 ether)
        );
    }

    function test_sanity_rateJunior_2() public {
        withinDiff(
            YieldTrancheuse.rateJunior(targetRatio, WAD / 2, seniorSupply * WAD, juniorSupply * WAD),
            WAD / 2,
            5000000
        );
    }

    function test_sanity_rateJunior_inv() public {
        withinDiff(
            YieldTrancheuse.rateJunior(targetRatio, WAD / 2, juniorSupply * WAD, seniorSupply * WAD),
            (9 ether) / 2,
            5000000
        );
    }

    function test_sanity_rateJunior() public {
        withinDiff(
            YieldTrancheuse.rateJunior(targetRatio, WAD / 2, seniorSupply, juniorSupply),
            WAD / 2,
            5000000
        );
    }

    function test_sanity_senior_nominal_rate() public {
        withinDiff(
            YieldTrancheuse.seniorRateNominal(targetRatio, seniorSupply, juniorSupply),
            uint256(WAD / uint256(2)),
            5000000
        );
    }

    function test_sanity_jun_sen() public {
        uint256 _yield = 500 ether;
        uint256 _seniorRate = YieldTrancheuse.seniorRateNominal(
            targetRatio,
            seniorSupply,
            juniorSupply
        );
        //uint256 _toJunior    = (_yield*_juniorRate)/WAD;
        uint256 _toSenior = (_yield * _seniorRate) / WAD;
        uint256 _toJunior = _yield - _toSenior;
        assert(_toSenior + _toJunior == _yield);
        withinDiff(_toJunior, 250 ether, 1 ether / 1000);
    }

    function test_sanity_junior_vs_nominal_residual() public {
        uint256 _yield = 0;
        uint256 _seniorRate = YieldTrancheuse.seniorRateNominal(
            targetRatio,
            seniorSupply,
            juniorSupply
        );
        //uint256 _toJunior    = (_yield*_juniorRate)/WAD;
        uint256 _toSenior = (_yield * _seniorRate) / WAD;
        uint256 _toJunior = _yield - _toSenior;

        uint256 toJunior =
            (_yield *
                YieldTrancheuse.rateJunior(targetRatio, _seniorRate, seniorSupply, juniorSupply)) /
            WAD;
        withinDiff(_toJunior, toJunior, 50000);
    }

    function test_sanity_jun_se_0() public view {
        uint256 _yield = 0;
        uint256 _seniorRate = YieldTrancheuse.seniorRateNominal(
            targetRatio,
            seniorSupply,
            juniorSupply
        );
        //uint256 _toJunior    = (_yield*_juniorRate)/WAD;
        uint256 _toSenior = (_yield * _seniorRate) / WAD;
        assert(_toSenior == 0);
    }

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
