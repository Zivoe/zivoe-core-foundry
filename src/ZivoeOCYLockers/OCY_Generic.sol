// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

/// @dev    This contract is for testing generic ZivoeLocker functions (inherited non-overridden functions).
contract OCY_Generic is ZivoeLocker {
    
    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the OCY_Generic.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    constructor(address DAO) {
        transferOwnership(DAO);
    }

    function canPush() external pure override returns(bool) {
        return true;
    }

    function canPull() external pure override returns(bool) {
        return true;
    }

}
