// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

import "../ZivoeOCLLockers/OCL_ZVE_CRV_1.sol";

contract OCL_ZVE_CRV_0Test is Utility {

    OCL_ZVE_CRV_1 OCL_CRV;

    function setUp() public {

        setUpFundedDAO();

        // Initialize and whitelist MyAAVELocker
        OCL_CRV = new OCL_ZVE_CRV_1(address(DAO), address(GBL));
        god.try_modifyLockerWhitelist(address(DAO), address(OCL_CRV), true);

    }

    function test_OCL_ZVE_CRV_1_init() public {

        assertEq(OCL_CRV.owner(),           address(DAO));

        assertEq(OCL_CRV.CRV_Deployer(),    0xB9fC157394Af804a3578134A6585C0dc9cc990d4);
        assertEq(OCL_CRV._3CRV_LP(),        0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
        assertEq(OCL_CRV._3CRV_TOKEN(),     0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
        assertEq(OCL_CRV.DAI(),             DAI);
        assertEq(OCL_CRV.USDC(),            USDC);
        assertEq(OCL_CRV.USDT(),            USDT);
        assertEq(OCL_CRV.GBL(),             address(GBL));

        assertEq(OCL_CRV.ZVE_MP(),          0x4e43151b78b5fbb16298C1161fcbF7531d5F8D93);

        // emit Debug('ZVE_MP', OCL_CRV.ZVE_MP());
        // emit Debug('a', ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(0));
        // emit Debug('b', ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(1));
        // emit Debug('c', ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(0));
        // emit Debug('c', ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(1));
        // emit Debug('c', ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(2));
    }

    // Simulate depositing various stablecoins into OCL_ZVE_CRV_1.sol from ZivoeDAO.sol via ZivoeDAO::pushToLockerMulti().

    function test_OCL_ZVE_CRV_1_pushMulti_DAI() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = DAI;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));


    }

    function test_OCL_ZVE_CRV_1_pushMulti_USDC() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = USDC;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**6;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));


    }

    function test_OCL_ZVE_CRV_1_pushMulti_USDT() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = USDT;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**6;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));


    }

}
