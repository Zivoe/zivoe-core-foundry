// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeRewards is Utility {

    function setUp() public {

        deployCore(false);

        // Simulate ITO (10mm * 8 * 4), DAI/FRAX/USDC/USDT.
        simulateITO(10_000_000 ether, 10_000_000 ether, 10_000_000 * USD, 10_000_000 * USD);

        claimITO_and_approveTokens_and_stakeTokens(false);

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

        // Pre-state.
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

    function test_ZivoeRewards_depositReward_subsequent_state(uint96 random, bool preStake) public {

        uint256 deposit = uint256(random);

        // stake().
        if (preStake) {
            stakeTokens(); // 50% chance to have someone stake prior here
        }

        // depositReward().
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

        assertEq(rewardPerTokenStored, 0);

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
        assertEq(rewardPerTokenStored, stZVE.rewardPerToken(address(DAI)));

    }
    
    // Validate stake() state changes.
    // Validate stake() restrictions.
    // This includes:
    //  - Stake amount must be greater than 0.

    function test_ZivoeRewards_stake_restrictions() public {

        // Can't stake a 0 amount.
        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        assert(!sam.try_stake(address(stZVE), 0));

    }

    function test_ZivoeRewards_stake_initial_state(uint96 random) public {

        uint256 deposit = uint256(random) % (ZVE.balanceOf(address(sam)) - 1) + 1;

        // Pre-state.
        uint256 _preSupply = stZVE.totalSupply();
        uint256 _preBal_stZVE_sam = stZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_sam = ZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_stZVE = ZVE.balanceOf(address(stZVE));

        assertEq(_preSupply, 0);
        assertEq(_preBal_stZVE_sam, 0);
        assertGt(_preBal_ZVE_sam, 0);
        assertEq(_preBal_ZVE_stZVE, 0);

        assertEq(stZVE.viewRewards(address(sam), DAI), 0);
        assertEq(stZVE.viewUserRewardPerTokenPaid(address(sam), DAI), 0);

        // stake().
        assert(sam.try_approveToken(address(ZVE), address(stZVE), deposit));
        assert(sam.try_stake(address(stZVE), deposit));

        // Post-state.
        assertEq(stZVE.totalSupply(), _preSupply + deposit);
        assertEq(stZVE.balanceOf(address(sam)), _preBal_stZVE_sam + deposit);
        assertEq(ZVE.balanceOf(address(sam)), _preBal_ZVE_sam - deposit);
        assertEq(ZVE.balanceOf(address(stZVE)), _preBal_ZVE_stZVE + deposit);

        assertEq(stZVE.viewRewards(address(sam), DAI), 0);
        assertEq(stZVE.viewUserRewardPerTokenPaid(address(sam), DAI), 0);

    }

    function test_ZivoeRewards_stake_subsequent_state(uint96 random, bool preStake, bool preDeposit) public {

        // stake(), 50% chance for sam to pre-stake 50% of his ZVE.
        if (preStake) {
            assert(sam.try_approveToken(address(ZVE), address(stZVE), ZVE.balanceOf(address(sam)) / 2));
            assert(sam.try_stake(address(stZVE), ZVE.balanceOf(address(sam)) / 2));
        }

        // depositReward(), 50% chance to deposit a reward.
        if (preDeposit) {
            depositReward_DAI(address(stZVE), uint256(random));
        }

        hevm.warp(block.timestamp + random % 60 days); // 50% chance to warp past rewardsDuration (30 days).

        uint256 deposit = uint256(random) % (ZVE.balanceOf(address(sam)) - 1) + 1;

        // Pre-state.
        uint256 _preSupply = stZVE.totalSupply();
        uint256 _preBal_stZVE_sam = stZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_sam = ZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_stZVE = ZVE.balanceOf(address(stZVE));

        preStake ? assertGt(_preSupply, 0) : assertEq(_preSupply, 0);
        preStake ? assertGt(_preBal_stZVE_sam, 0) : assertEq(_preBal_stZVE_sam, 0);
        preStake ? assertGt(_preBal_ZVE_stZVE, 0) : assertEq(_preBal_ZVE_stZVE, 0);
        assertGt(_preBal_ZVE_sam, 0);

        assertEq(stZVE.viewRewards(address(sam), DAI), 0);
        assertEq(stZVE.viewUserRewardPerTokenPaid(address(sam), DAI), 0);

        // stake().
        assert(sam.try_approveToken(address(ZVE), address(stZVE), deposit));
        assert(sam.try_stake(address(stZVE), deposit));

        // Post-state.
        (,,,, uint256 rewardPerTokenStored) = stZVE.rewardData(DAI);

        assertEq(stZVE.totalSupply(), _preSupply + deposit);
        assertEq(stZVE.balanceOf(address(sam)), _preBal_stZVE_sam + deposit);
        assertEq(ZVE.balanceOf(address(sam)), _preBal_ZVE_sam - deposit);
        assertEq(ZVE.balanceOf(address(stZVE)), _preBal_ZVE_stZVE + deposit);

        assertEq(stZVE.viewRewards(address(sam), DAI), stZVE.earned(address(sam), DAI));
        assertEq(stZVE.viewUserRewardPerTokenPaid(address(sam), DAI), rewardPerTokenStored);

    }

    // Validate withdraw() state changes.
    // Validate withdraw() restrictions.
    // This includes:
    //  - amount > 0

    function test_ZivoeRewards_withdraw_restrictions() public {

        stakeTokens();

        // Can't withdraw if amount == 0.
        assert(!sam.try_withdraw(address(stZVE), 0));

    }

    function test_ZivoeRewards_withdraw_state(uint96 random) public {

        stakeTokens();

        uint256 unstake = uint256(random) % (stZVE.balanceOf(address(sam)) - 1) + 1;

        // Pre-state.
        uint256 _preSupply = stZVE.totalSupply();
        uint256 _preBal_stZVE_sam = stZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_sam = ZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_stZVE = ZVE.balanceOf(address(stZVE));

        assertGt(_preSupply, 0);
        assertGt(_preBal_stZVE_sam, 0);
        assertEq(_preBal_ZVE_sam, 0);
        assertGt(_preBal_ZVE_stZVE, 0);

        // withdraw().
        assert(sam.try_withdraw(address(stZVE), unstake));

        // Post-state.
        assertEq(stZVE.totalSupply(), _preSupply - unstake);
        assertEq(stZVE.balanceOf(address(sam)), _preBal_stZVE_sam - unstake);
        assertEq(ZVE.balanceOf(address(sam)), _preBal_ZVE_sam + unstake);
        assertEq(ZVE.balanceOf(address(stZVE)), _preBal_ZVE_stZVE - unstake);

    }

    // Validate getRewardAt() state changes.

    function test_ZivoeRewards_getRewardAt_state(uint96 random) public {
        
        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        // stake().
        // depositReward().
        stakeTokens();
        depositReward_DAI(address(stZVE), deposit);

        uint256 _depositTime = block.timestamp;

        hevm.warp(block.timestamp + random % 60 days + 1 seconds); // 50% chance to go past periodFinish.

        // Pre-state.
        uint256 _preDAI_sam = IERC20(DAI).balanceOf(address(sam));
        
        {
            uint256 _preEarned = stZVE.viewRewards(address(sam), DAI);
            uint256 _preURPTP = stZVE.viewUserRewardPerTokenPaid(address(sam), DAI);
            assertEq(_preEarned, 0);
            assertEq(_preURPTP, 0);
        }

        (
            ,
            uint256 _prePeriodFinish,
            uint256 _preRewardRate,
            uint256 _preLastUpdateTime,
            uint256 _preRewardPerTokenStored
        ) = stZVE.rewardData(DAI);
        
        // uint256 _postPeriodFinish;
        // uint256 _postRewardRate;
        uint256 _postLastUpdateTime;
        uint256 _postRewardPerTokenStored;
        
        assertGt(IERC20(DAI).balanceOf(address(stZVE)), 0);
        
        // getRewardAt().
        assert(sam.try_getRewardAt(address(stZVE), 0));

        // Post-state.
        assertGt(IERC20(DAI).balanceOf(address(sam)), _preDAI_sam);

        (
            ,
            ,
            ,
            _postLastUpdateTime,
            _postRewardPerTokenStored
        ) = stZVE.rewardData(DAI);
        
        assertEq(_postRewardPerTokenStored, stZVE.rewardPerToken(DAI));
        assertEq(_postLastUpdateTime, stZVE.lastTimeRewardApplicable(DAI));

        assertEq(stZVE.viewUserRewardPerTokenPaid(address(sam), DAI), _postRewardPerTokenStored);
        assertEq(stZVE.viewRewards(address(sam), DAI), 0);
        assertEq(IERC20(DAI).balanceOf(address(sam)), _postRewardPerTokenStored * stZVE.balanceOf(address(sam)) / 10**18);

    }

    // Validate getRewards() works.
    // Validate fullWithdraw() works.
    // Note: These simply call other tested functions.

    function test_ZivoeRewards_fullWithdraw_works(uint96 random) public {

        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        // stake().
        // depositReward().
        stakeTokens();
        depositReward_DAI(address(stZVE), deposit);

        uint256 _depositTime = block.timestamp;

        hevm.warp(block.timestamp + random % 60 days + 1 seconds); // 50% chance to go past periodFinish.

        // getRewards().
        assert(sam.try_fullWithdraw(address(stZVE)));

    }

    function test_ZivoeRewards_getRewards_works(uint96 random) public {

        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        // stake().
        // depositReward().
        stakeTokens();
        depositReward_DAI(address(stZVE), deposit);

        uint256 _depositTime = block.timestamp;

        hevm.warp(block.timestamp + random % 60 days + 1 seconds); // 50% chance to go past periodFinish.

        // getRewards().
        assert(sam.try_getRewards(address(stZVE)));

    }
    
}
