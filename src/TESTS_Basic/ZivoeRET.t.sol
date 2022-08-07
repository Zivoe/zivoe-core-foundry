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
        
        // Should have about 11k FRAX available (more than 10k).
        assert(IERC20(FRAX).balanceOf(address(RET)) > 10000 ether);
    }


    // Verify pushAsset() state changes.
    // Verify pushAsset() restrictions.

    function test_ZivoeRET_pushAsset_state_changes() public {
        
    }

    function test_ZivoeRET_pushAsset_restrictions() public {

        // Any user except "god" cannot call pushAsset().
        assert(!bob.try_pushAsset(address(RET), FRAX, address(bob), 10000 ether));
    }


    // Verify passThroughYield() state changes.
    // Verify passThroughYield() restrictions.

    function test_ZivoeRET_passThroughYield_state_changes() public {
        
    }

    function test_ZivoeRET_passThroughYield_restrictions() public {

        // Any user except "god" cannot call passThroughYield().
        assert(!bob.try_passThroughYield(address(RET), FRAX, 10000 ether, address(GBL.stZVE())));
    }
    
}
