// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;


import "../OpenZeppelin/Ownable.sol";
import { SafeERC20 } from "../OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "../OpenZeppelin/IERC20.sol";
import {IUniswapRouterV3, ExactInputSingleParams, ExactInputParams} from "../interfaces/InterfacesAggregated.sol";



contract Swap is Ownable {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------


    /// @dev Uniswap swapRouter contract.
    address public UNI_ROUTER;


    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_CVX_FraxUSDC.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    
    constructor(address DAO, address UNI_Router) {
        transferOwnership(DAO);
        UNI_ROUTER = UNI_Router;

    }

    // ---------------
    //    Functions
    // ---------------


    function UniswapExactInputMultihop(address tokenIn, uint256 amountIn, address transitToken, address tokenOut, uint16 poolFee1, uint16 poolFee2, address recipient) external returns (uint256 amountOut) {

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).safeApprove(UNI_ROUTER, amountIn);

        ExactInputParams memory params = ExactInputParams({
            path: abi.encodePacked(tokenIn, poolFee1, transitToken, poolFee2, tokenOut),
            recipient: recipient,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0

        });

        amountOut = IUniswapRouterV3(UNI_ROUTER).exactInput(params);
    }

    /// Or better ZVL for governance ?
    function setUNI_Router(address newUNI_ROUTER) external onlyOwner {
        UNI_ROUTER = newUNI_ROUTER;
    }

}


