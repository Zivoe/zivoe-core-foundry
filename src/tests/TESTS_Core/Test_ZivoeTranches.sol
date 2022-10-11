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

    // Validate pushToLocker() restrictions.
    // Validate pullFromLocker() restrictions.
    // Validate pullFromLockerPartial() restrictions.
    // These include:
    //  - asset push or pull must be $ZVE.

    // Validate depositJunior() state.
    // Validate depositJunior() restrictions.
    // This includes:
    //  - asset must be whitelisted
    //  - ZVT contact must be unlocked

    // Validate depositSenior() state.
    // Validate depositSenior() restrictions.
    // This includes:
    //  - asset must be whitelisted
    //  - ZVT contact must be unlocked

    // Validate unlock() restrictions.
    // This includes:
    //  - Caller must be ITO contract.
    //  - Should only be callable once.

}