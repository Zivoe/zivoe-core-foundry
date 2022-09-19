// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "./libraries/OpenZeppelin/IERC20.sol";
import "./libraries/OpenZeppelin/ERC1155Holder.sol";
import "./libraries/OpenZeppelin/ERC721Holder.sol";
import "./libraries/OpenZeppelin/Ownable.sol";
import "./libraries/OpenZeppelin/SafeERC20.sol";

import { IERC104, IERC721, IERC1155, IZivoeGlobals } from "./misc/InterfacesAggregated.sol";

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

    /// @notice Emitted during push().
    /// @param  locker The locker receiving "asset".
    /// @param  asset The asset being pushed.
    /// @param  amount The amount of "asset" being pushed.
    event Pushed(address indexed locker, address asset, uint256 amount);

    /// @notice Emitted during pull().
    /// @param  locker The locker "asset" is pulled from.
    /// @param  asset The asset being pulled.
    event Pulled(address indexed locker, address asset);

    /// @notice Emitted during pullPartial().
    /// @param  locker The locker "asset" is pulled from.
    /// @param  asset The asset being pulled.
    /// @param  amount The amount of "asset" being pulled.
    event PulledPartial(address indexed locker, address asset, uint256 amount);

    /// @notice Emitted during pushMulti().
    /// @param  locker The locker receiving "assets".
    /// @param  assets The assets being pushed, corresponds to "amounts" by position in array.
    /// @param  amounts The amounts of "assets" being pushed, corresponds to "assets" by position in array.
    event PushedMulti(address locker, address[] assets, uint256[] amounts);

    /// @notice Emitted during pullMulti().
    /// @param  locker The locker "assets" are pulled from.
    /// @param  assets The assets being pulled.
    event PulledMulti(address locker, address[] assets);

    /// @notice Emitted during pullMultiPartial().
    /// @param  locker The locker "assets" are pulled from.
    /// @param  assets The assets being pulled, corresponds to "amounts" by position in array.
    /// @param  amounts The amounts of "assets" being pulled, corresponds to "assets" by position in array.
    event PulledMultiPartial(address locker, address[] assets, uint256[] amounts);

    // ----------------
    //    Functions
    // ----------------

    /// @notice Migrates capital from DAO to locker.
    /// @dev    Only callable by Admin.
    /// @param  locker  The locker to push capital to.
    /// @param  asset   The asset to push to locker.
    /// @param  amount  The amount of "asset" to push.
    function push(address locker, address asset, uint256 amount) external onlyOwner {
        require(IZivoeGlobals(GBL).isLocker(locker), "ZivoeDAO::push() !IZivoeGlobals(GBL).isLocker(locker)");
        require(IERC104(locker).canPush(), "ZivoeDAO::push() !IERC104(locker).canPush()");
        emit Pushed(locker, asset, amount);
        IERC20(asset).safeApprove(locker, amount);
        IERC104(locker).pushToLocker(asset, amount);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    Only callable by Admin.
    /// @param  locker The locker to pull from.
    /// @param  asset The asset to pull.
    function pull(address locker, address asset) external onlyOwner {
        require(IERC104(locker).canPull(), "ZivoeDAO::pull() !IERC104(locker).canPull()");
        emit Pulled(locker, asset);
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
        emit PulledPartial(locker, asset, amount);
        IERC104(locker).pullFromLockerPartial(asset, amount);
    }

    /// @notice Migrates multiple types of capital from DAO to locker.
    /// @dev    Only callable by Admin.
    /// @param  locker  The locker to push capital to.
    /// @param  assets  The assets to push to locker.
    /// @param  amounts The amount of "asset" to push.
    function pushMulti(address locker, address[] calldata assets, uint256[] calldata amounts) external onlyOwner {
        require(IZivoeGlobals(GBL).isLocker(locker), "ZivoeDAO::pushMulti() !IZivoeGlobals(GBL).isLocker(locker)");
        require(assets.length == amounts.length, "ZivoeDAO::pushMulti() assets.length != amounts.length");
        require(IERC104(locker).canPushMulti(), "ZivoeDAO::pushMulti() !IERC104(locker).canPushMulti()");
        emit PushedMulti(locker, assets, amounts);
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
        emit PulledMulti(locker, assets);
        IERC104(locker).pullFromLockerMulti(assets);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    Only callable by Admin.
    /// @param  locker The locker to pull from.
    /// @param  assets The asset to pull.
    /// @param  amounts The amounts to pull (may not refer to "assets", but rather a different asset within the OCY).
    function pullMultiPartial(address locker, address[] calldata assets, uint256[] calldata amounts) external onlyOwner {
        require(IERC104(locker).canPullMultiPartial(), "ZivoeDAO::pullMultiPartial() !IERC104(locker).canPullMultiPartial()");
        emit PulledMultiPartial(locker, assets, amounts);
        IERC104(locker).pullFromLockerMultiPartial(assets, amounts);
    }

    // TODO: Unit testing for ERC-721 push/pull + ERC-1155 push/pull + event logs

    /// @notice Migrates an NFT from the DAO to a locker.
    /// @dev    Only callable by Admin.
    /// @param  locker  The locker to push an NFT to.
    /// @param  asset The NFT contract.
    /// @param  tokenId The NFT ID to push.
    function pushERC721(address locker, address asset, uint tokenId, bytes calldata data) external onlyOwner {
        require(IZivoeGlobals(GBL).isLocker(locker), "ZivoeDAO::pushERC721() !IZivoeGlobals(GBL).isLocker(locker)");
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
        require(IZivoeGlobals(GBL).isLocker(locker), "ZivoeDAO::pushERC1155Batch() !IZivoeGlobals(GBL).isLocker(locker)");
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
