// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

    // TODO: Rename functions

contract ZivoeYDLTest is Utility {
    function setUp() public {
        setUpFundedDAO();
        mint("FRAX", address(tom), 10000000 * 1 ether);
    }

    function test_stake_tokens_Half() public {
        stakeTokensHalf();
        fundAndRepayBalloonLoan();
    }

    function test_stake_tokens_Full() public {
        stakeTokensFull();
        fundAndRepayBalloonLoan();
    }

    function test_stake_rewards_reg() public {
        stakeTokensHalf();
        uint256 bal1 = IERC20(FRAX).balanceOf(address(stSTT));

        assert(tom.try_approveToken(address(FRAX), address(YDL), 60000 ether));
        tom.try_passToTranchies(address(YDL), address(FRAX), 50000 ether);
        uint256 bal2 = IERC20(FRAX).balanceOf(address(stSTT));
        assert(bal2 > bal1);
    }

    function test_default_reg_response() public {
        stakeTokensHalf();
        assert(tom.try_approveToken(address(FRAX), address(YDL), 60000 ether));
        uint256 Jbal1 = IERC20(address(zJTT)).balanceOf(address(stJTT));
        uint256 bal1j = IERC20(address(FRAX)).balanceOf(address(stJTT));
        tom.try_passToTranchies(address(YDL), address(FRAX), 5000 ether);
        uint256 bal2j = IERC20(address(FRAX)).balanceOf(address(stJTT));

        assert(bal1j < bal2j);
        assert(god.try_registerDefault(address(YDL), Jbal1));
        tom.try_passToTranchies(address(YDL), address(FRAX), 50000 ether);
        uint256 bal2a = IERC20(address(FRAX)).balanceOf(address(stJTT));
        assert(bal2a < bal2j + 50000);
    }

    function test_default_reg_response_half() public {
        stakeTokensFull();
        assert(tom.try_approveToken(address(FRAX), address(YDL), 60000 ether));
        uint256 Jbal1 = IERC20(address(zJTT)).balanceOf(address(stJTT));
        uint256 bal1j = IERC20(address(FRAX)).balanceOf(address(stJTT));
        tom.try_passToTranchies(address(YDL), address(FRAX), 5000 ether);
        uint256 bal2j = IERC20(address(FRAX)).balanceOf(address(stJTT));

        assert(bal1j < bal2j);
        assert(god.try_registerDefault(address(YDL), Jbal1 / 2));
        tom.try_passToTranchies(address(YDL), address(FRAX), 5000 ether);
        uint256 bal2a = IERC20(address(FRAX)).balanceOf(address(stJTT));
        assert(bal2a < bal2j * 2);
    }

    function test_stakes_TokensHalf() public {
        assert(tom.try_approveToken(address(FRAX), address(YDL), 60000 ether));
        tom.try_passToTranchies(address(YDL), address(FRAX), 5000 ether);
        tom.try_approveToken(
            address(ZVE),
            address(stZVE),
            IERC20(address(ZVE)).balanceOf(address(tom))
        );
        tom.try_stake(address(stJTT), 1000 ether);
        uint256 bal = IERC20(address(FRAX)).balanceOf(address(stJTT));
        uint256 bal1j = IERC20(address(FRAX)).balanceOf(address(stSTT));
        withinDiff(bal + bal1j, 5000 ether, 1 ether);
    }

    function test_ZivoeYDL_make_fund_and_repay_baloon_payday() public {
        fundAndRepayBalloonLoan();
    }
}
