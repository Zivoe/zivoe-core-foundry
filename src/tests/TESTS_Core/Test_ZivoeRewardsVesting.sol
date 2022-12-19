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
    
    function depositReward_DAI(address loc, uint256 amount) public {
        // depositReward().
        mint("DAI", address(bob), amount);
        assert(bob.try_approveToken(DAI, loc, amount));
        assert(bob.try_depositReward(loc, DAI, amount));
    }
    
    function createVesting(address loc, uint256 amount) public {
        
    }

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate addReward() state changes.
    // Validate addReward() restrictions.
    // This includes:
    //  - Reward isn't already set (rewardData[_rewardsToken].rewardsDuration == 0)
    //  - Maximum of 10 rewards are set (rewardTokens.length < 10) .. TODO: Discuss with auditors @RTV what max feasible size is?

    function test_ZivoeRewardsVesting_addReward_restrictions_owner() public {
        // Can't call if not owner(), which should be "zvl".
        hevm.startPrank(address(bob));
        hevm.expectRevert("Ownable: caller is not the owner");
        vestZVE.addReward(FRAX, 30 days);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_addReward_restrictions_ZVE() public {
        // Can't call if asset == ZVE().
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::addReward() _rewardsToken == IZivoeGlobals_RewardsVesting(GBL).ZVE()");
        vestZVE.addReward(address(ZVE), 30 days);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_addReward_restrictions_rewardsDuration0() public {
        // Can't call if rewardData[_rewardsToken].rewardsDuration == 0 (meaning subsequent addReward() calls).
        assert(zvl.try_addReward(address(vestZVE), WETH, 30 days));
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::addReward() rewardData[_rewardsToken].rewardsDuration != 0");
        vestZVE.addReward(WETH, 20 days);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_addReward_restrictions_maxRewards() public {
        // Can't call if more than 10 rewards have been added.
        assert(zvl.try_addReward(address(vestZVE), WETH, 30 days));// Note: DAI added already.
        assert(zvl.try_addReward(address(vestZVE), address(3), 0));
        assert(zvl.try_addReward(address(vestZVE), address(4), 0));
        assert(zvl.try_addReward(address(vestZVE), address(5), 0));
        assert(zvl.try_addReward(address(vestZVE), address(6), 0));
        assert(zvl.try_addReward(address(vestZVE), address(7), 0));
        assert(zvl.try_addReward(address(vestZVE), address(8), 0));
        assert(zvl.try_addReward(address(vestZVE), address(9), 0));
        assert(zvl.try_addReward(address(vestZVE), address(10), 0));

        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::addReward() rewardTokens.length >= 10");
        vestZVE.addReward(address(11), 0);
        hevm.stopPrank();
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

    function test_ZivoeRewardsVesting_vest_restrictions_maxVest() public {

        assertEq(IERC20(address(ZVE)).balanceOf(address(vestZVE)), 12_500_000 ether);

        // Can't vest more ZVE than is present.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::vest() amountToVest > IERC20(vestingToken).balanceOf(address(this)) - vestingTokenAllocated");
        vestZVE.vest( address(poe), 30, 90, 12_500_000 ether + 1, false);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_vest_restrictions_maxCliff() public {

        assertEq(IERC20(address(ZVE)).balanceOf(address(vestZVE)), 12_500_000 ether);

        // Can't vest if cliff days > vesting days.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::vest() daysToCliff > daysToVest");
        vestZVE.vest(address(poe), 91, 90, 100 ether, false);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_vest_restrictions_amount0() public {

        assertEq(IERC20(address(ZVE)).balanceOf(address(vestZVE)), 12_500_000 ether);

        // Can't vest if amount == 0.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::_stake() amount == 0");
        vestZVE.vest(address(poe), 30, 90, 0, false);
        hevm.stopPrank();       
    }

    function test_ZivoeRewardsVesting_vest_restrictions_scheduleSet() public {

        assertEq(IERC20(address(ZVE)).balanceOf(address(vestZVE)), 12_500_000 ether);
        
        // Can't call vest if schedule already set.
        assert(zvl.try_vest(address(vestZVE), address(poe), 30, 90, 100 ether, false));
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::vest() vestingScheduleSet[account]");
        vestZVE.vest(address(poe), 30, 90, 100 ether, false);
        hevm.stopPrank();  
    }

    function test_ZivoeRewardsVesting_vest_state(uint96 random, bool choice) public {

        uint256 amount = uint256(random);

        // Pre-state.
        (
            uint256 startingUnix, 
            uint256 cliffUnix, 
            uint256 endingUnix, 
            uint256 totalVesting, 
            uint256 totalWithdrawn, 
            uint256 vestingPerSecond, 
            bool revokable
        ) = vestZVE.viewSchedule(address(tia));

        assertEq(vestZVE.vestingTokenAllocated(), 0);

        assertEq(startingUnix, 0);
        assertEq(cliffUnix, 0);
        assertEq(endingUnix, 0);
        assertEq(totalVesting, 0);
        assertEq(totalWithdrawn, 0);
        assertEq(vestingPerSecond, 0);
        assertEq(vestZVE.balanceOf(address(tia)), 0);
        assertEq(vestZVE.totalSupply(), 0);

        assert(!vestZVE.vestingScheduleSet(address(tia)));
        assert(!revokable);

        assert(zvl.try_vest(
            address(vestZVE), 
            address(tia), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_500_000 ether + 1, 
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
        ) = vestZVE.viewSchedule(address(tia));

        assertEq(vestZVE.vestingTokenAllocated(), amount % 12_500_000 ether + 1);

        assertEq(startingUnix, block.timestamp);
        assertEq(cliffUnix, block.timestamp + (amount % 360 + 1) * 1 days);
        assertEq(endingUnix, block.timestamp + (amount % 360 * 5 + 1) * 1 days);
        assertEq(totalVesting, amount % 12_500_000 ether + 1);
        assertEq(totalWithdrawn, 0);
        assertEq(vestingPerSecond, (amount % 12_500_000 ether + 1) / ((amount % 360 * 5 + 1) * 1 days));
        assertEq(vestZVE.balanceOf(address(tia)), amount % 12_500_000 ether + 1);
        assertEq(vestZVE.totalSupply(), amount % 12_500_000 ether + 1);

        assert(vestZVE.vestingScheduleSet(address(tia)));
        assert(revokable == choice);

    }

    // Experiment with amountWithdrawable() view endpoint here.

    function test_ZivoeRewardsVesting_amountWithdrawable_experiment() public {
        
        // Example:
        //  - 1,000,000 $ZVE vesting.
        //  - 30 day cliff period.
        //  - 120 day vesting period (of which 30 days is the cliff).
        assert(zvl.try_vest(
            address(vestZVE), 
            address(qcp), 
            30, 
            120,
            1_000_000 ether, 
            false
        ));

        // amountWithdrawble() should be 0 prior to cliff period ending.
        hevm.warp(block.timestamp + 30 days - 1 seconds);
        assertEq(vestZVE.amountWithdrawable(address(qcp)), 0);

        // amountWithdrawble() should be (approx) 25% with cliff period ending.
        hevm.warp(block.timestamp + 1 seconds);
        withinDiff(vestZVE.amountWithdrawable(address(qcp)), 250_000 ether, 1 ether);

        // amountWithdrawble() should be (approx) 50% when 60 days through.
        hevm.warp(block.timestamp + 30 days);
        withinDiff(vestZVE.amountWithdrawable(address(qcp)), 500_000 ether, 1 ether);

        // amountWithdrawble() should be 0 after claiming!
        assert(qcp.try_fullWithdraw(address(vestZVE)));
        assertEq(vestZVE.amountWithdrawable(address(qcp)), 0);

        // amountWithdrawble() should be (approx) 50% at end of period (already withdraw 50% above).
        hevm.warp(block.timestamp + 60 days + 1 seconds);
        withinDiff(vestZVE.amountWithdrawable(address(qcp)), 500_000 ether, 1 ether);

        // Should be able to withdraw everything, and have full vesting amount (of $ZVE) in posssession.
        assert(qcp.try_fullWithdraw(address(vestZVE)));
        assertEq(ZVE.balanceOf(address(qcp)), 1_000_000 ether);
    }


    // Validate revoke() state changes.
    // Validate revoke() restrictions.
    // This includes:
    //  - Account must be assigned vesting schedule (vestingScheduleSet[account]).
    //  - Account must be revokable (vestingScheduleSet[account]).

    function test_ZivoeRewardsVesting_revoke_restrictions_noVestingSchedule() public {
        // Can't revoke an account that doesn't exist.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::revoke() !vestingScheduleSet[account]");
        vestZVE.revoke(address(moe));
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_revoke_restrictions_notRevokable(uint96 random) public {
        uint256 amount = uint256(random);

        // vest().
        assert(zvl.try_vest(
            address(vestZVE), 
            address(moe), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_500_000 ether + 1, 
            false
        ));

        // Can't revoke an account that doesn't exist.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::revoke() !vestingScheduleOf[account].revokable");
        vestZVE.revoke(address(moe));
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_revoke_state(uint96 random) public {

        uint256 amount = uint256(random);

        assert(zvl.try_vest(
            address(vestZVE), 
            address(moe), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_500_000 ether + 1, 
            true
        ));

        // Pre-state.
        (
            uint256 startingUnix, 
            uint256 cliffUnix, 
            uint256 endingUnix, 
            uint256 totalVesting, 
            uint256 totalWithdrawn, 
            uint256 vestingPerSecond,
        ) = vestZVE.viewSchedule(address(moe));

        assertEq(startingUnix, block.timestamp);
        assertEq(cliffUnix, block.timestamp + (amount % 360 + 1) * 1 days);
        assertEq(endingUnix, block.timestamp + (amount % 360 * 5 + 1) * 1 days);
        assertEq(totalVesting, amount % 12_500_000 ether + 1);
        assertEq(totalWithdrawn, 0);
        assertEq(vestingPerSecond, (amount % 12_500_000 ether + 1) / ((amount % 360 * 5 + 1) * 1 days));
        assertEq(vestZVE.balanceOf(address(moe)), amount % 12_500_000 ether + 1);
        assertEq(vestZVE.totalSupply(), amount % 12_500_000 ether + 1);
        assertEq(ZVE.balanceOf(address(moe)), 0);

        // warp some random amount of time from now to endingUnix.
        hevm.warp(block.timestamp + amount % (endingUnix - startingUnix));

        uint256 amountWithdrawable = vestZVE.amountWithdrawable(address(moe));

        assert(zvl.try_revoke(address(vestZVE), address(moe)));

        // Post-state.
        bool revokable;
        (
            , 
            cliffUnix, 
            endingUnix, 
            totalVesting, 
            totalWithdrawn, 
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(moe));

        assertEq(totalVesting, amountWithdrawable);
        assertEq(totalWithdrawn, amountWithdrawable);
        assertEq(cliffUnix, block.timestamp - 1);
        assertEq(endingUnix, block.timestamp);
        assertEq(vestZVE.totalSupply(), 0);
        assertEq(vestZVE.balanceOf(address(moe)), 0);
        assertEq(ZVE.balanceOf(address(moe)), amountWithdrawable);

        assert(!revokable);

    }
    
    // Validate getRewardAt() state changes.

    function test_ZivoeRewardsVesting_getRewardAt_state(uint96 random) public {

        uint256 amount = uint256(random);
        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        assert(zvl.try_vest(
            address(vestZVE), 
            address(pam), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_500_000 ether + 1, 
            true
        ));

        depositReward_DAI(address(vestZVE), deposit);

        hevm.warp(block.timestamp + random % 360 * 10 days + 1 seconds); // 50% chance to go past periodFinish.

        // Pre-state.
        uint256 _preDAI_pam = IERC20(DAI).balanceOf(address(pam));
        
        {
            uint256 _preEarned = vestZVE.viewRewards(address(pam), DAI);
            uint256 _preURPTP = vestZVE.viewUserRewardPerTokenPaid(address(pam), DAI);
            assertEq(_preEarned, 0);
            assertEq(_preURPTP, 0);
        }
        
        assertGt(IERC20(DAI).balanceOf(address(vestZVE)), 0);
        
        // getRewardAt().
        assert(pam.try_getRewardAt(address(vestZVE), 0));

        // Post-state.
        assertGt(IERC20(DAI).balanceOf(address(pam)), _preDAI_pam);

        (
            ,
            ,
            ,
            uint256 _postLastUpdateTime,
            uint256 _postRewardPerTokenStored
        ) = vestZVE.rewardData(DAI);
        
        assertEq(_postRewardPerTokenStored, vestZVE.rewardPerToken(DAI));
        assertEq(_postLastUpdateTime, vestZVE.lastTimeRewardApplicable(DAI));

        assertEq(vestZVE.viewUserRewardPerTokenPaid(address(pam), DAI), _postRewardPerTokenStored);
        assertEq(vestZVE.viewRewards(address(pam), DAI), 0);
        assertEq(IERC20(DAI).balanceOf(address(pam)), _postRewardPerTokenStored * vestZVE.balanceOf(address(pam)) / 10**18);


    }
    
    // Validate withdraw() state changes.
    // Validate withdraw() restrictions.
    // This includes:
    //  - Withdraw amount must be greater than 0.

    function test_ZivoeRewardsVesting_withdraw_restrictions_withdraw0() public {
        
        // Can't call if amountWithdrawable() == 0.
        hevm.startPrank(address(pam));
        hevm.expectRevert("ZivoeRewardsVesting::withdraw() amountWithdrawable(_msgSender()) == 0");
        vestZVE.withdraw();
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_withdraw_state(uint96 random) public {

        uint256 amount = uint256(random);
        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        assert(zvl.try_vest(
            address(vestZVE), 
            address(pam), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_499_999 ether + 1 ether, 
            true
        ));

        depositReward_DAI(address(vestZVE), deposit);

        // Give little breathing room so amountWithdrawable() != 0.
        hevm.warp(block.timestamp + (amount % 360 + 1) * 1 days + random % (5000 days));

        uint256 unstake = vestZVE.amountWithdrawable(address(pam));

        // Pre-state.
        uint256 _preSupply = vestZVE.totalSupply();
        uint256 _preBal_vestZVE_pam = vestZVE.balanceOf(address(pam));
        uint256 _preBal_ZVE_pam = ZVE.balanceOf(address(pam));
        uint256 _preBal_ZVE_vestZVE = ZVE.balanceOf(address(vestZVE));

        assertGt(_preSupply, 0);
        assertGt(_preBal_vestZVE_pam, 0);
        assertEq(_preBal_ZVE_pam, 0);
        assertGt(_preBal_ZVE_vestZVE, 0);

        // withdraw().
        assert(pam.try_withdraw(address(vestZVE)));

        // Post-state.
        assertEq(vestZVE.totalSupply(), _preSupply - unstake);
        assertEq(vestZVE.balanceOf(address(pam)), _preBal_vestZVE_pam - unstake);
        assertEq(ZVE.balanceOf(address(pam)), _preBal_ZVE_pam + unstake);
        assertEq(ZVE.balanceOf(address(vestZVE)), _preBal_ZVE_vestZVE - unstake);

    }

    // Validate fullWithdraw() works.
    // Validate getRewards() works.

    function test_ZivoeRewardsVesting_fullWithdraw_works(uint96 random) public {

        uint256 amount = uint256(random);
        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        assert(zvl.try_vest(
            address(vestZVE), 
            address(pam), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_499_999 ether + 1 ether, 
            true
        ));

        depositReward_DAI(address(vestZVE), deposit);

        // Give little breathing room so amountWithdrawable() != 0.
        hevm.warp(block.timestamp + (amount % 360 + 1) * 1 days + random % (5000 days));

        // fullWithdraw().
        assert(pam.try_fullWithdraw(address(vestZVE)));

    }

    function test_ZivoeRewardsVesting_getRewards_works(uint96 random) public {
        
        uint256 amount = uint256(random);
        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        assert(zvl.try_vest(
            address(vestZVE), 
            address(pam), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_499_999 ether + 1 ether, 
            true
        ));

        depositReward_DAI(address(vestZVE), deposit);

        // Give little breathing room so amountWithdrawable() != 0.
        hevm.warp(block.timestamp + (amount % 360 + 1) * 1 days + random % (5000 days));

        // getRewards().
        assert(pam.try_getRewards(address(vestZVE)));
    }

    
    
}
