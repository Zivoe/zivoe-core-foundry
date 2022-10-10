// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCL/OCL_ZVE_SUSHI.sol";

contract Test_OCL_ZVE_SUSHI is Utility {

    OCL_ZVE_SUSHI OCL_ZVE_SUSHI_DAI;
    OCL_ZVE_SUSHI OCL_ZVE_SUSHI_FRAX;
    OCL_ZVE_SUSHI OCL_ZVE_SUSHI_USDC;
    OCL_ZVE_SUSHI OCL_ZVE_SUSHI_USDT;

    function setUp() public {

        deployCore(false);

        // Simulate ITO (10mm * 8 * 4), DAI/FRAX/USDC/USDT.
        simulateITO(10_000_000 ether, 10_000_000 ether, 10_000_000 * USD, 10_000_000 * USD);

        // Initialize and whitelist OCL_ZVE_SUSHI locker's.
        OCL_ZVE_SUSHI_DAI = new OCL_ZVE_SUSHI(address(DAO), address(GBL), DAI);
        OCL_ZVE_SUSHI_FRAX = new OCL_ZVE_SUSHI(address(DAO), address(GBL), FRAX);
        OCL_ZVE_SUSHI_USDC = new OCL_ZVE_SUSHI(address(DAO), address(GBL), USDC);
        OCL_ZVE_SUSHI_USDT = new OCL_ZVE_SUSHI(address(DAO), address(GBL), USDT);

        god.try_updateIsLocker(address(GBL), address(OCL_ZVE_SUSHI_DAI), true);
        god.try_updateIsLocker(address(GBL), address(OCL_ZVE_SUSHI_FRAX), true);
        god.try_updateIsLocker(address(GBL), address(OCL_ZVE_SUSHI_USDC), true);
        god.try_updateIsLocker(address(GBL), address(OCL_ZVE_SUSHI_USDT), true);

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function buyZVE(uint256 amt, address pairAsset) public {

        address SUSHI_ROUTER = OCL_ZVE_SUSHI_DAI.SUSHI_ROUTER();
        address[] memory path = new address[](2);
        path[1] = address(ZVE);

        if (pairAsset == DAI) {
            mint("DAI", address(this), amt);
            IERC20(DAI).approve(SUSHI_ROUTER, amt);
            path[0] = DAI;
        }
        else if (pairAsset == FRAX) {
            mint("FRAX", address(this), amt);
            IERC20(FRAX).approve(SUSHI_ROUTER, amt);
            path[0] = FRAX;
        }
        else if (pairAsset == USDC) {
            mint("USDC", address(this), amt);
            IERC20(USDC).approve(SUSHI_ROUTER, amt);
            path[0] = USDC;
        }
        else if (pairAsset == USDT) {
            mint("USDT", address(this), amt);
            IERC20(USDT).approve(SUSHI_ROUTER, amt);
            path[0] = USDT;
        }
        else { revert(); }

        // function swapExactTokensForTokens(
        //     uint amountIn,
        //     uint amountOutMin,
        //     address[] calldata path,
        //     address to,
        //     uint deadline
        // ) external returns (uint[] memory amounts);
        ISushiRouter(SUSHI_ROUTER).swapExactTokensForTokens(
            amt, 
            0, 
            path, 
            address(this), 
            block.timestamp + 5 days
        );
    }


    // ----------------
    //    Unit Tests
    // ----------------

    function test_OCL_ZVE_SUSHI_init() public {

        // Adjustable variables based on constructor().
        assertEq(OCL_ZVE_SUSHI_DAI.pairAsset(), DAI);
        assertEq(OCL_ZVE_SUSHI_FRAX.pairAsset(), FRAX);
        assertEq(OCL_ZVE_SUSHI_USDC.pairAsset(), USDC);
        assertEq(OCL_ZVE_SUSHI_USDT.pairAsset(), USDT);

        assertEq(OCL_ZVE_SUSHI_DAI.owner(), address(DAO));
        assertEq(OCL_ZVE_SUSHI_FRAX.owner(), address(DAO));
        assertEq(OCL_ZVE_SUSHI_USDC.owner(), address(DAO));
        assertEq(OCL_ZVE_SUSHI_USDT.owner(), address(DAO));

        assertEq(OCL_ZVE_SUSHI_DAI.GBL(), address(GBL));
        assertEq(OCL_ZVE_SUSHI_FRAX.GBL(), address(GBL));
        assertEq(OCL_ZVE_SUSHI_USDC.GBL(), address(GBL));
        assertEq(OCL_ZVE_SUSHI_USDT.GBL(), address(GBL));

        // Constants check, only need to check one instance.
        assertEq(OCL_ZVE_SUSHI_DAI.SUSHI_ROUTER(), 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
        assertEq(OCL_ZVE_SUSHI_DAI.SUSHI_FACTORY(), 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);
        assertEq(OCL_ZVE_SUSHI_DAI.baseline(), 0);
        assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), 0);
        assertEq(OCL_ZVE_SUSHI_DAI.amountForConversion(), 0);
        assertEq(OCL_ZVE_SUSHI_DAI.compoundingRateBIPS(), 5000);

        assert(OCL_ZVE_SUSHI_DAI.canPushMulti());
        assert(OCL_ZVE_SUSHI_DAI.canPull());
        assert(OCL_ZVE_SUSHI_DAI.canPullPartial());
    }

    // Simulate depositing various stablecoins into OCL_ZVE_SUSHI.sol from ZivoeDAO.sol via ZivoeDAO::pushToLocker().

    // function xtest_OCL_ZVE_SUSHI_pushMulti_FRAX_generic() public {

    //     address[] memory assets = new address[](2);
    //     uint256[] memory amounts = new uint256[](2);

    //     assets[0] = FRAX;
    //     assets[1] = address(ZVE);

    //     amounts[0] = 1000000 * 10**18;
    //     amounts[1] = 200000 * 10**18;

    //     assert(god.try_pushMulti(address(DAO), address(OCL_SUSHI), assets, amounts));


    // }

    // function xtest_OCL_ZVE_SUSHI_pullMulti_FRAX_pullFromLocker() public {

    //     address[] memory assets = new address[](2);
    //     uint256[] memory amounts = new uint256[](2);

    //     assets[0] = FRAX;
    //     assets[1] = address(ZVE);

    //     amounts[0] = 1000000 * 10**18;
    //     amounts[1] = 200000 * 10**18;

    //     assert(god.try_pushMulti(address(DAO), address(OCL_SUSHI), assets, amounts));

    //     address[] memory assets_pull = new address[](2);
    //     assets_pull[0] = FRAX;
    //     assets_pull[1] = address(ZVE);

    //     assert(god.try_pullMulti(address(DAO), address(OCL_SUSHI), assets_pull));

    // }

    // function xtest_OCL_ZVE_SUSHI_pushMulti_FRAX_forwardYield() public {

    //     address[] memory assets = new address[](2);
    //     uint256[] memory amounts = new uint256[](2);

    //     assets[0] = FRAX;
    //     assets[1] = address(ZVE);

    //     amounts[0] = 1000000 * 10**18;
    //     amounts[1] = 200000 * 10**18;

    //     assert(god.try_pushMulti(address(DAO), address(OCL_SUSHI), assets, amounts));

    //     (uint256 amt, uint256 lp) = OCL_SUSHI.FRAXConvertible();

    //     emit Debug("a", 11111);
    //     emit Debug("a", amt);
    //     emit Debug("a", 11111);
    //     emit Debug("a", lp);

    //     emit Debug("baseline", OCL_SUSHI.baseline());

    //     buyZVE_FRAX(100000 ether);
        
    //     (amt, lp) = OCL_SUSHI.FRAXConvertible();
    //     emit Debug("a", 22222);
    //     emit Debug("a", amt);
    //     emit Debug("a", 22222);
    //     emit Debug("a", lp);

    //     emit Debug("baseline", OCL_SUSHI.baseline());
        
    //     hevm.warp(block.timestamp + 31 days);
    //     OCL_SUSHI.forwardYield();
        
    //     (amt, lp) = OCL_SUSHI.FRAXConvertible();
    //     emit Debug("a", 33333);
    //     emit Debug("a", amt);
    //     emit Debug("a", 33333);
    //     emit Debug("a", lp);

    // }

}
