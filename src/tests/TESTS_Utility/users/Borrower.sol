// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;
pragma experimental ABIEncoderV2;

import "../../../../lib/OpenZeppelin/IERC20.sol";

contract Borrower {

    /************************/
    /*** DIRECT FUNCTIONS ***/
    /************************/

    function transferByTrader(address token, address to, uint256 amt) external {
        IERC20(token).transfer(to, amt);
    }

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/


    function try_approveToken(address token, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "approve(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }

    function try_requestLoan(
        address occ, 
        address borrower,
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 term,
        uint256 paymentInterval,
        uint256 gracePeriod,
        int8 schedule
    ) external returns (bool ok) {
        string memory sig = "requestLoan(address,uint256,uint256,uint256,uint256,uint256,uint256,int8)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, borrower, borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, schedule));
    }

    function try_cancelRequest(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "cancelRequest(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_fundLoan(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "fundLoan(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_makePayment(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "makePayment(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_resolveDefault(address occ, uint256 id, uint256 amt) external returns (bool ok) {
        string memory sig = "resolveDefault(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, amt));
    }

    function try_callLoan(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "callLoan(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_markDefault(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "markDefault(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_resolveInsolvency(address occ, uint256 id, uint256 amount) external returns (bool ok) {
        string memory sig = "resolveInsolvency(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, amount));
    }

    function try_supplyInterest(address occ, uint256 id, uint256 excessAmount) external returns (bool ok) {
        string memory sig = "supplyInterest(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, excessAmount));
    }
    
}