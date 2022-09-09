// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../OpenZeppelin/Ownable.sol";

import { SafeERC20 } from "../OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "../OpenZeppelin/IERC20.sol";

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

    /// @param success True/false if call succeeds/fails.
    /// @param _return Return data.
    event SwapExecuted(
        bool success,
        bytes _return
    );


    // ---------------
    //    Functions
    // ---------------

    function withdrawERC20(address asset) external onlyOwner {
        IERC20(asset).safeTransfer(_msgSender(), IERC20(asset).balanceOf(address(this)));
    }

    function swapViaRouter(
        address assetToSwap,
        bytes calldata data
    ) external onlyOwner {
        IERC20(assetToSwap).safeApprove(router1INCH_V4, IERC20(assetToSwap).balanceOf(address(this)));
        (bool success, bytes memory _return) = address(router1INCH_V4).call(data);
        emit SwapExecuted(success, _return);
    }

}
