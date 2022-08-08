// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract MultiRewardsVestingTest is Utility {

    function setUp() public {

        createActors();
        setUpFundedDAO();
        fundAndRepayBalloonLoan();

    }

    // Verify initial state MultiRewardsVesting.sol constructor().

    function test_MultiRewardsVesting_init_state() public {
        
    }
    
}
