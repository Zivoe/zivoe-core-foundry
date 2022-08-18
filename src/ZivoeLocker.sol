// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";

import { IERC20, IERC721, IERC1155 } from "./interfaces/InterfacesAggregated.sol";
import { ERC1155Holder } from "./OpenZeppelin/ERC1155Holder.sol";
import { ERC721Holder } from "./OpenZeppelin/ERC721Holder.sol";

/// @dev    This contract standardizes communication between the DAO and lockers.
abstract contract ZivoeLocker is Ownable, ERC1155Holder, ERC721Holder {
    
    constructor() {}

    // TODO: Add NatSpec to the following contract!

    function canPush() virtual external view returns(bool) {
        return false;
    }

    function canPull() virtual external view returns(bool) {
        return false;
    }

    function canPushMulti() virtual external view returns(bool) {
        return false;
    }

    function canPullMulti() virtual external view returns(bool) {
        return false;
    }

    function canPushERC721() virtual external view returns(bool) {
        return false;
    }

    function canPullERC721() virtual external view returns(bool) {
        return false;
    }

    function canPushERC1155() virtual external view returns(bool) {
        return false;
    }

    function canPullERC1155() virtual external view returns(bool) {
        return false;
    }

    function pushToLocker(address asset, uint256 amount) virtual external {
        IERC20(asset).transferFrom(owner(), address(this), amount);
    }

    function pullFromLocker(address asset) virtual external {
        IERC20(asset).transfer(owner(), IERC20(asset).balanceOf(address(this)));
    }

    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) virtual external {
        for (uint i = 0; i < assets.length; i++) {
            IERC20(assets[i]).transferFrom(owner(), address(this), amounts[i]);
        }
    }

    function pullFromLockerMulti(address[] calldata assets) virtual external {
        for (uint i = 0; i < assets.length; i++) {
            IERC20(assets[i]).transfer(owner(), IERC20(assets[i]).balanceOf(address(this)));
        }
    }

    function pushToLockerERC721(address asset, uint256 tokenId, bytes calldata data) virtual external {
        IERC721(asset).safeTransferFrom(owner(), address(this), tokenId, data);
    }

    function pullFromLockerERC721(address asset, uint256 tokenId, bytes calldata data) virtual external {
        IERC721(asset).safeTransferFrom(address(this), owner(), tokenId, data);
    }

    function pushToLockerERC1155(address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) virtual external {
        IERC1155(asset).safeBatchTransferFrom(owner(), address(this), ids, amounts, data);
    }

    function pullFromLockerERC1155(address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) virtual external {
        IERC1155(asset).safeBatchTransferFrom(address(this), owner(), ids, amounts, data);
    }

}
