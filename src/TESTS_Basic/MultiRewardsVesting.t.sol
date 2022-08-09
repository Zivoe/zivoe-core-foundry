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

    // Verify vest() state changes.
    // Verify vest() restrictions.

    function test_MultiRewardsVesting_vest_state_chages() public {

    }

    function test_MultiRewardsVesting_vest_state_restrictions() public {

    }

    // Verify convert() state changes.
    // Verify convert() restrictions.

    function test_MultiRewardsVesting_convert_state_chages() public {

    }

    function test_MultiRewardsVesting_convert_state_restrictions() public {

    }

    // Verify revoke() state changes.
    // Verify revoke() restrictions.

    function test_MultiRewardsVesting_revoke_state_chages() public {

    }

    function test_MultiRewardsVesting_revoke_state_restrictions() public {

    }
    
}
