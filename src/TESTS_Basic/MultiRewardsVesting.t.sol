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
        assertEq(address(vestZVE.stakingToken()), address(ZVE));
        assertEq(vestZVE.vestingToken(), address(ZVE));
        assertEq(vestZVE.GBL(), address(GBL));
        assertEq(vestZVE.owner(), address(GBL.ZVL()));
    }

    // Verify vest() state changes.
    // Verify vest() restrictions.

    function test_MultiRewardsVesting_vest_state_changes() public {

        // Pre-state check.



    }

    function test_MultiRewardsVesting_vest_state_restrictions() public {

    }

    // Verify convert() state changes.
    // Verify convert() restrictions.

    function test_MultiRewardsVesting_convert_state_changes() public {

    }

    function test_MultiRewardsVesting_convert_state_restrictions() public {

    }

    // Verify revoke() state changes.
    // Verify revoke() restrictions.

    function test_MultiRewardsVesting_revoke_state_changes() public {

    }

    function test_MultiRewardsVesting_revoke_state_restrictions() public {

    }

    // TODO: Test staking coins after distribution, if new staker is able
    //       to claim anything.

    // TODO: Test view function amountConvertible().

    function test_MultiRewardsVesting_amountConvertible_view() public {
        
    }
    
}
