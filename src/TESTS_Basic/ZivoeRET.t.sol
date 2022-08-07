// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract ZivoeRETTest is Utility {

    function setUp() public {

        createActors();
        setUpFundedDAO();
        fundAndRepayBalloonLoan();
        
    }

    // Verify initial state ZivoeRETTest.sol constructor().

    function test_ZivoeRET_init_state() public {
        assertEq(RET.GBL(), address(GBL));
        assertEq(RET.owner(), address(god));
    }


    // Verify pushAsset() state changes.
    // Verify pushAsset() restrictions.

    function test_ZivoeRET_pushAsset_state_changes() public {
        
    }

    function test_ZivoeRET_pushAsset_restrictions() public {

    }


    // Verify passThroughYield() state changes.
    // Verify passThroughYield() restrictions.

    function test_ZivoeRET_passThroughYield_state_changes() public {
        
    }

    function test_ZivoeRET_passThroughYield_restrictions() public {

    }
    
}
