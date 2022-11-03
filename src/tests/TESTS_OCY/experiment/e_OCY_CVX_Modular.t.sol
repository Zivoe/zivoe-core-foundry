// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../TESTS_Utility/Utility.sol";

import "../../../lockers/OCY/experiment/e_OCY_CVX_Modular.sol";
import "../../../../lib/OpenZeppelin/SafeERC20.sol";

import {ICVX_Booster, ICRVMetaPool, SwapDescription, IConvexRewards} from "../../../misc/InterfacesAggregated.sol";

interface ICurveRegistry {
    function get_n_coins(address) external view returns (uint256[2] memory);
}

contract Test_e_OCY_CVX_Modular is Utility {

    using SafeERC20 for IERC20;

    e_OCY_CVX_Modular OCY_CVX_FRAX_USDC;
    e_OCY_CVX_Modular OCY_CVX_MIM_3CRV;
    e_OCY_CVX_Modular OCY_CVX_FRAX_3CRV;

    address randomUser = 0x5a29280d4668622ae19B8bd0bacE271F11Ac89dA;

    function investInLockerMP(
        e_OCY_CVX_Modular locker, 
        address tokenReceived, 
        uint256 amount) 
        public returns (address[] memory _assets) {
        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = tokenReceived;
        amounts[0] = amount;

        if (tokenReceived == FRAX) {
            mint("FRAX", address(DAO), amount);
        }

        assert(god.try_pushMulti(address(DAO), address(locker), assets, amounts));

        hevm.warp(block.timestamp + 25 hours);
        locker.invest();

        return assets;
    }

    function investInLockerPP_FRAX_USDC() public returns(address[] memory _assets) {

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

        return assets;

    }

    function triggerUpdateReward() public {
        address FRAX_USDC_CurvePool = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
        address convex_deposit = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
        address curvePoolLP = ICVX_Booster(convex_deposit).poolInfo(100).lptoken;
        mint("FRAX", randomUser, 400000 * 10**18);
        mint("USDC", randomUser, 100000 * 10**6);

        uint256[2] memory deposits_pp;

        deposits_pp[0] = 400000 * 10**18;
        deposits_pp[1] = 100000 * 10**6;

        IERC20(FRAX).safeApprove(FRAX_USDC_CurvePool, 400000 * 10**18);
        IERC20(USDC).safeApprove(FRAX_USDC_CurvePool, 100000 * 10**6);

        ICRVPlainPoolFBP(FRAX_USDC_CurvePool).add_liquidity(deposits_pp, 0); 
        IERC20(curvePoolLP).safeApprove(convex_deposit, IERC20(curvePoolLP).balanceOf(randomUser));
        // will trigger stakeFor fct in baseRewardPool.
        ICVX_Booster(convex_deposit).depositAll(100, true);

    }


    
    function setUp() public {

        deployCore(false);

        address convex_deposit_address = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;

        //init Zivoe addresses
        address[] memory zivoeAddresses = new address[](2);
        zivoeAddresses[0] = address(DAO);
        zivoeAddresses[1] = address(GBL);

        //init metaOrPlainPool
        bool metaOrPlainPool_FRAX_USDC = false;
        bool metaOrPlainPool_MIM_3CRV = true;
        bool metaOrPlainPool_FRAX_3CRV = true;

        //init pool rewards
        address[] memory extraRewards_FRAX_USDC = new address[](1);
        address[] memory extraRewards_MIM_3CRV = new address[](1);
        address[] memory extraRewards_FRAX_3CRV = new address[](1);

        extraRewards_FRAX_USDC[0] = address(0);
        extraRewards_MIM_3CRV[0] = 0x090185f2135308BaD17527004364eBcC2D37e5F6;
        extraRewards_FRAX_3CRV[0] = 0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0;

        //init chainlink price feeds
        address[] memory chainlink_FRAX_USDC = new address[](2);
        address[] memory chainlink_MIM_3CRV = new address[](4);
        address[] memory chainlink_FRAX_3CRV = new address[](4);

        chainlink_FRAX_USDC[0] = 0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD;
        chainlink_FRAX_USDC[1] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

        chainlink_MIM_3CRV[0] = 0x7A364e8770418566e3eb2001A96116E6138Eb32F;
        chainlink_MIM_3CRV[1] = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
        chainlink_MIM_3CRV[2] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
        chainlink_MIM_3CRV[3] = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;

        chainlink_FRAX_3CRV[0] = 0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD;
        chainlink_FRAX_3CRV[1] = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
        chainlink_FRAX_3CRV[2] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
        chainlink_FRAX_3CRV[3] = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;


        OCY_CVX_FRAX_USDC = new e_OCY_CVX_Modular(
            zivoeAddresses,
            metaOrPlainPool_FRAX_USDC, 
            0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2, 
            convex_deposit_address,
            extraRewards_FRAX_USDC,  
            address(0),
            address(0),
            0,
            2, 
            100,
            chainlink_FRAX_USDC);

        OCY_CVX_MIM_3CRV = new e_OCY_CVX_Modular(
            zivoeAddresses,
            metaOrPlainPool_MIM_3CRV, 
            0x5a6A4D54456819380173272A5E8E9B9904BdF41B, 
            convex_deposit_address, 
            extraRewards_MIM_3CRV,
            0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3,
            0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7,
            3,
            0, 
            40,
            chainlink_MIM_3CRV);
        
        OCY_CVX_FRAX_3CRV = new e_OCY_CVX_Modular(
            zivoeAddresses,
            metaOrPlainPool_FRAX_3CRV, 
            0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B,
            convex_deposit_address,
            extraRewards_FRAX_3CRV,
            FRAX,
            0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7,
            3,
            0,
            32,
            chainlink_FRAX_3CRV);
    

        zvl.try_updateIsLocker(address(GBL), address(OCY_CVX_FRAX_USDC), true);
        zvl.try_updateIsLocker(address(GBL), address(OCY_CVX_MIM_3CRV), true);
        zvl.try_updateIsLocker(address(GBL), address(OCY_CVX_FRAX_3CRV), true);

        address vb2 = 0x1Db3439a222C519ab44bb1144fC28167b4Fa6EE6;

        zvl.try_updateIsKeeper(address(GBL), vb2, true);


    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function test_e_OCY_CVX_Modular_init() public {

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
        assertEq(OCY_CVX_FRAX_USDC.chainlinkPriceFeeds(0),     0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD);
        assertEq(OCY_CVX_FRAX_USDC.chainlinkPriceFeeds(1),     0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);

        ///Meta pool
        assert(OCY_CVX_MIM_3CRV.metaOrPlainPool() == true);
        assert(OCY_CVX_MIM_3CRV.extraRewards()    == true);

        assertEq(OCY_CVX_MIM_3CRV.convexPoolID(),                   40);
        assertEq(OCY_CVX_MIM_3CRV.numberOfTokensUnderlyingLPPool(), 3);
        assertEq(OCY_CVX_MIM_3CRV.CVX_Reward_Address(),             0xFd5AbF66b003881b88567EB9Ed9c651F14Dc4771);
        assertEq(OCY_CVX_MIM_3CRV.pool(),                           0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
        assertEq(OCY_CVX_MIM_3CRV.POOL_LP_TOKEN(),                  0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
        assertEq(OCY_CVX_MIM_3CRV.BASE_TOKEN(),                     0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
        assertEq(OCY_CVX_MIM_3CRV.extraRewardsAddresses(0),         0x090185f2135308BaD17527004364eBcC2D37e5F6);
        assertEq(OCY_CVX_MIM_3CRV.MP_UNDERLYING_LP_POOL(),          0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
        assertEq(OCY_CVX_MIM_3CRV.chainlinkPriceFeeds(0),           0x7A364e8770418566e3eb2001A96116E6138Eb32F);
        assertEq(OCY_CVX_MIM_3CRV.chainlinkPriceFeeds(1),           0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9);
        assertEq(OCY_CVX_MIM_3CRV.chainlinkPriceFeeds(2),           0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
        assertEq(OCY_CVX_MIM_3CRV.chainlinkPriceFeeds(3),           0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);

        uint256[2] memory assets;
        assets = ICurveRegistry(0x90E00ACe148ca3b23Ac1bC8C240C2a7Dd9c2d7f5).get_n_coins(0x3211C6cBeF1429da3D0d58494938299C92Ad5860);
        emit log_named_uint("ncoins1:", assets[0]);
        emit log_named_uint("ncoins2:", assets[1]);

    }

    function test_e_OCY_CVX_Modular_pushMulti_USDC_USDT_FRAX_DAI() public {

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
        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_MIM_3CRV), assets, amounts));

        assert(IERC20(DAI).balanceOf(address(OCY_CVX_MIM_3CRV)) == 500000 * 10**18);
        assert(IERC20(USDC).balanceOf(address(OCY_CVX_MIM_3CRV)) == 200000 * 10**6);
        assert(IERC20(USDT).balanceOf(address(OCY_CVX_MIM_3CRV)) == 300000 * 10**6);  
        assert(IERC20(FRAX).balanceOf(address(OCY_CVX_MIM_3CRV)) == 500000 * 10**18); 


    }

    ///Test to see the difference between depositing a 3CRV token or the BASE_TOKEN in a metapool with 11% 3CRV token vs BASE_TOKEN
    ///Results are better for 1) DAI=>(convert on 1inch) MIM => deposit in MP over 2) DAI=>deposit in 3CRV=>deposit in MP.
    function test_e_OCY_CVX_Modular_Deposit3CRV() public {
        uint256[2] memory amounts;
        amounts[1] = 977400 * 10**18;
        uint256 lptokensReceived = ICRVPlainPoolFBP(0x5a6A4D54456819380173272A5E8E9B9904BdF41B).calc_token_amount(amounts, true);
        emit log_uint(lptokensReceived);

        uint256[2] memory amountsforMIM;
        amountsforMIM[0] = 1004000 * 10**18;  
        uint256 lptokensReceivedMIM = ICRVPlainPoolFBP(0x5a6A4D54456819380173272A5E8E9B9904BdF41B).calc_token_amount(amountsforMIM, true);      
        emit log_uint(lptokensReceivedMIM);

    }

    function test_e_OCY_CVX_Modular_Invest_PP_FRAX_USDC() public {

        investInLockerPP_FRAX_USDC();

        //Ensuring number of LP tokens staked on Convex is within 5000 (out of 700k)
        withinDiff(IERC20(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_USDC)), 700000 * 10**18, 5000 * 10**18);

        emit log_named_uint("Number of LP Token staked on Convex:", IERC20(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_USDC)));

        // Ok we get 0 because the convex lp token is staked directly
        emit log_named_uint("cvxcrvFRAX Balance (should=0):", ERC20(0x117A0bab81F25e60900787d98061cCFae023560c).balanceOf(address(OCY_CVX_FRAX_USDC)));

    }

    function test_e_OCY_CVX_Modular_Invest_PP_FRAX_USDC_fail_timelock() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = USDC;

        amounts[0] = 500000 * 10**18;
        amounts[1] = 200000 * 10**6;

        mint("FRAX", address(DAO), 500000 * 10**18);
        mint("USDC", address(DAO), 200000 * 10**6);

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_USDC), assets, amounts));

        // We don't let more than 24 hours pass - should fail.
        hevm.expectRevert("timelock - restricted to keepers for now");
        OCY_CVX_FRAX_USDC.invest();
    }

    function test_e_OCY_CVX_Modular_Invest_PP_FRAX_USDC_keeper() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = USDC;

        amounts[0] = 500000 * 10**18;
        amounts[1] = 200000 * 10**6;

        mint("FRAX", address(DAO), 500000 * 10**18);
        mint("USDC", address(DAO), 200000 * 10**6);

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_USDC), assets, amounts));

        // We don't let more than 24 hours pass - but keeper thus should succeed.
        address keeper = 0x1Db3439a222C519ab44bb1144fC28167b4Fa6EE6;
        hevm.startPrank(keeper);
        OCY_CVX_FRAX_USDC.invest();
        hevm.stopPrank();
    }



    function test_e_OCY_CVX_Modular_Invest_MP_FRAX_3CRV() public {

        investInLockerMP(OCY_CVX_FRAX_3CRV, FRAX, 50000 *10**18);

        //Ensuring number of LP tokens staked on Convex is within 2000 (out of 50k)
        withinDiff(IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)), 50000 * 10**18, 2000 * 10**18);

        emit log_named_uint("Number of LP Token staked on Convex:", IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)));

        // Ok we get 0 because the convex lp token is staked directly
        emit log_named_uint("cvxFRAX3CRV Balance: (should=0)", IERC20(0xbE0F6478E0E4894CFb14f32855603A083A57c7dA).balanceOf(address(OCY_CVX_FRAX_3CRV)));

    }

    function test_e_OCY_CVX_Modular_Invest_MP_FRAX_3CRV_fail_timelock() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = FRAX;

        amounts[0] = 50000 * 10**18;

        mint("FRAX", address(DAO), 50000 * 10**18);

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_3CRV), assets, amounts));

        // We don't let more than 24 hours pass - should fail.
        hevm.expectRevert("timelock - restricted to keepers for now");
        OCY_CVX_FRAX_3CRV.invest();
    }

    function test_e_OCY_CVX_Modular_Invest_MP_FRAX_3CRV_keeper() public {

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = FRAX;

        amounts[0] = 50000 * 10**18;

        mint("FRAX", address(DAO), 50000 * 10**18);

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_3CRV), assets, amounts));

        // We don't let more than 24 hours pass - but keeper thus should succeed.
        address keeper = 0x1Db3439a222C519ab44bb1144fC28167b4Fa6EE6;        
        hevm.startPrank(keeper);
        OCY_CVX_FRAX_3CRV.invest();
        hevm.stopPrank();
    }

    function test_e_OCY_CVX_Modular_pullFromLockerMultiPP_FRAX_USDC() public {

        address[] memory assets = investInLockerPP_FRAX_USDC();

        assert(IERC20(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_USDC)) > 0);

        hevm.warp(block.timestamp + 30 days);

        assert(god.try_pullMulti(address(DAO), address(OCY_CVX_FRAX_USDC), assets));

        assert(IERC20(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_USDC)) == 0);

    }

    function test_e_OCY_CVX_Modular_pullFromLockerMultiPP_FRAX_USDC_fail() public {

        investInLockerPP_FRAX_USDC();

        hevm.warp(block.timestamp + 30 days);

        //We provide the wrong assets (in wrong order) - should fail
        address[] memory assetsWRONG = new address[](2);
        assetsWRONG[1] = FRAX;
        assetsWRONG[0] = USDC;

        hevm.startPrank(address(DAO));
        hevm.expectRevert(bytes("e_OCY_CVX_Modular::pullFromLockerMulti() assets input array should be equal to PP_TOKENS array and in the same order"));
        OCY_CVX_FRAX_USDC.pullFromLockerMulti(assetsWRONG); 
        hevm.stopPrank();    

    }

    function test_e_OCY_CVX_Modular_pullFromLockerMultiMP_FRAX_3CRV() public {

        address[] memory assets = investInLockerMP(OCY_CVX_FRAX_3CRV, FRAX, 50000 * 10**18);

        assert(IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)) > 0);

        hevm.warp(block.timestamp + 30 days);

        assert(god.try_pullMulti(address(DAO), address(OCY_CVX_FRAX_3CRV), assets));

        assert(IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)) == 0);       

    }

    function test_e_OCY_CVX_Modular_pullFromLockerMultiMP_FRAX_3CRV_fail() public {

        investInLockerMP(OCY_CVX_FRAX_3CRV, FRAX, 50000 * 10**18);

        assert(IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)) > 0);

        hevm.warp(block.timestamp + 30 days);

        //We provide the wrong asset
        address[] memory assetsWRONG = new address[](1);
        assetsWRONG[0] = USDC;  

        hevm.startPrank(address(DAO));
        hevm.expectRevert(bytes("e_OCY_CVX_Modular::pullFromLockerMulti() asset not equal to BASE_TOKEN"));
        OCY_CVX_FRAX_3CRV.pullFromLockerMulti(assetsWRONG);
        hevm.stopPrank();
    }

    function test_e_OCY_CVX_Modular_pullFromLockerPartialMP_FRAX_3CRV() public {

        investInLockerMP(OCY_CVX_FRAX_3CRV, FRAX, 50000 * 10**18);

        hevm.warp(block.timestamp + 30 days);

        assert(IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)) > 0);

        uint256 lpBalanceInit = IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV));
        uint256 lpToWithdraw = (IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)) / 2) + (1000 *10**18);

        assert(god.try_pullPartial(address(DAO), address(OCY_CVX_FRAX_3CRV), OCY_CVX_FRAX_3CRV.CVX_Reward_Address(), lpToWithdraw));

        assert(IERC20(OCY_CVX_FRAX_3CRV.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_3CRV)) <  (lpBalanceInit / 2));       

    }   

    function test_e_OCY_CVX_Modular_pullFromLockerPartialPP_FRAX_USDC() public {

        investInLockerPP_FRAX_USDC();

        hevm.warp(block.timestamp + 30 days);

        assert(IERC20(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_USDC)) > 0);

        uint256 lpBalanceInit = IERC20(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_USDC));
        uint256 lpToWithdraw = (IERC20(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_USDC)) / 2) + (1000 *10**18);

        emit log_named_uint("Init LP Balance: ", lpBalanceInit);
        assert(god.try_pullPartial(address(DAO), address(OCY_CVX_FRAX_USDC), OCY_CVX_FRAX_USDC.CVX_Reward_Address(), lpToWithdraw));
        emit log_named_uint("LP's to withdraw", lpToWithdraw);

        assert(IERC20(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).balanceOf(address(OCY_CVX_FRAX_USDC)) <  (lpBalanceInit / 2));       

    }

    function test_e_OCY_CVX_Modular_emit() public {
        emit log_named_address("OCY_CVX_FRAX_USDC addres:", address(OCY_CVX_FRAX_USDC));
        emit log_named_address("OCY_CVX_FRAX_3CRV addres:", address(OCY_CVX_FRAX_3CRV));
        emit log_named_address("OCY_CVX_MIM_3CRV addres:", address(OCY_CVX_MIM_3CRV));
    }


   /*  function test_e_OCY_CVX_Modular_FRAX_USDC_1inch() public {
        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = FRAX;
        amounts[0] = 200 * 10**18;

        mint("FRAX", address(DAO), 200 * 10**18);

        assert(god.try_pushMulti(address(DAO), address(OCY_CVX_FRAX_USDC), assets, amounts));

        emit log_named_uint("FRAX locker balance pre-swap:", IERC20(FRAX).balanceOf(address(OCY_CVX_FRAX_USDC)));

        bytes memory data = bytes("0xe449022e00000000000000000000000000000000000000000000000ad78ebc5ac6200000000000000000000000000000000000000000000000000000000000000bcbfeb7000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000009a834b70c07c81a9fcd6f22e842bf002fbffbe4dcfee7c08");

        address keeper = 0x1Db3439a222C519ab44bb1144fC28167b4Fa6EE6;        
        hevm.prank(keeper);
        
        OCY_CVX_FRAX_USDC.keeperConvertStablecoin(FRAX, USDC, data);

        
        emit log_named_uint("USDC locker balance after swap:", IERC20(USDC).balanceOf(address(OCY_CVX_FRAX_USDC)));

    } */

