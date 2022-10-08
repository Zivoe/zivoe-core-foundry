// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCL/OCL_ZVE_CRV_0.sol";

contract Test_OCL_ZVE_CRV_0 is Utility {

    OCL_ZVE_CRV_0 OCL_CRV;

    function setUp() public {

        deployCore(false);

        // Initialize and whitelist MyAAVELocker
        OCL_CRV = new OCL_ZVE_CRV_0(address(DAO), address(GBL));
        god.try_updateIsLocker(address(GBL), address(OCL_CRV), true);

    }

    function xtest_OCL_ZVE_CRV_0_init() public {
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

    // Simulate depositing various stablecoins into OCL_ZVE_CRV_0.sol from ZivoeDAO.sol via ZivoeDAO::pushToLocker().

    function xtest_OCL_ZVE_CRV_0_pushMulti_FRAX() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));


    }

    function xtest_OCL_ZVE_CRV_0_pushMulti_USDC() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = USDC;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**6;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));


    }

    function xtest_OCL_ZVE_CRV_0_pullMulti_USDC_pullFromLocker() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = USDC;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**6;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));

        (uint256 amt, uint256 lp) = OCL_CRV.FRAXConvertible();

        emit Debug("amt", amt);
        emit Debug("amt", lp);

        address[] memory assets_pull = new address[](3);
        assets_pull[0] = USDC;
        assets_pull[1] = FRAX;
        assets_pull[2] = address(ZVE);

        assert(god.try_pullMulti(address(DAO), address(OCL_CRV), assets_pull));

    }

    function xtest_OCL_ZVE_CRV_0_pullPartial() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = USDC;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**6;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));

        (uint256 amt, uint256 lp) = OCL_CRV.FRAXConvertible();

        emit Debug("amt", amt);
        emit Debug("amt", lp);

        address[] memory assets_pull = new address[](3);
        assets_pull[0] = USDC;
        assets_pull[1] = FRAX;
        assets_pull[2] = address(ZVE);

        // Pull out partial amount ...
        assert(
            god.try_pullPartial(
                address(DAO), 
                address(OCL_CRV), 
                OCL_CRV.ZVE_MP(), 
                IERC20(OCL_CRV.ZVE_MP()).balanceOf(address(OCL_CRV)) / 2
            )
        );
    }

    function buyZVE_FRAX(uint256 amt) public {
        mint("FRAX", address(bob), amt);
        assert(bob.try_approveToken(FRAX, OCL_CRV.ZVE_MP(), amt));
        assert(bob.try_exchange_underlying(OCL_CRV.ZVE_MP(), int128(1), int128(0), amt, 0));
    }

    function buyZVE_USDC(uint256 amt) public {
        mint("USDC", address(bob), amt);
        assert(bob.try_approveToken(USDC, OCL_CRV.ZVE_MP(), amt));
        assert(bob.try_exchange_underlying(OCL_CRV.ZVE_MP(), int128(2), int128(0), amt, 0));
    }

    function xtest_OCL_ZVE_CRV_0_pushMulti_USDC_forwardYield() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = USDC;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**6;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));

        (uint256 amt, uint256 lp) = OCL_CRV.FRAXConvertible();

        emit Debug("a", 11111);
        emit Debug("a", amt);
        emit Debug("a", 11111);
        emit Debug("a", lp);

        emit Debug("baseline", OCL_CRV.baseline());

        buyZVE_FRAX(100000 ether);
        buyZVE_USDC(100000 * 10**6);
        // buyZVE_FRAX(500000 ether);
        // buyZVE_USDC(500000 * 10**6);
        
        (amt, lp) = OCL_CRV.FRAXConvertible();
        emit Debug("a", 22222);
        emit Debug("a", amt);
        emit Debug("a", 22222);
        emit Debug("a", lp);

        emit Debug("baseline", OCL_CRV.baseline());

        emit Debug("a", IERC20(FRAX).balanceOf(address(OCL_CRV)));
        emit Debug("a", IERC20(OCL_CRV.ZVE_MP()).balanceOf(address(OCL_CRV)));
        
        hevm.warp(block.timestamp + 31 days);
        OCL_CRV.forwardYield();
        
        (amt, lp) = OCL_CRV.FRAXConvertible();
        emit Debug("a", 33333);
        emit Debug("a", amt);
        emit Debug("a", 33333);
        emit Debug("a", lp);

        emit Debug("a", IERC20(FRAX).balanceOf(address(OCL_CRV)));
        emit Debug("a", IERC20(OCL_CRV.ZVE_MP()).balanceOf(address(OCL_CRV)));
    }

}
