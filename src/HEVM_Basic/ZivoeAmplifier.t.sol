// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract ZivoeAmplifierTest is Utility {

    function setUp() public {

        createActors();

        ZVE = new ZivoeToken(
            10000000 ether,   // 10 million supply
            18,
            'Zivoe',
            'ZVE',
            address(god)
        );

        setUpFundedDAO();
        
        AMP = new ZivoeAmplifier(
            address(stZVE),
            address(VST),
            address(ZVE)
        );
        
    }

    // Verify initial state ZivoeAmplifier.sol constructor().

    function test_ZivoeAmplifier_init_state() public {
        assert(AMP.isWhitelistedAmplifier(address(stZVE)));
        assert(AMP.isWhitelistedAmplifier(address(VST)));
        assertEq(AMP.ZVE(), address(ZVE));
    }


    // Verify increaseAmplification() state changes.
    // Verify increaseAmplification() restrictions.

    function test_ZivoeAmplifier_increaseAmplification_state_changes() public {
        
        // Pre-state check.
        assertEq(AMP.amplification(address(tom)), 0);
        assertEq(AMP.dispersedAmplification(address(god), address(tom)), 0);

        // TODO: Add in scenario for vesting

        // TODO: Add in scenario for staking
        
    }

    function test_ZivoeAmplifier_increaseAmplification_restrictions() public {

        // Non-whitelisted account can't call increaseAmplification().
        assert(!bob.try_increaseAmplification(address(AMP), address(tom), 100));
    }


    // Verify decreaseAmplification() state changes.
    // Verify decreaseAmplification() restrictions.

    function test_ZivoeAmplifier_decreaseAmplification_state_changes() public {
        
        // Pre-state check.
        assertEq(AMP.amplification(address(tom)), 0);
        assertEq(AMP.dispersedAmplification(address(god), address(tom)), 0);

        // TODO: Add in scenario for staking

        // TODO: Add in scenario for vesting
        
        // Post-state check.
        assertEq(AMP.amplification(address(tom)), 0);
        assertEq(AMP.dispersedAmplification(address(god), address(tom)), 0);
    }

    function test_ZivoeAmplifier_decreaseAmplification_restrictions() public {

        // Call decreaseAmplification(), "god" deamplifies "tom" by 100.
        assert(!god.try_decreaseAmplification(address(AMP), address(tom), 100));
    }
    
}
