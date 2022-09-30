// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeYDL is Utility {
    
    function setUp() public {
        setUpFundedDAO();
    }

    function test_ZivoeYDL_distribution() public {

        fundAndRepayBalloonLoan_FRAX();

    }

    function test_ZivoeYDL_distribution_BIG() public {

        fundAndRepayBalloonLoan_BIG_BACKDOOR_FRAX();

    }

}
