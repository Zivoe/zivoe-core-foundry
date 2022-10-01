// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_LiveDeployment_Scenario is Utility {

    function setUp() public {

        deployCore();

    }

    function test_LiveDeployment_init_ZivoeYDL() public {
        assert(true);
    }

}
