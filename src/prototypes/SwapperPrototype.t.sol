// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

// import "../Swapper/SwapperPrototype.sol";

contract SwapperTest is Utility {

    SwapperPrototype swapper;

    function setUp() public {

        setUpTokens();

        // Initialize one inch Swapper prototype.
        swapper = new SwapperPrototype();

        mint("DAI", address(swapper2), 1000000 ether);
        emit Debug('a', address(swapper2));

    }

    function test_Swapper_decode() public {
        
    }

}
