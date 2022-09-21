// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";
import "../../../lib/forge-std/src/Vm.sol";

import "../../lockers/OCY/OCY_CVX_FRAX_USDC_SWAPPER.sol";

contract OCY_CVX_Test is Utility {

    OCY_CVX_FRAX_USDC OCY_CVX;
    address oneInchAggregator = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
    address UNI_Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    function setUp() public {

        setUpFundedDAO();
        // Initialize and whitelist CVX_FRAX_USDC_LOCKER
        OCY_CVX = new OCY_CVX_FRAX_USDC(address(DAO), address(GBL));
        god.try_updateIsLocker(address(GBL), address(OCY_CVX), true);

    }

    function test_OCY_CVX_init() public {

        assertEq(OCY_CVX.owner(),               address(DAO));

        assertEq(OCY_CVX.UNI_V3_ROUTER(),       0xE592427A0AEce92De3Edee1F18E0157C05861564);
        assertEq(OCY_CVX.oneInchAggregator(),   0x1111111254fb6c44bAC0beD2854e76F90643097d);
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


        // emit Debug("ZVE_MP", OCL_CRV.ZVE_MP());
        // emit Debug("a", ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(0));
        // emit Debug("b", ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(1));
        // emit Debug("c", ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(0));
        // emit Debug("c", ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(1));
        // emit Debug("c", ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(2));
    }

    // Simulate depositing various stablecoins into OCL_ZVE_CRV_1.sol from ZivoeDAO.sol via ZivoeDAO::pushToLockerMulti().

    function test_OCY_CVX_ConvertPublic() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = DAI;
        assets[1] = USDT;

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**6;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

        assertEq(OCY_CVX.swapperTimelockStablecoin(), block.timestamp + 12 hours);

        hevm.warp(block.timestamp + 13 hours);

        OCY_CVX.publicConvertStablecoins(assets);

        emit Debug("a", 1);
        emit Debug("a", IERC20(OCY_CVX.CVX_Reward_Address()).balanceOf(address(OCY_CVX)));

        assert(IERC20(OCY_CVX.CVX_Reward_Address()).balanceOf(address(OCY_CVX)) > 0);

    }

    function testFail_OCY_CVX_ConvertPublic() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = DAI;
        assets[1] = USDT;

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**6;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

        assertEq(OCY_CVX.swapperTimelockStablecoin(), block.timestamp + 12 hours);

        // public tries to convert while block.timestamp < swapperTimelockStablecoin. Should fail.

        OCY_CVX.publicConvertStablecoins(assets);

    }

    // TODO: input test data for 1inch
    function test_OCY_CVX_ConvertKeeperAndInvest() public {

        address[] memory assets = new address[](4);
        uint256[] memory amounts = new uint256[](4);

        bytes memory dataDAItoFRAX= "";
        bytes memory dataUSDTtoUSDC= "";

        assets[0] = DAI;
        assets[1] = USDC;
        assets[2] = USDT;
        assets[3] = FRAX;

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**6;
        amounts[2] = 300000 * 10**6;
        amounts[3] = 500000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

        //Vm.startPrank(zvl);
        OCY_CVX.keeperConvertStablecoin(DAI, FRAX, dataDAItoFRAX);
        OCY_CVX.keeperConvertStablecoin(USDT, USDC, dataUSDTtoUSDC);

        assert(IERC20(DAI).balanceOf(address(OCY_CVX)) == 0);

        assert(IERC20(USDT).balanceOf(address(OCY_CVX)) == 0);

        OCY_CVX.invest();
        //Vm.stopPrank();


    }

    // TODO: input test data for 1inch
    function testFail_OCY_CVX_ConvertKeeper() public {

        address[] memory assets = new address[](4);
        uint256[] memory amounts = new uint256[](4);

        bytes memory dataDAItoFRAX= "";
        bytes memory dataUSDTtoUSDC= "";

        assets[0] = DAI;
        assets[1] = USDC;
        assets[2] = USDT;
        assets[3] = FRAX;

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**6;
        amounts[2] = 300000 * 10**6;
        amounts[3] = 500000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

        OCY_CVX.keeperConvertStablecoin(DAI, FRAX, dataDAItoFRAX);
        OCY_CVX.keeperConvertStablecoin(USDT, USDC, dataUSDTtoUSDC);

    }

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

        assertEq(OCY_CVX.swapperTimelockStablecoin(), block.timestamp + 12 hours);

        assert(IERC20(DAI).balanceOf(address(OCY_CVX)) == 1000000 * 10**18);
        assert(IERC20(USDC).balanceOf(address(OCY_CVX)) == 200000 * 10**6);
        assert(IERC20(USDT).balanceOf(address(OCY_CVX)) == 300000 * 10**6);  
        assert(IERC20(FRAX).balanceOf(address(OCY_CVX)) == 500000 * 10**18); 


    }

    function test_OCY_CVX_pushMulti_USDC() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = USDC;

        amounts[0] = 1000000 * 10**6;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

        assert(IERC20(USDC).balanceOf(address(OCY_CVX)) == 1000000 * 10**6);

    }   

    function test_OCY_CVX_pushMulti_USDT() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = USDT;

        amounts[0] = 1000000 * 10**6;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

        assert(IERC20(USDT).balanceOf(address(OCY_CVX)) == 1000000 * 10**6);


    }

    function test_OCY_CVX_pushMulti_DAI() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = DAI;

        amounts[0] = 1000000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

        assert(IERC20(DAI).balanceOf(address(OCY_CVX)) == 1000000 * 10**18);        

    }

    function test_OCY_CVX_pushMulti_FRAX() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = FRAX;

        amounts[0] = 1000000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

        assert(IERC20(FRAX).balanceOf(address(OCY_CVX)) == 1000000 * 10**18);  


    }

    function test_OCY_CVX_pullPartial() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = FRAX;
        amounts[0] = 1000000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

        hevm.warp(block.timestamp + 13 hours);

        OCY_CVX.invest();

        uint256 LPBalance = IERC20(OCY_CVX.CVX_Reward_Address()).balanceOf(address(OCY_CVX));

        // Pull out partial amount ...
        assert(
            god.try_pullPartial(
                address(DAO), 
                address(OCY_CVX), 
                OCY_CVX.CVX_Reward_Address(), 
                IERC20(OCY_CVX.CVX_Reward_Address()).balanceOf(address(OCY_CVX)) / 2
            )
        );

        uint256 NewLPBalance = IERC20(OCY_CVX.CVX_Reward_Address()).balanceOf(address(OCY_CVX)); 

        assert(NewLPBalance < LPBalance && NewLPBalance != 0);

    }

    function test_OCY_CVX_pullMulti() public {
        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = FRAX;
        amounts[0] = 1000000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

        assert(IERC20(FRAX).balanceOf(address(OCY_CVX)) == 1000000 * 10**18);

        hevm.warp(block.timestamp + 13 hours);

        OCY_CVX.invest();

        hevm.warp(block.timestamp + 31 days);

        address[] memory assets_pull = new address[](2);
        assets_pull[0] = FRAX;
        assets_pull[1] = USDC;

        assert(god.try_pullMulti(address(DAO), address(OCY_CVX), assets_pull));

    }


    function test_OCY_CVX_ForwardYield() public {
        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        bytes memory oneInchDataCRV;
        bytes memory oneInchDataCVX;

        assets[0] = FRAX;
        amounts[0] = 1000000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX), assets, amounts));

        hevm.warp(block.timestamp + 13 hours);

        OCY_CVX.invest();

        hevm.warp(block.timestamp + 31 days);

        //Vm.startPrank(zvl);

        //here check balance of YDL and check if increases
        OCY_CVX.ZVLforwardYield(oneInchDataCRV, oneInchDataCVX);
        
        //Vm.stopPrank();

    }

}