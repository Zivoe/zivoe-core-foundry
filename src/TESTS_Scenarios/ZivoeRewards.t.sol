// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

contract MultiRewardsTest is Utility {

    function setUp() public {

        setUpFundedDAO();
        stakeTokensHalf();

    }

    function test_stake_distributeLoanRepayments() public {


        fundAndRepayBalloonLoan();

        emit Debug("bal", IERC20(FRAX).balanceOf(address(stSTT)));
        emit Debug("bal", IERC20(FRAX).balanceOf(address(stJTT)));
        emit Debug("bal", IERC20(FRAX).balanceOf(address(stZVE)));
        emit Debug("bal", IERC20(FRAX).balanceOf(address(god)));

        tom.try_getRewards(address(stJTT));
        tom.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stSTT));
        sam.try_getRewards(address(stZVE));

        hevm.warp(block.timestamp + 1000 seconds);

        
        tom.try_getRewards(address(stJTT));
        tom.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stSTT));
        sam.try_getRewards(address(stZVE));

        hevm.warp(block.timestamp + 1 days);

        tom.try_getRewards(address(stJTT));
        tom.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stSTT));
        sam.try_getRewards(address(stZVE));

    }

    function test_stakeZVE_linearDelayedStake_0() public {

        fundAndRepayBalloonLoan();

        hevm.warp(block.timestamp + 1 days);

        tom.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stZVE));

    }

    function test_stakeZVE_linearDelayedStake_1() public {
        
        fundAndRepayBalloonLoan();

        hevm.warp(block.timestamp + 0.5 days);

        tom.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stZVE));

        // "tom" stakes full into stZVE.
        tom.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(tom)));
        tom.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(tom)));

        hevm.warp(block.timestamp + 0.5 days);

        tom.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stZVE));

    }

    function test_stakeZVE_linearDelayedStake_2() public {
        
        fundAndRepayBalloonLoan();

        hevm.warp(block.timestamp + 0.5 days);

        tom.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stZVE));

        // "tom" unstakes stZVE via fullWithdraw(), which withdraws + simultaneously claims rewards.
        tom.try_fullWithdraw(address(stZVE));

        hevm.warp(block.timestamp + 0.5 days);

        tom.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stZVE));

    }

}
