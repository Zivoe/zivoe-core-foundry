// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../TESTS_Utility/Utility.sol";

import "../../../lockers/OCY/production/OCY_CVX_Modular.sol";
import "../../../../lib/OpenZeppelin/SafeERC20.sol";

import {ICVX_Booster, ICRVMetaPool, SwapDescription, IConvexRewards} from "../../../misc/InterfacesAggregated.sol";

contract Test_OCY_CVX_Modular is Utility {

    using SafeERC20 for IERC20;

    OCY_CVX_Modular OCY_CVX_FRAX_USDC;
    OCY_CVX_Modular OCY_CVX_MIM_3CRV;
    OCY_CVX_Modular OCY_CVX_FRAX_3CRV;

    address randomUser = 0x5a29280d4668622ae19B8bd0bacE271F11Ac89dA;
    
    function setUp() public {

        deployCore(false);

        address convex_deposit_address = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;

        // Init metaOrPlainPool
        bool metaOrPlainPool_FRAX_USDC = false;
        bool metaOrPlainPool_MIM_3CRV = true;
        bool metaOrPlainPool_FRAX_3CRV = true;

        // Init pool rewards
        address[] memory extraRewards_FRAX_USDC = new address[](1);
        address[] memory extraRewards_MIM_3CRV = new address[](1);
        address[] memory extraRewards_FRAX_3CRV = new address[](1);

        extraRewards_FRAX_USDC[0] = address(0);
        extraRewards_MIM_3CRV[0] = 0x090185f2135308BaD17527004364eBcC2D37e5F6;
        extraRewards_FRAX_3CRV[0] = 0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0;

        // Init chainlink price feeds
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


        OCY_CVX_FRAX_USDC = new OCY_CVX_Modular(
            address(GBL),
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

        OCY_CVX_MIM_3CRV = new OCY_CVX_Modular(
            address(GBL),
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
        
        OCY_CVX_FRAX_3CRV = new OCY_CVX_Modular(
            address(GBL),
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

    function test_p_OCY_CVX_Modular_init() public {

        // In common
        assertEq(OCY_CVX_FRAX_USDC.GBL(),                     address(GBL));
        assertEq(OCY_CVX_FRAX_USDC.CVX_Deposit_Address(),     0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
        assertEq(OCY_CVX_FRAX_USDC.CRV(),                     0xD533a949740bb3306d119CC777fa900bA034cd52);
        assertEq(OCY_CVX_FRAX_USDC.CVX(),                     0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);    
        assertEq(OCY_CVX_FRAX_USDC.owner(),                   address(DAO));        
       
        // Plain Pool
        assert(OCY_CVX_FRAX_USDC.metaOrPlainPool() == false);
        assert(OCY_CVX_FRAX_USDC.extraRewards()    == false);

        assertEq(OCY_CVX_FRAX_USDC.convexPoolID(),            100);
        assertEq(OCY_CVX_FRAX_USDC.CVX_Reward_Address(),      0x7e880867363A7e321f5d260Cade2B0Bb2F717B02);
        assertEq(OCY_CVX_FRAX_USDC.curvePool(),               0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2);
        assertEq(OCY_CVX_FRAX_USDC.POOL_LP_TOKEN(),           0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
        assertEq(OCY_CVX_FRAX_USDC.PP_TOKENS(0),              0x853d955aCEf822Db058eb8505911ED77F175b99e);
        assertEq(OCY_CVX_FRAX_USDC.PP_TOKENS(1),              0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        assertEq(OCY_CVX_FRAX_USDC.chainlinkPriceFeeds(0),    0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD);
        assertEq(OCY_CVX_FRAX_USDC.chainlinkPriceFeeds(1),    0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);

        // Meta pool
        assert(OCY_CVX_MIM_3CRV.metaOrPlainPool() == true);
        assert(OCY_CVX_MIM_3CRV.extraRewards()    == true);

        assertEq(OCY_CVX_MIM_3CRV.convexPoolID(),                   40);
        assertEq(OCY_CVX_MIM_3CRV.numberOfTokensUnderlyingLPPool(), 3);
        assertEq(OCY_CVX_MIM_3CRV.CVX_Reward_Address(),             0xFd5AbF66b003881b88567EB9Ed9c651F14Dc4771);
        assertEq(OCY_CVX_MIM_3CRV.curvePool(),                      0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
        assertEq(OCY_CVX_MIM_3CRV.POOL_LP_TOKEN(),                  0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
        assertEq(OCY_CVX_MIM_3CRV.BASE_TOKEN(),                     0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
        assertEq(OCY_CVX_MIM_3CRV.extraRewardsAddresses(0),         0x090185f2135308BaD17527004364eBcC2D37e5F6);
        assertEq(OCY_CVX_MIM_3CRV.MP_UNDERLYING_LP_POOL(),          0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
        assertEq(OCY_CVX_MIM_3CRV.chainlinkPriceFeeds(0),           0x7A364e8770418566e3eb2001A96116E6138Eb32F);
        assertEq(OCY_CVX_MIM_3CRV.chainlinkPriceFeeds(1),           0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9);
        assertEq(OCY_CVX_MIM_3CRV.chainlinkPriceFeeds(2),           0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
        assertEq(OCY_CVX_MIM_3CRV.chainlinkPriceFeeds(3),           0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
    }

}
