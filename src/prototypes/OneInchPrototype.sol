// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../OpenZeppelin/Ownable.sol";

import { SafeERC20 } from "../OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "../OpenZeppelin/IERC20.sol";

import { IAggregationExecutor, IAggregationRouterV4 } from "../interfaces/InterfacesAggregated.sol";

/// @dev OneInchPrototype contract integrates with 1INCH to support custom data input.
contract OneInchPrototype is Ownable {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
        bytes permit;
    }

    address public immutable router1INCH_V4 = 0x1111111254fb6c44bAC0beD2854e76F90643097d;



    // -----------------
    //    Constructor
    // -----------------

    constructor() {

    }



    // ---------------
    //    Functions
    // ---------------

    function withdrawERC20(address asset) external onlyOwner {
        IERC20(asset).safeTransfer(_msgSender(), IERC20(asset).balanceOf(address(this)));
    }

    /*

        /// @notice Performs a swap, delegating all calls encoded in `data` to `caller`. See tests for usage examples
        /// @param caller Aggregation executor that executes calls described in `data`
        /// @param desc Swap description
        /// @param data Encoded calls that `caller` should execute in between of swaps
        /// @return returnAmount Resulting token amount
        /// @return spentAmount Source token amount
        /// @return gasLeft Gas left
        function swap(
            IAggregationExecutor caller,
            SwapDescription calldata desc,
            bytes calldata data
        )
            external
            payable
            returns (
                uint256 returnAmount,
                uint256 spentAmount,
                uint256 gasLeft
            )
        {

    */

    function swapViaRouter(
        address assetToSwap,
        IAggregationExecutor caller,
        SwapDescription calldata desc,
        bytes calldata data
    ) external onlyOwner {
        IERC20(assetToSwap).safeApprove(router1INCH_V4, IERC20(assetToSwap).balanceOf(address(this)));
        IAggregationRouterV4(router1INCH_V4).swap(caller, desc, data);
    }

}
