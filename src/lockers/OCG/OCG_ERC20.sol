// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

/// @dev    This contract is for testing generic ERC20 ZivoeLocker functions (inherited non-overridden functions).
contract OCG_ERC20 is ZivoeLocker {
    
    // -----------------
    //    Constructor
    // -----------------
    
    /// @notice Initializes the OCY_Generic.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    constructor(address DAO) {
        transferOwnership(DAO);
    }



    // ---------------
    //    Functions
    // ---------------

    function canPush() public pure override returns (bool) {
        return true;
    }

    function canPull() public pure override returns (bool) {
        return true;
    }

    function canPullPartial() public pure override returns (bool) {
        return true;
    }

    function canPushMulti() public pure override returns (bool) {
        return true;
    }

    function canPullMulti() public pure override returns (bool) {
        return true;
    }

    function canPullMultiPartial() public pure override returns (bool) {
        return true;
    }


}
