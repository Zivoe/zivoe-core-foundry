// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

import "../ZivoeOCLLockers/OCL_ZVE_CRV_0.sol";

contract OCL_ZVE_CRV_0Test is Utility {

    OCL_ZVE_CRV_0 OCL_CRV;

    function setUp() public {

        setUpFundedDAO();

        // Initialize and whitelist MyAAVELocker
        OCL_CRV = new OCL_ZVE_CRV_0(address(DAO), address(GBL));
        god.try_modifyLockerWhitelist(address(DAO), address(OCL_CRV), true);

    }

    function test_OCL_ZVE_CRV_0_init() public {
        assertEq(OCL_CRV.owner(),               address(DAO));
        
        assertEq(OCL_CRV.CRV_Deployer(),        0xB9fC157394Af804a3578134A6585C0dc9cc990d4);
        assertEq(OCL_CRV.FBP(),                 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2);
        assertEq(OCL_CRV.FRAX(),                FRAX);
        assertEq(OCL_CRV.USDC(),                USDC);
        assertEq(OCL_CRV.GBL(),                 address(GBL));

        emit Debug('ZVE_MetaPool', OCL_CRV.ZVE_MetaPool());
    }

    // Simulate depositing various stablecoins into OCYLocker_AAVE.sol from ZivoeDAO.sol via ZivoeDAO::pushToLocker().

    function test_OCL_ZVE_CRV_0_push() public {

    }

}
