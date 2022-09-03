// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract ZivoeYDLTest is Utility {
    function setUp() public {
        setUpFundedDAO();
        mint("FRAX", address(tom), 10 * 1 ether);

    }
    function try_tx() public{
        tom.transferToken(address(FRAX),address(sam),4 ether);
    }
    // Verify initial state ZivoeRETTest.sol constructor().
    function test_ZivoeYDL_passToTranchies() public {
        assert(tom.try_passToTranchies(address(YDL), address(FRAX), 5 ether));
    }

    function test_ZivoeYDL_make_first_payday() public {
        fundAndRepayBalloonLoan();
    }
}
