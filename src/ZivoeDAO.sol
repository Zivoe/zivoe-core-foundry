// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/OwnableGovernance.sol";

import { IERC20, IERC104, IERC721, IERC1155, IZivoeGBL } from "./interfaces/InterfacesAggregated.sol";
import { ERC1155Holder } from "./OpenZeppelin/ERC1155Holder.sol";
import { ERC721Holder } from "./OpenZeppelin/ERC721Holder.sol";

/// @dev    This contract escrows unused or unallocated capital.
///         This contract has the following responsibilities:
///          - Deployment and redemption of capital:
///             (a) Pushing assets to a locker.
///             (b) Pulling assets from a locker.
///           - Enforces a whitelist of lockers through which pushing and pulling capital can occur.
///           - This whitelist is modifiable.
///         To be determined:
///          - How governance would be used to enforce actions.
contract ZivoeDAO is OwnableGovernance, ERC1155Holder, ERC721Holder {
    
    // ---------------
    // State Variables
    // ---------------

    mapping(address => bool) public lockerWhitelist;   /// @dev The whitelist for lockers.

    address public immutable GBL;   /// @dev The ZivoeGlobals contract.



    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the ZivoeDAO.sol contract.
    /// @param gov  Governance contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address gov, address _GBL) {
        GBL = _GBL;
        transferOwnershipOnce(gov);
    }



    // ------
    // Events
    // ------

    /// @notice Emitted during modifyLockerWhitelist().
    /// @param  locker  The locker whose status on lockerWhitelist() mapping is updated.
    /// @param  allowed The boolean value to assign.
    event ModifyLockerWhitelist(address locker, bool allowed);



    // ---------
    // Functions
    // ---------

    /// @notice Modifies the lockerWhitelist.
    /// @dev    Only callable by ZVL.
    /// @param  locker  The locker to update.
    /// @param  allowed The value to assign (true = permitted, false = prohibited).
    function modifyLockerWhitelist(address locker, bool allowed) external {
        require(_msgSender() == IZivoeGBL(GBL).ZVL());
        lockerWhitelist[locker] = allowed;
        emit ModifyLockerWhitelist(locker, allowed);
    }

    /// @notice Migrates capital from DAO to locker.
    /// @dev    Only callable by Admin.
    /// @param  locker  The locker to push capital to.
    /// @param  asset   The asset to push to locker.
    /// @param  amount  The amount of "asset" to push.
    function push(address locker, address asset, uint256 amount) public onlyGovernance {
        require(lockerWhitelist[locker]);
        require(IERC104(locker).canPush());
        IERC20(asset).approve(locker, amount);
        IERC104(locker).pushToLocker(asset, amount);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    Only callable by Admin.
    /// @param  locker The locker to pull from.
    /// @param  locker The asset to pull.
    function pull(address locker, address asset) public onlyGovernance {
        require(IERC104(locker).canPull());
        IERC104(locker).pullFromLocker(asset);
    }

    /// @notice Migrates multiple types of capital from DAO to locker.
    /// @dev    Only callable by Admin.
    /// @param  locker  The locker to push capital to.
    /// @param  assets  The assets to push to locker.
    /// @param  amounts The amount of "asset" to push.
    function pushMulti(address locker, address[] calldata assets, uint256[] calldata amounts) public onlyGovernance {
        require(lockerWhitelist[locker]);
        require(assets.length == amounts.length);
        require(IERC104(locker).canPushMulti());
        for (uint i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(locker, amounts[i]);
        }
        IERC104(locker).pushToLockerMulti(assets, amounts);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    Only callable by Admin.
    /// @param  locker The locker to pull from.
    /// @param  locker The asset to pull.
    function pullMulti(address locker, address[] calldata assets) public onlyGovernance {
        require(IERC104(locker).canPullMulti());
        IERC104(locker).pullFromLockerMulti(assets);
    }

    /// @notice Migrates an NFT from the DAO to a locker.
    /// @dev    Only callable by Admin.
    /// @param  locker  The locker to push an NFT to.
    /// @param  asset The NFT contract.
    /// @param  tokenId The NFT ID to push.
    function pushERC721(address locker, address asset, uint tokenId, bytes calldata data) public onlyGovernance {
        require(lockerWhitelist[locker]);
        require(IERC104(locker).canPushERC721());
        IERC721(asset).approve(locker, tokenId);
        IERC104(locker).pushToLockerERC721(asset, tokenId, data);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    Only callable by Admin.
    /// @param  locker The locker to pull from.
    /// @param  asset The NFT contract.
    /// @param  tokenId The NFT ID to pull.
    function pullERC721(address locker, address asset, uint tokenId, bytes calldata data) public onlyGovernance {
        require(IERC104(locker).canPullERC721());
        IERC104(locker).pullFromLockerERC721(asset, tokenId, data);
    }

    

    // TODO: Unit testing for ERC-721 push/pull + ERC-1155 push/pull

    /// @notice Migrates capital from DAO to locker.
    /// @dev    Only callable by Admin.
    /// @param  locker  The locker to push capital to.
    /// @param  asset   The asset to push to locker.
    /// @param  ids  The ids of "assets" to push.
    /// @param  amounts  The amounts of "assets" to push.
    /// @param data Any misc. string data to pass through.
    function pushERC1155Batch(
            address locker,
            address asset,
            uint256[] calldata ids, 
            uint256[] calldata amounts,
            bytes calldata data
    ) public onlyGovernance {
        require(lockerWhitelist[locker]);
        require(IERC104(locker).canPushERC1155());
        IERC1155(asset).setApprovalForAll(locker, true);
        IERC104(locker).pushToLockerERC1155(asset, ids, amounts, data);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    Only callable by Admin.
    /// @param  locker The locker to pull from.
    /// @param  locker The asset to pull.
    function pullERC1155Batch(
            address locker,
            address asset,
            uint256[] calldata ids, 
            uint256[] calldata amounts,
            bytes calldata data
    ) public onlyGovernance {
        require(IERC104(locker).canPullERC1155());
        IERC104(locker).pullFromLockerERC1155(asset, ids, amounts, data);
    }

}
