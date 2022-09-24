// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeRewards_Scenarios is Utility {

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
        
        mint("FRAX", address(this), 100000 ether);
        IERC20(FRAX).approve(address(stZVE), 100000 ether);
        stZVE.depositReward(FRAX, 100000 ether);

        hevm.warp(block.timestamp + 0.25 days);

        emit Debug('a', stZVE.earned(address(tom), address(FRAX)));
        emit Debug('a', stZVE.earned(address(sam), address(FRAX)));
        emit Debug('a', stZVE.pendingRewards(address(tom), address(FRAX)));
        emit Debug('a', stZVE.pendingRewards(address(sam), address(FRAX)));

        hevm.warp(block.timestamp + 0.5 days);

        emit Debug('a', stZVE.earned(address(tom), address(FRAX)));
        emit Debug('a', stZVE.earned(address(sam), address(FRAX)));
        emit Debug('a', stZVE.pendingRewards(address(tom), address(FRAX)));
        emit Debug('a', stZVE.pendingRewards(address(sam), address(FRAX)));

        emit Debug('b', IERC20(FRAX).balanceOf(address(tom)));
        emit Debug('b', IERC20(FRAX).balanceOf(address(sam)));

        tom.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stZVE));
        
        emit Debug('c', IERC20(FRAX).balanceOf(address(tom)));
        emit Debug('c', IERC20(FRAX).balanceOf(address(sam)));

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
