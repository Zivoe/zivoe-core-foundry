// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCL/OCL_ZVE_UNIV2.sol";

contract Test_OCL_ZVE_UNIV2 is Utility {

    OCL_ZVE_UNIV2 OCL_ZVE_UNIV2_DAI;
    OCL_ZVE_UNIV2 OCL_ZVE_UNIV2_FRAX;
    OCL_ZVE_UNIV2 OCL_ZVE_UNIV2_USDC;
    OCL_ZVE_UNIV2 OCL_ZVE_UNIV2_USDT;

    function setUp() public {

        deployCore(false);

        // Simulate ITO (10mm * 8 * 4), DAI/FRAX/USDC/USDT.
        simulateITO(10_000_000 ether, 10_000_000 ether, 10_000_000 * USD, 10_000_000 * USD);

        // Initialize and whitelist OCL_ZVE_UNIV2 locker's.
        OCL_ZVE_UNIV2_DAI = new OCL_ZVE_UNIV2(address(DAO), address(GBL), DAI);
        OCL_ZVE_UNIV2_FRAX = new OCL_ZVE_UNIV2(address(DAO), address(GBL), FRAX);
        OCL_ZVE_UNIV2_USDC = new OCL_ZVE_UNIV2(address(DAO), address(GBL), USDC);
        OCL_ZVE_UNIV2_USDT = new OCL_ZVE_UNIV2(address(DAO), address(GBL), USDT);

        god.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_DAI), true);
        god.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_FRAX), true);
        god.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_USDC), true);
        god.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_USDT), true);

    }

    function test_OCL_ZVE_UNIV2_init() public {
        
        // Adjustable variables based on constructor().
        assertEq(OCL_ZVE_UNIV2_DAI.pairAsset(), DAI);
        assertEq(OCL_ZVE_UNIV2_FRAX.pairAsset(), FRAX);
        assertEq(OCL_ZVE_UNIV2_USDC.pairAsset(), USDC);
        assertEq(OCL_ZVE_UNIV2_USDT.pairAsset(), USDT);

        assertEq(OCL_ZVE_UNIV2_DAI.owner(), address(DAO));
        assertEq(OCL_ZVE_UNIV2_FRAX.owner(), address(DAO));
        assertEq(OCL_ZVE_UNIV2_USDC.owner(), address(DAO));
        assertEq(OCL_ZVE_UNIV2_USDT.owner(), address(DAO));

        assertEq(OCL_ZVE_UNIV2_DAI.GBL(), address(GBL));
        assertEq(OCL_ZVE_UNIV2_FRAX.GBL(), address(GBL));
        assertEq(OCL_ZVE_UNIV2_USDC.GBL(), address(GBL));
        assertEq(OCL_ZVE_UNIV2_USDT.GBL(), address(GBL));

        // Constants check, only need to check one instance.
        assertEq(OCL_ZVE_UNIV2_DAI.UNIV2_ROUTER(), 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        assertEq(OCL_ZVE_UNIV2_DAI.UNIV2_FACTORY(), 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        assertEq(OCL_ZVE_UNIV2_DAI.baseline(), 0);
        assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), 0);
        assertEq(OCL_ZVE_UNIV2_DAI.amountForConversion(), 0);
        assertEq(OCL_ZVE_UNIV2_DAI.compoundingRateBIPS(), 5000);

        assert(OCL_ZVE_UNIV2_DAI.canPushMulti());
        assert(OCL_ZVE_UNIV2_DAI.canPull());
        assert(OCL_ZVE_UNIV2_DAI.canPullPartial());
 
    }

    // Validate pushToLockerMulti() state changes (initial call).
    // Validate pushToLockerMulti() state changes (subsequent calls).
    // Validate pushToLockerMulti() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.
    //  - Only callable if assets[0] == pairAsset && assets[1] == $ZVE

    // Validate pullFromLocker() state changes.
    // Validate pullFromLocker() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.
    //  - Only callable if asset == pair (the UNIV2 LP token).

    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.
    //  - Only callable if asset == pair (the UNIV2 LP token).

    // Validate setExponentialDecayPerSecond() state changes.
    // Validate setExponentialDecayPerSecond() restrictions.
    // This includes:
    //  - Only governance contract (TLC / "god") may call this function.

    // // Simulate depositing various stablecoins into OCL_ZVE_UNIV2.sol from ZivoeDAO.sol via ZivoeDAO::pushToLocker().

    // function xtest_OCL_ZVE_UNIV2_pushMulti_FRAX() public {

    //     address[] memory assets = new address[](2);
    //     uint256[] memory amounts = new uint256[](2);

    //     assets[0] = FRAX;
    //     assets[1] = address(ZVE);

    //     amounts[0] = 1000000 * 10**18;
    //     amounts[1] = 200000 * 10**18;

    //     assert(god.try_pushMulti(address(DAO), address(OCL_UNI), assets, amounts));


    // }

    // function buyZVE_FRAX(uint256 amt) public {
    //     mint("FRAX", address(this), amt);
    //     IERC20(FRAX).approve(OCL_UNI.UNIV2_ROUTER(), amt);
    //     // function swapExactTokensForTokens(
    //     //     uint amountIn,
    //     //     uint amountOutMin,
    //     //     address[] calldata path,
    //     //     address to,
    //     //     uint deadline
    //     // ) external returns (uint[] memory amounts);
    //     address[] memory path = new address[](2);
    //     path[0] = FRAX;
    //     path[1] = address(ZVE);
    //     IUniswapV2Router01(OCL_UNI.UNIV2_ROUTER()).swapExactTokensForTokens(
    //         amt, 0, path, address(this), block.timestamp + 5 days
    //     );
    // }

    // function xtest_OCL_ZVE_UNIV2_pullMulti_FRAX_pullFromLocker() public {

    //     address[] memory assets = new address[](2);
    //     uint256[] memory amounts = new uint256[](2);

    //     assets[0] = FRAX;
    //     assets[1] = address(ZVE);

    //     amounts[0] = 1000000 * 10**18;
    //     amounts[1] = 200000 * 10**18;

    //     assert(god.try_pushMulti(address(DAO), address(OCL_UNI), assets, amounts));

    //     address[] memory assets_pull = new address[](2);
    //     assets_pull[0] = FRAX;
    //     assets_pull[1] = address(ZVE);

    //     assert(god.try_pullMulti(address(DAO), address(OCL_UNI), assets_pull));

    // }

    // function xtest_OCL_ZVE_UNIV2_pushMulti_FRAX_forwardYield() public {

    //     address[] memory assets = new address[](2);
    //     uint256[] memory amounts = new uint256[](2);

    //     assets[0] = FRAX;
    //     assets[1] = address(ZVE);

    //     amounts[0] = 1000000 * 10**18;
    //     amounts[1] = 200000 * 10**18;

    //     assert(god.try_pushMulti(address(DAO), address(OCL_UNI), assets, amounts));

    //     (uint256 amt, uint256 lp) = OCL_UNI.FRAXConvertible();

    //     emit Debug("a", 11111);
    //     emit Debug("a", amt);
    //     emit Debug("a", 11111);
    //     emit Debug("a", lp);

    //     emit Debug("baseline", OCL_UNI.baseline());

    //     buyZVE_FRAX(100000 ether);
        
    //     (amt, lp) = OCL_UNI.FRAXConvertible();
    //     emit Debug("a", 22222);
    //     emit Debug("a", amt);
    //     emit Debug("a", 22222);
    //     emit Debug("a", lp);

    //     emit Debug("baseline", OCL_UNI.baseline());
        
    //     hevm.warp(block.timestamp + 31 days);
    //     OCL_UNI.forwardYield();
        
    //     (amt, lp) = OCL_UNI.FRAXConvertible();
    //     emit Debug("a", 33333);
    //     emit Debug("a", amt);
    //     emit Debug("a", 33333);
    //     emit Debug("a", lp);

    // }

}
