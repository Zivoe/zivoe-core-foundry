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
        god.try_modifyLockerWhitelist(address(DAO), address(OCL_CRV), true);

    }

    function test_OCL_ZVE_CRV_0_init() public {
        assertEq(OCL_CRV.owner(),               address(DAO));
        
        assertEq(OCL_CRV.CRV_Deployer(),        0xB9fC157394Af804a3578134A6585C0dc9cc990d4);
        assertEq(OCL_CRV.FBP_BP(),              0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2);
        assertEq(OCL_CRV.FBP_TOKEN(),           0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
        assertEq(OCL_CRV.FRAX(),                FRAX);
        assertEq(OCL_CRV.USDC(),                USDC);
        assertEq(OCL_CRV.GBL(),                 address(GBL));

        // emit Debug("ZVE_MP", OCL_CRV.ZVE_MP());
        emit Debug("a", ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(0));
        emit Debug("b", ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(1));
        // emit Debug("c", ICRVPlainPoolFBP(OCL_CRV.FBP()).coins(0));
        // emit Debug("d", ICRVPlainPoolFBP(OCL_CRV.FBP()).coins(1));
    }

}
