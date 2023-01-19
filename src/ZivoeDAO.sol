// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "./libraries/ZivoeOwnableLocked.sol";

interface DAO_IZivoeGlobals {
    /// @notice Returns "true" when a locker is whitelisted, for DAO interactions and accounting accessibility.
    /// @param locker The address of the locker to check for.
    function isLocker(address locker) external view returns (bool);
}

interface DAO_ILocker {
    /// @notice Migrates specific amount of ERC20 from owner() to locker.
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLocker(address asset, uint256 amount, bytes calldata data) external;

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external;

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(address asset, uint256 amount, bytes calldata data) external;

    /// @notice Migrates specific amounts of ERC20s from owner() to locker.
    /// @param  assets The assets to migrate.
    /// @param  amounts The amounts of "assets" to migrate, corresponds to "assets" by position in array.   
    /// @param  data Accompanying transaction data.
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data) external;

    /// @notice Migrates full amount of ERC20s from locker to owner().
    /// @param  assets The assets to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerMulti(address[] calldata assets, bytes[] calldata data) external;

    /// @notice Migrates specific amounts of ERC20s from locker to owner().
    /// @param  assets The assets to migrate.
    /// @param  amounts The amounts of "assets" to migrate, corresponds to "assets" by position in array.
    /// @param  data Accompanying transaction data.
    function pullFromLockerMultiPartial(address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data) external;

    /// @notice Migrates an ERC721 from owner() to locker.
    /// @param  asset The NFT contract.
    /// @param  tokenId The ID of the NFT to migrate.
    /// @param  data Accompanying transaction data.  
    function pushToLockerERC721(address asset, uint256 tokenId, bytes calldata data) external;

    /// @notice Migrates an ERC721 from locker to owner().
    /// @param  asset The NFT contract.
    /// @param  tokenId The ID of the NFT to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerERC721(address asset, uint256 tokenId, bytes calldata data) external;

    /// @notice Migrates ERC721s from owner() to locker.
    /// @param  assets The NFT contracts.
    /// @param  tokenIds The IDs of the NFTs to migrate.
    /// @param  data Accompanying transaction data.   
    function pushToLockerMultiERC721(address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external;

    /// @notice Migrates ERC721s from locker to owner().
    /// @param  assets The NFT contracts.
    /// @param  tokenIds The IDs of the NFTs to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerMultiERC721(address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external;

    /// @notice Migrates ERC1155 assets from owner() to locker.
    /// @param  asset The ERC1155 contract.
    /// @param  ids The IDs of the assets within the ERC1155 to migrate.
    /// @param  amounts The amounts to migrate.
    /// @param  data Accompanying transaction data.   
    function pushToLockerERC1155(
        address asset, 
        uint256[] calldata ids, 
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    /// @notice Migrates ERC1155 assets from locker to owner().
    /// @param  asset The ERC1155 contract.
    /// @param  ids The IDs of the assets within the ERC1155 to migrate.
    /// @param  amounts The amounts to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerERC1155(
        address asset, 
        uint256[] calldata ids, 
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    /// @notice Permission for calling pushToLocker().
    function canPush() external view returns (bool);

    /// @notice Permission for calling pullFromLocker().  
    function canPull() external view returns (bool);

    /// @notice Permission for calling pullFromLockerPartial().
    function canPullPartial() external view returns (bool);

    /// @notice Permission for calling pushToLockerMulti().  
    function canPushMulti() external view returns (bool);

    /// @notice Permission for calling pullFromLockerMulti(). 
    function canPullMulti() external view returns (bool);

    /// @notice Permission for calling pullFromLockerMultiPartial().   
    function canPullMultiPartial() external view returns (bool);

    /// @notice Permission for calling pushToLockerERC721().
    function canPushERC721() external view returns (bool);

    /// @notice Permission for calling pullFromLockerERC721().
    function canPullERC721() external view returns (bool);

    /// @notice Permission for calling pushToLockerMultiERC721().
    function canPushMultiERC721() external view returns (bool);

    /// @notice Permission for calling pullFromLockerMultiERC721().    
    function canPullMultiERC721() external view returns (bool);

    /// @notice Permission for calling pushToLockerERC1155().    
    function canPushERC1155() external view returns (bool);

    /// @notice Permission for calling pullFromLockerERC1155().   
    function canPullERC1155() external view returns (bool);
}

interface DAO_IERC721 {
    /// @notice Safely transfers `tokenId` token from `from` to `to`
    /// @param from The address sending the token.
    /// @param to The address receiving the token.
    /// @param tokenId The ID of the token to transfer.
    /// @param _data Accompanying transaction data. 
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) external;

    /// @notice Gives permission to `to` to transfer `tokenId` token to another account.
    /// The approval is cleared when the token is transferred.
    /// @param to The address to grant permission to.
    /// @param tokenId The number of the tokenId to give approval for.
    function approve(address to, uint256 tokenId) external;

}

