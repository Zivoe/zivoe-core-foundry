// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;
pragma experimental ABIEncoderV2;

import { IERC20 } from "../OpenZeppelin/IERC20.sol";

contract Lender {

    /************************/
    /*** DIRECT FUNCTIONS ***/
    /************************/

    function transferByTrader(address token, address to, uint256 amt) external {
        IERC20(token).transfer(to, amt);
    }

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/

    function try_transferByTrader(address token, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "transfer(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }
    
}