// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

/// @notice  OCR stands for "On-Chain Redemption".
///          This locker is responsible for handling redemptions of tranche tokens to stablecoins.
contract OCC_Modular is ZivoeLocker {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    /// @dev Redemption fee on withdrawals via OCR (in BIPS)
    uint16 redemptionFee;

    
    // -----------------
    //    Constructor
    // -----------------

    // ------------
    //    Events
    // ------------

    // ---------------
    //    Modifiers
    // ---------------

    // ---------------
    //    Functions
    // ---------------    

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }



}