interface DAO_IERC1155 {
    /// @notice Grants or revokes permission to `operator` to transfer the caller's tokens.
    /// @param operator The address to grant permission to.
    /// @param approved "true" = approve, "false" = don't approve or cancel approval.
    function setApprovalForAll(address operator, bool approved) external;

    /// @notice Transfers `amount` tokens of token type `id` from `from` to `to`.
    /// @param from The address sending the tokens.
    /// @param to The address receiving the tokens.
    /// @param ids An array with the tokenIds to send.
    /// @param amounts An array of corresponding amount of each tokenId to send.
    /// @param data Accompanying transaction data. 
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
contract ZivoeDAO is ERC1155Holder, ERC721Holder, ZivoeOwnableLocked {
    
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

    /// @notice Emitted during push(), pushMulti().
    /// @param  locker The locker receiving "asset".
    /// @param  asset The asset being pushed.
    /// @param  amount The amount of "asset" being pushed.
    /// @param  data Accompanying transaction data.
    event Pushed(address indexed locker, address indexed asset, uint256 amount, bytes data);

    /// @notice Emitted during pull(), pullMulti().
    /// @param  locker The locker "asset" is pulled from.
    /// @param  asset The asset being pulled.
    /// @param  data Accompanying transaction data.
    event Pulled(address indexed locker, address indexed asset, bytes data);

    /// @notice Emitted during pullPartial(), pullMultiPartial().
    /// @param  locker The locker "asset" is pulled from.
    /// @param  asset The asset being pulled.
    /// @param  amount The amount of "asset" being pulled (or could represent a percentage, in basis points).
    /// @param  data Accompanying transaction data.
    event PulledPartial(address indexed locker, address indexed asset, uint256 amount, bytes data);

    /// @notice Emitted during pushERC721(), pushMultiERC721().
    /// @param  locker The locker receiving "assets".
    /// @param  asset The asset being pushed.
    /// @param  tokenId The ID for a given "asset" / NFT.
    /// @param  data Accompanying data for the transaction.
    event PushedERC721(address indexed locker, address indexed asset, uint256 indexed tokenId, bytes data);
    
    /// @notice Emitted during pullERC721(), pullMultiERC721().
    /// @param  locker The locker "assets" are pulled from.
    /// @param  asset The asset being pulled.
    /// @param  tokenId The ID for a given "asset" / NFT.
    /// @param  data Accompanying data for the transaction.
    event PulledERC721(address indexed locker, address indexed asset, uint256 indexed tokenId, bytes data);
    
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
    /// @param  data Accompanying transaction data.
    function push(address locker, address asset, uint256 amount, bytes calldata data) external onlyOwner {
        require(DAO_IZivoeGlobals(GBL).isLocker(locker), "ZivoeDAO::push() !DAO_IZivoeGlobals(GBL).isLocker(locker)");
        require(DAO_ILocker(locker).canPush(), "ZivoeDAO::push() !DAO_ILocker(locker).canPush()");

        emit Pushed(locker, asset, amount, data);
        IERC20(asset).safeApprove(locker, amount);
        DAO_ILocker(locker).pushToLocker(asset, amount, data);
        if (IERC20(asset).allowance(address(this), locker) > 0) {
            IERC20(asset).safeApprove(locker, 0);
        }
    }

    /// @notice Pulls capital from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  asset The asset to pull.
    /// @param  data Accompanying transaction data.
    function pull(address locker, address asset, bytes calldata data) external onlyOwner {
        require(DAO_ILocker(locker).canPull(), "ZivoeDAO::pull() !DAO_ILocker(locker).canPull()");

        emit Pulled(locker, asset, data);
        DAO_ILocker(locker).pullFromLocker(asset, data);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    The input "amount" might represent a ratio, BIPS, or an absolute amount depending on locker.
    /// @param  locker The locker to pull from.
    /// @param  asset The asset to pull.
    /// @param  amount The amount to pull (may not refer to "asset", but rather a different asset within the locker).
    /// @param  data Accompanying transaction data.
    function pullPartial(address locker, address asset, uint256 amount, bytes calldata data) external onlyOwner {
        require(DAO_ILocker(locker).canPullPartial(), "ZivoeDAO::pullPartial() !DAO_ILocker(locker).canPullPartial()");

        emit PulledPartial(locker, asset, amount, data);
        DAO_ILocker(locker).pullFromLockerPartial(asset, amount, data);
    }

    /// @notice Migrates multiple types of capital from DAO to locker.
    /// @param  locker  The locker to push capital to.
    /// @param  assets  The assets to push to locker.
    /// @param  amounts The amount of "asset" to push.
    /// @param  data Accompanying transaction data.
    function pushMulti(address locker, address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data) external onlyOwner {
        require(DAO_IZivoeGlobals(GBL).isLocker(locker), "ZivoeDAO::pushMulti() !DAO_IZivoeGlobals(GBL).isLocker(locker)");
        require(assets.length == amounts.length, "ZivoeDAO::pushMulti() assets.length != amounts.length");
        require(DAO_ILocker(locker).canPushMulti(), "ZivoeDAO::pushMulti() !DAO_ILocker(locker).canPushMulti()");

        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeApprove(locker, amounts[i]);
            emit Pushed(locker, assets[i], amounts[i], data[i]);
        }
        DAO_ILocker(locker).pushToLockerMulti(assets, amounts, data);
        for (uint256 i = 0; i < assets.length; i++) {
            if (IERC20(assets[i]).allowance(address(this), locker) > 0) {
                IERC20(assets[i]).safeApprove(locker, 0);
            }
        }
    }

    /// @notice Pulls capital from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  assets The assets to pull.
    /// @param  data Accompanying transaction data.
    function pullMulti(address locker, address[] calldata assets, bytes[] calldata data) external onlyOwner {
        require(DAO_ILocker(locker).canPullMulti(), "ZivoeDAO::pullMulti() !DAO_ILocker(locker).canPullMulti()");

        for (uint256 i = 0; i < assets.length; i++) {
            emit Pulled(locker, assets[i], data[i]);
        }
        DAO_ILocker(locker).pullFromLockerMulti(assets, data);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  assets The asset to pull.
    /// @param  amounts The amounts to pull (may not refer to "assets", but rather a different asset within the locker).
    /// @param  data Accompanying transaction data.
    function pullMultiPartial(address locker, address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data) external onlyOwner {
        require(DAO_ILocker(locker).canPullMultiPartial(), "ZivoeDAO::pullMultiPartial() !DAO_ILocker(locker).canPullMultiPartial()");
        require(assets.length == amounts.length, "ZivoeDAO::pullMultiPartial() assets.length != amounts.length");

        for (uint256 i = 0; i < assets.length; i++) {
            emit PulledPartial(locker, assets[i], amounts[i], data[i]);
        }
        DAO_ILocker(locker).pullFromLockerMultiPartial(assets, amounts, data);
    }
    
    /// @notice Migrates an NFT from the DAO to a locker.
    /// @param  locker  The locker to push an NFT to.
    /// @param  asset The NFT contract.
    /// @param  tokenId The NFT ID to push.
    /// @param  data Accompanying data for the transaction.
    function pushERC721(address locker, address asset, uint256 tokenId, bytes calldata data) external onlyOwner {
        require(DAO_IZivoeGlobals(GBL).isLocker(locker), "ZivoeDAO::pushERC721() !DAO_IZivoeGlobals(GBL).isLocker(locker)");
        require(DAO_ILocker(locker).canPushERC721(), "ZivoeDAO::pushERC721() !DAO_ILocker(locker).canPushERC721()");

        emit PushedERC721(locker, asset, tokenId, data);
        DAO_IERC721(asset).approve(locker, tokenId);
        DAO_ILocker(locker).pushToLockerERC721(asset, tokenId, data);
        // TODO: Unapprove if approval > 0 at end of pushToLockerERC721().
    }

    /// @notice Migrates NFTs from the DAO to a locker.
    /// @param  locker  The locker to push NFTs to.
    /// @param  assets The NFT contracts.
    /// @param  tokenIds The NFT IDs to push.
    /// @param  data Accompanying data for the transaction(s).
    function pushMultiERC721(address locker, address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external onlyOwner {
        require(DAO_IZivoeGlobals(GBL).isLocker(locker), "ZivoeDAO::pushMultiERC721() !DAO_IZivoeGlobals(GBL).isLocker(locker)");
        require(assets.length == tokenIds.length, "ZivoeDAO::pushMultiERC721() assets.length != tokenIds.length");
        require(tokenIds.length == data.length, "ZivoeDAO::pushMultiERC721() tokenIds.length != data.length");
        require(DAO_ILocker(locker).canPushMultiERC721(), "ZivoeDAO::pushMultiERC721() !DAO_ILocker(locker).canPushMultiERC721()");

        for (uint256 i = 0; i < assets.length; i++) {
            DAO_IERC721(assets[i]).approve(locker, tokenIds[i]);
            emit PushedERC721(locker, assets[i], tokenIds[i], data[i]);
        }
        DAO_ILocker(locker).pushToLockerMultiERC721(assets, tokenIds, data);
        // TODO: Unapprove if approval > 0 at end of pushToLockerMultiERC721().
    }

    /// @notice Pulls an NFT from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  asset The NFT contract.
    /// @param  tokenId The NFT ID to pull.
    /// @param  data Accompanying data for the transaction.
    function pullERC721(address locker, address asset, uint256 tokenId, bytes calldata data) external onlyOwner {
        require(DAO_ILocker(locker).canPullERC721(), "ZivoeDAO::pullERC721() !DAO_ILocker(locker).canPullERC721()");

        emit PulledERC721(locker, asset, tokenId, data);
        DAO_ILocker(locker).pullFromLockerERC721(asset, tokenId, data);
    }

    /// @notice Pulls NFTs from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  assets The NFT contracts.
    /// @param  tokenIds The NFT IDs to pull.
    /// @param  data Accompanying data for the transaction(s).
    function pullMultiERC721(address locker, address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external onlyOwner {
        require(DAO_ILocker(locker).canPullMultiERC721(), "ZivoeDAO::pullMultiERC721() !DAO_ILocker(locker).canPullMultiERC721()");
        require(assets.length == tokenIds.length, "ZivoeDAO::pullMultiERC721() assets.length != tokenIds.length");
        require(tokenIds.length == data.length, "ZivoeDAO::pullMultiERC721() tokenIds.length != data.length");

        for (uint256 i = 0; i < assets.length; i++) {
            emit PulledERC721(locker, assets[i], tokenIds[i], data[i]);
        }
        DAO_ILocker(locker).pullFromLockerMultiERC721(assets, tokenIds, data);
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
        require(DAO_IZivoeGlobals(GBL).isLocker(locker), "ZivoeDAO::pushERC1155Batch() !DAO_IZivoeGlobals(GBL).isLocker(locker)");
        require(ids.length == amounts.length, "ZivoeDAO::pushERC1155Batch() ids.length != amounts.length");
        require(DAO_ILocker(locker).canPushERC1155(), "ZivoeDAO::pushERC1155Batch() !DAO_ILocker(locker).canPushERC1155()");

        emit PushedERC1155(locker, asset, ids, amounts, data);
        DAO_IERC1155(asset).setApprovalForAll(locker, true);
        DAO_ILocker(locker).pushToLockerERC1155(asset, ids, amounts, data);
        // TODO: Unapprove if approval > 0 at end of pushToLockerERC1155().
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
        require(DAO_ILocker(locker).canPullERC1155(), "ZivoeDAO::pullERC1155Batch() !DAO_ILocker(locker).canPullERC1155()");
        require(ids.length == amounts.length, "ZivoeDAO::pullERC1155Batch() ids.length != amounts.length");

        emit PulledERC1155(locker, asset, ids, amounts, data);
        DAO_ILocker(locker).pullFromLockerERC1155(asset, ids, amounts, data);
    }

}
