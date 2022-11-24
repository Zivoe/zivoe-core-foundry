// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../lockers/Utility/ZivoeSwapper.sol";
import "../TESTS_Utility/Utility.sol";
import "../../../lib/OpenZeppelin/SafeERC20.sol";


/// @dev We setup a separate contract in order to be able to call "convertAsset"
///      on the ZivoeSwapper contract as it is an internal function.
contract SwapperTest is ZivoeSwapper {

    using SafeERC20 for IERC20;

    function convertTest(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        bytes calldata data
    ) 
    public
    returns (bytes4 sig)
    {
        sig = bytes4(data[:4]);
        IERC20(assetIn).safeApprove(router1INCH_V4, IERC20(assetIn).balanceOf(address(this)));
        convertAsset(assetIn, assetOut, amountIn, data);
    }
}


contract Test_ZivoeSwapper is Utility {

    using SafeERC20 for IERC20;

    // Initiate contract variable
    SwapperTest swapper;

    // ERC20 token addresses used for testing
    address CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;

    function setUp() public {
        // initiate contract instance
        swapper = new SwapperTest();
        
        // Fund the swapper contract
        deal(address(swapper), 1 ether);
    }


    // ============================ "7c025200": swap() ==========================


    function test_ZivoeSwapper_swap_convertAsset() public {

        bytes memory data = hex"7c02520000000000000000000000000053222470cdcfb8081c0e3a50fd106f0d69e63f2000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000853d955acef822db058eb8505911ed77f175b99e000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000053222470cdcfb8081c0e3a50fd106f0d69e63f20000000000000000000000000ce71065d4017f316ec606fe4422e11eb2c47c24600000000000000000000000000000000000000000001a784379d99db42000000000000000000000000000000000000000000000000000000000001cfde9a359a00000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001360000000000000000000000000000000000000000000000f80000ca0000b05120d632f22692fac7611d2aa1c0d552930d43caed3b853d955acef822db058eb8505911ed77f175b99e0044a6417ed6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001cc9cd8ce430020d6bdbf78a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4880a06c4eca27a0b86991c6218b36c1d19d4a2e9eb0ce3606eb481111111254fb6c44bac0bed2854e76f90643097d00000000000000000000000000000000000000000001a784379d99db4200000000000000000000000000cfee7c08";
        address assetIn = FRAX;
        address assetOut = USDC;
        uint256 amountIn = 2_000_000 ether;

        // fund contract with the right amount of tokens to swap.
        deal(assetIn, address(swapper), amountIn);

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        emit log_named_uint("swapper assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));

        bytes4 sig = swapper.convertTest(
                        assetIn,
                        assetOut,
                        amountIn,
                        data
                    );

        emit log_named_uint("swapper assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));

        // ensure we go through the right validation function.
        assert(sig == bytes4(keccak256("swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)")));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    }
/*
    function test_ZivoeSwapper_swap_restrictions_assetIn() public {
        bytes memory data = "";
        address assetIn;
        address assetOut;
        uint256 amountIn;

        // fund address(swapper) with the right amount of tokens to swap.
        hevm.deal(assetIn, address(swapper), amountIn);

        // ensure we go through the right validation function.
        bytes4 sig = bytes4(data[:4]);
        assert(sig == bytes4(keccak256("swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)")));

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        hevm.expectRevert("");
        swapper.convertAsset(
            assetIn,
            assetOut,
            amountIn,
            data
        );
        hevm.stopPrank();
    }

    function test_ZivoeSwapper_swap_restrictions_assetOut() public {

    }

    function test_ZivoeSwapper_swap_restrictions_amountIn() public {

    }

    function test_ZivoeSwapper_swap_restrictions_receiver() public {
        
    } */


    // ==================== "e449022e": uniswapV3Swap() ==========================


    function test_ZivoeSwapper_uniswapV3Swap_convertAsset() public {
        bytes memory data = hex"e449022e00000000000000000000000000000000000000000000043c33c19375648000000000000000000000000000000000000000000000000004399480e39a4a8ad121000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000020000000000000000000000005777d92f208679db4b9778590fa3cab3ac9e21688000000000000000000000009a834b70c07c81a9fcd6f22e842bf002fbffbe4dcfee7c08";
        address assetIn = DAI;
        address assetOut = FRAX;
        uint256 amountIn = 20_000 ether;

        // fund address(swapper) with the right amount of tokens to swap.
        deal(assetIn, address(swapper), amountIn);

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        emit log_named_uint("swapper assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));

        bytes4 sig = swapper.convertTest(
                        assetIn,
                        assetOut,
                        amountIn,
                        data
                    );

        // ensure we go through the right validation function.
        assert(sig == bytes4(keccak256("uniswapV3Swap(uint256,uint256,uint256[])")));

        emit log_named_uint("swapper assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_assetIn_token0() public {

    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_assetIn_token1() public {

    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_assetOut_token0() public {

    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_assetOut_token1() public {

    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_amountIn() public {

    }


    // ======================== "2e95b6c8": unoswap() ============================

        // handle_validation_2e95b6c8() assetIn != token1()
/*     function test_ZivoeSwapper_unoswap_convertAsset() public {
        bytes memory data = hex"2e95b6c80000000000000000000000006b175474e89094c44da98b954eedeac495271d0f00000000000000000000000000000000000000000000000ad78ebc5ac620000000000000000000000000000000000000000000000000000f41ee4bf12a441a8a0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000200000000000000003b6d0340a478c2975ab1ea89e8196811f51a7b7ade33eb1100000000000000003b6d03403da1313ae46132a397d90d95b1424a9a7e3e0fcecfee7c08";
        address assetIn = DAI;
        address assetOut = CRV;
        uint256 amountIn = 200 ether;

        // fund address(swapper) with the right amount of tokens to swap.
        deal(assetIn, address(swapper), amountIn);

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        bytes4 sig = swapper.convertTest(
                        assetIn,
                        assetOut,
                        amountIn,
                        data
                    );

        // ensure we go through the right validation function.
        assert(sig == bytes4(keccak256("unoswap(address,uint256,uint256,bytes32[])")));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    } */

    function test_ZivoeSwapper_unoswap_restrictions_assetIn() public {

    }

    function test_ZivoeSwapper_unoswap_restrictions_assetIn_token0() public {

    }

    function test_ZivoeSwapper_unoswap_restrictions_assetIn_token1() public {

    }

    function test_ZivoeSwapper_unoswap_restrictions_assetOut_token0() public {

    }

    function test_ZivoeSwapper_unoswap_restrictions_assetOut_token1() public {

    }

    function test_ZivoeSwapper_unoswap_restrictions_amountIn() public {

    }
/*

    // ===================== "d0a3b665": fillOrderRFQ() ==========================


    function test_ZivoeSwapper_fillOrderRFQ_convertAsset() public {
        bytes memory data = "";
        address assetIn;
        address assetOut;
        uint256 amountIn;

        // fund user with the right amount of tokens to swap.
        hevm.deal(assetIn, address(swapper), amountIn);

        // ensure we go through the right validation function.
        bytes4 sig = bytes4(data[:4]);
        assert(sig == bytes4(keccak256(
            "fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256)")));

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        swapper.convertAsset(
            assetIn,
            assetOut,
            amountIn,
            data
        );

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    }

    function test_ZivoeSwapper_fillOrderRFQ_restrictions_assetIn() public {

    }

    function test_ZivoeSwapper_fillOrderRFQ_restrictions_assetOut() public {

    }

    function test_ZivoeSwapper_fillOrderRFQ_restrictions_amountInOrderRFQ() public {

    }

    function test_ZivoeSwapper_fillOrderRFQ_restrictions_amountIn() public {

    }


    // ====================== "b0431182": clipperSwap() ==========================


    function test_ZivoeSwapper_clipperSwap_convertAsset() public {
        bytes memory data = "";
        address assetIn;
        address assetOut;
        uint256 amountIn;

        // fund user with the right amount of tokens to swap.
        hevm.deal(assetIn, address(swapper), amountIn);

        // ensure we go through the right validation function.
        bytes4 sig = bytes4(data[:4]);
        assert(sig == bytes4(keccak256("clipperSwap(address,address,uint256,uint256)")));

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        swapper.convertAsset(
            assetIn,
            assetOut,
            amountIn,
            data
        );

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    }

    function test_ZivoeSwapper_clipperSwap_restrictions_assetIn() public {

    }

    function test_ZivoeSwapper_clipperSwap_assetOut() public {

    }

    function test_ZivoeSwapper_clipperSwap_amountIn() public {

    }
 */
    // ====================== extra testing ==========================

    function test_ZivoeSwapper_extra_log() public {
        emit log_named_address("swapper testing address", address(swapper));
    }


}