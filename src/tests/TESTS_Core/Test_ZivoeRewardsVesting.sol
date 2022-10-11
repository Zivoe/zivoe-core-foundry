// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeRewardsVesting is Utility {

    function setUp() public {

        deployCore(false);

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate addReward() state changes.
    // Validate addReward() restrictions.
    // This includes:
    //  - Reward isn't already set (rewardData[_rewardsToken].rewardsDuration == 0)
    //  - Maximum of 10 rewards are set (rewardTokens.length < 10) .. TODO: Discuss with auditors @RTV what max feasible size is?

    function test_ZivoeRewardsVesting_addReward_restrictions() public {

    }

    function test_ZivoeRewardsVesting_addReward_state() public {

    }

    // Validate depositReward() state changes.
    
    function test_ZivoeRewardsVesting_depositReward_state() public {

    }

    // Validate fullWithdraw() state changes.

    function test_ZivoeRewardsVesting_fullWithdraw_state() public {

    }

    // Validate vest() state changes.
    // Validate vest() restrictions.
    // This includes:
    //  - Account must not be assigned vesting schedule (!vestingScheduleSet[account]).
    //  - Must be enough $ZVE present to vest out.
    //  - Cliff timeline must be appropriate (daysToCliff <= daysToVest).

    function test_ZivoeRewardsVesting_vest_restrictions() public {

    }

    function test_ZivoeRewardsVesting_vest_state() public {

    }

    // Validate revoke() state changes.
    // Validate revoke() restrictions.
    // This includes:
    //  - Account must be assigned vesting schedule (vestingScheduleSet[account]).
    //  - Account must be revokable (vestingScheduleSet[account]).

    function test_ZivoeRewardsVesting_revoke_restrictions() public {

    }

    function test_ZivoeRewardsVesting_revoke_state() public {

    }
    
    // Validate getRewards() state changes.
    // Validate getRewardAt() state changes.

    function test_ZivoeRewardsVesting_getRewards_state() public {

    }

    function test_ZivoeRewardsVesting_getRewardAt_state() public {

    }
    
    // Validate withdraw() state changes.
    // Validate withdraw() restrictions.
    // This includes:
    //  - Withdraw amount must be greater than 0.

    function test_ZivoeRewardsVesting_withdraw_restrictions() public {
        
    }

    function test_ZivoeRewardsVesting_withdraw_state() public {

    }

    
    
}
