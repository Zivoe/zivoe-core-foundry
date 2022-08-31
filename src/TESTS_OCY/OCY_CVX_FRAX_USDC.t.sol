// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

import "../ZivoeOCYLockers/OCY_CVX_FRAX_USDC.sol";
import "../ZivoeOCYLockers/Swap.sol";

contract OCY_CVX_Test is Utility {


    function setUp() public {

        setUpFundedDAO();
        address UNI_Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
        // Initialize and whitelist CVX_FRAX_USDC_LOCKER
        SwapContract = new Swap(address(DAO), UNI_Router);
        OCY_CVX = new OCY_CVX_FRAX_USDC(address(DAO), address(GBL), address(SwapContract));
        god.try_modifyLockerWhitelist(address(DAO), address(OCY_CVX), true);

    }

    function test_OCY_CVX_init() public {

        assertEq(OCY_CVX.owner(),               address(DAO));

        assertEq(OCY_CVX.CRV_PP(),              0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
        assertEq(OCY_CVX.FRAX_3CRV_MP(),        0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B);
        assertEq(OCY_CVX.CRV_PP_FRAX_USDC(),    0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2);
        assertEq(OCY_CVX.lpFRAX_USDC(),         0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
        assertEq(OCY_CVX.CVX_Deposit_Address(), 0xF403C135812408BFbE8713b5A23a04b3D48AAE31);  
        assertEq(OCY_CVX.CVX_Reward_Address(),  0x7e880867363A7e321f5d260Cade2B0Bb2F717B02);
        assertEq(OCY_CVX.CVX(),                 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
        assertEq(OCY_CVX.CRV(),                 0xD533a949740bb3306d119CC777fa900bA034cd52);
        assertEq(OCY_CVX.DAI(),                 DAI);
        assertEq(OCY_CVX.USDC(),                USDC);
        assertEq(OCY_CVX.USDT(),                USDT);
        assertEq(OCY_CVX.WETH(),                WETH);
        assertEq(OCY_CVX.GBL(),                 address(GBL));

        assertEq(OCY_CVX.ZVE_MP(),           0x4e43151b78b5fbb16298C1161fcbF7531d5F8D93);

        // emit Debug("ZVE_MP", OCL_CRV.ZVE_MP());
        // emit Debug("a", ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(0));
        // emit Debug("b", ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(1));
        // emit Debug("c", ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(0));
        // emit Debug("c", ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(1));
        // emit Debug("c", ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(2));
    }

    // Simulate depositing various stablecoins into OCL_ZVE_CRV_1.sol from ZivoeDAO.sol via ZivoeDAO::pushToLockerMulti().

    function test_OCY_CVX_pushMulti_USDC_USDT_FRAX_DAI() public {

        address[] memory assets = new address[](4);
        uint256[] memory amounts = new uint256[](4);

        assets[0] = DAI;
        assets[1] = USDC;
        assets[2] = USDT;
        assets[3] = FRAX;


        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**6;
        amounts[2] = 300000 * 10**6;
        amounts[3] = 500000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

    }

    function test_OCY_CVX_pushMulti_USDC() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = USDC;

        amounts[0] = 1000000 * 10**6;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

    }

    function test_OCY_CVX_pushMulti_USDT() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = USDT;

        amounts[0] = 1000000 * 10**6;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

    }


}
