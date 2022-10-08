// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeRewards_Scenarios is Utility {

    function setUp() public {

        deployCore(false);
        stakeTokensHalf();

    }

    function xtest_stake_distributeLoanRepayments() public {


        fundAndRepayBalloonLoan_FRAX();

        emit Debug("bal", IERC20(FRAX).balanceOf(address(stSTT)));
        emit Debug("bal", IERC20(FRAX).balanceOf(address(stJTT)));
        emit Debug("bal", IERC20(FRAX).balanceOf(address(stZVE)));
        emit Debug("bal", IERC20(FRAX).balanceOf(address(god)));

        jim.try_getRewards(address(stJTT));
        jim.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stSTT));
        sam.try_getRewards(address(stZVE));

        hevm.warp(block.timestamp + 1000 seconds);

        
        jim.try_getRewards(address(stJTT));
        jim.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stSTT));
        sam.try_getRewards(address(stZVE));

        hevm.warp(block.timestamp + 1 days);

        jim.try_getRewards(address(stJTT));
        jim.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stSTT));
        sam.try_getRewards(address(stZVE));

    }

    function xtest_stakeZVE_linearDelayedStake_0() public {

        fundAndRepayBalloonLoan_FRAX();
        
        mint("FRAX", address(this), 100000 ether);
        IERC20(FRAX).approve(address(stZVE), 100000 ether);
        stZVE.depositReward(FRAX, 100000 ether);

        hevm.warp(block.timestamp + 0.25 days);

        emit Debug('a', stZVE.earned(address(jim), address(FRAX)));
        emit Debug('a', stZVE.earned(address(sam), address(FRAX)));

        hevm.warp(block.timestamp + 0.5 days);

        emit Debug('a', stZVE.earned(address(jim), address(FRAX)));
        emit Debug('a', stZVE.earned(address(sam), address(FRAX)));

        emit Debug('b', IERC20(FRAX).balanceOf(address(jim)));
        emit Debug('b', IERC20(FRAX).balanceOf(address(sam)));

        jim.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stZVE));
        
        emit Debug('c', IERC20(FRAX).balanceOf(address(jim)));
        emit Debug('c', IERC20(FRAX).balanceOf(address(sam)));

    }

    function xtest_stakeZVE_linearDelayedStake_1() public {
        
        fundAndRepayBalloonLoan_FRAX();

        hevm.warp(block.timestamp + 0.5 days);

        jim.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stZVE));

        // "jim" stakes full into stZVE.
        jim.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim)));
        jim.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim)));

        hevm.warp(block.timestamp + 0.5 days);

        jim.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stZVE));

    }

    function xtest_stakeZVE_linearDelayedStake_2() public {
        
        fundAndRepayBalloonLoan_FRAX();

        hevm.warp(block.timestamp + 0.5 days);

        jim.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stZVE));

        // "jim" unstakes stZVE via fullWithdraw(), which withdraws + simultaneously claims rewards.
        jim.try_fullWithdraw(address(stZVE));

        hevm.warp(block.timestamp + 0.5 days);

        jim.try_getRewards(address(stZVE));
        sam.try_getRewards(address(stZVE));

    }

}
