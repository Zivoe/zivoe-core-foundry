// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../../lib/OpenZeppelin/IERC20.sol";
import "../../../lib/OpenZeppelin/Ownable.sol";
import "../../../lib/OpenZeppelin/SafeERC20.sol";

import { IUniswapV3Pool, IUniswapV2Pool } from "../../misc/InterfacesAggregated.sol";

/// @dev OneInchPrototype contract integrates with 1INCH to support custom data input.
contract ZivoeSwapper is Ownable {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable router1INCH_V4 = 0x1111111254fb6c44bAC0beD2854e76F90643097d;

    uint256 private constant _ONE_FOR_ZERO_MASK = 1 << 255;
    uint256 private constant _REVERSE_MASK =   0x8000000000000000000000000000000000000000000000000000000000000000;

    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address srcReceiver;
        address dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
        bytes permit;
    }

    struct OrderRFQ {
        // lowest 64 bits is the order id, next 64 bits is the expiration timestamp
        // highest bit is unwrap WETH flag which is set on taker's side
        // [unwrap eth(1 bit) | unused (127 bits) | expiration timestamp(64 bits) | orderId (64 bits)]
        uint256 info;
        IERC20 makerAsset;
        IERC20 takerAsset;
        address maker;
        address allowedSender;  // equals to Zero address on public orders
        uint256 makingAmount;
        uint256 takingAmount;
    }


    // -----------------
    //    Constructor
    // -----------------

    constructor() {

    }


    // ------------
    //    Events
    // ------------

    // TODO: Consider upgrading validation functions to emit events.

    // ::swap()
    event SwapExecuted_7c025200(
        uint256 returnAmount,
        uint256 spentAmount,
        uint256 gasLeft,
        address assetToSwap,
        SwapDescription info,
        bytes data
    );

    // ::uniswapV3Swap()
    event SwapExecuted_e449022e(
        uint256 returnAmount,
        uint256 amount,
        uint256 minReturn,
        uint256[] pools
    );

    // ::unoswap()
    event SwapExecuted_2e95b6c8(
        uint256 returnAmount,
        address srcToken,
        uint256 amount,
        uint256 minReturn,
        bytes32[] pools
    );

    // ::fillOrderRFQ()
    event SwapExecuted_d0a3b665(
        uint256 actualMakingAmount,
        uint256 actualTakingAmount,
        OrderRFQ order,
        bytes signature,
        uint256 makingAmount,
        uint256 takingAmount
    );

    // ::clipperSwap()
    event SwapExecuted_b0431182(
        uint256 returnAmount,
        address srcToken,
        address dstToken,
        uint256 amount,
        uint256 minReturn
    );

    // -----------
    //    1INCH
    // -----------

    /// @dev "7c025200": "swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)"
    function handle_validation_7c025200(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal view {
        (, SwapDescription memory _b,) = abi.decode(data[4:], (address, SwapDescription, bytes));
        require(address(_b.srcToken) == assetIn);
        require(address(_b.dstToken) == assetOut);
        require(_b.amount == amountIn);
        require(_b.dstReceiver == address(this));
    }

    /// @dev "e449022e": "uniswapV3Swap(uint256,uint256,uint256[])"
    function handle_validation_e449022e(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal view {
        (uint256 _a,, uint256[] memory _c) = abi.decode(data[4:], (uint256, uint256, uint256[]));
        require(_a == amountIn);
        bool zeroForOne_0 = _c[0] & _ONE_FOR_ZERO_MASK == 0;
        bool zeroForOne_CLENGTH = _c[_c.length - 1] & _ONE_FOR_ZERO_MASK == 0;
        if (zeroForOne_0) {
            require(IUniswapV3Pool(address(uint160(uint256(_c[0])))).token0() == assetIn);
        }
        else {
            require(IUniswapV3Pool(address(uint160(uint256(_c[0])))).token1() == assetIn);
        }
        if (zeroForOne_CLENGTH) {
            require(IUniswapV3Pool(address(uint160(uint256(_c[_c.length - 1])))).token1() == assetOut);
        }
        else {
            require(IUniswapV3Pool(address(uint160(uint256(_c[_c.length - 1])))).token0() == assetOut);
        }
    }

    /// @dev "2e95b6c8": "unoswap(address,uint256,uint256,bytes32[])"
    function handle_validation_2e95b6c8(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal view {
        (address _a,, uint256 _c, bytes32[] memory _d) = abi.decode(data[4:], (address, uint256, uint256, bytes32[]));
        require(_a == assetIn);
        require(_c == amountIn);
        bool zeroForOne_0;
        bool zeroForOne_DLENGTH;
        bytes32 info_0 = _d[0];
        bytes32 info_DLENGTH = _d[_d.length - 1];
        assembly {
            zeroForOne_0 := and(info_0, _REVERSE_MASK)
            zeroForOne_DLENGTH := and(info_DLENGTH, _REVERSE_MASK)
        }
        if (zeroForOne_0) {
            require(IUniswapV2Pool(address(uint160(uint256(_d[0])))).token0() == assetIn);
        }
        else {
            require(IUniswapV2Pool(address(uint160(uint256(_d[0])))).token1() == assetIn);
        }
        if (zeroForOne_DLENGTH) {
            require(IUniswapV2Pool(address(uint160(uint256(_d[_d.length - 1])))).token1() == assetOut);
        }
        else {
            require(IUniswapV2Pool(address(uint160(uint256(_d[_d.length - 1])))).token0() == assetOut);
        }
    }

    /// @dev "d0a3b665": "fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256)"
    function handle_validation_d0a3b665(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal pure {
        (OrderRFQ memory _a,,, uint256 _d) = abi.decode(data[4:], (OrderRFQ, bytes, uint256, uint256));
        require(address(_a.takerAsset) == assetIn);
        require(address(_a.makerAsset) == assetOut);
        require(_a.takingAmount == amountIn);
        require(_d == amountIn);
    }

    /// @dev "b0431182": "clipperSwap(address,address,uint256,uint256)"
    function handle_validation_b0431182(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal pure {
        (address _a, address _b, uint256 _c,) = abi.decode(data[4:], (address, address, uint256, uint256));
        require(_a == assetIn);
        require(_b == assetOut);
        require(_c == amountIn);
    }

    function _handleValidationAndSwap(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        bytes calldata data
    ) internal {
        // Handle validation.
        bytes4 sig = bytes4(data[:4]);
        if (sig == bytes4(keccak256("swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)"))) {
            handle_validation_7c025200(data, assetIn, assetOut, amountIn);
        }
        else if (sig == bytes4(keccak256("uniswapV3Swap(uint256,uint256,uint256[])"))) {
            handle_validation_e449022e(data, assetIn, assetOut, amountIn);
        }
        else if (sig == bytes4(keccak256("unoswap(address,uint256,uint256,bytes32[])"))) {
            handle_validation_2e95b6c8(data, assetIn, assetOut, amountIn);
        }
        else if (sig == bytes4(keccak256("fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256)"))) {
            handle_validation_d0a3b665(data, assetIn, assetOut, amountIn);
        }
        else if (sig == bytes4(keccak256("clipperSwap(address,address,uint256,uint256)"))) {
            handle_validation_b0431182(data, assetIn, assetOut, amountIn);
        }
        else {
            revert();
        }
        // Execute swap.
        (bool succ,) = address(router1INCH_V4).call(data);
        require(succ, "::convertAsset() !succ");
    }

    function convertAsset(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        bytes calldata data
    ) internal {
        // Handle decoding and validation cases.
        _handleValidationAndSwap(assetIn, assetOut, amountIn, data);
    }

}