// test for  USD_Convertible + harvestYield + forwardYield
    function test_e_OCY_CVX_Modular_USD_ConvertiblePP_FRAX_USDC() public {
        investInLockerPP_FRAX_USDC();
        uint256 USDConvertible = OCY_CVX_FRAX_USDC.USD_Convertible();
        emit log_named_uint("USD_Convertible FRAX USDC:", USDConvertible);
        //Check that amount is within 2000 USD of invested amount 700k.
        withinDiff(USDConvertible, 700000 * 10**18, 2000 * 10**18);

    }

    function test_e_OCY_CVX_Modular_USD_ConvertibleMP_FRAX_3CRV() public {
        investInLockerMP(OCY_CVX_FRAX_3CRV, FRAX, 50000 * 10**18);
        uint256 USDConvertible = OCY_CVX_FRAX_3CRV.USD_Convertible();  
        emit log_named_uint("USD_Convertible FRAX 3CRV:", USDConvertible);  
        withinDiff(USDConvertible, 50000 * 10**18, 500 * 10**18);       

    }

    function test_e_OCY_CVX_Modular_lpPriceInUSD_PP_FRAX_USDC() public {
        emit log_named_uint("lpPriceInUSD FRAX USDC:", OCY_CVX_FRAX_USDC.lpPriceInUSD());
        assert(OCY_CVX_FRAX_USDC.lpPriceInUSD() > 9 * 10**17 && OCY_CVX_FRAX_3CRV.lpPriceInUSD() < (10**18 + (2 * 10**17)));
    }

    function test_e_OCY_CVX_Modular_lpPriceInUSD_MP_FRAX_3CRV() public {
        emit log_named_uint("lpPriceInUSD FRAX 3CRV:", OCY_CVX_FRAX_3CRV.lpPriceInUSD());
        assert(OCY_CVX_FRAX_3CRV.lpPriceInUSD() > 9 * 10**17 && OCY_CVX_FRAX_3CRV.lpPriceInUSD() < (10**18 + (2 * 10**17)));

    }

    function test_e_OCY_CVX_Modular_harvestYield_PP_FRAX_USDC() public {
        investInLockerPP_FRAX_USDC();    
        hevm.warp(block.timestamp + 6 hours);
        hevm.startPrank(randomUser);
        triggerUpdateReward();
        hevm.stopPrank();
        hevm.warp(block.timestamp + 6 hours);
        hevm.startPrank(address(OCY_CVX_FRAX_USDC));
        IConvexRewards(OCY_CVX_FRAX_USDC.CVX_Reward_Address()).withdrawAllAndUnwrap(true);
        emit log_named_uint("locker CRV rewards:", IERC20(OCY_CVX_FRAX_USDC.CRV()).balanceOf(address(OCY_CVX_FRAX_USDC)));
        emit log_named_uint("locker CVX rewards:", IERC20(OCY_CVX_FRAX_USDC.CVX()).balanceOf(address(OCY_CVX_FRAX_USDC)));


    }

    function test_e_OCY_CVX_Modular_harvestYield_MP_FRAX_USDC() public {
        investInLockerMP(OCY_CVX_FRAX_3CRV, FRAX, 50000 * 10**18);
    }



}
