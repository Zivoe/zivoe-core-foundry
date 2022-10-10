// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCY/OCY_CVX_Modular.sol";

contract Test_OCY_CVX_Modular is Utility {

    OCY_CVX_Modular OCY_CVX_FRAX_USDC;
    OCY_CVX_Modular OCY_CVX_mUSD_3CRV;
    address oneInchAggregator = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
    address convex_deposit_address = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    address convex_reward_address = 0x7e880867363A7e321f5d260Cade2B0Bb2F717B02;
    address ANGLE = 0x31429d1856aD1377A8A0079410B297e1a9e214c2;

    function setUp() public {

        deployCore(false);

        OCY_CVX_FRAX_USDC = new OCY_CVX_Modular(address(DAO), address(GBL), false, oneInchAggregator, address(0), convex_deposit_address, convex_reward_address, address(0), [0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2, 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC], address(0), 2, 100);
        OCY_CVX_mUSD_3CRV = new OCY_CVX_Modular(address(DAO), address(GBL), true, oneInchAggregator, FRAX, convex_deposit_address, convex_reward_address, ANGLE, [0x8474DdbE98F5aA3179B3B3F5942D724aFcdec9f6, 0x1AEf73d49Dedc4b1778d0706583995958Dc862e6], 0xe2f2a5C287993345a840Db3B0845fbC70f5935a5,  0, 50 );

        zvl.try_updateIsLocker(address(GBL), address(OCY_CVX_FRAX_USDC), true);
        zvl.try_updateIsLocker(address(GBL), address(OCY_CVX_mUSD_3CRV), true);
    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function test_OCY_CVX_Modular_init() public {

    }


}
