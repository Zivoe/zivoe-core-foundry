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
        assertEq(OCL_CRV._3CRV_BP(),        0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
        assertEq(OCL_CRV._3CRV_TOKEN(),     0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
        assertEq(OCL_CRV.DAI(),             DAI);
        assertEq(OCL_CRV.USDC(),            USDC);
        assertEq(OCL_CRV.USDT(),            USDT);
        assertEq(OCL_CRV.GBL(),             address(GBL));

        assertEq(OCL_CRV.ZVE_MP(),          0x4e43151b78b5fbb16298C1161fcbF7531d5F8D93);

        // emit Debug("ZVE_MP", OCL_CRV.ZVE_MP());
        // emit Debug("a", ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(0));
        // emit Debug("b", ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(1));
        // emit Debug("c", ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(0));
        // emit Debug("c", ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(1));
        // emit Debug("c", ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(2));
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

        (uint256 amt, uint256 lp) = OCL_CRV._FRAXConvertible();

        emit Debug("amt", amt);
        emit Debug("amt", lp);

        emit Debug("baseline", OCL_CRV.baseline());

    }

    function test_OCL_ZVE_CRV_1_pushMulti_USDT() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = USDT;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**6;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));

        (uint256 amt, uint256 lp) = OCL_CRV._FRAXConvertible();

        emit Debug("amt", amt);
        emit Debug("amt", lp);

        emit Debug("baseline", OCL_CRV.baseline());

    }

    function test_OCL_ZVE_CRV_1_pullMulti_USDC_pullFromLocker() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = USDT;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**6;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));

        (uint256 amt, uint256 lp) = OCL_CRV._FRAXConvertible();

        emit Debug("amt", amt);
        emit Debug("amt", lp);

        emit Debug("baseline", OCL_CRV.baseline());

        address[] memory assets_pull = new address[](4);
        assets_pull[0] = DAI;
        assets_pull[1] = USDC;
        assets_pull[2] = USDT;
        assets_pull[3] = address(ZVE);

        assert(god.try_pullMulti(address(DAO), address(OCL_CRV), assets_pull));

    }

    function test_OCL_ZVE_CRV_1_pushMulti_USDT_forwardYield() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = USDT;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**6;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));

        (uint256 amt, uint256 lp) = OCL_CRV._FRAXConvertible();

        emit Debug("amt", amt);
        emit Debug("amt", lp);

        emit Debug("baseline", OCL_CRV.baseline());

    }

    function test_OCL_ZVE_CRV_1_pushMulti_DAI_forwardYield() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = DAI;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));

        (uint256 amt, uint256 lp) = OCL_CRV._FRAXConvertible();

        emit Debug("amt", amt);
        emit Debug("amt", lp);

        emit Debug("baseline", OCL_CRV.baseline());

    }

    function buyZVE_DAI(uint256 amt) public {
        mint("DAI", address(bob), amt);
        assert(bob.try_approveToken(DAI, OCL_CRV.ZVE_MP(), amt));
        assert(bob.try_exchange_underlying(OCL_CRV.ZVE_MP(), int128(1), int128(0), amt, 0));
    }

    function buyZVE_USDC(uint256 amt) public {
        mint("USDC", address(bob), amt);
        assert(bob.try_approveToken(USDC, OCL_CRV.ZVE_MP(), amt));
        assert(bob.try_exchange_underlying(OCL_CRV.ZVE_MP(), int128(2), int128(0), amt, 0));
    }

    function buyZVE_USDT(uint256 amt) public {
        mint("USDT", address(bob), amt);
        assert(bob.try_approveToken(USDT, OCL_CRV.ZVE_MP(), amt));
        assert(bob.try_exchange_underlying(OCL_CRV.ZVE_MP(), int128(3), int128(0), amt, 0));
    }

    function test_OCL_ZVE_CRV_1_pushMulti_USDC_forwardYield() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = USDT;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**6;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_CRV), assets, amounts));

        (uint256 amt, uint256 lp) = OCL_CRV._FRAXConvertible();

        emit Debug("a", 1);
        emit Debug("a", amt);
        emit Debug("a", 1);
        emit Debug("a", lp);

        emit Debug("baseline", OCL_CRV.baseline());

        buyZVE_DAI(100000 ether);
        buyZVE_USDC(100000 * 10**6);
        buyZVE_DAI(500000 ether);
        buyZVE_USDC(500000 * 10**6);
        buyZVE_USDT(500000 * 10**6);
        buyZVE_USDT(500000 * 10**6);
        
        (amt, lp) = OCL_CRV._FRAXConvertible();
        emit Debug("a", 2);
        emit Debug("a", amt);
        emit Debug("a", 2);
        emit Debug("a", lp);

        emit Debug("baseline", OCL_CRV.baseline());

        emit Debug("a", IERC20(FRAX).balanceOf(address(OCL_CRV)));
        emit Debug("a", IERC20(OCL_CRV.ZVE_MP()).balanceOf(address(OCL_CRV)));
        
        hevm.warp(block.timestamp + 31 days);
        OCL_CRV.forwardYield();
        
        (amt, lp) = OCL_CRV._FRAXConvertible();
        emit Debug("a", 3);
        emit Debug("a", amt);
        emit Debug("a", 3);
        emit Debug("a", lp);

        emit Debug("a", IERC20(FRAX).balanceOf(address(OCL_CRV)));
        emit Debug("a", IERC20(OCL_CRV.ZVE_MP()).balanceOf(address(OCL_CRV)));

    }


}
