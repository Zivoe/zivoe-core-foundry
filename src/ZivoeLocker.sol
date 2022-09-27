// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "./libraries/OpenZeppelin/IERC20.sol";
import "./libraries/OpenZeppelin/ERC1155Holder.sol";
import "./libraries/OpenZeppelin/ERC721Holder.sol";
import "./libraries/OpenZeppelin/Ownable.sol";
import "./libraries/OpenZeppelin/SafeERC20.sol";

import { IERC721, IERC1155 } from "./misc/InterfacesAggregated.sol";

/// @dev    This contract standardizes communication between the DAO and lockers.
abstract contract ZivoeLocker is Ownable, ERC1155Holder, ERC721Holder {
    
    using SafeERC20 for IERC20;

    constructor() {}

    /// @notice Permission for calling pushToLocker().
    function canPush() public virtual view returns (bool) {
        return false;
    }

    /// @notice Permission for calling pullFromLocker().
    function canPull() public virtual view returns (bool) {
        return false;
    }

    /// @notice Permission for calling pullFromLockerPartial().
    function canPullPartial() public virtual view returns (bool) {
        return false;
    }

    /// @notice Permission for calling pushToLockerMulti().
    function canPushMulti() public virtual view returns (bool) {
        return false;
    }

    /// @notice Permission for calling pullFromLockerMulti().
    function canPullMulti() public virtual view returns (bool) {
        return false;
    }

    /// @notice Permission for calling pullFromLockerMultiPartial().
    function canPullMultiPartial() public virtual view returns (bool) {
        return false;
    }

    /// @notice Permission for calling pushToLockerERC721().
    function canPushERC721() public virtual view returns (bool) {
        return false;
    }

    /// @notice Permission for calling pullFromLockerERC721().
    function canPullERC721() public virtual view returns (bool) {
        return false;
    }

    /// @notice Permission for calling pushToLockerMultiERC721().
    function canPushMultiERC721() public virtual view returns (bool) {
        return false;
    }

    /// @notice Permission for calling pullFromLockerMultiERC721().
    function canPullMultiERC721() public virtual view returns (bool) {
        return false;
    }

    /// @notice Permission for calling pushToLockerERC1155().
    function canPushERC1155() public virtual view returns (bool) {
        return false;
    }

    /// @notice Permission for calling pullFromLockerERC1155().
    function canPullERC1155() public virtual view returns (bool) {
        return false;
    }

    /// @notice Migrates specific amount of ERC20 from owner() to locker.
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    function pushToLocker(address asset, uint256 amount) external virtual onlyOwner {
        require(canPush(), "ZivoeLocker::pushToLocker() !canPush()");
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    function pullFromLocker(address asset) external virtual onlyOwner {
        require(canPull(), "ZivoeLocker::pullFromLocker() !canPull()");
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    function pullFromLockerPartial(address asset, uint256 amount) external virtual onlyOwner {
        require(canPullPartial(), "ZivoeLocker::pullFromLockerPartial() !canPullPartial()");
        IERC20(asset).safeTransfer(owner(), amount);
    }

    /// @notice Migrates specific amounts of ERC20s from owner() to locker.
    /// @param  assets The assets to migrate.
    /// @param  amounts The amounts of "assets" to migrate, corresponds to "assets" by position in array.
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) external virtual onlyOwner {
        require(canPushMulti(), "ZivoeLocker::pushToLockerMulti() !canPushMulti()");
        for (uint i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
        }
    }

    /// @notice Migrates full amount of ERC20s from locker to owner().
    /// @param  assets The assets to migrate.
    function pullFromLockerMulti(address[] calldata assets) external virtual onlyOwner {
        require(canPullMulti(), "ZivoeLocker::pullFromLockerMulti() !canPullMulti()");
        for (uint i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransfer(owner(), IERC20(assets[i]).balanceOf(address(this)));
        }
    }

    /// @notice Migrates specific amounts of ERC20s from locker to owner().
    /// @param  assets The assets to migrate.
    /// @param  amounts The amounts of "assets" to migrate, corresponds to "assets" by position in array.
    function pullFromLockerMultiPartial(address[] calldata assets, uint256[] calldata amounts) external virtual onlyOwner {
        require(canPullMultiPartial(), "ZivoeLocker::pullFromLockerMultiPartial() !canPullMultiPartial()");
        for (uint i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransfer(owner(), amounts[i]);
        }
    }

    // TODO: Update NatSpec below after unit testing.

    function pushToLockerERC721(address asset, uint256 tokenId, bytes calldata data) external virtual onlyOwner {
        require(canPushERC721(), "ZivoeLocker::pushToLockerERC721() !canPushERC721()");
        IERC721(asset).safeTransferFrom(owner(), address(this), tokenId, data);
    }

    function pullFromLockerERC721(address asset, uint256 tokenId, bytes calldata data) external virtual onlyOwner {
        require(canPullERC721(), "ZivoeLocker::pullFromLockerERC721() !canPullERC721()");
        IERC721(asset).safeTransferFrom(address(this), owner(), tokenId, data);
    }

    function pushToLockerMultiERC721(address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external virtual onlyOwner {
        require(canPushMultiERC721(), "ZivoeLocker::pushToLockerMultiERC721() !canPushMultiERC721()");
        for (uint i = 0; i < assets.length; i++) {
           IERC721(assets[i]).safeTransferFrom(owner(), address(this), tokenIds[i], data[i]);
        }
    }

    function pullFromLockerMultiERC721(address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external virtual onlyOwner {
        require(canPullMultiERC721(), "ZivoeLocker::pullFromLockerMultiERC721() !canPullMultiERC721()");
        for (uint i = 0; i < assets.length; i++) {
           IERC721(assets[i]).safeTransferFrom(address(this), owner(), tokenIds[i], data[i]);
        }
    }

    function pushToLockerERC1155(address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external virtual onlyOwner {
        require(canPushERC1155(), "ZivoeLocker::pushToLockerERC1155() !canPushERC1155()");
        IERC1155(asset).safeBatchTransferFrom(owner(), address(this), ids, amounts, data);
    }

    function pullFromLockerERC1155(address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external virtual onlyOwner {
        require(canPullERC1155(), "ZivoeLocker::pullFromLockerERC1155() !canPullERC1155()");
        IERC1155(asset).safeBatchTransferFrom(address(this), owner(), ids, amounts, data);
    }

}
