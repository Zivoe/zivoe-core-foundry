// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../lockers/Utility/ZivoeSwapper.sol";
import "../TESTS_Utility/Utility.sol";

// Test (foundry-rs) imports.
import "../../../lib/forge-std/src/Test.sol";

// Interface imports.
interface Hevm {
    function warp(uint256) external;
    function store(address,bytes32,bytes32) external;
    function expectRevert(bytes calldata) external;
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function deal(address to, uint256 give) external;
    function deal(address token, address to, uint256 give) external;
}


contract Test_ZivoeSwapper is DSTest {

    using SafeERC20 for IERC20;

    Hevm hevm;      /// @dev The core import of Hevm from Test.sol to support simulations.
    ZivoeSwapper swapper;

    function setUp() public {

        swapper = new ZivoeSwapper();
        hevm = Hevm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    }

    // ============================ "7c025200": swap() ==========================

    function test_swap_validation() public {

        bytes memory data = "";
        address assetIn;
        address assetOut;
        uint256 amountIn;

        // fund user with the right amount of tokens to swap.
        hevm.deal(assetIn, address(swapper), amountIn);

        // ensure we go through the right validation function.
        bytes4 sig = bytes4(data[:4]);
        assert(sig == bytes4(keccak256("swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)")));

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(user));
        assertEq(0, IERC20(assetOut).balanceOf(user));

        hevm.prank(address(swapper));
        swapper.convertAsset(
            assetIn,
            assetOut,
            amountIn,
            data
        );

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(user));
        assert(IERC20(assetOut).balanceOf(user) > 0);
    }

    function test_swap_restrictions() public {

    }

    // ==================== "e449022e": uniswapV3Swap() ==========================

    function test_uniswapV3Swap_validation() public {
        bytes memory data = "";
        address assetIn;
        address assetOut;
        uint256 amountIn;

        // fund user with the right amount of tokens to swap.
        hevm.deal(assetIn, user, amountIn);

        // ensure we go through the right validation function.
        bytes4 sig = bytes4(data[:4]);
        assert(sig == bytes4(keccak256("uniswapV3Swap(uint256,uint256,uint256[])")));

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(user));
        assertEq(0, IERC20(assetOut).balanceOf(user));

        hevm.prank(address(swapper));
        swapper.convertAsset(
            assetIn,
            assetOut,
            amountIn,
            data
        );

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(user));
        assert(IERC20(assetOut).balanceOf(user) > 0);
    }


    // ======================== "2e95b6c8": unoswap() ============================

    function test_unoswap_validation() public {
        bytes memory data = "";
        address assetIn;
        address assetOut;
        uint256 amountIn;

        // fund user with the right amount of tokens to swap.
        hevm.deal(assetIn, user, amountIn);

        // ensure we go through the right validation function.
        bytes4 sig = bytes4(data[:4]);
        assert(sig == bytes4(keccak256("unoswap(address,uint256,uint256,bytes32[])")));

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(user));
        assertEq(0, IERC20(assetOut).balanceOf(user));

        hevm.prank(address(swapper));
        swapper.convertAsset(
            assetIn,
            assetOut,
            amountIn,
            data
        );

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(user));
        assert(IERC20(assetOut).balanceOf(user) > 0);
    }



    // ===================== "d0a3b665": fillOrderRFQ() ==========================

    function test_fillOrderRFQ_validation() public {
        bytes memory data = "";
        address assetIn;
        address assetOut;
        uint256 amountIn;

        // fund user with the right amount of tokens to swap.
        hevm.deal(assetIn, user, amountIn);

        // ensure we go through the right validation function.
        bytes4 sig = bytes4(data[:4]);
        assert(sig == bytes4(keccak256(
            "fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256)")));

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(user));
        assertEq(0, IERC20(assetOut).balanceOf(user));

        hevm.prank(address(swapper));
        swapper.convertAsset(
            assetIn,
            assetOut,
            amountIn,
            data
        );

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(user));
        assert(IERC20(assetOut).balanceOf(user) > 0);
    }


    // ====================== "b0431182": clipperSwap() ==========================

    function test_clipperSwap_validation() public {
        bytes memory data = "";
        address assetIn;
        address assetOut;
        uint256 amountIn;

        // fund user with the right amount of tokens to swap.
        hevm.deal(assetIn, user, amountIn);

        // ensure we go through the right validation function.
        bytes4 sig = bytes4(data[:4]);
        assert(sig == bytes4(keccak256("clipperSwap(address,address,uint256,uint256)")));

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(user));
        assertEq(0, IERC20(assetOut).balanceOf(user));

        hevm.prank(address(swapper));
        swapper.convertAsset(
            assetIn,
            assetOut,
            amountIn,
            data
        );

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(user));
        assert(IERC20(assetOut).balanceOf(user) > 0);
    }


}