// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;


import "../OpenZeppelin/Ownable.sol";
import { SafeERC20 } from "../OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "../OpenZeppelin/IERC20.sol";
import {IUniswapRouterV3, ExactInputSingleParams, ExactInputParams} from "../interfaces/InterfacesAggregated.sol";

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeApprove: approve failed'
        );
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }
}


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

        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        TransferHelper.safeApprove(tokenIn, UNI_ROUTER, amountIn);

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


