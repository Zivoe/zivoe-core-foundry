// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/OwnableGovernance.sol";

import { IERC20, IZivoeYDL } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract escrows retained earnings distribute via the Zivoe Yield Distribution Locker.
///         This contract has the following responsibilities:
///          - Deployment and redemption of capital:
///             (a) Pushing assets to a locker.
///             (b) Pulling assets from a locker.
///           - Enforces a whitelist of lockers through which pushing and pulling capital can occur.
///           - This whitelist is modifiable.
///         To be determined:
///          - How governance would be used to enforce actions.
contract ZivoeRET is OwnableGovernance {
    
    // ---------------
    // State Variables
    // ---------------

    address public YDL;     /// @dev The address for ZivoeYieldDistributionLocker.sol.


    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the ZivoeDAO.sol contract.
    /// @param gov Governance contract.
    constructor(address gov, address _YDL) {
        YDL = _YDL;
        transferOwnershipOnce(gov);
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

    /// @notice Push assets to a MultiRewards.sol contract via ZivoeYieldDistributionLocker.sol.
    /// @dev    Only callable by governance.
    /// @param  asset   The asset to push.
    /// @param  amount  The amount to push.
    /// @param  multi   The specific MultiRewards.sol contract address.
    function passThroughYield(address asset, uint256 amount, address multi) public onlyGovernance {
        IERC20(asset).approve(YDL, amount);
        IZivoeYDL(YDL).passThrough(asset, amount, multi);
    }
}
