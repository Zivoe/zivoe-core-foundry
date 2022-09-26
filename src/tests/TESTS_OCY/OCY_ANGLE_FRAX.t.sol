// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";
//import "../../../lib/forge-std/src/Vm.sol";

import "../../lockers/OCY/OCY_ANGLE_FRAX.sol";

contract OCY_ANGLE_Test is Utility {

    OCY_ANGLE_FRAX OCY_ANGLE;
    address oneInchAggregator = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
    address UNI_Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    function setUp() public {

        setUpFundedDAO();
        // Initialize and whitelist CVX_FRAX_USDC_LOCKER
        OCY_ANGLE = new OCY_ANGLE_FRAX(address(DAO), address(GBL));
        god.try_updateIsLocker(address(GBL), address(OCY_ANGLE), true);

    }

    function test_OCY_ANGLE_init() public {

        assertEq(OCY_ANGLE.owner(),               address(DAO));

        assertEq(OCY_ANGLE.UNI_V3_ROUTER(),       0xE592427A0AEce92De3Edee1F18E0157C05861564);
        assertEq(OCY_ANGLE.oneInchAggregator(),   0x1111111254fb6c44bAC0beD2854e76F90643097d);
        assertEq(OCY_ANGLE.FRAX_3CRV_MP(),        0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B);
        assertEq(OCY_ANGLE.CRV_PP_FRAX_USDC(),    0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2);
        assertEq(OCY_ANGLE.CRV_PP_SDT_ETH(),         0xfB8814D005C5f32874391e888da6eB2fE7a27902);
        assertEq(OCY_ANGLE.FRAX_PoolManager(), 0x6b4eE7352406707003bC6f6b96595FD35925af48);  
        assertEq(OCY_ANGLE.sanFRAX_EUR(),  0xb3B209Bb213A5Da5B947C56f2C770b3E1015f1FE);
        assertEq(OCY_ANGLE.AngleStableMasterFront(),                 0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87);
        assertEq(OCY_ANGLE.ANGLE(),                 0x31429d1856aD1377A8A0079410B297e1a9e214c2);
        assertEq(OCY_ANGLE.agEUR(),                 0x1a7e4e63778B4f12a199C062f3eFdD288afCBce8);
        assertEq(OCY_ANGLE.StakeDAO_Vault(),                 0x1BD865ba36A510514d389B2eA763bad5d96b6ff9);
        assertEq(OCY_ANGLE.sanFRAX_SD_LiquidityGauge(),                 0xB6261Be83EA2D58d8dd4a73f3F1A353fa1044Ef7);
        assertEq(OCY_ANGLE.SDT(),                 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F);

        assertEq(OCY_ANGLE.DAI(),                 DAI);
        assertEq(OCY_ANGLE.USDC(),                USDC);
        assertEq(OCY_ANGLE.USDT(),                USDT);
        assertEq(OCY_ANGLE.WETH(),                WETH);
        assertEq(OCY_ANGLE.FRAX(),                FRAX);
        assertEq(OCY_ANGLE.GBL(),                 address(GBL));


        // emit Debug("ZVE_MP", OCL_CRV.ZVE_MP());
        // emit Debug("a", ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(0));
        // emit Debug("b", ICRVMetaPool(OCL_CRV.ZVE_MP()).coins(1));
        // emit Debug("c", ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(0));
        // emit Debug("c", ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(1));
        // emit Debug("c", ICRVPlainPool3CRV(OCL_CRV._3CRV()).coins(2));
    }

    function test_OCY_ANGLE_ConvertPublic() public {

        address[] memory assets = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        assets[0] = DAI;
        assets[1] = USDT;
        assets[2] = USDC;

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**6;
        amounts[2] = 200000 * 10**6;

        assert(god.try_pushMulti(address(DAO), address(OCY_ANGLE), assets, amounts));

        assertEq(OCY_ANGLE.swapperTimelockStablecoin(), block.timestamp + 12 hours);

        hevm.warp(block.timestamp + 13 hours);

        OCY_ANGLE.publicConvertStablecoins(assets);

        emit Debug("a", 1);
        emit Debug("a", IERC20(OCY_ANGLE.sanFRAX_SD_LiquidityGauge()).balanceOf(address(OCY_ANGLE)));

        assert(IERC20(OCY_ANGLE.sanFRAX_SD_LiquidityGauge()).balanceOf(address(OCY_ANGLE)) > 0);


    }

    function testFail_OCY_ANGLE_ConvertPublic() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = DAI;
        assets[1] = USDT;
        assets[2] = USDC;

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**6;
        amounts[2] = 200000 * 10**6;

        assert(god.try_pushMulti(address(DAO), address(OCY_ANGLE), assets, amounts));

        assertEq(OCY_ANGLE.swapperTimelockStablecoin(), block.timestamp + 12 hours);

        // public tries to convert while block.timestamp < swapperTimelockStablecoin. Should fail.

        OCY_ANGLE.publicConvertStablecoins(assets);

        //TODO: add assertion

    }

    // TODO: input test data for 1inch
    function test_OCY_ANGLE_ConvertKeeperAndInvest() public {

        address[] memory assets = new address[](4);
        uint256[] memory amounts = new uint256[](4);

        bytes memory dataDAItoFRAX= "";
        bytes memory dataUSDTtoFRAX= "";
        bytes memory dataUSDCtoFRAX= "";

        assets[0] = DAI;
        assets[1] = USDC;
        assets[2] = USDT;
        assets[3] = FRAX;

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**6;
        amounts[2] = 300000 * 10**6;
        amounts[3] = 500000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_ANGLE), assets, amounts));

        //Vm.startPrank(address(ZVL));
        OCY_ANGLE.keeperConvertStablecoin(DAI, FRAX, dataDAItoFRAX);
        OCY_ANGLE.keeperConvertStablecoin(USDT, FRAX, dataUSDTtoFRAX);
        OCY_ANGLE.keeperConvertStablecoin(USDC, FRAX, dataUSDCtoFRAX);

        assert(IERC20(DAI).balanceOf(address(OCY_ANGLE)) == 0);
        assert(IERC20(USDT).balanceOf(address(OCY_ANGLE)) == 0);
        assert(IERC20(USDC).balanceOf(address(OCY_ANGLE)) == 0);        

        OCY_ANGLE.invest();
        //Vm.stopPrank();
        //TODO: add assertion


    }

    // TODO: input test data for 1inch
    function testFail_OCY_ANGLE_ConvertKeeper() public {

        address[] memory assets = new address[](4);
        uint256[] memory amounts = new uint256[](4);

        bytes memory dataDAItoFRAX= "";
        bytes memory dataUSDTtoFRAX= "";
        bytes memory dataUSDCtoFRAX= "";

        assets[0] = DAI;
        assets[1] = USDC;
        assets[2] = USDT;
        assets[3] = FRAX;

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**6;
        amounts[2] = 300000 * 10**6;
        amounts[3] = 500000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_ANGLE), assets, amounts));

        OCY_ANGLE.keeperConvertStablecoin(DAI, FRAX, dataDAItoFRAX);
        OCY_ANGLE.keeperConvertStablecoin(USDT, FRAX, dataUSDTtoFRAX);
        OCY_ANGLE.keeperConvertStablecoin(USDC, FRAX, dataUSDCtoFRAX);

    }

    function test_OCY_ANGLE_pushMulti_USDC_USDT_FRAX_DAI() public {

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

        assert(god.try_pushMulti(address(DAO), address(OCY_ANGLE), assets, amounts));

        assertEq(OCY_ANGLE.swapperTimelockStablecoin(), block.timestamp + 12 hours);

        assert(IERC20(DAI).balanceOf(address(OCY_ANGLE)) == 1000000 * 10**18);
        assert(IERC20(USDC).balanceOf(address(OCY_ANGLE)) == 200000 * 10**6);
        assert(IERC20(USDT).balanceOf(address(OCY_ANGLE)) == 300000 * 10**6);  
        assert(IERC20(FRAX).balanceOf(address(OCY_ANGLE)) == 500000 * 10**18); 


    }

    function test_OCY_ANGLE_pushMulti_USDC() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = USDC;

        amounts[0] = 1000000 * 10**6;

        assert(god.try_pushMulti(address(DAO), address(OCY_ANGLE), assets, amounts));

        assert(IERC20(USDC).balanceOf(address(OCY_ANGLE)) == 1000000 * 10**6);

    } 

    function test_OCY_ANGLE_pushMulti_USDT() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = USDT;

        amounts[0] = 1000000 * 10**6;

        assert(god.try_pushMulti(address(DAO), address(OCY_ANGLE), assets, amounts));

        assert(IERC20(USDT).balanceOf(address(OCY_ANGLE)) == 1000000 * 10**6);


    }

    function test_OCY_ANGLE_pushMulti_DAI() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = DAI;

        amounts[0] = 1000000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_ANGLE), assets, amounts));

        assert(IERC20(DAI).balanceOf(address(OCY_ANGLE)) == 1000000 * 10**18);        

    }

    function test_OCY_ANGLE_pushMulti_FRAX() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = FRAX;

        amounts[0] = 1000000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_ANGLE), assets, amounts));

        assert(IERC20(FRAX).balanceOf(address(OCY_ANGLE)) == 1000000 * 10**18);  


    }

    function test_OCY_ANGLE_pullPartial() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = FRAX;
        amounts[0] = 1000000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_ANGLE), assets, amounts));

        hevm.warp(block.timestamp + 13 hours);

        OCY_ANGLE.invest();

        emit log("FRAX Convertible after investing 1m FRAX: ");
        emit log_uint(OCY_ANGLE.USDConvertible());
        emit log("Baseline after investing 1m FRAX: ");
        emit log_uint(OCY_ANGLE.baseline());
        assert(OCY_ANGLE.USDConvertible() == OCY_ANGLE.baseline());
        
        uint256 preBaseline = OCY_ANGLE.baseline();

        uint256 LPBalance = IERC20(OCY_ANGLE.sanFRAX_SD_LiquidityGauge()).balanceOf(address(OCY_ANGLE));

        // Pull out partial amount ...
        assert(
            god.try_pullPartial(
                address(DAO), 
                address(OCY_ANGLE), 
                OCY_ANGLE.sanFRAX_SD_LiquidityGauge(), 
                IERC20(OCY_ANGLE.sanFRAX_SD_LiquidityGauge()).balanceOf(address(OCY_ANGLE)) / 2
            )
        );

        uint256 NewLPBalance = IERC20(OCY_ANGLE.sanFRAX_SD_LiquidityGauge()).balanceOf(address(OCY_ANGLE)); 

        assert(NewLPBalance < LPBalance && NewLPBalance != 0);

        uint256 afterPullBaseline = OCY_ANGLE.USDConvertible();
        assert(afterPullBaseline < preBaseline);

        emit log("FRAX Convertible after pulling lpBalance/2: ");
        emit log_uint(OCY_ANGLE.USDConvertible());
        emit log("Baseline after pulling lpBalance/2: ");
        emit log_uint(OCY_ANGLE.baseline());

    }

    ///TODO: test baseline
    function test_OCY_ANGLE_ForwardYield() public {
        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        bytes memory oneInchDataSDT;
        bytes memory oneInchDataANGLE;
        bytes memory oneInchDataFRAX;

        assets[0] = FRAX;
        amounts[0] = 1000000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCY_ANGLE), assets, amounts));

        hevm.warp(block.timestamp + 13 hours);

        OCY_ANGLE.invest();

        hevm.warp(block.timestamp + 31 days);

        //Vm.startPrank(address(ZVL));

        //here check balance of YDL and check if increases
        //OCY_ANGLE.ZVLforwardYield(oneInchDataSDT, oneInchDataANGLE, oneInchDataFRAX);
        
        //Vm.stopPrank();

    }

    function test_OCY_ANGLE_dataLog() public {
        emit log("PoolCollateralRatio:");
        emit log_uint(OCY_ANGLE.getPoolCollateralRatio());

        address[] memory assets = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        assets[0] = DAI;
        assets[1] = USDT;
        assets[2] = USDC;

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**6;
        amounts[2] = 200000 * 10**6;

        assert(god.try_pushMulti(address(DAO), address(OCY_ANGLE), assets, amounts));

        assertEq(OCY_ANGLE.swapperTimelockStablecoin(), block.timestamp + 12 hours);

        hevm.warp(block.timestamp + 13 hours);

        OCY_ANGLE.publicConvertStablecoins(assets);

        emit log("USDConvertible after 1.4m invested:");
        emit log_uint(OCY_ANGLE.USDConvertible());
        emit log("LP Balance after 1.4m invested:");
        emit log_uint(IERC20(OCY_ANGLE.sanFRAX_SD_LiquidityGauge()).balanceOf(address(OCY_ANGLE)));

        uint256 sanTokenBalance = IERC20(OCY_ANGLE.sanFRAX_SD_LiquidityGauge()).balanceOf(address(OCY_ANGLE));

        uint256 sanRate = IAngleStableMasterFront(OCY_ANGLE.AngleStableMasterFront()).collateralMap(OCY_ANGLE.FRAX_PoolManager()).sanRate;

        uint256 sanTokenValueInFrax = (sanTokenBalance * 10**9 * sanRate)/(10**18 * 10**9);
        emit log("sanRate");
        emit log_uint(sanRate);
        emit log("sanTokenValueInFrax");
        emit log_uint(sanTokenValueInFrax);

    }


}    