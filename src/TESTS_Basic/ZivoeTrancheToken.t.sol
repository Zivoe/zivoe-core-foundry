// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

import "../ZivoeTrancheToken.sol";

contract ZivoeTrancheTokenTest is Utility {
    
    ZivoeTrancheToken ZTT;

    function setUp() public {

        createActors();

        ZTT = new ZivoeTrancheToken(
            "ZivoeGenericTrancheToken",
            "zGTT"
        );

        ZTT.transferOwnership(address(god));
    }

    // Verify initial state of TrancheToken.sol.

    function test_ZivoeTrancheToken_constructor() public {

        // Pre-state checks.
        assertEq(ZTT.name(), "ZivoeGenericTrancheToken");
        assertEq(ZTT.symbol(), "zGTT");
        assertEq(ZTT.decimals(), 18);
        assertEq(ZTT.totalSupply(), 0 ether);
        assertEq(ZTT.owner(), address(god));
        assertEq(ZTT.balanceOf(address(god)), 0 ether);
    }


    // Verify transfer() restrictions.
    // Verify transfer() state changes.

    function test_ZivoeTrancheToken_transfer_restrictions() public {

        // Can't transfer to address(0).
        assert(!bob.try_transferToken(address(ZTT), address(0), 100));

        // Can't transfer more than balance.
        assert(!bob.try_transferToken(address(ZTT), address(1), 100000000 ether));

        // Currently CAN transfer 0 tokens.
        assert(bob.try_transferToken(address(ZTT), address(1), 0));
    }

    function test_ZivoeTrancheToken_transfer_state_changes() public {

        // User "god" will add themselves as isMinter(), then mint 1000 $zTT for "god" (himself).
        assert(god.try_changeMinterRole(address(ZTT), address(god), true));
        assert(god.try_mint(address(ZTT), address(god), 1000 ether));

        // Pre-state values.
        uint preBal_god = ZTT.balanceOf(address(god));
        uint preBal_tom = ZTT.balanceOf(address(tom));

        // Transfer 100 $zTT.
        assert(god.try_transferToken(address(ZTT), address(tom), 100));

        // Post-state check.
        uint postBal_god = ZTT.balanceOf(address(god));
        uint postBal_tom = ZTT.balanceOf(address(tom));
        assertEq(preBal_god - postBal_god, 100);
        assertEq(postBal_tom - preBal_tom, 100);
    }

    // Verify approve() state changes.
    // Verify approve() restrictions.

    function test_ZivoeTrancheToken_approve_state_changes() public {

        // Pre-state check.
        assertEq(ZTT.allowance(address(god), address(this)), 0);

        // Increase to 100 ether.
        assert(god.try_approveToken(address(ZTT), address(this), 100 ether));
        assertEq(ZTT.allowance(address(god), address(this)), 100 ether);

        // Reduce to 0.
        assert(god.try_approveToken(address(ZTT), address(this), 0));
        assertEq(ZTT.allowance(address(god), address(this)), 0);
    }

    function test_ZivoeTrancheToken_approve_restrictions() public {
        // Can't approve address(0).
        assert(!bob.try_approveToken(address(ZTT), address(0), 100 ether));
    }

    // Verify transferFrom() state changes.
    // Verify transferFrom() restrictions.

    function test_ZivoeTrancheToken_transferFrom_state_changes() public {

        // User "god" will add themselves as isMinter(), then mint 1000 $zTT for "god" (himself).
        assert(god.try_changeMinterRole(address(ZTT), address(god), true));
        assert(god.try_mint(address(ZTT), address(god), 1000 ether));

        // Increase allowance of "this" contract to 100 ether.
        assert(god.try_approveToken(address(ZTT), address(this), 100 ether));
    
        // Pre-state check.
        assertEq(ZTT.balanceOf(address(this)), 0);
        assertEq(ZTT.allowance(address(god), address(this)), 100 ether);

        // Transfer 50 $zTT from "god" to "this" contract.
        ZTT.transferFrom(address(god), address(this), 50 ether);

        // Post-state check.
        assertEq(ZTT.balanceOf(address(this)), 50 ether);
        assertEq(ZTT.allowance(address(god), address(this)), 50 ether);
        
        // Transfer 50 more $zTT from "god" to "this" contract.
        ZTT.transferFrom(address(god), address(this), 50 ether);

        // Post-state check.
        assertEq(ZTT.balanceOf(address(this)), 100 ether);
        assertEq(ZTT.allowance(address(god), address(this)), 0);
    }

    function test_ZivoeTrancheToken_transferFrom_restrictions() public {
        // User "god" will add themselves as isMinter(), then mint 100 $zTT for "god" (himself).
        assert(god.try_changeMinterRole(address(ZTT), address(god), true));
        assert(god.try_mint(address(ZTT), address(god), 100 ether));

        // Approve god to transfer 100 $zTT.
        assert(ZTT.approve(address(god), 100 ether));

        // Can't transfer more than allowance (110 $zTT vs. 100 $zTT).
        assert(!god.try_transferFromToken(address(ZTT), address(this), address(god), 110 ether));
    }

    // Verify changeMinterRole() state changes.
    // Verify changeMinterRole() restrictions.

    function test_ZivoeTrancheToken_changeMinterRole_state_changes() public {
        
        // Pre-state check, "this" contract is not a minter.
        assert(!ZTT.isMinter(address(this)));

        // Add "this" contract as a minter.
        assert(god.try_changeMinterRole(address(ZTT), address(this), true));

        // Post-state check, "this" contract is a minter.
        assert(ZTT.isMinter(address(this)));

        // Remove "this" contract as a minter.
        assert(god.try_changeMinterRole(address(ZTT), address(this), false));

        // Post-state check, "this" contract is no longer a minter.
        assert(!ZTT.isMinter(address(this)));
    }

    function test_ZivoeTrancheToken_changeMinterRole_restrictions() public {

        // User "bob" is unable to call changeMinterRole(), not ZivoeTrancheToken.sol _owner.
        assert(!bob.try_changeMinterRole(address(ZTT), address(this), false));
    }

    // Verify mint() state changes.
    // Verify mint() restrictions.

    function test_ZivoeTrancheToken_mint_state_changes() public {
        
        // Add "tom" as a minter.
        assert(god.try_changeMinterRole(address(ZTT), address(tom), true));

        // Pre-state checks.
        assert(ZTT.isMinter(address(tom)));
        assertEq(ZTT.totalSupply(), 0 ether);
        assertEq(ZTT.balanceOf(address(tom)), 0);

        // User "tom" mints 10 $zTT tokens for himself.
        assert(tom.try_mint(address(ZTT), address(tom), 10 ether));

        // Post-state checks.
        assertEq(ZTT.totalSupply(), 10 ether);
        assertEq(ZTT.balanceOf(address(tom)), 10 ether);

        // Pre-state check for user "len".
        assertEq(ZTT.balanceOf(address(len)), 0);

        // User "tom" mints 10 $zTT tokens for user "len".
        assert(tom.try_mint(address(ZTT), address(len), 10 ether));

        // Post-state checks.
        assertEq(ZTT.totalSupply(), 20 ether);
        assertEq(ZTT.balanceOf(address(len)), 10 ether);
    }

    function test_ZivoeTrancheToken_mint_restrictions() public {

        // User "bob" is not a minter, and is unable to call mint().
        assert(!ZTT.isMinter(address(bob)));
        assert(!bob.try_mint(address(ZTT), address(bob), 10 ether));

        // User "bob" is added as a minter.
        assert(god.try_changeMinterRole(address(ZTT), address(bob), true));

        // User "bob" is unable to call mint() if account == address(0).
        assert(ZTT.isMinter(address(bob)));
        assert(!bob.try_mint(address(ZTT), address(0), 10 ether));
    }

    // Verify increaseAllowance() state changes.
    // NOTE: No restrictions on increaseAllowance().

    function test_ZivoeTrancheToken_increaseAllowance_state_changes() public {
        
        // Pre-state allowance check, for "tom" controlling "this".
        assertEq(ZTT.allowance(address(this), address(tom)), 0);

        // Increase allowance for "tom" controlling "this" by 10 ether (10 $zTT).
        ZTT.increaseAllowance(address(tom), 10 ether);

        // Post-state check.
        assertEq(ZTT.allowance(address(this), address(tom)), 10 ether);
    }

    // Verify decreaseAllowance() state changes.
    // Verify decreaseAllowance() restrictions.
    
    function test_ZivoeTrancheToken_decreaseAllowance_state_changes() public {
        
        // Increase allowance for "god" controlling "this" by 100 ether (100 $zTT).
        ZTT.increaseAllowance(address(god), 100 ether);

        // Post-state check.
        assertEq(ZTT.allowance(address(this), address(god)), 100 ether);

        // Decrease allowance for "god" controlling "this" by 50 ether (50 $zTT).
        ZTT.decreaseAllowance(address(god), 50 ether);
        
        // Post-state check.
        assertEq(ZTT.allowance(address(this), address(god)), 50 ether);

        // Decrease allowance for "god" controlling "this" by 50 ether (50 $zTT).
        ZTT.decreaseAllowance(address(god), 50 ether);

        // Post-state check.
        assertEq(ZTT.allowance(address(this), address(god)), 0);
    }
    
    function test_ZivoeTrancheToken_decreaseAllowance_restrictions() public {
        
        // Increase allowance for "bob" controlling "tom" by 100 ether (100 $zTT).
        assert(bob.try_increaseAllowance(address(ZTT), address(tom), 100 ether));

        // Can't decreaseAllowance() more than current allowance (sub-zero / underflow).
        assert(!bob.try_decreaseAllowance(address(ZTT), address(tom), 105 ether));
    }

    // Verify burn() state changes.
    // Verify burn() restrictions.

    function test_ZivoeTrancheToken_burn_state_changes() public {
        
        // User "god" will add themselves as isMinter(), then mint 1000 $zTT.
        assert(god.try_changeMinterRole(address(ZTT), address(god), true));
        assert(god.try_mint(address(ZTT), address(god), 1000 ether));

        // Pre-state check.
        assertEq(ZTT.totalSupply(),           1000 ether);
        assertEq(ZTT.balanceOf(address(god)), 1000 ether);

        // User "god" will burn 500 $zTT.
        assert(god.try_burn(address(ZTT), 500 ether));

        // Post-state check.
        assertEq(ZTT.totalSupply(),           500 ether);
        assertEq(ZTT.balanceOf(address(god)), 500 ether);

    }

    function test_ZivoeTrancheToken_burn_restrictions() public {
        
        // Can't burn more than balance, "bob" owns 0 $zTT, as there is no initial supply.
        assert(!bob.try_burn(address(ZTT), 10 ether));
    }

}
