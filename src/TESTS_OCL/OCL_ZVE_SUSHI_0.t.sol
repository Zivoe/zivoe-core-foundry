// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

import "../ZivoeOCLLockers/OCL_ZVE_SUSHI_0.sol";

contract OCL_ZVE_SUSHI_0Test is Utility {

    OCL_ZVE_SUSHI_0 OCL_CRV;

    function setUp() public {

        setUpFundedDAO();

        // Initialize and whitelist MyAAVELocker
        OCL_CRV = new OCL_ZVE_SUSHI_0(address(DAO), address(GBL));
        god.try_modifyLockerWhitelist(address(DAO), address(OCL_CRV), true);

    }

    function test_OCL_ZVE_SUSHI_0_init() public {

        assertEq(OCL_CRV.owner(),               address(DAO));
        
    }

    // Simulate depositing various stablecoins into OCL_ZVE_SUSHI_0.sol from ZivoeDAO.sol via ZivoeDAO::pushToLocker().

    function test_OCL_ZVE_SUSHI_0_pushMulti_FRAX_generic() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));


    }

    function test_OCL_ZVE_SUSHI_0_pullMulti_FRAX_pullFromLocker() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));

        address[] memory assets_pull = new address[](2);
        assets_pull[0] = FRAX;
        assets_pull[1] = address(ZVE);

        assert(god.try_pullMulti(address(DAO), address(OCL_CRV), assets_pull));

    }

    function test_OCL_ZVE_SUSHI_0_pushMulti_FRAX_forwardYield() public {

        // address[] memory assets = new address[](2);
        // uint256[] memory amounts = new uint256[](2);

        // assets[0] = FRAX;
        // assets[1] = address(ZVE);

        // amounts[0] = 1000000 * 10**18;
        // amounts[1] = 200000 * 10**18;

        // assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));

    }

}
