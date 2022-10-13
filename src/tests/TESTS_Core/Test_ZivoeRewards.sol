// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeRewards is Utility {

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

    function test_ZivoeRewards_addReward_restrictions() public {

        // Can't call if not owner(), which should be "zvl".
        assert(!bob.try_addReward(address(stZVE), FRAX, 30 days));
        assert(!bob.try_addReward(address(stSTT), FRAX, 30 days));
        assert(!bob.try_addReward(address(stJTT), FRAX, 30 days));

        // Can't call if rewardData[_rewardsToken].rewardsDuration == 0 (meaning subsequent addReward() calls).
        assert(zvl.try_addReward(address(stZVE), WETH, 30 days));
        assert(!zvl.try_addReward(address(stZVE), WETH, 20 days));

        // Can't call if more than 10 rewards have been added.
        assert(zvl.try_addReward(address(stZVE), address(4), 0)); // Note: DAI, ZVE, WETH added already.
        assert(zvl.try_addReward(address(stZVE), address(5), 0));
        assert(zvl.try_addReward(address(stZVE), address(6), 0));
        assert(zvl.try_addReward(address(stZVE), address(7), 0));
        assert(zvl.try_addReward(address(stZVE), address(8), 0));
        assert(zvl.try_addReward(address(stZVE), address(9), 0));
        assert(zvl.try_addReward(address(stZVE), address(10), 0));
        assert(!zvl.try_addReward(address(stZVE), address(11), 0));

    }

    function test_ZivoeRewards_addReward_state(uint96 random) public {

        uint256 duration = uint256(random);

        (
            uint256 rewardsDuration,
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = stZVE.rewardData(WETH);

        assertEq(rewardsDuration, 0);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);


        assert(zvl.try_addReward(address(stZVE), WETH, duration));

        // Post-state.
        assertEq(stZVE.rewardTokens(2), WETH);

        (
            rewardsDuration,
            periodFinish,
            rewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = stZVE.rewardData(WETH);

        assertEq(rewardsDuration, duration);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

    }

    // Validate depositReward() state changes.
    
    function test_ZivoeRewards_depositReward_state() public {

    }

    // Validate fullWithdraw() state changes.

    function test_ZivoeRewards_fullWithdraw_state() public {

    }
    
    // Validate stake() state changes.
    // Validate stake() restrictions.
    // This includes:
    //  - Stake amount must be greater than 0 ... 
    //     .... TODO: Experiment if 0 = tick state w/o stake functionality?

    function test_ZivoeRewards_stake_restrictions() public {

    }

    function test_ZivoeRewards_stake_state() public {

    }
    
}
