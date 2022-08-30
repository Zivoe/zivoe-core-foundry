// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract ZivoeYDLTest is Utility {

    uint256 juniorSupply = 10000 ether;
    uint256 seniorSupply = 30000 ether;

    function setUp() public { 
        setUpFundedDAO();
    }

    function test_ZivoeYDL_dLilStatic_0() public {
        assert(YDL.dLilStatic(juniorSupply, seniorSupply) > (1 ether));
    }

    function test_ZivoeYDL_dLilStatic_1() public {
        withinDiff(
            YDL.dLilStatic(juniorSupply, seniorSupply),
            (2 ether),
            500000000
        );
    }

    function test_ZivoeYDL_dLilDynamic_0() public {
        assert(YDL.dLilDynamic() > (1 ether));
    }

    function test_ZivoeYDL_dLilDynamic_1() public {
        withinDiff(
            YDL.dLilDynamic(),
            (2 ether),
            500000000
        );
    }

    function test_ZivoeYDL_seniorRateNominalDynamic_0() public {
        withinDiff(
            YDL.seniorRateNominalDynamic(),
            uint256((1 ether) / uint256(2)),
            50000000000
        );
    }
}
