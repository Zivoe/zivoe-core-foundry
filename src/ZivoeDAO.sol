// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";

import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { IERC104, IERC721, IERC1155, IZivoeGlobals } from "./interfaces/InterfacesAggregated.sol";
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
contract ZivoeDAO is ERC1155Holder, ERC721Holder, Ownable {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;                       /// The ZivoeGlobals contract.

    mapping(address => bool) public lockerWhitelist;    /// The whitelist for lockers.


    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeDAO.sol contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address _GBL) {
        GBL = _GBL;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during modifyLockerWhitelist().
    /// @param  locker  The locker whose status on lockerWhitelist() mapping is updated.
    /// @param  allowed The boolean value to assign.
    event ModifyLockerWhitelist(address locker, bool allowed);

    // TODO: Add events for each specific push/pull variant.


    // ----------------
    //    Functions
    // ----------------

    /// @notice Modifies the lockerWhitelist.
    /// @dev    Only callable by ZVL.
    /// @param  locker  The locker to update.
    /// @param  allowed The value to assign (true = permitted, false = prohibited).
    function modifyLockerWhitelist(address locker, bool allowed) external {
        require(_msgSender() == IZivoeGlobals(GBL).ZVL(), "ZivoeDAO::modifyLockerWhitelist() _msgSender() != IZivoeGlobals(GBL).ZVL()");
        lockerWhitelist[locker] = allowed;
        emit ModifyLockerWhitelist(locker, allowed);
    }

    /// @notice Migrates capital from DAO to locker.
    /// @dev    Only callable by Admin.
    /// @param  locker  The locker to push capital to.
    /// @param  asset   The asset to push to locker.
    /// @param  amount  The amount of "asset" to push.
    function push(address locker, address asset, uint256 amount) external onlyOwner {
        require(lockerWhitelist[locker], "ZivoeDAO::push() !lockerWhitelist[locker]");
        require(IERC104(locker).canPush(), "ZivoeDAO::push() !IERC104(locker).canPush()");
        IERC20(asset).safeApprove(locker, amount);
        IERC104(locker).pushToLocker(asset, amount);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    Only callable by Admin.
    /// @param  locker The locker to pull from.
    /// @param  asset The asset to pull.
    function pull(address locker, address asset) external onlyOwner {
        require(IERC104(locker).canPull(), "ZivoeDAO::pull() !IERC104(locker).canPull()");
        IERC104(locker).pullFromLocker(asset);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    Only callable by Admin.
    /// @dev    The input "amount" might represent a ratio, BIPS, or an absolute amount depending on OCY.
    /// @param  locker The locker to pull from.
    /// @param  asset The asset to pull.
    /// @param  amount The amount to pull (may not refer to "asset", but rather a different asset within the OCY).
    function pullPartial(address locker, address asset, uint256 amount) external onlyOwner {
        require(IERC104(locker).canPullPartial(), "ZivoeDAO::pullPartial() !IERC104(locker).canPullPartial()");
        IERC104(locker).pullFromLockerPartial(asset, amount);
    }

    /// @notice Migrates multiple types of capital from DAO to locker.
    /// @dev    Only callable by Admin.
    /// @param  locker  The locker to push capital to.
    /// @param  assets  The assets to push to locker.
    /// @param  amounts The amount of "asset" to push.
    function pushMulti(address locker, address[] calldata assets, uint256[] calldata amounts) external onlyOwner {
        require(lockerWhitelist[locker], "ZivoeDAO::pushMulti() !lockerWhitelist[locker]");
        require(assets.length == amounts.length, "ZivoeDAO::pushMulti() assets.length != amounts.length");
        require(IERC104(locker).canPushMulti(), "ZivoeDAO::pushMulti() !IERC104(locker).canPushMulti()");
        for (uint i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeApprove(locker, amounts[i]);
        }
        IERC104(locker).pushToLockerMulti(assets, amounts);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    Only callable by Admin.
    /// @param  locker The locker to pull from.
    /// @param  assets The assets to pull.
    function pullMulti(address locker, address[] calldata assets) external onlyOwner {
        require(IERC104(locker).canPullMulti(), "ZivoeDAO::pullMulti() !IERC104(locker).canPullMulti()");
        IERC104(locker).pullFromLockerMulti(assets);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    Only callable by Admin.
    /// @param  locker The locker to pull from.
    /// @param  assets The asset to pull.
    /// @param  amounts The amounts to pull (may not refer to "assets", but rather a different asset within the OCY).
    function pullMultiPartial(address locker, address[] calldata assets, uint256[] calldata amounts) external onlyOwner {
        require(IERC104(locker).canPullMultiPartial(), "ZivoeDAO::pullMultiPartial() !IERC104(locker).canPullMultiPartial()");
        IERC104(locker).pullFromLockerMultiPartial(assets, amounts);
    }

    /// @notice Migrates an NFT from the DAO to a locker.
    /// @dev    Only callable by Admin.
    /// @param  locker  The locker to push an NFT to.
    /// @param  asset The NFT contract.
    /// @param  tokenId The NFT ID to push.
    function pushERC721(address locker, address asset, uint tokenId, bytes calldata data) external onlyOwner {
        require(lockerWhitelist[locker], "ZivoeDAO::pushERC721() !lockerWhitelist[locker]");
        require(IERC104(locker).canPushERC721(), "ZivoeDAO::pushERC721() !IERC104(locker).canPushERC721()");
        IERC721(asset).approve(locker, tokenId);
        IERC104(locker).pushToLockerERC721(asset, tokenId, data);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    Only callable by Admin.
    /// @param  locker The locker to pull from.
    /// @param  asset The NFT contract.
    /// @param  tokenId The NFT ID to pull.
    function pullERC721(address locker, address asset, uint tokenId, bytes calldata data) external onlyOwner {
        require(IERC104(locker).canPullERC721(), "ZivoeDAO::pullERC721() !IERC104(locker).canPullERC721()");
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
    ) external onlyOwner {
        require(lockerWhitelist[locker], "ZivoeDAO::pushERC1155Batch() !lockerWhitelist[locker]");
        require(IERC104(locker).canPushERC1155(), "ZivoeDAO::pushERC1155Batch() !IERC104(locker).canPushERC1155()");
        IERC1155(asset).setApprovalForAll(locker, true);
        IERC104(locker).pushToLockerERC1155(asset, ids, amounts, data);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    Only callable by Admin.
    /// @param  locker The locker to pull from.
    /// @param  asset The asset to pull.
    function pullERC1155Batch(
            address locker,
            address asset,
            uint256[] calldata ids, 
            uint256[] calldata amounts,
            bytes calldata data
    ) external onlyOwner {
        require(IERC104(locker).canPullERC1155(), "ZivoeDAO::pullERC1155Batch() !IERC104(locker).canPullERC1155()");
        IERC104(locker).pullFromLockerERC1155(asset, ids, amounts, data);
    }

}
