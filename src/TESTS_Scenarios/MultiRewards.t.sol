// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

contract MultiRewardsTest is Utility {

    function setUp() public {

        setUpFundedDAO();
        stakeTokens();

    }

    function test_stake_distributeLoanRepayments() public {


        fundAndRepayBalloonLoan();

        emit Debug('bal', IERC20(FRAX).balanceOf(address(stSTT)));
        emit Debug('bal', IERC20(FRAX).balanceOf(address(stJTT)));
        emit Debug('bal', IERC20(FRAX).balanceOf(address(stZVE)));
        emit Debug('bal', IERC20(FRAX).balanceOf(address(god)));

        tom.try_getReward(address(stJTT));
        tom.try_getReward(address(stZVE));
        sam.try_getReward(address(stSTT));
        sam.try_getReward(address(stZVE));

        hevm.warp(block.timestamp + 1000 seconds);

        
        tom.try_getReward(address(stJTT));
        tom.try_getReward(address(stZVE));
        sam.try_getReward(address(stSTT));
        sam.try_getReward(address(stZVE));

        hevm.warp(block.timestamp + 1 days);

        tom.try_getReward(address(stJTT));
        tom.try_getReward(address(stZVE));
        sam.try_getReward(address(stSTT));
        sam.try_getReward(address(stZVE));



    }

}
