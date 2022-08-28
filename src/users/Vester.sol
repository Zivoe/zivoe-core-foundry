// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;
pragma experimental ABIEncoderV2;

contract Vester {

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/

    function try_fullWithdraw(address mrv) external returns (bool ok) {
        string memory sig = "fullWithdraw()";
        (ok,) = address(mrv).call(abi.encodeWithSignature(sig));
    }

    function try_withdraw(address mrv) external returns (bool ok) {
        string memory sig = "withdraw()";
        (ok,) = address(mrv).call(abi.encodeWithSignature(sig));
    }

    function try_getRewards(address mrv) external returns (bool ok) {
        string memory sig = "getRewards()";
        (ok,) = address(mrv).call(abi.encodeWithSignature(sig));
    }
}