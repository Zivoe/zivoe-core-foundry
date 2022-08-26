// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/OwnableGovernance.sol";

import { IERC20, IZivoeYDL, IZivoeGBL } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract escrows retained earnings distribute via the Zivoe Yield Distribution Locker.
contract ZivoeRET is OwnableGovernance {
    
    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;  /// @dev Zivoe globals contract.



    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the ZivoeDAO.sol contract.
    /// @param god Governance contract.
    /// @param _GBL     The ZivoeGlobals contract.
    constructor(address god, address _GBL) { 
        GBL = _GBL;
        transferOwnershipOnce(god);
    }



    // ---------
    // Functions
    // --------- 

    /// @notice Migrates capital from RET to specified location.
    /// @dev    Only callable by governance.
    /// @param  asset   The asset to push.
    /// @param  to      The location to push asset.
    /// @param  amount  The amount to push.
    function pushAsset(address asset, address to, uint256 amount) public onlyGovernance {
        IERC20(asset).transfer(to, amount);
    }

    /// @notice Push assets to a MultiRewards.sol contract via ZivoeYDL.sol.
    /// @dev    Only callable by governance.
    /// @param  asset   The asset to push.
    /// @param  amount  The amount to push.
    /// @param  multi   The specific MultiRewards.sol contract address.
    function passThroughYDL(address asset, uint256 amount, address multi) public onlyGovernance {
        IERC20(asset).transfer(IZivoeGBL(GBL).YDL(), amount);
        IZivoeYDL(IZivoeGBL(GBL).YDL()).passThrough(asset, amount, multi);
    }
    
}
