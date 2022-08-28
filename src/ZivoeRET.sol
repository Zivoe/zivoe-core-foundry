// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";

import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { IZivoeYDL, IZivoeGlobals } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract escrows retained earnings distribute via the Zivoe Yield Distribution Locker.
contract ZivoeRET is Ownable {
    
    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;  /// @dev The ZivoeGlobals contract.



    // -----------------
    //    Constructor
    // -----------------

    // TODO: Refactor into GnosisSafe multi-sig (upon further discussion).

    /// @notice Initializes the ZivoeDAO.sol contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address _GBL) { 
        GBL = _GBL;
    }



    // ---------------
    //    Functions
    // ---------------

    // TODO: Consider required functionality, or BAL-like governance / asset management.

    /// @notice Push assets to a ZivoeRewards.sol contract via ZivoeYDL.sol.
    /// @dev    Only callable by governance.
    /// @param  asset   The asset to push.
    /// @param  amount  The amount to push.
    /// @param  multi   The specific ZivoeRewards.sol contract address.
    function passThroughYDL(address asset, uint256 amount, address multi) external onlyOwner {
        IERC20(asset).transfer(IZivoeGlobals(GBL).YDL(), amount);
        IZivoeYDL(IZivoeGlobals(GBL).YDL()).passThrough(asset, amount, multi);
    }

    /// @notice Migrates capital from RET to specified location.
    /// @dev    Only callable by governance.
    /// @param  asset   The asset to push.
    /// @param  to      The location to push asset.
    /// @param  amount  The amount to push.
    function pushAsset(address asset, address to, uint256 amount) external onlyOwner {
        IERC20(asset).transfer(to, amount);
    }
    
}
