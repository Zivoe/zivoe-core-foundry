// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../lockers/Utility/ZivoeSwapper.sol";
import "../TESTS_Utility/Utility.sol";
import "../../../lib/OpenZeppelin/SafeERC20.sol";

/// NOTE Expect one test to fail for fillOrderRFQ() as data should be updated.
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
    returns (
        bytes4 sig, 
        uint256[] memory poolsV3, 
        bytes32[] memory poolsV2
    )
    {
        sig = bytes4(data[:4]);

        IERC20(assetIn).safeApprove(router1INCH_V4, IERC20(assetIn).balanceOf(address(this)));
        convertAsset(assetIn, assetOut, amountIn, data);

        if (sig == bytes4(keccak256("uniswapV3Swap(uint256,uint256,uint256[])"))) {
            (,, uint256[] memory _c) = abi.decode(data[4:], (uint256, uint256, uint256[]));
            poolsV3 = _c;
        }
        if (sig == bytes4(keccak256("unoswap(address,uint256,uint256,bytes32[])"))) {
            (,,, bytes32[] memory _d) = abi.decode(data[4:], (address, uint256, uint256, bytes32[]));
            poolsV2 = _d;
        }
    }
}


contract Test_ZivoeSwapper is Utility {

    using SafeERC20 for IERC20;

    uint256 private constant _ONE_FOR_ZERO_MASK = 1 << 255;
    uint256 private constant _REVERSE_MASK =   0x8000000000000000000000000000000000000000000000000000000000000000;

    // Initiate contract variable
    SwapperTest swapper;

    // ERC20 token addresses used for testing
    address CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;

    // 1inch data retrieved from API
    // FRAX to USDC for 2_000_000
    bytes dataSwap = hex"7c02520000000000000000000000000053222470cdcfb8081c0e3a50fd106f0d69e63f2000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000853d955acef822db058eb8505911ed77f175b99e000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000053222470cdcfb8081c0e3a50fd106f0d69e63f20000000000000000000000000ce71065d4017f316ec606fe4422e11eb2c47c24600000000000000000000000000000000000000000001a784379d99db42000000000000000000000000000000000000000000000000000000000001cfde9a359a00000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001360000000000000000000000000000000000000000000000f80000ca0000b05120d632f22692fac7611d2aa1c0d552930d43caed3b853d955acef822db058eb8505911ed77f175b99e0044a6417ed6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001cc9cd8ce430020d6bdbf78a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4880a06c4eca27a0b86991c6218b36c1d19d4a2e9eb0ce3606eb481111111254fb6c44bac0bed2854e76f90643097d00000000000000000000000000000000000000000001a784379d99db4200000000000000000000000000cfee7c08";

    // DAI to FRAX for 20_000
    bytes dataUniswapV3Swap = 
    // hex"e449022e00000000000000000000000000000000000000000000043c33c19375648000000000000000000000000000000000000000000000000004399480e39a4a8ad121000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000020000000000000000000000005777d92f208679db4b9778590fa3cab3ac9e21688000000000000000000000009a834b70c07c81a9fcd6f22e842bf002fbffbe4dcfee7c08";
    // DAI -> FRAX, 2k
    // hex"e449022e00000000000000000000000000000000000000000000006c6b935b8bbd40000000000000000000000000000000000000000000000000006be0d10228830e54770000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000097e7d56a0408570ba1a7852de36350f7713906eccfee7c08";
    // FRAX -> DAI, 2k
    hex"e449022e00000000000000000000000000000000000000000000006c6b935b8bbd40000000000000000000000000000000000000000000000000006bc524c46f1a7e5aff0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000180000000000000000000000097e7d56a0408570ba1a7852de36350f7713906eccfee7c08";

    // DAI to CRV for 200
    bytes dataUnoSwap =
    // hex"2e95b6c80000000000000000000000006b175474e89094c44da98b954eedeac495271d0f00000000000000000000000000000000000000000000000ad78ebc5ac620000000000000000000000000000000000000000000000000000f41ee4bf12a441a8a0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000200000000000000003b6d0340a478c2975ab1ea89e8196811f51a7b7ade33eb1100000000000000003b6d03403da1313ae46132a397d90d95b1424a9a7e3e0fcecfee7c08";
    // USDC -> AAVE, 200
    // hex"2e95b6c8000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000002faf0800000000000000000000000000000000000000000000000000b0876e818baaa890000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000200000000000000003b6d0340b4e16d0168e52d35cacd2c6185b44281ec28c9dc80000000000000003b6d0340d75ea151a61d06868e31f8988d28dfe5e9df57b4cfee7c08";
    // AAVE -> USDC, 1
    hex"2e95b6c80000000000000000000000007fc66500c84a76ad7e9c93437bfc5ac33e2ddae90000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000000000003aafbe20000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000200000000000000003b6d0340d75ea151a61d06868e31f8988d28dfe5e9df57b480000000000000003b6d0340397ff1542f962076d0bfe58ea045ffa2d347aca0cfee7c08";

    // USDT to WBTC for 5000
    // NOTE: Data needs to be updated for every call
    bytes dataFillOrderRFQ =
    hex"d0a3b665000000000000000000000000000000000000000063860ef600000184c3a89d900000000000000000000000002260fac5e5542a773aa44fbcfedf7c193bc2c599000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000945bcf562085de2d5875b9e2012ed5fd5cfab927000000000000000000000000ce71065d4017f316ec606fe4422e11eb2c47c2460000000000000000000000000000000000000000000000000000000001d1c076000000000000000000000000000000000000000000000000000000012a05f20000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012a05f2000000000000000000000000000000000000000000000000000000000000000041735c5f1c4a202c5c3c20ee2f6ab849a2f78676a6cd046daddb83437792e777ea2b8eb23962bf6aea5f468df6882b1c8b8cd5b1b06dd7f088f987348e8eb7116e1b00000000000000000000000000000000000000000000000000000000000000cfee7c08";

    function setUp() public {
        // initiate contract instance
        swapper = new SwapperTest();
        
        // Fund the swapper contract
        deal(address(swapper), 1 ether);
    }


    // ============================ "7c025200": swap() ==========================


    function test_ZivoeSwapper_swap_convertAsset() public {

        address assetIn = FRAX;
        address assetOut = USDC;
        uint256 amountIn = 2_000_000 ether;

        // fund contract with the right amount of tokens to swap.
        deal(assetIn, address(swapper), amountIn);

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        emit log_named_uint("swapper assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));

        (bytes4 sig,,) = swapper.convertTest(
                        assetIn,
                        assetOut,
                        amountIn,
                        dataSwap
                    );

        emit log_named_uint("swapper assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));

        // ensure we go through the right validation function.
        assert(sig == bytes4(keccak256("swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)")));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    }

    function test_ZivoeSwapper_swap_restrictions_assetIn() public {

        // We provide the wrong assetIn (USDT instead of FRAX)
        address assetIn = USDT; 
        address assetOut = USDC;
        uint256 amountIn = 2_000_000 ether;

        // We expect the following call to revert due to assetIn != FRAX
        hevm.expectRevert("ZivoeSwapper::handle_validation_7c025200() assetIn != data");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataSwap
        );
    }

    function test_ZivoeSwapper_swap_restrictions_assetOut() public {
        // We provide the wrong assetOut (DAI instead of USDC)
        address assetIn = FRAX; 
        address assetOut = DAI;
        uint256 amountIn = 2_000_000 ether;

        // We expect the following call to revert due to assetOut != USDC
        hevm.expectRevert("ZivoeSwapper::handle_validation_7c025200() assetOut != data");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataSwap
        );
    }

    function test_ZivoeSwapper_swap_restrictions_amountIn() public {
        // We provide the wrong amountIn (2000 instead of 2_000_000)
        address assetIn = FRAX; 
        address assetOut = USDC;
        uint256 amountIn = 2_000 ether;

        // We expect the following call to revert due to amountIn != 2_000_000
        hevm.expectRevert("ZivoeSwapper::handle_validation_7c025200() amountIn != data");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataSwap
        );

    }

    function test_ZivoeSwapper_swap_restrictions_receiver() public {
        // We provide the wrong "fromAddress" when calling the API
        bytes memory dataOtherReceiver =
        hex"7c02520000000000000000000000000053222470cdcfb8081c0e3a50fd106f0d69e63f2000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000853d955acef822db058eb8505911ed77f175b99e000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000053222470cdcfb8081c0e3a50fd106f0d69e63f20000000000000000000000000972ea38d8ceb5811b144afcce5956a279e47ac4600000000000000000000000000000000000000000001a784379d99db42000000000000000000000000000000000000000000000000000000000001cfeb14895200000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001360000000000000000000000000000000000000000000000f80000ca0000b05120d632f22692fac7611d2aa1c0d552930d43caed3b853d955acef822db058eb8505911ed77f175b99e0044a6417ed6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001cca93cb4850020d6bdbf78a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4880a06c4eca27a0b86991c6218b36c1d19d4a2e9eb0ce3606eb481111111254fb6c44bac0bed2854e76f90643097d00000000000000000000000000000000000000000001a784379d99db4200000000000000000000000000cfee7c08";
        address assetIn = FRAX; 
        address assetOut = USDC;
        uint256 amountIn = 2_000_000 ether;

        // We expect the following call to revert due to assetIn != FRAX
        hevm.expectRevert("ZivoeSwapper::handle_validation_7c025200() receiver != address(this)");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataOtherReceiver
        );
    }


    // ==================== "e449022e": uniswapV3Swap() ==========================


    function test_ZivoeSwapper_uniswapV3Swap_convertAsset() public {
        // address assetIn = DAI;
        // address assetOut = FRAX;
        address assetIn = FRAX;
        address assetOut = DAI;
        // uint256 amountIn = 20_000 ether;
        // address assetIn = USDC;
        // address assetOut = WBTC;
        uint256 amountIn = 2000 ether;

        // fund address(swapper) with the right amount of tokens to swap.
        deal(assetIn, address(swapper), amountIn);

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        emit log_named_uint("swapper assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));
        emit log_named_uint("swapper assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(swapper)));

        
        (bytes4 sig, uint256[] memory pools,) = swapper.convertTest(
                                                    assetIn,
                                                    assetOut,
                                                    amountIn,
                                                    dataUniswapV3Swap
                                                );

        bool zeroForOne_0 = pools[0] & _ONE_FOR_ZERO_MASK == 0;
        bool zeroForOne_CLENGTH = pools[pools.length - 1] & _ONE_FOR_ZERO_MASK == 0;

        // = true
        if (zeroForOne_0 == true) {
            emit log_string("zeroForOne_0 TRUE");
        }
        // = false
        if (zeroForOne_CLENGTH == true) {
            emit log_string("zeroForOne_CLENGTH TRUE");
        }

        // ensure we go through the right validation function.
        assert(sig == bytes4(keccak256("uniswapV3Swap(uint256,uint256,uint256[])")));

        emit log_named_uint("swapper assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));
        emit log_named_uint("swapper assetOut after-swap balance:", IERC20(assetOut).balanceOf(address(swapper)));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_assetIn_token0() public {
        // Case with zeroForOne_0 = true
        // We provide the wrong assetIn (USDT instead of DAI)
        address assetIn = USDT; 
        address assetOut = FRAX;
        uint256 amountIn = 20_000 ether;

        // We expect the following call to revert due to assetIn != DAI and zeroForOne_0 = true
        hevm.expectRevert("ZivoeSwapper::handle_validation_e449022e() token0() != assetIn");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataUniswapV3Swap
        );
    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_assetIn_token1() public {
        // Case with zeroForOne_0 = false
        // We provide the wrong assetIn (USDT instead of USDC)
        address assetIn = USDT; 
        address assetOut = DAI;
        uint256 amountIn = 20_000 * 10**6;

        bytes memory data = hex"e449022e00000000000000000000000000000000000000000000000000000004a817c800000000000000000000000000000000000000000000000438d5d5c6fa2cf2abe4000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000018000000000000000000000005777d92f208679db4b9778590fa3cab3ac9e2168cfee7c08";

        // We expect the following call to revert due to assetIn != USDC and zeroForOne_0 = false
        hevm.expectRevert("ZivoeSwapper::handle_validation_e449022e() token1() != assetIn");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            data
        );
    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_assetOut_token0() public {
        // Case with zeroForOne_CLENGTH = false
        // We provide the wrong assetOut (USDT instead of FRAX)
        address assetIn = DAI; 
        address assetOut = USDT;
        uint256 amountIn = 20_000 ether;
 
        // We expect the following call to revert due to assetOut != FRAX and zeroForOne_CLENGTH = false
        hevm.expectRevert("ZivoeSwapper::handle_validation_e449022e() token0() != assetOut");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataUniswapV3Swap
        );
    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_assetOut_token1() public {
        // Case with zeroForOne_CLENGTH = true
        // We provide the wrong assetOut (USDC instead of USDT)
        address assetIn = DAI; 
        address assetOut = USDC;
        uint256 amountIn = 5_000 ether;

        bytes memory data =
        hex"e449022e00000000000000000000000000000000000000000000010f0cf064dd59200000000000000000000000000000000000000000000000000000000000012938f1cd0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000048da0965ab2d2cbf1c17c09cfb5cbe67ad5b1406cfee7c08";

        // We expect the following call to revert due to assetOut != USDT and zeroForOne_CLENGTH = true
        hevm.expectRevert("ZivoeSwapper::handle_validation_e449022e() token1() != assetOut");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            data
        );
    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_amountIn() public {
        // We provide the wrong amountIn (2_000 instead of 20_000)
        address assetIn = DAI; 
        address assetOut = FRAX;
        uint256 amountIn = 2_000 ether;

        // We expect the following call to revert due to amountIn != 20_000
        hevm.expectRevert("ZivoeSwapper::handle_validation_e449022e() amountIn != data");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataUniswapV3Swap
        );
    }


    // ======================== "2e95b6c8": unoswap() ============================


    function test_ZivoeSwapper_unoswap_convertAsset() public {
        // address assetIn = DAI;
        // address assetOut = CRV;
        // uint256 amountIn = 200 ether;
        address assetIn = AAVE;
        address assetOut = USDC;
        // uint256 amountIn = 200 * 10**6;
        uint256 amountIn = 1 ether;

        // fund address(swapper) with the right amount of tokens to swap.
        deal(assetIn, address(swapper), amountIn);

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        emit log_named_uint("swapper assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));
        emit log_named_uint("swapper assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(swapper)));

        (bytes4 sig,,bytes32[] memory pools) = swapper.convertTest(
                                                assetIn,
                                                assetOut,
                                                amountIn,
                                                dataUnoSwap
                                            );
        
        bool zeroForOne_0;
        bool zeroForOne_DLENGTH;
        bytes32 info_0 = pools[0];
        bytes32 info_DLENGTH = pools[pools.length - 1];
        assembly {
            zeroForOne_0 := and(info_0, _REVERSE_MASK)
            zeroForOne_DLENGTH := and(info_DLENGTH, _REVERSE_MASK)
        }

        // = false
        if (zeroForOne_0 == true) {
            emit log_string("zeroForOne_0 TRUE");
        }
        // = false
        if (zeroForOne_DLENGTH == true) {
            emit log_string("zeroForOne_CLENGTH TRUE");
        }

        // ensure we go through the right validation function.
        assert(sig == bytes4(keccak256("unoswap(address,uint256,uint256,bytes32[])")));

        emit log_named_uint("swapper assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));
        emit log_named_uint("swapper assetOut after-swap balance:", IERC20(assetOut).balanceOf(address(swapper)));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    }


    function test_ZivoeSwapper_unoswap_restrictions_assetIn_token0() public {
        // Case with zeroForOne_0 = false
        // "data" below is equal to "dataUnoSwap" with first address of assetIn modified, see below.
        // We provide the wrong assetIn (FRAX instead of DAI)
        address assetIn = FRAX; 
        address assetOut = CRV;
        uint256 amountIn = 200 ether;

        // in below data we modified the first address to be equal to FRAX otherwise 2 errors are thrown
        bytes memory data = 
        hex"2e95b6c8000000000000000000000000853d955acef822db058eb8505911ed77f175b99e00000000000000000000000000000000000000000000000ad78ebc5ac620000000000000000000000000000000000000000000000000000f41ee4bf12a441a8a0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000200000000000000003b6d0340a478c2975ab1ea89e8196811f51a7b7ade33eb1100000000000000003b6d03403da1313ae46132a397d90d95b1424a9a7e3e0fcecfee7c08";

        // We expect the following call to revert due to assetIn != DAI and zeroForOne_0 = false
        hevm.expectRevert("ZivoeSwapper::handle_validation_2e95b6c8() assetIn != token0()");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            data
        );
    }

    function test_ZivoeSwapper_unoswap_restrictions_assetIn_token1() public {
        // Case with zeroForOne_0 = true
        // "data" below is for a CRV to WETH swap for amount = 200 * 10**18
        // We provide the wrong assetIn (FRAX instead of CRV)
        address assetIn = FRAX; 
        address assetOut = WETH;
        uint256 amountIn = 200 ether;

        // in below data we modified the first address to be equal to FRAX otherwise 2 errors are thrown
        bytes memory data = 
        hex"2e95b6c8000000000000000000000000853d955acef822db058eb8505911ed77f175b99e00000000000000000000000000000000000000000000000ad78ebc5ac62000000000000000000000000000000000000000000000000000000185b5941251fda60000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000180000000000000003b6d03403da1313ae46132a397d90d95b1424a9a7e3e0fcecfee7c08";

        // We expect the following call to revert due to assetIn != CRV and zeroForOne_0 = true
        hevm.expectRevert("ZivoeSwapper::handle_validation_2e95b6c8() assetIn != token1()");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            data
        );
    }

    function test_ZivoeSwapper_unoswap_restrictions_assetOut_token0() public {
        // Case with zeroForOne_DLENGTH = true
        // "data" below is for a CRV to WETH swap for amount = 200 * 10**18
        // We provide the wrong assetOut (FRAX instead of WETH)
        address assetIn = CRV; 
        address assetOut = FRAX;
        uint256 amountIn = 200 ether;


        bytes memory data = 
        hex"2e95b6c8000000000000000000000000d533a949740bb3306d119cc777fa900ba034cd5200000000000000000000000000000000000000000000000ad78ebc5ac62000000000000000000000000000000000000000000000000000000185b5941251fda60000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000180000000000000003b6d03403da1313ae46132a397d90d95b1424a9a7e3e0fcecfee7c08";

        // We expect the following call to revert due to assetOut != WETH and zeroForOne_DLENGTH = true
        hevm.expectRevert("ZivoeSwapper::handle_validation_2e95b6c8() assetOut != token0()");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            data
        );
    }

    function test_ZivoeSwapper_unoswap_restrictions_assetOut_token1() public {
        // Case with zeroForOne_DLENGTH = false
        // We provide the wrong assetOut (FRAX instead of CRV)
        address assetIn = DAI; 
        address assetOut = FRAX;
        uint256 amountIn = 200 ether;


        // We expect the following call to revert due to assetIn != DAI and zeroForOne_0 = false
        hevm.expectRevert("ZivoeSwapper::handle_validation_2e95b6c8() assetOut != token1()");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataUnoSwap
        );
    }

    function test_ZivoeSwapper_unoswap_restrictions_amountIn() public {
        // We provide the wrong amountIn (2_000 instead of 200)
        address assetIn = DAI; 
        address assetOut = FRAX;
        uint256 amountIn = 2_000 ether;


        // We expect the following call to revert due to amountIn != 200
        hevm.expectRevert("ZivoeSwapper::handle_validation_2e95b6c8() amountIn != data");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataUnoSwap
        );
    }


    // ===================== "d0a3b665": fillOrderRFQ() ==========================


    function test_ZivoeSwapper_fillOrderRFQ_convertAsset() public {
 
        address assetIn = USDT;
        address assetOut = WBTC;
        uint256 amountIn = 5_000 * 10**6;

        // fund contract with the right amount of tokens to swap.
        deal(assetIn, address(swapper), amountIn);

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        emit log_named_uint("swapper assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));

        (bytes4 sig,,) = swapper.convertTest(
                        assetIn,
                        assetOut,
                        amountIn,
                        dataFillOrderRFQ
                    );

        emit log_named_uint("swapper assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));

        // ensure we go through the right validation function.
        assert(sig == bytes4(keccak256("fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256)")));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    }

    function test_ZivoeSwapper_fillOrderRFQ_restrictions_assetIn() public {
        // We provide the wrong assetIn (USDC instead of USDT)
        address assetIn = USDC; 
        address assetOut = WBTC;
        uint256 amountIn = 5_000 * 10**6;


        // We expect the following call to revert due to amountIn != 200
        hevm.expectRevert("ZivoeSwapper::handle_validation_d0a3b665() assetIn != data");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataFillOrderRFQ
        );
    }

    function test_ZivoeSwapper_fillOrderRFQ_restrictions_assetOut() public {
        // We provide the wrong assetOut (DAI instead of WBTC)
        address assetIn = USDT; 
        address assetOut = DAI;
        uint256 amountIn = 5_000 * 10**6;


        // We expect the following call to revert due to assetOut != WBTC
        hevm.expectRevert("ZivoeSwapper::handle_validation_d0a3b665() assetOut != data");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataFillOrderRFQ
        );
    }

    function test_ZivoeSwapper_fillOrderRFQ_restrictions_amountInToStruct() public {
        // We provide the wrong amountIn (500 instead of 5_000)
        address assetIn = USDT; 
        address assetOut = WBTC;
        uint256 amountIn = 500 * 10**6;


        // We expect the following call to revert due to assetOut != WBTC
        hevm.expectRevert("ZivoeSwapper::handle_validation_d0a3b665() amountIn != data._a");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataFillOrderRFQ
        );     
    }


    // ====================== helper testing ==========================


    function test_ZivoeSwapper_extra_log() public {
        emit log_named_address("swapper testing address", address(swapper));
    }
}