// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCY/OCY_CVX_Modular.sol";

import {ICVX_Booster, ICRVMetaPool} from "../../misc/InterfacesAggregated.sol";

contract Test_OCY_CVX_Modular is Utility {

    OCY_CVX_Modular OCY_CVX_FRAX_USDC;
    OCY_CVX_Modular OCY_CVX_mUSD_3CRV;
    OCY_CVX_Modular OCY_CVX_FRAX_3CRV;
    
    function setUp() public {

        deployCore(false);

        address convex_deposit_address = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;

        address[] memory rewards_FRAX_USDC = new address[](1);
        address[] memory rewards_mUSD_3CRV = new address[](1);
        address[] memory rewards_FRAX_3CRV = new address[](1);

        rewards_FRAX_USDC[0] = address(0);
        rewards_mUSD_3CRV[0] = 0xa3BeD4E1c75D00fa6f4E5E6922DB7261B5E9AcD2;
        rewards_FRAX_3CRV[0] = 0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0;

        OCY_CVX_FRAX_USDC = new OCY_CVX_Modular(
            address(DAO), 
            address(GBL), 
            false, 
            0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2, 
            convex_deposit_address, 
            false, 
            rewards_FRAX_USDC, 
            address(0), 
            2, 
            100);

        OCY_CVX_mUSD_3CRV = new OCY_CVX_Modular(
            address(DAO),
            address(GBL), 
            true, 
            0x8474DdbE98F5aA3179B3B3F5942D724aFcdec9f6, 
            convex_deposit_address, 
            true, 
            rewards_mUSD_3CRV, 
            0xe2f2a5C287993345a840Db3B0845fbC70f5935a5,
            0, 
            14);
        
        OCY_CVX_FRAX_3CRV = new OCY_CVX_Modular(
            address(DAO),
            address(GBL), 
            true, 
            0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B,
            convex_deposit_address,
            true,
            rewards_FRAX_3CRV,
            FRAX,
            0,
            32);
    

        zvl.try_updateIsLocker(address(GBL), address(OCY_CVX_FRAX_USDC), true);
        zvl.try_updateIsLocker(address(GBL), address(OCY_CVX_mUSD_3CRV), true);
        zvl.try_updateIsLocker(address(GBL), address(OCY_CVX_FRAX_3CRV), true);
    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function test_OCY_CVX_Modular_init() public {

        /// In common
        assertEq(OCY_CVX_FRAX_USDC.GBL(),                     address(GBL));
        assertEq(OCY_CVX_FRAX_USDC.CVX_Deposit_Address(),     0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
        assertEq(OCY_CVX_FRAX_USDC.CRV(),                     0xD533a949740bb3306d119CC777fa900bA034cd52);
        assertEq(OCY_CVX_FRAX_USDC.CVX(),                     0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
       
        ///Plain Pool
        assert(OCY_CVX_FRAX_USDC.metaOrPlainPool() == false);
        assert(OCY_CVX_FRAX_USDC.extraRewards()    == false);

        assertEq(OCY_CVX_FRAX_USDC.convexPoolID(),            100);
        assertEq(OCY_CVX_FRAX_USDC.CVX_Reward_Address(),      0x7e880867363A7e321f5d260Cade2B0Bb2F717B02);
        assertEq(OCY_CVX_FRAX_USDC.pool(),                    0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2);
        assertEq(OCY_CVX_FRAX_USDC.POOL_LP_TOKEN(),           0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
        assertEq(OCY_CVX_FRAX_USDC.PP_TOKENS(0),              0x853d955aCEf822Db058eb8505911ED77F175b99e);
        assertEq(OCY_CVX_FRAX_USDC.PP_TOKENS(1),              0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);


        ///Meta pool
        assert(OCY_CVX_mUSD_3CRV.metaOrPlainPool() == true);
        assert(OCY_CVX_mUSD_3CRV.extraRewards()    == true);

        assertEq(OCY_CVX_mUSD_3CRV.convexPoolID(),            14);
        assertEq(OCY_CVX_mUSD_3CRV.CVX_Reward_Address(),      0xDBFa6187C79f4fE4Cda20609E75760C5AaE88e52);
        assertEq(OCY_CVX_mUSD_3CRV.pool(),                    0x8474DdbE98F5aA3179B3B3F5942D724aFcdec9f6);
        assertEq(OCY_CVX_mUSD_3CRV.POOL_LP_TOKEN(),           0x1AEf73d49Dedc4b1778d0706583995958Dc862e6);
        assertEq(OCY_CVX_mUSD_3CRV.BASE_TOKEN(),              0xe2f2a5C287993345a840Db3B0845fbC70f5935a5);
        assertEq(OCY_CVX_mUSD_3CRV.rewardsAddresses(0),       0xa3BeD4E1c75D00fa6f4E5E6922DB7261B5E9AcD2);
    }

    function test_OCY_CVX_Modular_pushMulti_USDC_USDT_FRAX_DAI() public {

        address[] memory assets = new address[](4);
        uint256[] memory amounts = new uint256[](4);

        assets[0] = DAI;
        assets[1] = USDC;
        assets[2] = USDT;
        assets[3] = FRAX;

        amounts[0] = 500000 * 10**18;
        amounts[1] = 200000 * 10**6;
        amounts[2] = 300000 * 10**6;
        amounts[3] = 500000 * 10**18;

        mint("DAI", address(DAO), 1000000 * 10**18);
        mint("USDC", address(DAO), 400000 * 10**6);
        mint("USDT", address(DAO), 600000 * 10**6);
        mint("FRAX", address(DAO), 1000000 * 10**18);

        //Plain Pool
        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_USDC), assets, amounts));

        assert(IERC20(DAI).balanceOf(address(OCY_CVX_FRAX_USDC)) == 500000 * 10**18);
        assert(IERC20(USDC).balanceOf(address(OCY_CVX_FRAX_USDC)) == 200000 * 10**6);
        assert(IERC20(USDT).balanceOf(address(OCY_CVX_FRAX_USDC)) == 300000 * 10**6);  
        assert(IERC20(FRAX).balanceOf(address(OCY_CVX_FRAX_USDC)) == 500000 * 10**18); 

        //Meta Pool
        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_mUSD_3CRV), assets, amounts));

        assert(IERC20(DAI).balanceOf(address(OCY_CVX_mUSD_3CRV)) == 500000 * 10**18);
        assert(IERC20(USDC).balanceOf(address(OCY_CVX_mUSD_3CRV)) == 200000 * 10**6);
        assert(IERC20(USDT).balanceOf(address(OCY_CVX_mUSD_3CRV)) == 300000 * 10**6);  
        assert(IERC20(FRAX).balanceOf(address(OCY_CVX_mUSD_3CRV)) == 500000 * 10**18); 


    }

    ///Test to see the difference between depositing a 3CRV token or the BASE_TOKEN in a metapool with 11% 3CRV token vs BASE_TOKEN
    ///Results are better for 1) DAI=>(convert on 1inch) MIM => deposit in MP over 2) DAI=>deposit in 3CRV=>deposit in MP.
    function test_OCY_CVX_Modular_Deposit3CRV() public {
        uint256[2] memory amounts;
        amounts[1] = 977400 * 10**18;
        uint256 lptokensReceived = ICRVPlainPoolFBP(0x5a6A4D54456819380173272A5E8E9B9904BdF41B).calc_token_amount(amounts, true);
        emit log_uint(lptokensReceived);

        uint256[2] memory amountsforMIM;
        amountsforMIM[0] = 1004000 * 10**18;  
        uint256 lptokensReceivedMIM = ICRVPlainPoolFBP(0x5a6A4D54456819380173272A5E8E9B9904BdF41B).calc_token_amount(amountsforMIM, true);      
        emit log_uint(lptokensReceivedMIM);

    }

    function test_OCY_CVX_Modular_Invest_PP() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = USDC;

        amounts[0] = 500000 * 10**18;
        amounts[1] = 200000 * 10**6;

        mint("FRAX", address(DAO), 500000 * 10**18);
        mint("USDC", address(DAO), 200000 * 10**6);

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_USDC), assets, amounts));

        hevm.warp(block.timestamp + 25 hours);

        assert(IERC20(OCY_CVX_FRAX_USDC.POOL_LP_TOKEN()).balanceOf(address(OCY_CVX_FRAX_USDC)) == 0);

        OCY_CVX_FRAX_USDC.invest();

        //Ensuring number of LP tokens staked on Convex is within 5000 (out of 700k)
        withinDiff(IERC20(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_USDC)), 700000 * 10**18, 5000 * 10**18);

        emit log("Number of LP Token staked on Convex");
        emit log_uint(IERC20(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_USDC)));

        // Ok we get 0 because the convex lp token is staked directly
        emit log("cvxcrvFRAX Balance");
        emit log_uint(IERC20(0x117A0bab81F25e60900787d98061cCFae023560c).balanceOf(address(OCY_CVX_FRAX_USDC)));

    }

    function testFail_OCY_CVX_Modular_Invest_PP() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = USDC;

        amounts[0] = 500000 * 10**18;
        amounts[1] = 200000 * 10**6;

        mint("FRAX", address(DAO), 500000 * 10**18);
        mint("USDC", address(DAO), 200000 * 10**6);

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_USDC), assets, amounts));

        OCY_CVX_FRAX_USDC.invest();
    }

    function test_OCY_CVX_Modular_Invest_MP() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = FRAX;

        amounts[0] = 50000 * 10**18;

        mint("FRAX", address(DAO), 50000 * 10**18);

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_3CRV), assets, amounts));

        hevm.warp(block.timestamp + 25 hours);

        assert(IERC20(OCY_CVX_FRAX_3CRV.POOL_LP_TOKEN()).balanceOf(address(OCY_CVX_FRAX_3CRV)) == 0);

        OCY_CVX_FRAX_3CRV.invest();

        //Ensuring number of LP tokens staked on Convex is within 2000 (out of 50k)
        withinDiff(IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)), 50000 * 10**18, 2000 * 10**18);

        emit log("Number of LP Token staked on Convex");
        emit log_uint(IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)));

        // Ok we get 0 because the convex lp token is staked directly
        emit log("cvxFRAX3CRV Balance");
        emit log_uint(IERC20(0xbE0F6478E0E4894CFb14f32855603A083A57c7dA).balanceOf(address(OCY_CVX_FRAX_3CRV)));

    }

    function testFail_OCY_CVX_Modular_Invest_MP() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = FRAX;

        amounts[0] = 50000 * 10**18;

        mint("FRAX", address(DAO), 50000 * 10**18);

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_3CRV), assets, amounts));

        OCY_CVX_FRAX_3CRV.invest();
    }

    function test_OCY_CVX_Modular_pullFromLockerMultiPP() public {
        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = USDC;

        amounts[0] = 500000 * 10**18;
        amounts[1] = 200000 * 10**6;

        mint("FRAX", address(DAO), 500000 * 10**18);
        mint("USDC", address(DAO), 200000 * 10**6);

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_USDC), assets, amounts));

        hevm.warp(block.timestamp + 25 hours);

        OCY_CVX_FRAX_USDC.invest();

        assert(IERC20(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_USDC)) > 0);

        hevm.warp(block.timestamp + 30 days);

        assert(god.try_pullMulti(address(DAO), address(OCY_CVX_FRAX_USDC), assets));

        assert(IERC20(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_USDC)) == 0);

    }

    function testFail_OCY_CVX_Modular_pullFromLockerMultiPP() public {
        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = USDC;

        amounts[0] = 500000 * 10**18;
        amounts[1] = 200000 * 10**6;

        mint("FRAX", address(DAO), 500000 * 10**18);
        mint("USDC", address(DAO), 200000 * 10**6);

        god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_USDC), assets, amounts);

        hevm.warp(block.timestamp + 25 hours);

        OCY_CVX_FRAX_USDC.invest();

        hevm.warp(block.timestamp + 30 days);

        //We provide the wrong assets (in wrong order)
        address[] memory assetsWRONG = new address[](2);
        assetsWRONG[1] = FRAX;
        assetsWRONG[0] = USDC;     

        assert(god.try_pullMulti(address(DAO), address(OCY_CVX_FRAX_USDC), assetsWRONG));

    }

    function test_OCY_CVX_Modular_pullFromLockerMultiMP() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = FRAX;

        amounts[0] = 50000 * 10**18;

        mint("FRAX", address(DAO), 50000 * 10**18);

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_3CRV), assets, amounts));

        hevm.warp(block.timestamp + 25 hours);

        OCY_CVX_FRAX_3CRV.invest();

        assert(IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)) > 0);

        hevm.warp(block.timestamp + 30 days);

        assert(god.try_pullMulti(address(DAO), address(OCY_CVX_FRAX_3CRV), assets));

        assert(IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)) == 0);       

    }

    function test_OCY_CVX_Modular_pullFromLockerMultiMP_fail() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = FRAX;

        amounts[0] = 50000 * 10**18;

        mint("FRAX", address(DAO), 50000 * 10**18);

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_3CRV), assets, amounts));

        hevm.warp(block.timestamp + 25 hours);

        OCY_CVX_FRAX_3CRV.invest();

        assert(IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)) > 0);

        hevm.warp(block.timestamp + 30 days);

        //We provide the wrong asset
        address[] memory assetsWRONG = new address[](1);
        assetsWRONG[0] = USDC;  

        hevm.expectRevert(bytes("OCY_CVX_Modular::pullFromLockerMulti() asset not equal to BASE_TOKEN"));
        god.try_pullMulti(address(DAO), address(OCY_CVX_FRAX_3CRV), assetsWRONG);

    }

}
