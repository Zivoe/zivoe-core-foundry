// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract ZivoeTokenTest is Utility {

    function setUp() public {

        createActors();

        ZVE = new ZivoeToken(
            10000000 ether,   // 10 million supply
            18,
            'Zivoe',
            'ZVE',
            address(god)
        );
    }

    // Verify initial state of ZivoeToken.sol.

    function test_ZivoeToken_constructor() public {

        // Pre-state checks.
        assertEq(ZVE.name(), 'Zivoe');
        assertEq(ZVE.symbol(), 'ZVE');
        assertEq(ZVE.decimals(), 18);
        assertEq(ZVE.totalSupply(), 10000000 ether);
        assertEq(ZVE.balanceOf(address(god)), 10000000 ether);
    }


    // Verify transfer() restrictions.
    // Verify transfer() state changes.

    function test_ZivoeToken_transfer_restrictions() public {

        // Can't transfer to address(0).
        assert(!god.try_transferToken(address(ZVE), address(0), 100));

        // Can't transfer more than balance.
        assert(!god.try_transferToken(address(ZVE), address(1), 100000000 ether));

        // Currently CAN transfer 0 tokens.
        assert(god.try_transferToken(address(ZVE), address(1), 0));
    }

    function test_ZivoeToken_transfer_state_changes() public {

        // Pre-state check.
        uint preBal_god = ZVE.balanceOf(address(god));
        uint preBal_tom = ZVE.balanceOf(address(tom));

        // Transfer 100 tokens.
        assert(god.try_transferToken(address(ZVE), address(tom), 100));

        // Post-state check.
        uint postBal_god = ZVE.balanceOf(address(god));
        uint postBal_tom = ZVE.balanceOf(address(tom));
        assertEq(preBal_god - postBal_god, 100);
        assertEq(postBal_tom - preBal_tom, 100);
    }

    // Verify approve() state changes.
    // Verify approve() restrictions.

    function test_ZivoeToken_approve_state_changes() public {
        // Pre-state check.
        assertEq(ZVE.allowance(address(god), address(this)), 0);

        // Increase to 100 ether.
        assert(god.try_approveToken(address(ZVE), address(this), 100 ether));
        assertEq(ZVE.allowance(address(god), address(this)), 100 ether);

        // Reduce to 0.
        assert(god.try_approveToken(address(ZVE), address(this), 0));
        assertEq(ZVE.allowance(address(god), address(this)), 0);
    }

    function test_ZivoeToken_approve_restrictions() public {
        // Can't approve address(0).
        assert(!bob.try_approveToken(address(ZVE), address(0), 100 ether));
    }

    // Verify transferFrom() state changes.
    // Verify transferFrom() restrictions.

    function test_ZivoeToken_transferFrom_state_changes() public {

        // Increase allowance of this contract to 100 ether.
        assert(god.try_approveToken(address(ZVE), address(this), 100 ether));
    
        // Pre-state check.
        assertEq(ZVE.balanceOf(address(this)), 0);
        assertEq(ZVE.allowance(address(god), address(this)), 100 ether);

        // Transfer 50 $ZVE.
        ZVE.transferFrom(address(god), address(this), 50 ether);

        // Post-state check.
        assertEq(ZVE.balanceOf(address(this)), 50 ether);
        assertEq(ZVE.allowance(address(god), address(this)), 50 ether);
        
        // Transfer 50 more $ZVE.
        ZVE.transferFrom(address(god), address(this), 50 ether);

        // Post-state check.
        assertEq(ZVE.balanceOf(address(this)), 100 ether);
        assertEq(ZVE.allowance(address(god), address(this)), 0);
    }

    function test_ZivoeToken_transferFrom_restrictions() public {
        
        // Approve "bob" to transfer 100 $ZVE.
        assert(god.try_approveToken(address(ZVE), address(bob), 100 ether));

        // Can't transfer more than allowance (110 $ZVE vs. 100 $ZVE).
        assert(!bob.try_transferFromToken(address(ZVE), address(god), address(bob), 110 ether));
    }

    // Verify increaseAllowance() state changes.
    // NOTE: No restrictions on increaseAllowance().

    function test_ZivoeToken_increaseAllowance_state_changes() public {
        
        // Pre-state allowance check, for "tom" controlling "this".
        assertEq(ZVE.allowance(address(this), address(tom)), 0);

        // Increase allowance for "tom" controlling "this" by 10 ether (10 $ZVE).
        ZVE.increaseAllowance(address(tom), 10 ether);

        // Post-state check.
        assertEq(ZVE.allowance(address(this), address(tom)), 10 ether);
    }

    // Verify decreaseAllowance() state changes.
    // Verify decreaseAllowance() restrictions.
    
    function test_ZivoeToken_decreaseAllowance_state_changes() public {
        
        // Increase allowance for "god" controlling "this" by 100 ether (100 $ZVE).
        ZVE.increaseAllowance(address(god), 100 ether);

        // Post-state check.
        assertEq(ZVE.allowance(address(this), address(god)), 100 ether);

        // Decrease allowance for "god" controlling "this" by 50 ether (50 $ZVE).
        ZVE.decreaseAllowance(address(god), 50 ether);
        
        // Post-state check.
        assertEq(ZVE.allowance(address(this), address(god)), 50 ether);

        // Decrease allowance for "god" controlling "this" by 50 ether (50 $ZVE).
        ZVE.decreaseAllowance(address(god), 50 ether);

        // Post-state check.
        assertEq(ZVE.allowance(address(this), address(god)), 0);
    }
    
    function test_ZivoeToken_decreaseAllowance_restrictions() public {
        
        // Increase allowance for "bob" controlling "tom" by 100 ether (100 $ZVE).
        assert(bob.try_increaseAllowance(address(ZVE), address(tom), 100 ether));

        // Can't decreaseAllowance() more than current allowance (sub-zero / underflow).
        assert(!bob.try_decreaseAllowance(address(ZVE), address(tom), 105 ether));
    }

    // Verify burn() state changes.
    // Verify burn() restrictions.

    function test_ZivoeToken_burn_state_changes() public {
        
        // Pre-state check.
        assertEq(ZVE.totalSupply(),           10000000 ether);
        assertEq(ZVE.balanceOf(address(god)), 10000000 ether);

        // User "god" will burn 1000 $ZVE.
        assert(god.try_burn(address(ZVE), 1000 ether));

        // Post-state check.
        assertEq(ZVE.totalSupply(),           9999000 ether);
        assertEq(ZVE.balanceOf(address(god)), 9999000 ether);

    }

    function test_ZivoeToken_burn_restrictions() public {
        
        // Can't burn more than balance, "god" owns all 10,000,000 $ZVE.
        assert(!god.try_burn(address(ZVE), 10000005 ether));
    }

}
