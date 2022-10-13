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
    
    function depositReward_DAI(address loc, uint256 amt) public {
        // depositReward().
        mint("DAI", address(bob), amt);
        assert(bob.try_approveToken(DAI, loc, amt));
        assert(bob.try_depositReward(loc, DAI, amt));
    }

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
    
    function test_ZivoeRewards_depositReward_initial_state(uint96 random) public {

        uint256 deposit = uint256(random);

        // Pre-state.
        uint256 _preDAI = IERC20(DAI).balanceOf(address(stZVE));

        (
            uint256 rewardsDuration,
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = stZVE.rewardData(DAI);

        assert(block.timestamp >= periodFinish);

        // depositReward().
        mint("DAI", address(bob), deposit);
        assert(bob.try_approveToken(DAI, address(stZVE), deposit));
        assert(bob.try_depositReward(address(stZVE), DAI, deposit));

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(stZVE)), _preDAI + deposit);

        (
            rewardsDuration,
            periodFinish,
            rewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = stZVE.rewardData(DAI);

        assertEq(rewardsDuration, 30 days);
        assertEq(periodFinish, block.timestamp + rewardsDuration);
        /*
            if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
                rewardData[_rewardsToken].rewardRate = reward.div(rewardData[_rewardsToken].rewardsDuration);
            }
        */
        assertEq(rewardRate, deposit / rewardsDuration);
        assertEq(lastUpdateTime, block.timestamp);
        assertEq(rewardPerTokenStored, 0);

    }

    function test_ZivoeRewards_depositReward_subsequent_state(uint96 random) public {

        uint256 deposit = uint256(random);

        depositReward_DAI(address(stZVE), deposit);

        hevm.warp(block.timestamp + random % 60 days); // 50% chance warp past periodFinish

        // Pre-state.
        uint256 _preDAI = IERC20(DAI).balanceOf(address(stZVE));

        (
            uint256 rewardsDuration,
            uint256 _prePeriodFinish,
            uint256 _preRewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = stZVE.rewardData(DAI);
        
        uint256 _postPeriodFinish;
        uint256 _postRewardRate;

        // depositReward().
        mint("DAI", address(bob), deposit);
        assert(bob.try_approveToken(DAI, address(stZVE), deposit));
        assert(bob.try_depositReward(address(stZVE), DAI, deposit));

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(stZVE)), _preDAI + deposit);
        (
            rewardsDuration,
            _postPeriodFinish,
            _postRewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = stZVE.rewardData(DAI);

        assertEq(rewardsDuration, 30 days);
        assertEq(_postPeriodFinish, block.timestamp + rewardsDuration);
        /*
            if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
                rewardData[_rewardsToken].rewardRate = reward.div(rewardData[_rewardsToken].rewardsDuration);
            }
            else {
                uint256 remaining = rewardData[_rewardsToken].periodFinish.sub(block.timestamp);
                uint256 leftover = remaining.mul(rewardData[_rewardsToken].rewardRate);
                rewardData[_rewardsToken].rewardRate = reward.add(leftover).div(rewardData[_rewardsToken].rewardsDuration);
            }
        */
        if (block.timestamp >= _prePeriodFinish) {
            assertEq(_postRewardRate, deposit / rewardsDuration);
        }
        else {
            uint256 remaining = _prePeriodFinish - block.timestamp;
            uint256 leftover = remaining * _preRewardRate;
            assertEq(_postRewardRate, (deposit + leftover) / rewardsDuration);
        }
        assertEq(lastUpdateTime, block.timestamp);
        assertEq(rewardPerTokenStored, 0);

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
