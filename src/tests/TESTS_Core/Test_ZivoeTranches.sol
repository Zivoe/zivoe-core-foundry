// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeTranches is Utility {
    
    function setUp() public {

        deployCore(false);

        // Move 2.5mm ZVE from DAO to ZVT.
        assert(god.try_push(address(DAO), address(ZVT), address(ZVE), 2500000 ether));

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate pushToLocker() state, restrictions.
    // Validate pullFromLocker() state, restrictions.
    // Validate pullFromLockerPartial() state, restrictions.
    // These include:
    //  - asset push or pull must be $ZVE.

    function test_ZivoeTranches_pushToLocker_restrictions() public {
        
    }

    function test_ZivoeTranches_pushToLocker_state() public {

    }

    function test_ZivoeTranches_pullFromLocker_restrictions() public {
        
    }

    function test_ZivoeTranches_pullFromLocker_state() public {

    }

    function test_ZivoeTranches_pullFromLockerPartial_restrictions() public {
        
    }

    function test_ZivoeTranches_pullFromLockerPartial_state() public {

    }

    // Validate depositJunior() state.
    // Validate depositJunior() restrictions.
    // This includes:
    //  - asset must be whitelisted
    //  - ZVT contact must be unlocked

    function test_ZivoeTranches_depositJunior_restrictions() public {
        
    }

    function test_ZivoeTranches_depositJunior_state() public {

    }

    // Validate depositSenior() state.
    // Validate depositSenior() restrictions.
    // This includes:
    //  - asset must be whitelisted
    //  - ZVT contact must be unlocked

    function test_ZivoeTranches_depositSenior_restrictions() public {
        
    }

    function test_ZivoeTranches_depositSenior_state() public {

    }

    // Validate unlock() restrictions.
    // This includes:
    //  - Caller must be ITO contract.
    //  - Should only be callable once.

    function test_ZivoeTranches_unlock_restrictions() public {
        
    }

    function test_ZivoeTranches_unlock_state() public {

    }

}