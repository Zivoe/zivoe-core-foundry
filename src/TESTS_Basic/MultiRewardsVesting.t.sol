// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract MultiRewardsVestingTest is Utility {

    function setUp() public {

        createActors();
        setUpFundedDAO();

    }

    // Utility functions.

    function createVestingSchedules() public {

        // Revokable 100k $ZVE vesting schedule.
        // 180 day cliff.
        // 1080 day vesting period.
        assert(god.try_vest(
            address(vestZVE), address(poe), 180, 1080, 100000 ether, true
        ));

        // Non-revokable 250k $ZVE vesting schedule.
        // 300 day cliff.
        // 1500 day vesting period.
        assert(god.try_vest(
            address(vestZVE), address(qcp), 300, 1500, 250000 ether, false
        ));

    }

    // Verify initial state MultiRewardsVesting.sol constructor().

    function test_MultiRewardsVesting_init_state() public {

        assertEq(vestZVE.vestingToken(), address(ZVE));
        assertEq(vestZVE.GBL(), address(GBL));
        assertEq(vestZVE.owner(), address(GBL.ZVL()));

        assertEq(address(vestZVE.stakingToken()), address(ZVE));

        // Should have 40% of $ZVE initial supply.
        assertEq(IERC20(address(ZVE)).balanceOf(address(vestZVE)), 4000000 ether);
    }

    // Verify vest() state changes.
    // Verify vest() restrictions.

    function test_MultiRewardsVesting_vest_state_changes() public {

        // Pre-state check.
        assertEq(vestZVE.totalSupply(), 0);
        assertEq(vestZVE.vestingTokenAllocated(), 0);
        assert(!vestZVE.vestingScheduleSet(address(poe)));
        assert(!vestZVE.vestingScheduleSet(address(qcp)));

        (
            uint256 startingUnix, 
            uint256 cliffUnix, 
            uint256 endingUnix, 
            uint256 totalVesting, 
            uint256 totalWithdrawn, 
            uint256 vestingPerSecond, 
            bool revokable
        ) = vestZVE.vestingScheduleOf(address(poe));

        assertEq(vestZVE.balanceOf(address(poe)), 0);
        assertEq(startingUnix, 0);
        assertEq(cliffUnix, 0);
        assertEq(endingUnix, 0);
        assertEq(totalVesting, 0);
        assertEq(totalWithdrawn, 0);
        assertEq(vestingPerSecond, 0);
        assert(!revokable);

        
        (
            startingUnix, 
            cliffUnix, 
            endingUnix, 
            totalVesting, 
            totalWithdrawn, 
            vestingPerSecond, 
            revokable
        ) = vestZVE.vestingScheduleOf(address(qcp));

        assertEq(vestZVE.balanceOf(address(qcp)), 0);
        assertEq(startingUnix, 0);
        assertEq(cliffUnix, 0);
        assertEq(endingUnix, 0);
        assertEq(totalVesting, 0);
        assertEq(totalWithdrawn, 0);
        assertEq(vestingPerSecond, 0);
        assert(!revokable);

        // Create vesting schedules.
        createVestingSchedules();

        // Post-state check.
        assertEq(vestZVE.vestingTokenAllocated(), 350000 ether);
        assertEq(vestZVE.totalSupply(), 350000 ether);
        assert(vestZVE.vestingScheduleSet(address(poe)));
        assert(vestZVE.vestingScheduleSet(address(qcp)));

        (
            startingUnix, 
            cliffUnix, 
            endingUnix, 
            totalVesting, 
            totalWithdrawn, 
            vestingPerSecond, 
            revokable
        ) = vestZVE.vestingScheduleOf(address(poe));

        // Revokable 100k $ZVE vesting schedule.
        // 180 day cliff.
        // 1080 day vesting period.
        // assert(god.try_vest(
        //     address(vestZVE), address(poe), 180, 1080, 100000 ether, true
        // ));

        assertEq(vestZVE.balanceOf(address(poe)), 100000 ether);
        assertEq(startingUnix, block.timestamp);
        assertEq(cliffUnix, block.timestamp + 180 days);
        assertEq(endingUnix, block.timestamp + 1080 days);
        assertEq(totalVesting, 100000 ether);
        assertEq(totalWithdrawn, 0);
        assertEq(vestingPerSecond, 1071673525377229);
        assert(revokable);

        
        (
            startingUnix, 
            cliffUnix, 
            endingUnix, 
            totalVesting, 
            totalWithdrawn, 
            vestingPerSecond, 
            revokable
        ) = vestZVE.vestingScheduleOf(address(qcp));

        // Non-revokable 250k $ZVE vesting schedule.
        // 300 day cliff.
        // 1500 day vesting period.
        // assert(god.try_vest(
        //     address(vestZVE), address(qcp), 300, 1500, 250000 ether, false
        // ));

        assertEq(vestZVE.balanceOf(address(qcp)), 250000 ether);
        assertEq(startingUnix, block.timestamp);
        assertEq(cliffUnix, block.timestamp + 300 days);
        assertEq(endingUnix, block.timestamp + 1500 days);
        assertEq(totalVesting, 250000 ether);
        assertEq(totalWithdrawn, 0);
        assertEq(vestingPerSecond, 1929012345679012);
        assert(!revokable);
        
    }

    function test_MultiRewardsVesting_vest_state_restrictions() public {

        // Can't vest an already vested account.

        // IERC20(vestingToken).balanceOf(address(this)) - vestingTokenAllocated >= amountToVest
        // TODO: Reconsider this accounting, revision needed

        // Can't vest if daysToCliff <= daysToVest

        // Can't vest 0 $ZVE tokens.



    }

    // Verify withdraw() state changes.
    // Verify withdraw() restrictions.

    function test_MultiRewardsVesting_withdraw_state_changes() public {

        // Pre-state check.

        // Withdraw partially vested vesting schedule.

        // Post-state check.

        // ~

        // Pre-state check.

        // Withdraw fully vested vesting scheduled.

        // Post-state check.

    }

    function test_MultiRewardsVesting_withdraw_state_restrictions() public {
        
        // Can't withdraw during cliff period.

        // Can withdraw immediately after cliff period.

        // Can't withdraw if not msg.sender == account or ZVL (?).

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
