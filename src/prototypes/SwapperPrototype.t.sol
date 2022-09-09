// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

import "../Swapper/SwapperPrototype.sol";

contract SwapperTest is Utility {

    SwapperPrototype Swapper;

    function setUp() public {

        setUpTokens();

        // Initialize one inch Swapper prototype.
        Swapper = new SwapperPrototype();

        mint("DAI", address(Swapper), 1000000 ether);

        emit Debug('a', address(Swapper));

    }

    function test_Swapper_init() public {
        emit Debug('a', address(Swapper));
        assertEq(Swapper.owner(),                address(this));
        assertEq(Swapper.router1INCH_V4(),       0x1111111254fb6c44bAC0beD2854e76F90643097d);
    }

    function test_Swapper_execute() public {

        Swapper.swapViaRouter(
            address(DAI),
            "0xe449022e00000000000000000000000000000000000000000000152d02c7e14af68000000000000000000000000000000000000000000000000014f6899151e1788a7f340000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000097e7d56a0408570ba1a7852de36350f7713906eccfee7c08"
        );

    }

}
