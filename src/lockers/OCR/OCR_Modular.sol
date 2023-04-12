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

    uint16 public redemptionFee;             /// @dev Redemption fee on withdrawals via OCR (in BIPS)
    address public immutable stablecoin;     /// @dev The stablecoin redeemable in this contract
    address public immutable GBL;            /// @dev The ZivoeGlobals contract.    
    


    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCR_Modular contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _stablecoin The stablecoin redeemable in this OCR contract.
    /// @param _GBL The yield distribution locker that collects and distributes capital for this OCR locker.
    constructor(address DAO, address _stablecoin, address _GBL) {
        transferOwnershipAndLock(DAO);
        stablecoin = _stablecoin;
        GBL = _GBL;
    }

    // ------------
    //    Events
    // ------------

    // ---------------
    //    Functions
    // ---------------    

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }



}