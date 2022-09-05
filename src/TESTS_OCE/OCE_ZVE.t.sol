// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

import "../ZivoeOCELockers/OCE_ZVE.sol";

contract OCL_ZVE_CRV_0Test is Utility {

    OCE_ZVE OCE_ZVE_0;

    function setUp() public {

        setUpFundedDAO();

        // Initialize and whitelist OCELocker
        OCE_ZVE_0 = new OCE_ZVE(address(DAO), address(GBL));
        god.try_modifyLockerWhitelist(address(DAO), address(OCE_ZVE_0), true);

    }

    function test_OCE_ZVE_0_init() public {
        assertEq(OCE_ZVE_0.owner(),     address(DAO));
        assertEq(OCE_ZVE_0.GBL(),       address(GBL));
        assertEq(OCE_ZVE_0.nextDistribution(),     0);
        assertEq(OCE_ZVE_0.distributionsMade(),    0);

        assert(OCE_ZVE_0.canPush());
        assert(OCE_ZVE_0.canPull());
        assert(OCE_ZVE_0.canPullPartial());
    }

    // Verify pushToLocker() restrictions.
    // Verify pushToLocker() state changes.

    function test_OCE_ZVE_0_pushToLocker_restrictions() public {
        
    }

    function test_OCE_ZVE_0_pushToLocker_state_changes() public {
        
    }

    // Verify pullFromLocker() restrictions.
    // Verify pullFromLocker() state changes.

    function test_OCE_ZVE_0_pullFromLocker_restrictions() public {
        
    }

    function test_OCE_ZVE_0_pullFromLocker_state_changes() public {
        
    }

    // Verify pullFromLockerPartial() restrictions.
    // Verify pullFromLockerPartial() state changes.

    function test_OCE_ZVE_0_pullFromLockerPartial_restrictions() public {
        
    }

    function test_OCE_ZVE_0_pullFromLockerPartial_state_changes() public {
        
    }

    // Verify forwardEmissions() restrictions.
    // Verify forwardEmissions() state changes.

    function test_OCE_ZVE_0_forwardEmissions_restrictions() public {
        
    }

    function test_OCE_ZVE_0_forwardEmissions_state_changes() public {
        
    }

}
