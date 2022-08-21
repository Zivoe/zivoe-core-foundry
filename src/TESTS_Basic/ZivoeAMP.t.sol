// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract ZivoeAMPTest is Utility {

    function setUp() public {

        setUpFundedDAO();
        
    }

    // Verify getVotes() state changes.

    function test_ZivoeAMP_delegate_getVotes_0() public {
        
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
        assertEq(ZVE.getVotes(address(tom)),        0);
        assertEq(ZVE.balanceOf(address(sam)),       1875000000000000000000000);
        assertEq(ZVE.balanceOf(address(tom)),       625000000000000000000000);

        tom.try_delegate(address(ZVE), address(tom));
        sam.try_delegate(address(ZVE), address(sam));

        assertEq(ZVE.getVotes(address(sam)),        1875000000000000000000000);
        assertEq(ZVE.getVotes(address(tom)),        625000000000000000000000);
        assertEq(ZVE.balanceOf(address(sam)),       1875000000000000000000000);
        assertEq(ZVE.balanceOf(address(tom)),       625000000000000000000000);

        sam.try_approveToken(address(ZVE), address(stZVE), 1875000000000000000000000);
        tom.try_approveToken(address(ZVE), address(stZVE), 625000000000000000000000);

        sam.try_stake(address(stZVE), 1875000000000000000000000);
        tom.try_stake(address(stZVE), 625000000000000000000000);
        sam.try_delegate(address(ZVE), address(sam));

        assertEq(ZVE.getVotes(address(sam)),        1875000000000000000000000);
        assertEq(ZVE.getVotes(address(tom)),        625000000000000000000000);
        assertEq(ZVE.balanceOf(address(sam)),       0);
        assertEq(ZVE.balanceOf(address(tom)),       0);

    }

    
}
