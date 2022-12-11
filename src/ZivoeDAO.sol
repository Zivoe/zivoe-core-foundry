// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../lib/OpenZeppelin/IERC20.sol";
import "../lib/OpenZeppelin/ERC1155Holder.sol";
import "../lib/OpenZeppelin/ERC721Holder.sol";
import "../lib/OpenZeppelin/Ownable.sol";
import "../lib/OpenZeppelin/SafeERC20.sol";

interface IZivoeGlobals_P_5 {
    function isLocker(address) external view returns (bool);
}

interface IERC104_P_0 {
    function pushToLocker(address asset, uint256 amount) external;
    function pullFromLocker(address asset) external;
    function pullFromLockerPartial(address asset, uint256 amount) external;
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) external;
    function pullFromLockerMulti(address[] calldata assets) external;
    function pullFromLockerMultiPartial(address[] calldata assets, uint256[] calldata amounts) external;
    function pushToLockerERC721(address asset, uint256 tokenId, bytes calldata data) external;
    function pullFromLockerERC721(address asset, uint256 tokenId, bytes calldata data) external;
    function pushToLockerMultiERC721(address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external;
    function pullFromLockerMultiERC721(address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external;
    function pushToLockerERC1155(
        address asset, 
        uint256[] calldata ids, 
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
    function pullFromLockerERC1155(
        address asset, 
        uint256[] calldata ids, 
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
    function canPush() external view returns (bool);
    function canPull() external view returns (bool);
    function canPullPartial() external view returns (bool);
    function canPushMulti() external view returns (bool);
    function canPullMulti() external view returns (bool);
    function canPullMultiPartial() external view returns (bool);
    function canPushERC721() external view returns (bool);
    function canPullERC721() external view returns (bool);
    function canPushMultiERC721() external view returns (bool);
    function canPullMultiERC721() external view returns (bool);
    function canPushERC1155() external view returns (bool);
    function canPullERC1155() external view returns (bool);
}

interface IERC721_P_0 {
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) external;
    function approve(address to, uint256 tokenId) external;
}

interface IERC1155_P_0 {
    function setApprovalForAll(address operator, bool approved) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

/// @notice This contract escrows unused or unallocated capital.
///         This contract has the following responsibilities:
///          - Deployment and redemption of capital:
///             (a) Pushing assets to a locker.
///             (b) Pulling assets from a locker.
///           - Enforces a whitelist of lockers through which pushing and pulling capital can occur.
///           - This whitelist is modifiable.
contract ZivoeDAO is ERC1155Holder, ERC721Holder, Ownable {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;   /// @dev The ZivoeGlobals contract.



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
    event Pushed(address indexed locker, address indexed asset, uint256 amount);

    /// @notice Emitted during pull().
    /// @param  locker The locker "asset" is pulled from.
    /// @param  asset The asset being pulled.
    event Pulled(address indexed locker, address indexed asset);

    /// @notice Emitted during pullPartial().
    /// @param  locker The locker "asset" is pulled from.
    /// @param  asset The asset being pulled.
    /// @param  amount The amount of "asset" being pulled (or could represent a percentage, in basis points).
    event PulledPartial(address indexed locker, address indexed asset, uint256 amount);

    /// @notice Emitted during pushMulti().
    /// @param  locker The locker receiving "assets".
    /// @param  assets The assets being pushed, corresponds to "amounts" by position in array.
    /// @param  amounts The amounts of "assets" being pushed, corresponds to "assets" by position in array.
    event PushedMulti(address indexed locker, address[] assets, uint256[] amounts);

    /// @notice Emitted during pullMulti().
    /// @param  locker The locker "assets" are pulled from.
    /// @param  assets The assets being pulled.
    event PulledMulti(address indexed locker, address[] assets);

    /// @notice Emitted during pullMultiPartial().
    /// @param  locker The locker "assets" are pulled from.
    /// @param  assets The assets being pulled, corresponds to "amounts" by position in array.
    /// @param  amounts The amounts of "assets" being pulled, corresponds to "assets" by position in array.
    event PulledMultiPartial(address indexed locker, address[] assets, uint256[] amounts);

    /// @notice Emitted during pushERC721().
    /// @param  locker The locker receiving "assets".
    /// @param  asset The asset being pushed.
    /// @param  tokenId The ID for a given "asset" / NFT.
    /// @param  data Accompanying data for the transaction.
    event PushedERC721(address indexed locker, address indexed asset, uint256 indexed tokenId, bytes data);

    /// @notice Emitted during pushMultiERC721().
    /// @param  locker The locker receiving "assets".
    /// @param  assets The assets being pushed, corresponds to "tokenIds".
    /// @param  tokenIds The ID for a given "asset" / NFT.
    /// @param  data Accompanying data for the transaction(s).
    event PushedMultiERC721(address indexed locker, address[] assets, uint256[] tokenIds, bytes[] data);
    
    /// @notice Emitted during pullERC721().
    /// @param  locker The locker "assets" are pulled from.
    /// @param  asset The asset being pulled.
    /// @param  tokenId The ID for a given "asset" / NFT.
    /// @param  data Accompanying data for the transaction.
    event PulledERC721(address indexed locker, address indexed asset, uint256 indexed tokenId, bytes data);

    /// @notice Emitted during pullMultiERC721().
    /// @param  locker The locker "assets" are pulled from.
    /// @param  assets The assets being pulled.
    /// @param  tokenIds The ID for a given "asset" / NFT.
    /// @param  data Accompanying data for the transaction(s).
    event PulledMultiERC721(address indexed locker, address[] assets, uint256[] tokenIds, bytes[] data);
    
    /// @notice Emitted during pushERC1155Batch().
    /// @param  locker The locker receiving "assets".
    /// @param  asset The asset being pushed.
    /// @param  ids The IDs for a given "asset" / ERC1155, corresponds to "amounts".
    /// @param  amounts The amount of "id" to transfer.
    /// @param  data Accompanying data for the transaction.
    event PushedERC1155(address indexed locker, address indexed asset, uint256[] ids, uint256[] amounts, bytes data);

    /// @notice Emitted during pullERC1155Batch().
    /// @param  locker The locker "assets" are pulled from.
    /// @param  asset The asset being pushed.
    /// @param  ids The IDs for a given "asset" / ERC1155, corresponds to "amounts".
    /// @param  amounts The amount of "id" to transfer.
    /// @param  data Accompanying data for the transaction.
    event PulledERC1155(address indexed locker, address indexed asset, uint256[] ids, uint256[] amounts, bytes data);

    

    // ----------------
    //    Functions
    // ----------------

    /// @notice Migrates capital from DAO to locker.
    /// @param  locker  The locker to push capital to.
    /// @param  asset   The asset to push to locker.
    /// @param  amount  The amount of "asset" to push.
    function push(address locker, address asset, uint256 amount) external onlyOwner {
        require(IZivoeGlobals_P_5(GBL).isLocker(locker), "ZivoeDAO::push() !IZivoeGlobals_P_5(GBL).isLocker(locker)");
        require(IERC104_P_0(locker).canPush(), "ZivoeDAO::push() !IERC104_P_0(locker).canPush()");
        emit Pushed(locker, asset, amount);
        IERC20(asset).safeApprove(locker, amount);
        IERC104_P_0(locker).pushToLocker(asset, amount);
        if (IERC20(asset).allowance(address(this), locker) > 0) {
            IERC20(asset).safeApprove(locker, 0);
        }
    }

    /// @notice Pulls capital from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  asset The asset to pull.
    function pull(address locker, address asset) external onlyOwner {
        require(IERC104_P_0(locker).canPull(), "ZivoeDAO::pull() !IERC104_P_0(locker).canPull()");
        emit Pulled(locker, asset);
        IERC104_P_0(locker).pullFromLocker(asset);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    The input "amount" might represent a ratio, BIPS, or an absolute amount depending on locker.
    /// @param  locker The locker to pull from.
    /// @param  asset The asset to pull.
    /// @param  amount The amount to pull (may not refer to "asset", but rather a different asset within the locker).
    function pullPartial(address locker, address asset, uint256 amount) external onlyOwner {
        require(IERC104_P_0(locker).canPullPartial(), "ZivoeDAO::pullPartial() !IERC104_P_0(locker).canPullPartial()");
        emit PulledPartial(locker, asset, amount);
        IERC104_P_0(locker).pullFromLockerPartial(asset, amount);
    }

    /// @notice Migrates multiple types of capital from DAO to locker.
    /// @param  locker  The locker to push capital to.
    /// @param  assets  The assets to push to locker.
    /// @param  amounts The amount of "asset" to push.
    function pushMulti(address locker, address[] calldata assets, uint256[] calldata amounts) external onlyOwner {
        require(IZivoeGlobals_P_5(GBL).isLocker(locker), "ZivoeDAO::pushMulti() !IZivoeGlobals_P_5(GBL).isLocker(locker)");
        require(assets.length == amounts.length, "ZivoeDAO::pushMulti() assets.length != amounts.length");
        require(IERC104_P_0(locker).canPushMulti(), "ZivoeDAO::pushMulti() !IERC104_P_0(locker).canPushMulti()");
        emit PushedMulti(locker, assets, amounts);
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeApprove(locker, amounts[i]);
            emit Pushed(locker, assets[i], amounts[i]);
        }
        IERC104_P_0(locker).pushToLockerMulti(assets, amounts);
        for (uint256 i = 0; i < assets.length; i++) {
            if (IERC20(assets[i]).allowance(address(this), locker) > 0) {
                IERC20(assets[i]).safeApprove(locker, 0);
            }
        }
    }

    /// @notice Pulls capital from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  assets The assets to pull.
    function pullMulti(address locker, address[] calldata assets) external onlyOwner {
        require(IERC104_P_0(locker).canPullMulti(), "ZivoeDAO::pullMulti() !IERC104_P_0(locker).canPullMulti()");
        emit PulledMulti(locker, assets);
        for (uint256 i = 0; i < assets.length; i++) {
            emit Pulled(locker, assets[i]);
        }
        IERC104_P_0(locker).pullFromLockerMulti(assets);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  assets The asset to pull.
    /// @param  amounts The amounts to pull (may not refer to "assets", but rather a different asset within the locker).
    function pullMultiPartial(address locker, address[] calldata assets, uint256[] calldata amounts) external onlyOwner {
        require(IERC104_P_0(locker).canPullMultiPartial(), "ZivoeDAO::pullMultiPartial() !IERC104_P_0(locker).canPullMultiPartial()");
        require(assets.length == amounts.length, "ZivoeDAO::pullMultiPartial() assets.length != amounts.length");
        emit PulledMultiPartial(locker, assets, amounts);
        for (uint256 i = 0; i < assets.length; i++) {
            emit PulledPartial(locker, assets[i], amounts[i]);
        }
        IERC104_P_0(locker).pullFromLockerMultiPartial(assets, amounts);
    }
    
    /// @notice Migrates an NFT from the DAO to a locker.
    /// @param  locker  The locker to push an NFT to.
    /// @param  asset The NFT contract.
    /// @param  tokenId The NFT ID to push.
    /// @param  data Accompanying data for the transaction.
    function pushERC721(address locker, address asset, uint256 tokenId, bytes calldata data) external onlyOwner {
        require(IZivoeGlobals_P_5(GBL).isLocker(locker), "ZivoeDAO::pushERC721() !IZivoeGlobals_P_5(GBL).isLocker(locker)");
        require(IERC104_P_0(locker).canPushERC721(), "ZivoeDAO::pushERC721() !IERC104_P_0(locker).canPushERC721()");
        emit PushedERC721(locker, asset, tokenId, data);
        IERC721_P_0(asset).approve(locker, tokenId);
        IERC104_P_0(locker).pushToLockerERC721(asset, tokenId, data);
    }

    /// @notice Migrates NFTs from the DAO to a locker.
    /// @param  locker  The locker to push NFTs to.
    /// @param  assets The NFT contracts.
    /// @param  tokenIds The NFT IDs to push.
    /// @param  data Accompanying data for the transaction(s).
    function pushMultiERC721(address locker, address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external onlyOwner {
        require(IZivoeGlobals_P_5(GBL).isLocker(locker), "ZivoeDAO::pushMultiERC721() !IZivoeGlobals_P_5(GBL).isLocker(locker)");
        require(assets.length == tokenIds.length, "ZivoeDAO::pushMultiERC721() assets.length != tokenIds.length");
        require(tokenIds.length == data.length, "ZivoeDAO::pushMultiERC721() tokenIds.length != data.length");
        require(IERC104_P_0(locker).canPushMultiERC721(), "ZivoeDAO::pushMultiERC721() !IERC104_P_0(locker).canPushMultiERC721()");
        emit PushedMultiERC721(locker, assets, tokenIds, data);
        for (uint256 i = 0; i < assets.length; i++) {
            IERC721_P_0(assets[i]).approve(locker, tokenIds[i]);
            emit PushedERC721(locker, assets[i], tokenIds[i], data[i]);
        }
        IERC104_P_0(locker).pushToLockerMultiERC721(assets, tokenIds, data);
    }

    /// @notice Pulls an NFT from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  asset The NFT contract.
    /// @param  tokenId The NFT ID to pull.
    /// @param  data Accompanying data for the transaction.
    function pullERC721(address locker, address asset, uint256 tokenId, bytes calldata data) external onlyOwner {
        require(IERC104_P_0(locker).canPullERC721(), "ZivoeDAO::pullERC721() !IERC104_P_0(locker).canPullERC721()");
        emit PulledERC721(locker, asset, tokenId, data);
        IERC104_P_0(locker).pullFromLockerERC721(asset, tokenId, data);
    }

    /// @notice Pulls NFTs from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  assets The NFT contracts.
    /// @param  tokenIds The NFT IDs to pull.
    /// @param  data Accompanying data for the transaction(s).
    function pullMultiERC721(address locker, address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external onlyOwner {
        require(IERC104_P_0(locker).canPullMultiERC721(), "ZivoeDAO::pullMultiERC721() !IERC104_P_0(locker).canPullMultiERC721()");
        require(assets.length == tokenIds.length, "ZivoeDAO::pullMultiERC721() assets.length != tokenIds.length");
        require(tokenIds.length == data.length, "ZivoeDAO::pullMultiERC721() tokenIds.length != data.length");
        emit PulledMultiERC721(locker, assets, tokenIds, data);
        for (uint256 i = 0; i < assets.length; i++) {
            emit PulledERC721(locker, assets[i], tokenIds[i], data[i]);
        }
        IERC104_P_0(locker).pullFromLockerMultiERC721(assets, tokenIds, data);
    }

    /// @notice Migrates ERC1155 assets from DAO to locker.
    /// @param  locker The locker to push ERC1155 assets to.
    /// @param  asset The ERC1155 asset to push to locker.
    /// @param  ids The ids of "assets" to push.
    /// @param  amounts The amounts of "assets" to push.
    /// @param  data Accompanying data for the transaction.
    function pushERC1155Batch(
            address locker,
            address asset,
            uint256[] calldata ids, 
            uint256[] calldata amounts,
            bytes calldata data
    ) external onlyOwner {
        require(IZivoeGlobals_P_5(GBL).isLocker(locker), "ZivoeDAO::pushERC1155Batch() !IZivoeGlobals_P_5(GBL).isLocker(locker)");
        require(ids.length == amounts.length, "ZivoeDAO::pushERC1155Batch() ids.length != amounts.length");
        require(IERC104_P_0(locker).canPushERC1155(), "ZivoeDAO::pushERC1155Batch() !IERC104_P_0(locker).canPushERC1155()");
        emit PushedERC1155(locker, asset, ids, amounts, data);
        IERC1155_P_0(asset).setApprovalForAll(locker, true);
        IERC104_P_0(locker).pushToLockerERC1155(asset, ids, amounts, data);
    }

    /// @notice Pulls ERC1155 assets from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  asset The ERC1155 asset to pull.
    /// @param  ids The ids of "assets" to pull.
    /// @param  amounts The amounts of "assets" to pull.
    /// @param  data Accompanying data for the transaction.
    function pullERC1155Batch(
            address locker,
            address asset,
            uint256[] calldata ids, 
            uint256[] calldata amounts,
            bytes calldata data
    ) external onlyOwner {
        require(IERC104_P_0(locker).canPullERC1155(), "ZivoeDAO::pullERC1155Batch() !IERC104_P_0(locker).canPullERC1155()");
        require(ids.length == amounts.length, "ZivoeDAO::pullERC1155Batch() ids.length != amounts.length");
        emit PulledERC1155(locker, asset, ids, amounts, data);
        IERC104_P_0(locker).pullFromLockerERC1155(asset, ids, amounts, data);
    }

}
