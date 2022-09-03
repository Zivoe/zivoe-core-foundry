// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";

import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { IERC721, IERC1155 } from "./interfaces/InterfacesAggregated.sol";
import { ERC1155Holder } from "./OpenZeppelin/ERC1155Holder.sol";
import { ERC721Holder } from "./OpenZeppelin/ERC721Holder.sol";

/// @dev    This contract standardizes communication between the DAO and lockers.
abstract contract ZivoeLocker is Ownable, ERC1155Holder, ERC721Holder {
    
    using SafeERC20 for IERC20;

    constructor() {}

    // TODO: Add NatSpec to the following contract!

    function canPush() external virtual view returns (bool) {
        return false;
    }

    function canPull() external virtual view returns (bool) {
        return false;
    }

    function canPullPartial() external virtual view returns (bool) {
        return false;
    }

    function canPushMulti() external virtual view returns (bool) {
        return false;
    }

    function canPullMulti() external virtual view returns (bool) {
        return false;
    }

    function canPullMultiPartial() external virtual view returns (bool) {
        return false;
    }

    function canPushERC721() external virtual view returns (bool) {
        return false;
    }

    function canPullERC721() external virtual view returns (bool) {
        return false;
    }

    function canPushERC1155() external virtual view returns (bool) {
        return false;
    }

    function canPullERC1155() external virtual view returns (bool) {
        return false;
    }

    function pushToLocker(address asset, uint256 amount) external virtual onlyOwner {
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }

    function pullFromLocker(address asset) external virtual onlyOwner {
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
    }

    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) external virtual onlyOwner {
        for (uint i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
        }
    }

    function pullFromLockerMulti(address[] calldata assets) external virtual onlyOwner {
        for (uint i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransfer(owner(), IERC20(assets[i]).balanceOf(address(this)));
        }
    }

    function pushToLockerERC721(address asset, uint256 tokenId, bytes calldata data) external virtual onlyOwner {
        IERC721(asset).safeTransferFrom(owner(), address(this), tokenId, data);
    }

    function pullFromLockerERC721(address asset, uint256 tokenId, bytes calldata data) external virtual onlyOwner {
        IERC721(asset).safeTransferFrom(address(this), owner(), tokenId, data);
    }

    function pushToLockerERC1155(address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external virtual onlyOwner {
        IERC1155(asset).safeBatchTransferFrom(owner(), address(this), ids, amounts, data);
    }

    function pullFromLockerERC1155(address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external virtual onlyOwner {
        IERC1155(asset).safeBatchTransferFrom(address(this), owner(), ids, amounts, data);
    }

}
