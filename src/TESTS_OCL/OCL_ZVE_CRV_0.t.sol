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

        // emit Debug('ZVE_MP', OCL_CRV.ZVE_MP());
        // emit Debug('a', ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(0));
        // emit Debug('b', ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(1));
        // emit Debug('c', ICRVPlainPoolFBP(OCL_CRV.FBP()).coins(0));
        // emit Debug('d', ICRVPlainPoolFBP(OCL_CRV.FBP()).coins(1));
    }

    // Simulate depositing various stablecoins into OCYLocker_AAVE.sol from ZivoeDAO.sol via ZivoeDAO::pushToLocker().

    function test_OCL_ZVE_CRV_0_pushMulti() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));


    }

}
