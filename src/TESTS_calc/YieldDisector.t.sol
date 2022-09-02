// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

import "../calc/YieldDisector.sol";

contract calc_DisectorTest is Utility {
    //function setUp() public view {
    //}
    uint256 targetRatio = uint256(3) * WAD;
    uint256 juniorSupply = 10000 ether;
    uint256 seniorSupply = 30000 ether;

    uint256 public cumsumYield = 1; //so it doesnt start at 0
    uint256 public numPayDays = 1; //these are 1 so that they dont cause div by 0 errors
    uint256 public yieldTimeUnit = 7 days; /// @dev The period between yield distributions.
    uint256 public retrospectionTime = 13; /// @dev The historical period to track shortfall in units of yieldTime.
    uint256 public targetYield = uint256(1 ether) / uint256(20); /// @dev The target senior yield in wei, per token.

    function test_sanity_1() public view {
        assert(YieldDisector.dLil(targetRatio, juniorSupply, seniorSupply) > (1 ether));
    }

    function test_sanity_2() public {
        withinDiff(
            YieldDisector.dLil(targetRatio, juniorSupply, seniorSupply),
            (2 ether),
            500000000
        );
    }

    function test_sanity_rateJunior() public {
        withinDiff(
            YieldDisector.rateJunior(targetRatio, (1 ether) / 2, 1, 3),
            (1 ether) / 2,
            500000000
        );
    }

    function test_sanity_senior_nominal_rate() public {
        withinDiff(
            YieldDisector.seniorRateNominal(targetRatio, juniorSupply, seniorSupply),
            uint256((1 ether) / uint256(2)),
            50000000000
        );
    }
}
