// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeVotingPower is Utility {

    function setUp() public {

        deployCore(false);
        
    }

    // Verify getVotes() state changes.

    function xtest_ZivoeAMP_delegate_getVotes_0() public {
        
        // Pre-state check.
        assertEq(ZVE.getVotes(address(god)),        0);
        assertEq(ZVE.balanceOf(address(god)),       0);

        assertEq(ZVE.getVotes(address(DAO)),        0);
        assertEq(ZVE.getVotes(address(ITO)),        0);
        assertEq(ZVE.getVotes(address(vestZVE)),    0);
        assertEq(ZVE.balanceOf(address(DAO)),       12500000000000000000000000);
        assertEq(ZVE.balanceOf(address(ITO)),       0);
        assertEq(ZVE.balanceOf(address(vestZVE)),   10000000000000000000000000);

        assertEq(ZVE.getVotes(address(sam)),        0);
        assertEq(ZVE.getVotes(address(jim)),        0);
        assertEq(ZVE.balanceOf(address(sam)),       1875000000000000000000000);
        assertEq(ZVE.balanceOf(address(jim)),       625000000000000000000000);

        jim.try_delegate(address(ZVE), address(jim));
        sam.try_delegate(address(ZVE), address(sam));

        assertEq(ZVE.getVotes(address(sam)),        1875000000000000000000000);
        assertEq(ZVE.getVotes(address(jim)),        625000000000000000000000);
        assertEq(ZVE.balanceOf(address(sam)),       1875000000000000000000000);
        assertEq(ZVE.balanceOf(address(jim)),       625000000000000000000000);

        sam.try_approveToken(address(ZVE), address(stZVE), 1875000000000000000000000);
        jim.try_approveToken(address(ZVE), address(stZVE), 625000000000000000000000);

        sam.try_stake(address(stZVE), 1875000000000000000000000);
        jim.try_stake(address(stZVE), 625000000000000000000000);
        sam.try_delegate(address(ZVE), address(sam));

        assertEq(ZVE.getVotes(address(sam)),        1875000000000000000000000);
        assertEq(ZVE.getVotes(address(jim)),        625000000000000000000000);
        assertEq(ZVE.balanceOf(address(sam)),       0);
        assertEq(ZVE.balanceOf(address(jim)),       0);

        sam.try_fullWithdraw(address(stZVE));

        assertEq(ZVE.balanceOf(address(sam)),         1875000000000000000000000);
        sam.transferToken(address(ZVE), address(jim), 1000000000000000000000000);

        assertEq(ZVE.balanceOf(address(sam)),       875000000000000000000000);
        assertEq(ZVE.balanceOf(address(jim)),       1000000000000000000000000);

        assertEq(ZVE.getVotes(address(sam)),        875000000000000000000000);
        assertEq(ZVE.getVotes(address(jim)),        1625000000000000000000000);

        jim.try_fullWithdraw(address(stZVE));
        
        assertEq(ZVE.getVotes(address(sam)),        875000000000000000000000);
        assertEq(ZVE.getVotes(address(jim)),        1625000000000000000000000);
        assertEq(ZVE.balanceOf(address(jim)),       1625000000000000000000000);

    }

    function xtest_ZivoeAMP_delegate_getVotes_1() public {
        
        // Pre-state check.
        assertEq(ZVE.getVotes(address(god)),        0);
        assertEq(ZVE.balanceOf(address(god)),       0);

        assertEq(ZVE.getVotes(address(DAO)),        0);
        assertEq(ZVE.getVotes(address(ITO)),        0);
        assertEq(ZVE.getVotes(address(vestZVE)),    0);
        assertEq(ZVE.balanceOf(address(DAO)),       12500000000000000000000000);
        assertEq(ZVE.balanceOf(address(ITO)),       0);
        assertEq(ZVE.balanceOf(address(vestZVE)),   10000000000000000000000000);

        assertEq(ZVE.getVotes(address(sam)),        0);
        assertEq(ZVE.getVotes(address(jim)),        0);
        assertEq(ZVE.balanceOf(address(sam)),       1875000000000000000000000);
        assertEq(ZVE.balanceOf(address(jim)),       625000000000000000000000);

        sam.try_approveToken(address(ZVE), address(stZVE), 1875000000000000000000000);
        jim.try_approveToken(address(ZVE), address(stZVE), 625000000000000000000000);

        sam.try_stake(address(stZVE), 1875000000000000000000000);
        jim.try_stake(address(stZVE), 625000000000000000000000);

        assertEq(ZVE.getVotes(address(sam)),        0);
        assertEq(ZVE.getVotes(address(jim)),        0);
        assertEq(ZVE.balanceOf(address(sam)),       0);
        assertEq(ZVE.balanceOf(address(jim)),       0);

        // Test delegation post-stake.

        jim.try_delegate(address(ZVE), address(jim));
        sam.try_delegate(address(ZVE), address(sam));

        assertEq(ZVE.getVotes(address(sam)),        1875000000000000000000000);
        assertEq(ZVE.getVotes(address(jim)),        625000000000000000000000);
        assertEq(ZVE.balanceOf(address(sam)),       0);
        assertEq(ZVE.balanceOf(address(jim)),       0);

        sam.try_fullWithdraw(address(stZVE));
        jim.try_fullWithdraw(address(stZVE));
        jim.try_delegate(address(ZVE), address(jim));
        sam.try_delegate(address(ZVE), address(sam));

        assertEq(ZVE.getVotes(address(sam)),        1875000000000000000000000);
        assertEq(ZVE.getVotes(address(jim)),        625000000000000000000000);
        assertEq(ZVE.balanceOf(address(sam)),       1875000000000000000000000);
        assertEq(ZVE.balanceOf(address(jim)),       625000000000000000000000);
        
        sam.try_approveToken(address(ZVE), address(stZVE), 1875000000000000000000000);
        jim.try_approveToken(address(ZVE), address(stZVE), 625000000000000000000000);
        sam.try_stake(address(stZVE), 1875000000000000000000000);
        jim.try_stake(address(stZVE), 625000000000000000000000);
        sam.try_fullWithdraw(address(stZVE));
        jim.try_fullWithdraw(address(stZVE));
        sam.try_approveToken(address(ZVE), address(stZVE), 1875000000000000000000000);
        jim.try_approveToken(address(ZVE), address(stZVE), 625000000000000000000000);
        sam.try_stake(address(stZVE), 1875000000000000000000000);
        jim.try_stake(address(stZVE), 625000000000000000000000);
        sam.try_fullWithdraw(address(stZVE));
        jim.try_fullWithdraw(address(stZVE));
        sam.try_approveToken(address(ZVE), address(stZVE), 1875000000000000000000000);
        jim.try_approveToken(address(ZVE), address(stZVE), 625000000000000000000000);
        sam.try_stake(address(stZVE), 1875000000000000000000000);
        jim.try_stake(address(stZVE), 625000000000000000000000);
        sam.try_fullWithdraw(address(stZVE));
        jim.try_fullWithdraw(address(stZVE));
        
        assertEq(ZVE.getVotes(address(sam)),        1875000000000000000000000);
        assertEq(ZVE.getVotes(address(jim)),        625000000000000000000000);
        assertEq(ZVE.balanceOf(address(sam)),       1875000000000000000000000);
        assertEq(ZVE.balanceOf(address(jim)),       625000000000000000000000);
        
        sam.try_approveToken(address(ZVE), address(stZVE), 1875000000000000000000000);
        jim.try_approveToken(address(ZVE), address(stZVE), 625000000000000000000000);
        sam.try_stake(address(stZVE), 1875000000000000000000000);
        jim.try_stake(address(stZVE), 625000000000000000000000);
        sam.try_fullWithdraw(address(stZVE));
        jim.try_fullWithdraw(address(stZVE));
        sam.try_approveToken(address(ZVE), address(stZVE), 1875000000000000000000000);
        jim.try_approveToken(address(ZVE), address(stZVE), 625000000000000000000000);
        sam.try_stake(address(stZVE), 1875000000000000000000000);
        jim.try_stake(address(stZVE), 625000000000000000000000);
        sam.try_fullWithdraw(address(stZVE));
        jim.try_fullWithdraw(address(stZVE));
        sam.try_approveToken(address(ZVE), address(stZVE), 1875000000000000000000000);
        jim.try_approveToken(address(ZVE), address(stZVE), 625000000000000000000000);
        sam.try_stake(address(stZVE), 1875000000000000000000000);
        jim.try_stake(address(stZVE), 625000000000000000000000);
        
        assertEq(ZVE.getVotes(address(sam)),        1875000000000000000000000);
        assertEq(ZVE.getVotes(address(jim)),        625000000000000000000000);
        assertEq(ZVE.balanceOf(address(sam)),       0);
        assertEq(ZVE.balanceOf(address(jim)),       0);
    
    }

    
}
