// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

/// @dev    This contract is for testing generic ZivoeLocker functions (inherited non-overridden functions).
contract OCY_Generic_ERC721 is ZivoeLocker {
    
    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the OCY_Generic.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    constructor(address DAO) {
        transferOwnership(DAO);
    }

    function canPushERC721() public pure override returns (bool) {
        return true;
    }

    function canPullERC721() public pure override returns (bool) {
        return true;
    }

    function canPushMultiERC721() public pure override returns (bool) {
        return true;
    }

    function canPullMultiERC721() public pure override returns (bool) {
        return true;
    }

}
