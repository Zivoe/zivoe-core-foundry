// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeRewardsVesting is Utility {

    function setUp() public {

        deployCore(false);

        // Simulate ITO (10mm * 8 * 4), DAI/FRAX/USDC/USDT.
        simulateITO(10_000_000 ether, 10_000_000 ether, 10_000_000 * USD, 10_000_000 * USD);

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
    
    function createVesting(address loc, uint256 amt) public {
        
    }

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate addReward() state changes.
    // Validate addReward() restrictions.
    // This includes:
    //  - Reward isn't already set (rewardData[_rewardsToken].rewardsDuration == 0)
    //  - Maximum of 10 rewards are set (rewardTokens.length < 10) .. TODO: Discuss with auditors @RTV what max feasible size is?

    function test_ZivoeRewardsVesting_addReward_restrictions() public {

        // Can't call if not owner(), which should be "zvl".
        assert(!bob.try_addReward(address(vestZVE), FRAX, 30 days));
        
        // Can't call if asset == ZVE().
        assert(!zvl.try_addReward(address(vestZVE), address(ZVE), 30 days));

        // Can't call if rewardData[_rewardsToken].rewardsDuration == 0 (meaning subsequent addReward() calls).
        assert(zvl.try_addReward(address(vestZVE), WETH, 30 days));
        assert(!zvl.try_addReward(address(vestZVE), WETH, 20 days));

        // Can't call if more than 10 rewards have been added.
        assert(zvl.try_addReward(address(vestZVE), address(3), 0)); // Note: DAI, WETH added already.
        assert(zvl.try_addReward(address(vestZVE), address(4), 0));
        assert(zvl.try_addReward(address(vestZVE), address(5), 0));
        assert(zvl.try_addReward(address(vestZVE), address(6), 0));
        assert(zvl.try_addReward(address(vestZVE), address(7), 0));
        assert(zvl.try_addReward(address(vestZVE), address(8), 0));
        assert(zvl.try_addReward(address(vestZVE), address(9), 0));
        assert(zvl.try_addReward(address(vestZVE), address(10), 0));
        assert(!zvl.try_addReward(address(vestZVE), address(11), 0));

    }

    function test_ZivoeRewardsVesting_addReward_state(uint96 random) public {

        uint256 duration = uint256(random);

        // Pre-state.
        (
            uint256 rewardsDuration,
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = vestZVE.rewardData(WETH);

        assertEq(rewardsDuration, 0);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);


        assert(zvl.try_addReward(address(vestZVE), WETH, duration));

        // Post-state.
        assertEq(vestZVE.rewardTokens(1), WETH);

        (
            rewardsDuration,
            periodFinish,
            rewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = vestZVE.rewardData(WETH);

        assertEq(rewardsDuration, duration);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

    }

    // Validate depositReward() state changes.
    
    function test_ZivoeRewardsVesting_depositReward_initial_state(uint96 random) public {

        uint256 deposit = uint256(random);

        // Pre-state.
        uint256 _preDAI = IERC20(DAI).balanceOf(address(vestZVE));

        (
            uint256 rewardsDuration,
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = vestZVE.rewardData(DAI);

        assert(block.timestamp >= periodFinish);

        // depositReward().
        mint("DAI", address(bob), deposit);
        assert(bob.try_approveToken(DAI, address(vestZVE), deposit));
        assert(bob.try_depositReward(address(vestZVE), DAI, deposit));

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(vestZVE)), _preDAI + deposit);

        (
            rewardsDuration,
            periodFinish,
            rewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = vestZVE.rewardData(DAI);

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

    function test_ZivoeRewardsVesting_depositReward_subsequent_state(uint96 random) public {

        uint256 deposit = uint256(random);

        depositReward_DAI(address(vestZVE), deposit);

        hevm.warp(block.timestamp + random % 60 days); // 50% chance warp past periodFinish

        // Pre-state.
        uint256 _preDAI = IERC20(DAI).balanceOf(address(vestZVE));

        (
            uint256 rewardsDuration,
            uint256 _prePeriodFinish,
            uint256 _preRewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = vestZVE.rewardData(DAI);
        
        uint256 _postPeriodFinish;
        uint256 _postRewardRate;

        // depositReward().
        mint("DAI", address(bob), deposit);
        assert(bob.try_approveToken(DAI, address(vestZVE), deposit));
        assert(bob.try_depositReward(address(vestZVE), DAI, deposit));

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(vestZVE)), _preDAI + deposit);
        (
            rewardsDuration,
            _postPeriodFinish,
            _postRewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = vestZVE.rewardData(DAI);

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

    // Validate vest() state changes.
    // Validate vest() restrictions.
    // This includes:
    //  - Account must not be assigned vesting schedule (!vestingScheduleSet[account]).
    //  - Must be enough $ZVE present to vest out.
    //  - Cliff timeline must be appropriate (daysToCliff <= daysToVest).

    function test_ZivoeRewardsVesting_vest_restrictions() public {

        assertEq(IERC20(address(ZVE)).balanceOf(address(vestZVE)), 12_500_000 ether);

        // Can't vest more ZVE than is present.
        assert(!zvl.try_vest(address(vestZVE), address(jay), 30, 90, 12_500_000 ether + 1, false));

        // Can't vest if cliff days > vesting days.
        assert(!zvl.try_vest(address(vestZVE), address(jay), 91, 90, 100 ether, false));

        // Can't vest if amt == 0.
        assert(!zvl.try_vest(address(vestZVE), address(jay), 30, 90, 0, false));
        
        // Can't call vest if schedule already set.
        assert(zvl.try_vest(address(vestZVE), address(jay), 30, 90, 100 ether, false));
        assert(!zvl.try_vest(address(vestZVE), address(jay), 30, 90, 100 ether, false));

    }

    function test_ZivoeRewardsVesting_vest_state(uint96 random, bool choice) public {

        uint256 amt = uint256(random);

        // Pre-state.
        (
            uint256 startingUnix, 
            uint256 cliffUnix, 
            uint256 endingUnix, 
            uint256 totalVesting, 
            uint256 totalWithdrawn, 
            uint256 vestingPerSecond, 
            bool revokable
        ) = vestZVE.viewSchedule(address(jay));

        assertEq(startingUnix, 0);
        assertEq(cliffUnix, 0);
        assertEq(endingUnix, 0);
        assertEq(totalVesting, 0);
        assertEq(totalWithdrawn, 0);
        assertEq(vestingPerSecond, 0);

        assert(!revokable);

        assert(zvl.try_vest(
            address(vestZVE), 
            address(jay), 
            amt % 360 + 1, 
            (amt % 360 * 5 + 1),
            amt % 12_500_000 ether + 1, 
            choice
        ));

        // Post-state.
        (
            startingUnix, 
            cliffUnix, 
            endingUnix, 
            totalVesting, 
            totalWithdrawn, 
            vestingPerSecond, 
            revokable
        ) = vestZVE.viewSchedule(address(jay));

        assertEq(startingUnix, block.timestamp);
        assertEq(cliffUnix, block.timestamp + (amt % 360 + 1) * 1 days);
        assertEq(endingUnix, block.timestamp + (amt % 360 * 5 + 1) * 1 days);
        assertEq(totalVesting, amt % 12_500_000 ether + 1);
        assertEq(totalWithdrawn, 0);
        assertEq(vestingPerSecond, (amt % 12_500_000 ether + 1) / ((amt % 360 * 5 + 1) * 1 days));

        assert(revokable == choice);

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

    // Validate fullWithdraw() state changes.

    function test_ZivoeRewardsVesting_fullWithdraw_state() public {

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
