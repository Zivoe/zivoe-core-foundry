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

        // Vest a few tokens.

        // Post-state check.
        
    }

    function test_MultiRewardsVesting_vest_state_restrictions() public {

        // Can't vest an already vested account.

        // IERC20(vestingToken).balanceOf(address(this)) - vestingTokenAllocated >= amountToVest
        // TODO: Reconsider this accounting, revision needed

        // Can't vest if daysToCliff <= daysToVest

        // Can't vest 0 $ZVE tokens.



    }

    // Verify convert() state changes.
    // Verify convert() restrictions.

    function test_MultiRewardsVesting_convert_state_changes() public {

        // Pre-state check.

        // Convert partially vested vesting schedule.

        // Post-state check.

        // ~

        // Pre-state check.

        // Convert fully vested vesting scheduled.

        // Post-state check.

    }

    function test_MultiRewardsVesting_convert_state_restrictions() public {
        
        // Can't convert during cliff period.

        // Can convert immediately after cliff period.

        // Can't convert if not msg.sender == account or ZVL (?).

    }

    // Verify revoke() state changes.
    // Verify revoke() restrictions.

    function test_MultiRewardsVesting_revoke_state_changes() public {

        // Pre-state check.

        // Revoke a vesting schedule.

        // Post-state check.

    }

    function test_MultiRewardsVesting_revoke_state_restrictions() public {

        // Only ZVL can call revoke().

        // Can't revoke a non-revokable vesting schedule.

        // Can't revoke a schedule that isn't set.

    }

    // TODO: Test staking coins after distribution, if new staker is able
    //       to claim anything.

    // TODO: Test view function amountConvertible().

    function test_MultiRewardsVesting_amountConvertible_view() public {

    }
    
}
