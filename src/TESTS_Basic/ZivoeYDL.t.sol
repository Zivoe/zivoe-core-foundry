// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract ZivoeYDLTest is Utility {
    function setUp() public {
        setUpFundedDAO();
        mint("FRAX", address(tom), 10 * 1 ether);
    }

    function try_stake_tokens_Half() public {
        stakeTokensHalf();

        fundAndRepayBalloonLoan();
    }

    function try_stake_tokens_Full() public {
        stakeTokensFull();

        fundAndRepayBalloonLoan();
    }

    function try_tx() public {
        tom.transferToken(address(FRAX), address(sam), 4 ether);
    }

    function test_ZivoeYDL_passToTranchies() public {
        assert(tom.try_approveToken(address(FRAX), address(YDL), 5 ether));
        assert(tom.try_passToTranchies(address(YDL), address(FRAX), 5 ether));
    }

    function test_ZivoeYDL_make_fund_and_repay_baloon_payday() public {
        fundAndRepayBalloonLoan();
    }
}
