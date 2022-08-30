// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract ZivoeYDLTest is Utility {

    uint256 juniorSupply = 10000 ether;
    uint256 seniorSupply = 30000 ether;

    function setUp() public { 
        setUpFundedDAO();
    }

    function test_ZivoeYDL_calc_1() public {
        assert(YDL.dLil(juniorSupply, seniorSupply) > (1 ether));
    }

    function test_ZivoeYDL_calc_2() public {
        withinDiff(
            YDL.dLil(juniorSupply, seniorSupply),
            (2 ether),
            500000000
        );
    }

    function test_ZivoeYDL_calc_senior_nominal_rate() public {
        withinDiff(
            YDL.seniorRateNominal(juniorSupply, seniorSupply),
            uint256((1 ether) / uint256(2)),
            50000000000
        );
    }
}
