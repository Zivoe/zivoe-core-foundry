// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;



/// @notice This contract is an ERC4626 vault for zSTT.
///         This contract has the following responsibilities:
///          - Mints zSTT with stablecoins, then mints zUSD vault tokens for user.
///          - Handles vault deposit checks according to:
/*
 * CAUTION: When the vault is empty or nearly empty, deposits are at high risk of being stolen through frontrunning with
 * a "donation" to the vault that inflates the price of a share. This is variously known as a donation or inflation
 * attack and is essentially a problem of slippage. Vault deployers can protect against this attack by making an initial
 * deposit of a non-trivial amount of the asset, such that price manipulation becomes infeasible. Withdrawals may
 * similarly be affected by slippage. Users can protect against this attack as well unexpected slippage in general by
 * verifying the amount received is as expected, using a wrapper that performs these checks such as
 * https://github.com/fei-protocol/ERC4626#erc4626router-and-base[ERC4626Router].
 *
*/

// ALSO SEE https://github.com/ERC4626-Alliance/ERC4626-Contracts#erc4626router-and-base%5BERC4626Router%5D
contract ZivoeRouterV1 {

    // ---------------------
    //    State Variables
    // ---------------------

    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeRouterV1 contract.
    constructor() { }


    // ------------
    //    Events
    // ------------

    // ---------------
    //    Modifiers
    // ---------------

    // ----------------
    //    Functions
    // ----------------

}