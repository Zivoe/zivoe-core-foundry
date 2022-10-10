// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCY/OCY_CVX_Modular.sol";

import {ICVX_Booster} from "../../misc/InterfacesAggregated.sol";

contract Test_OCY_CVX_Modular is Utility {

    OCY_CVX_Modular OCY_CVX_FRAX_USDC;
    OCY_CVX_Modular OCY_CVX_mUSD_3CRV;
    address convex_deposit_address = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    

    function setUp() public {

        deployCore(false);

        address[] memory rewards_FRAX_USDC = new address[](1);
        address[] memory rewards_mUSD_3CRV = new address[](1);

        rewards_FRAX_USDC[0] = address(0);
        rewards_mUSD_3CRV[0] = 0xa3BeD4E1c75D00fa6f4E5E6922DB7261B5E9AcD2;

        OCY_CVX_FRAX_USDC = new OCY_CVX_Modular(
            address(DAO), 
            address(GBL), 
            false, 
            0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2, 
            convex_deposit_address, 
            false, 
            rewards_FRAX_USDC, 
            address(0), 
            2, 
            100);

        OCY_CVX_mUSD_3CRV = new OCY_CVX_Modular(
            address(DAO),
            address(GBL), 
            true, 
            0x8474DdbE98F5aA3179B3B3F5942D724aFcdec9f6, 
            convex_deposit_address, 
            true, 
            rewards_mUSD_3CRV, 
            0xe2f2a5C287993345a840Db3B0845fbC70f5935a5,
            0, 
            14);

        zvl.try_updateIsLocker(address(GBL), address(OCY_CVX_FRAX_USDC), true);
        zvl.try_updateIsLocker(address(GBL), address(OCY_CVX_mUSD_3CRV), true);
    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function test_OCY_CVX_Modular_init() public {

        /// In common
        assertEq(OCY_CVX_FRAX_USDC.GBL(),                   address(GBL));
        assertEq(OCY_CVX_FRAX_USDC.CVX_Deposit_Address(),   0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
       
        ///Plain Pool
        assert(OCY_CVX_FRAX_USDC.metaOrPlainPool() == false);
        assertEq(OCY_CVX_FRAX_USDC.convexPoolID(), 100);

        ///Meta pool
        assert(OCY_CVX_mUSD_3CRV.metaOrPlainPool() == true);
        assertEq(OCY_CVX_mUSD_3CRV.convexPoolID(), 14);



    }


}
