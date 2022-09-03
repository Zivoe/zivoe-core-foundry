// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract ZivoeYDLTest is Utility {
    function setUp() public {
        setUpFundedDAO();
        mint("FRAX", address(tom), 10 * 1 ether);
    }

    function test_stake_tokens_Half() public {
        fundAndRepayBalloonLoan();
        stakeTokensHalf();
    }

    function test_stake_tokens_Full() public {
        fundAndRepayBalloonLoan();
        stakeTokensFull();
    }

    function test_default_reg() public {
        god.try_registerDefault(address(YDL), 5 ether);
    }

    function test_ZivoeYDL_passToTranchies() public {
        tom.transferToken(address(FRAX), address(sam), 4 ether);
        assert(tom.try_approveToken(address(FRAX), address(YDL), 5 ether));
        assert(tom.try_passToTranchies(address(YDL), address(FRAX), 5 ether));
    }

    function test_ZivoeYDL_make_fund_and_repay_baloon_payday() public {
        fundAndRepayBalloonLoan();
    }
}
