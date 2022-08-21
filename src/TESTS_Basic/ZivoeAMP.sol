// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

import "../ZivoeAMP.sol";

contract ZivoeAMPTest is Utility {

    ZivoeAMP AMP;

    function setUp() public {

        createActors();
        setUpFundedDAO();
        
        AMP = new ZivoeAMP(
            address(GBL)
        );
        
    }

    // Verify initial state ZivoeAMP.sol constructor().

    function test_ZivoeAMP_init_state() public {
        assert(AMP.isWhitelistedAmplifier(address(stZVE)));
        assertEq(AMP.GBL(), address(GBL));
    }


    // Verify increaseAmplification() state changes.
    // Verify increaseAmplification() restrictions.

    function test_ZivoeAMP_increaseAmplification_state_changes() public {
        
        // Pre-state check.
        assertEq(AMP.amplification(address(tom)), 0);
        assertEq(AMP.dispersedAmplification(address(god), address(tom)), 0);

        // TODO: Add in scenario for staking
        
        // Post-state check.
        assertEq(AMP.amplification(address(tom)), 0);
        assertEq(AMP.dispersedAmplification(address(god), address(tom)), 0);
        
    }

    function test_ZivoeAMP_increaseAmplification_restrictions() public {

        // Non-whitelisted account can't call increaseAmplification().
        assert(!bob.try_increaseAmplification(address(AMP), address(tom), 100));
    }


    // Verify decreaseAmplification() state changes.
    // Verify decreaseAmplification() restrictions.

    function test_ZivoeAMP_decreaseAmplification_state_changes() public {
        
        // Pre-state check.
        assertEq(AMP.amplification(address(tom)), 0);
        assertEq(AMP.dispersedAmplification(address(god), address(tom)), 0);

        // TODO: Add in scenario for staking
        
        // Post-state check.
        assertEq(AMP.amplification(address(tom)), 0);
        assertEq(AMP.dispersedAmplification(address(god), address(tom)), 0);
    }

    function test_ZivoeAMP_decreaseAmplification_restrictions() public {

        // Call decreaseAmplification(), "god" deamplifies "tom" by 100.
        assert(!god.try_decreaseAmplification(address(AMP), address(tom), 100));
    }
    
}
