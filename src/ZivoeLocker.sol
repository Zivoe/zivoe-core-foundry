// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../lib/OpenZeppelin/IERC20.sol";
import "../lib/OpenZeppelin/ERC1155Holder.sol";
import "../lib/OpenZeppelin/ERC721Holder.sol";
import "../lib/OpenZeppelin/Ownable.sol";
import "../lib/OpenZeppelin/SafeERC20.sol";

interface IERC721_P_1 {
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) external;
    function approve(address to, uint256 tokenId) external;
}

interface IERC1155_P_1 {
    function setApprovalForAll(address operator, bool approved) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

/// @notice  This contract standardizes communication between the DAO and lockers.
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
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
        }
    }

    /// @notice Migrates full amount of ERC20s from locker to owner().
    /// @param  assets The assets to migrate.
    function pullFromLockerMulti(address[] calldata assets) external virtual onlyOwner {
        require(canPullMulti(), "ZivoeLocker::pullFromLockerMulti() !canPullMulti()");
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransfer(owner(), IERC20(assets[i]).balanceOf(address(this)));
        }
    }

    /// @notice Migrates specific amounts of ERC20s from locker to owner().
    /// @param  assets The assets to migrate.
    /// @param  amounts The amounts of "assets" to migrate, corresponds to "assets" by position in array.
    function pullFromLockerMultiPartial(address[] calldata assets, uint256[] calldata amounts) external virtual onlyOwner {
        require(canPullMultiPartial(), "ZivoeLocker::pullFromLockerMultiPartial() !canPullMultiPartial()");
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransfer(owner(), amounts[i]);
        }
    }

    /// @notice Migrates an ERC721 from owner() to locker.
    /// @param  asset The NFT contract.
    /// @param  tokenId The ID of the NFT to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLockerERC721(address asset, uint256 tokenId, bytes calldata data) external virtual onlyOwner {
        require(canPushERC721(), "ZivoeLocker::pushToLockerERC721() !canPushERC721()");
        IERC721_P_1(asset).safeTransferFrom(owner(), address(this), tokenId, data);
    }

    /// @notice Migrates an ERC721 from locker to owner().
    /// @param  asset The NFT contract.
    /// @param  tokenId The ID of the NFT to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerERC721(address asset, uint256 tokenId, bytes calldata data) external virtual onlyOwner {
        require(canPullERC721(), "ZivoeLocker::pullFromLockerERC721() !canPullERC721()");
        IERC721_P_1(asset).safeTransferFrom(address(this), owner(), tokenId, data);
    }

    /// @notice Migrates ERC721s from owner() to locker.
    /// @param  assets The NFT contracts.
    /// @param  tokenIds The IDs of the NFTs to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLockerMultiERC721(address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external virtual onlyOwner {
        require(canPushMultiERC721(), "ZivoeLocker::pushToLockerMultiERC721() !canPushMultiERC721()");
        for (uint256 i = 0; i < assets.length; i++) {
           IERC721_P_1(assets[i]).safeTransferFrom(owner(), address(this), tokenIds[i], data[i]);
        }
    }

    /// @notice Migrates ERC721s from locker to owner().
    /// @param  assets The NFT contracts.
    /// @param  tokenIds The IDs of the NFTs to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerMultiERC721(address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external virtual onlyOwner {
        require(canPullMultiERC721(), "ZivoeLocker::pullFromLockerMultiERC721() !canPullMultiERC721()");
        for (uint256 i = 0; i < assets.length; i++) {
           IERC721_P_1(assets[i]).safeTransferFrom(address(this), owner(), tokenIds[i], data[i]);
        }
    }

    /// @notice Migrates ERC1155 assets from owner() to locker.
    /// @param  asset The ERC1155 contract.
    /// @param  ids The IDs of the assets within the ERC1155 to migrate.
    /// @param  amounts The amounts to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLockerERC1155(address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external virtual onlyOwner {
        require(canPushERC1155(), "ZivoeLocker::pushToLockerERC1155() !canPushERC1155()");
        IERC1155_P_1(asset).safeBatchTransferFrom(owner(), address(this), ids, amounts, data);
    }

    /// @notice Migrates ERC1155 assets from locker to owner().
    /// @param  asset The ERC1155 contract.
    /// @param  ids The IDs of the assets within the ERC1155 to migrate.
    /// @param  amounts The amounts to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerERC1155(address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external virtual onlyOwner {
        require(canPullERC1155(), "ZivoeLocker::pullFromLockerERC1155() !canPullERC1155()");
        IERC1155_P_1(asset).safeBatchTransferFrom(address(this), owner(), ids, amounts, data);
    }

    // NOTE: Delete the below ?
    // TODO: Determine if this overwrites sub-function transferOwnership() properly to prevent
    //       the DAO from transferring ZivoeLocker to any other actor as a default (but keep
    //       as a virtual function in case on an individual locker level we want this).

    function transferOwnership() external virtual onlyOwner {
        revert();
    }

}
