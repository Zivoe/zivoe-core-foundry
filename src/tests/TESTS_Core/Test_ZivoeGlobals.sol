// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeGlobals is Utility {

    function setUp() public {
        deployCore(false);
    }

    // Validate restrictions of decreaseDefaults() / increaseDefaults().
    // This includes:
    //  - _msgSender() must be a whitelisted ZivoeLocker.
    //  - Overflow / underflow checks (?).

    function test_ZivoeGlobals_decreaseDefaults() public {
        
    }
    
}
