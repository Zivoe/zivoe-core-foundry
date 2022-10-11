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

    // Validate depositReward() state changes.

    // Validate fullWithdraw() state changes.
    
    // Validate stake() state changes.
    // Validate stake() restrictions.
    // This includes:
    //  - Stake amount must be greater than 0 ... 
    //     .... TODO: Experiment if 0 = tick state w/o stake functionality?

    // Validate vest() state changes.
    // Validate vest() restrictions.
    // This includes:
    //  - Account must not be assigned vesting schedule (!vestingScheduleSet[account]).
    //  - Must be enough $ZVE present to vest out.
    //  - Cliff timeline must be appropriate (daysToCliff <= daysToVest).

    // Validate revoke() state changes.
    // Validate revoke() restrictions.
    // This includes:
    //  - Account must be assigned vesting schedule (vestingScheduleSet[account]).
    //  - Account must be revokable (vestingScheduleSet[account]).
    
    // Validate getRewards() state changes.
    // Validate getRewardAt() state changes.
    
    // Validate withdraw() state changes.
    // Validate withdraw() restrictions.
    // This includes:
    //  - Withdraw amount must be greater than 0.

    
    
}
