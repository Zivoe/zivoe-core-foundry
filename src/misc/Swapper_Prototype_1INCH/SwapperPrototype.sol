// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../libraries/OpenZeppelin/IERC20.sol";
import "../../libraries/OpenZeppelin/Ownable.sol";
import "../../libraries/OpenZeppelin/SafeERC20.sol";

/// @dev OneInchPrototype contract integrates with 1INCH to support custom data input.
contract SwapperPrototype is Ownable {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable router1INCH_V4 = 0x1111111254fb6c44bAC0beD2854e76F90643097d;



    // -----------------
    //    Constructor
    // -----------------

    constructor() {

    }


    // ------------
    //    Events
    // ------------

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



    // ---------------
    //    Functions
    // ---------------

    function withdrawERC20(address asset) external onlyOwner {
        IERC20(asset).safeTransfer(_msgSender(), IERC20(asset).balanceOf(address(this)));
    }

    // {
    //     "3644e515": "DOMAIN_SEPARATOR()",
    //     "06bf53d0": "LIMIT_ORDER_RFQ_TYPEHASH()",
    //     "825caba1": "cancelOrderRFQ(uint256)",
    //     "b0431182": "clipperSwap(address,address,uint256,uint256)",
    //     "9994dd15": "clipperSwapTo(address,address,address,uint256,uint256)",
    //     "d6a92a5d": "clipperSwapToWithPermit(address,address,address,uint256,uint256,bytes)",
    //     "83197ef0": "destroy()",
    //     "d0a3b665": "fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256)",
    //     "baba5855": "fillOrderRFQTo((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256,address)",
    //     "4cc4a27b": "fillOrderRFQToWithPermit((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256,address,bytes)",
    //     "56f16124": "invalidatorForOrderRFQ(address,uint256)",
    //     "8da5cb5b": "owner()",
    //     "715018a6": "renounceOwnership()",
    //     "78e3214f": "rescueFunds(address,uint256)",
    //     "7c025200": "swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)",
    //     "f2fde38b": "transferOwnership(address)",
    //     "e449022e": "uniswapV3Swap(uint256,uint256,uint256[])",
    //     "fa461e33": "uniswapV3SwapCallback(int256,int256,bytes)",
    //     "bc80f1a8": "uniswapV3SwapTo(address,uint256,uint256,uint256[])",
    //     "2521b930": "uniswapV3SwapToWithPermit(address,address,uint256,uint256,uint256[],bytes)",
    //     "2e95b6c8": "unoswap(address,uint256,uint256,bytes32[])",
    //     "a1251d75": "unoswapWithPermit(address,uint256,uint256,bytes32[],bytes)"
    // }

    // CRITICAL FUNCTION SELECTORS FROM 1INCH API ENDPOINT RETURNED

    

    // -----------
    //    1INCH
    // -----------

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

    /// @dev "7c025200": "swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)"
    function handle_validation_7c025200(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal view {
        (,SwapDescription memory _b,) = abi.decode(data[4:], (address, SwapDescription, bytes));
        require(address(_b.srcToken) == assetIn);
        require(address(_b.dstToken) == assetOut);
        require(_b.amount == amountIn);
        require(_b.dstReceiver == address(this));
    }

    /// @dev "e449022e": "uniswapV3Swap(uint256,uint256,uint256[])"
    function handle_validation_e449022e(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal {
        uint256 _a;
        uint256 _b;
        uint256[] memory _c;
        (_a, _b, _c) = abi.decode(data[4:], (uint256, uint256, uint256[]));
    }

    /// @dev "2e95b6c8": "unoswap(address,uint256,uint256,bytes32[])"
    function handle_validation_2e95b6c8(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal {
        address _a;
        uint256 _b;
        uint256 _c;
        bytes32[] memory _d;
        (_a, _b, _c, _d) = abi.decode(data[4:], (address, uint256, uint256, bytes32[]));
    }

    /// @dev "d0a3b665": "fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256)"
    function handle_validation_d0a3b665(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal {
        OrderRFQ memory _a;
        bytes memory _b;
        uint256 _c;
        uint256 _d;
        (_a, _b, _c, _d) = abi.decode(data[4:], (OrderRFQ, bytes, uint256, uint256));
    }

    /// @dev "b0431182": "clipperSwap(address,address,uint256,uint256)"
    function handle_validation_b0431182(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal {
        address _a;
        address _b;
        uint256 _c;
        uint256 _d;
        (_a, _b, _c, _d) = abi.decode(data[4:], (address, address, uint256, uint256));
    }

    function convertAsset(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 slippageBPS,
        bytes calldata data
    ) public {

        // Add hard-coded restrictions here (e.g. allowable assets in/out, slippageBPS thresholds, etc.)

        // Handle decoding and validation cases.
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

    }

    /// @dev "7c025200": "swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)"
    function dataDecode_7c025200(
        bytes calldata data
    ) external pure returns(address _a, SwapDescription memory _b, bytes memory _c) {
        (_a, _b, _c) = abi.decode(data[4:], (address, SwapDescription, bytes));
    }

    /// @dev "e449022e": "uniswapV3Swap(uint256,uint256,uint256[])"
    function dataDecode_e449022e(
        bytes calldata data
    ) external pure returns(uint256 _a, uint256 _b, uint256[] memory _c) {
        (_a, _b, _c) = abi.decode(data[4:], (uint256, uint256, uint256[]));
    }

    /// @dev "2e95b6c8": "unoswap(address,uint256,uint256,bytes32[])"
    function dataDecode_2e95b6c8(
        bytes calldata data
    ) external pure returns(address _a, uint256 _b, uint256 _c, bytes32[] memory _d) {
        (_a, _b, _c, _d) = abi.decode(data[4:], (address, uint256, uint256, bytes32[]));
    }

    /// @dev "d0a3b665": "fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256)"
    function dataDecode_d0a3b665(
        bytes calldata data
    ) external pure returns(OrderRFQ memory _a, bytes memory _b, uint256 _c, uint256 _d) {
        (_a, _b, _c, _d) = abi.decode(data[4:], (OrderRFQ, bytes, uint256, uint256));
    }

    /// @dev "b0431182": "clipperSwap(address,address,uint256,uint256)"
    function dataDecode_b0431182(
        bytes calldata data
    ) external pure returns(address _a, address _b, uint256 _c, uint256 _d) {
        (_a, _b, _c, _d) = abi.decode(data[4:], (address, address, uint256, uint256));
    }

    /// @dev "7c025200": "swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)"
    function dataDecode_7c025200_VALIDATE_AND_EXECUTE(
        bytes calldata data,
        address assetToSwap,
        uint256 amountToSwap
    ) external returns(address _a, SwapDescription memory _b, bytes memory _c) {
        IERC20(assetToSwap).safeApprove(address(router1INCH_V4), amountToSwap);
        (_a, _b, _c) = abi.decode(data[4:], (address, SwapDescription, bytes));
        require(_b.dstReceiver == address(this), "::dataDecode_7c025200_VALIDATE_AND_EXECUTE() _b.dstReceiver != address(this)");
        (bool succ, bytes memory _data) = address(router1INCH_V4).call(data);
        require(succ, "::dataDecode_7c025200_VALIDATE_AND_EXECUTE() !succ");
        (uint returnAmount, uint spentAmount, uint gasLeft) = abi.decode(_data, (uint, uint, uint));
        emit SwapExecuted_7c025200(returnAmount, spentAmount, gasLeft, _a, _b, _c);
    }

    /// @dev "e449022e": "uniswapV3Swap(uint256,uint256,uint256[])"
    function dataDecode_e449022e_VALIDATE_AND_EXECUTE(
        bytes calldata data,
        address assetToSwap,
        uint256 amountToSwap
    ) external returns(uint256 _a, uint256 _b, uint256[] memory _c) {
        IERC20(assetToSwap).safeApprove(address(router1INCH_V4), amountToSwap);
        (_a, _b, _c) = abi.decode(data[4:], (uint256, uint256, uint256[]));
        (bool succ, bytes memory _data) = address(router1INCH_V4).call(data);
        require(succ, "::dataDecode_7c025200_VALIDATE_AND_EXECUTE() !succ");
        uint returnAmount = abi.decode(_data, (uint));
        emit SwapExecuted_e449022e(returnAmount, _a, _b, _c);
    }

    /// @dev "2e95b6c8": "unoswap(address,uint256,uint256,bytes32[])"
    function dataDecode_2e95b6c8_VALIDATE_AND_EXECUTE(
        bytes calldata data,
        address assetToSwap,
        uint256 amountToSwap
    ) external returns(address _a, uint256 _b, uint256 _c, bytes32[] memory _d) {
        IERC20(assetToSwap).safeApprove(address(router1INCH_V4), amountToSwap);
        (_a, _b, _c, _d) = abi.decode(data[4:], (address, uint256, uint256, bytes32[]));
        (bool succ, bytes memory _data) = address(router1INCH_V4).call(data);
        require(succ, "::dataDecode_7c025200_VALIDATE_AND_EXECUTE() !succ");
        uint returnAmount = abi.decode(_data, (uint));
        emit SwapExecuted_2e95b6c8(returnAmount, _a, _b, _c, _d);
    }

    /// @dev "d0a3b665": "fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256)"
    function dataDecode_d0a3b665_VALIDATE_AND_EXECUTE(
        bytes calldata data,
        address assetToSwap,
        uint256 amountToSwap
    ) external returns(OrderRFQ memory _a, bytes memory _b, uint256 _c, uint256 _d) {
        IERC20(assetToSwap).safeApprove(address(router1INCH_V4), amountToSwap);
        (_a, _b, _c, _d) = abi.decode(data[4:], (OrderRFQ, bytes, uint256, uint256));
        (bool succ, bytes memory _data) = address(router1INCH_V4).call(data);
        require(succ, "::dataDecode_7c025200_VALIDATE_AND_EXECUTE() !succ");
        (uint actualMakingAmount, uint actualTakingAmount)= abi.decode(_data, (uint, uint));
        emit SwapExecuted_d0a3b665(actualMakingAmount, actualTakingAmount, _a, _b, _c, _d);
    }

    /// @dev "b0431182": "clipperSwap(address,address,uint256,uint256)"
    function dataDecode_b0431182_VALIDATE_AND_EXECUTE(
        bytes calldata data,
        address assetToSwap,
        uint256 amountToSwap
    ) external returns(address _a, address _b, uint256 _c, uint256 _d) {
        IERC20(assetToSwap).safeApprove(address(router1INCH_V4), amountToSwap);
        (_a, _b, _c, _d) = abi.decode(data[4:], (address, address, uint256, uint256));
        (bool succ, bytes memory _data) = address(router1INCH_V4).call(data);
        require(succ, "::dataDecode_7c025200_VALIDATE_AND_EXECUTE() !succ");
        uint returnAmount = abi.decode(_data, (uint));
        emit SwapExecuted_b0431182(returnAmount, _a, _b, _c, _d);
    }

}
