// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "./libraries/ZivoeOwnableLocked.sol";

interface IZivoeGlobals_DAO {
    /// @notice Returns "true" when a locker is whitelisted, for DAO interactions and accounting accessibility.
    /// @param locker The address of the locker to check for.
    function isLocker(address locker) external view returns (bool);
}

interface IERC104_DAO {
    /// @notice Migrates specific amount of ERC20 from owner() to locker.
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    function pushToLocker(address asset, uint256 amount) external;

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    function pullFromLocker(address asset) external;

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    function pullFromLockerPartial(address asset, uint256 amount) external;

    /// @notice Migrates specific amounts of ERC20s from owner() to locker.
    /// @param  assets The assets to migrate.
    /// @param  amounts The amounts of "assets" to migrate, corresponds to "assets" by position in array.   
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) external;

    /// @notice Migrates full amount of ERC20s from locker to owner().
    /// @param  assets The assets to migrate.
    function pullFromLockerMulti(address[] calldata assets) external;

    /// @notice Migrates specific amounts of ERC20s from locker to owner().
    /// @param  assets The assets to migrate.
    /// @param  amounts The amounts of "assets" to migrate, corresponds to "assets" by position in array.
    function pullFromLockerMultiPartial(address[] calldata assets, uint256[] calldata amounts) external;

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

interface IERC721_DAO {
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

interface IERC1155_DAO {
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
        require(IZivoeGlobals_DAO(GBL).isLocker(locker), "ZivoeDAO::push() !IZivoeGlobals_DAO(GBL).isLocker(locker)");
        require(IERC104_DAO(locker).canPush(), "ZivoeDAO::push() !IERC104_DAO(locker).canPush()");
        
        emit Pushed(locker, asset, amount);
        IERC20(asset).safeApprove(locker, amount);
        IERC104_DAO(locker).pushToLocker(asset, amount);
        if (IERC20(asset).allowance(address(this), locker) > 0) {
            IERC20(asset).safeApprove(locker, 0);
        }
    }

    /// @notice Pulls capital from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  asset The asset to pull.
    function pull(address locker, address asset) external onlyOwner {
        require(IERC104_DAO(locker).canPull(), "ZivoeDAO::pull() !IERC104_DAO(locker).canPull()");

        emit Pulled(locker, asset);
        IERC104_DAO(locker).pullFromLocker(asset);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @dev    The input "amount" might represent a ratio, BIPS, or an absolute amount depending on locker.
    /// @param  locker The locker to pull from.
    /// @param  asset The asset to pull.
    /// @param  amount The amount to pull (may not refer to "asset", but rather a different asset within the locker).
    function pullPartial(address locker, address asset, uint256 amount) external onlyOwner {
        require(IERC104_DAO(locker).canPullPartial(), "ZivoeDAO::pullPartial() !IERC104_DAO(locker).canPullPartial()");

        emit PulledPartial(locker, asset, amount);
        IERC104_DAO(locker).pullFromLockerPartial(asset, amount);
    }

    /// @notice Migrates multiple types of capital from DAO to locker.
    /// @param  locker  The locker to push capital to.
    /// @param  assets  The assets to push to locker.
    /// @param  amounts The amount of "asset" to push.
    function pushMulti(address locker, address[] calldata assets, uint256[] calldata amounts) external onlyOwner {
        require(IZivoeGlobals_DAO(GBL).isLocker(locker), "ZivoeDAO::pushMulti() !IZivoeGlobals_DAO(GBL).isLocker(locker)");
        require(assets.length == amounts.length, "ZivoeDAO::pushMulti() assets.length != amounts.length");
        require(IERC104_DAO(locker).canPushMulti(), "ZivoeDAO::pushMulti() !IERC104_DAO(locker).canPushMulti()");

        emit PushedMulti(locker, assets, amounts);
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeApprove(locker, amounts[i]);
            emit Pushed(locker, assets[i], amounts[i]);
        }
        IERC104_DAO(locker).pushToLockerMulti(assets, amounts);
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
        require(IERC104_DAO(locker).canPullMulti(), "ZivoeDAO::pullMulti() !IERC104_DAO(locker).canPullMulti()");

        emit PulledMulti(locker, assets);
        for (uint256 i = 0; i < assets.length; i++) {
            emit Pulled(locker, assets[i]);
        }
        IERC104_DAO(locker).pullFromLockerMulti(assets);
    }

    /// @notice Pulls capital from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  assets The asset to pull.
    /// @param  amounts The amounts to pull (may not refer to "assets", but rather a different asset within the locker).
    function pullMultiPartial(address locker, address[] calldata assets, uint256[] calldata amounts) external onlyOwner {
        require(IERC104_DAO(locker).canPullMultiPartial(), "ZivoeDAO::pullMultiPartial() !IERC104_DAO(locker).canPullMultiPartial()");
        require(assets.length == amounts.length, "ZivoeDAO::pullMultiPartial() assets.length != amounts.length");

        emit PulledMultiPartial(locker, assets, amounts);
        for (uint256 i = 0; i < assets.length; i++) {
            emit PulledPartial(locker, assets[i], amounts[i]);
        }
        IERC104_DAO(locker).pullFromLockerMultiPartial(assets, amounts);
    }
    
    /// @notice Migrates an NFT from the DAO to a locker.
    /// @param  locker  The locker to push an NFT to.
    /// @param  asset The NFT contract.
    /// @param  tokenId The NFT ID to push.
    /// @param  data Accompanying data for the transaction.
    function pushERC721(address locker, address asset, uint256 tokenId, bytes calldata data) external onlyOwner {
        require(IZivoeGlobals_DAO(GBL).isLocker(locker), "ZivoeDAO::pushERC721() !IZivoeGlobals_DAO(GBL).isLocker(locker)");
        require(IERC104_DAO(locker).canPushERC721(), "ZivoeDAO::pushERC721() !IERC104_DAO(locker).canPushERC721()");

        emit PushedERC721(locker, asset, tokenId, data);
        IERC721_DAO(asset).approve(locker, tokenId);
        IERC104_DAO(locker).pushToLockerERC721(asset, tokenId, data);
        // TODO: Unapprove if approval > 0 at end of pushToLockerERC721().
    }

    /// @notice Migrates NFTs from the DAO to a locker.
    /// @param  locker  The locker to push NFTs to.
    /// @param  assets The NFT contracts.
    /// @param  tokenIds The NFT IDs to push.
    /// @param  data Accompanying data for the transaction(s).
    function pushMultiERC721(address locker, address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external onlyOwner {
        require(IZivoeGlobals_DAO(GBL).isLocker(locker), "ZivoeDAO::pushMultiERC721() !IZivoeGlobals_DAO(GBL).isLocker(locker)");
        require(assets.length == tokenIds.length, "ZivoeDAO::pushMultiERC721() assets.length != tokenIds.length");
        require(tokenIds.length == data.length, "ZivoeDAO::pushMultiERC721() tokenIds.length != data.length");
        require(IERC104_DAO(locker).canPushMultiERC721(), "ZivoeDAO::pushMultiERC721() !IERC104_DAO(locker).canPushMultiERC721()");

        emit PushedMultiERC721(locker, assets, tokenIds, data);
        for (uint256 i = 0; i < assets.length; i++) {
            IERC721_DAO(assets[i]).approve(locker, tokenIds[i]);
            emit PushedERC721(locker, assets[i], tokenIds[i], data[i]);
        }
        IERC104_DAO(locker).pushToLockerMultiERC721(assets, tokenIds, data);
        // TODO: Unapprove if approval > 0 at end of pushToLockerMultiERC721().
    }

    /// @notice Pulls an NFT from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  asset The NFT contract.
    /// @param  tokenId The NFT ID to pull.
    /// @param  data Accompanying data for the transaction.
    function pullERC721(address locker, address asset, uint256 tokenId, bytes calldata data) external onlyOwner {
        require(IERC104_DAO(locker).canPullERC721(), "ZivoeDAO::pullERC721() !IERC104_DAO(locker).canPullERC721()");

        emit PulledERC721(locker, asset, tokenId, data);
        IERC104_DAO(locker).pullFromLockerERC721(asset, tokenId, data);
    }

    /// @notice Pulls NFTs from locker to DAO.
    /// @param  locker The locker to pull from.
    /// @param  assets The NFT contracts.
    /// @param  tokenIds The NFT IDs to pull.
    /// @param  data Accompanying data for the transaction(s).
    function pullMultiERC721(address locker, address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external onlyOwner {
        require(IERC104_DAO(locker).canPullMultiERC721(), "ZivoeDAO::pullMultiERC721() !IERC104_DAO(locker).canPullMultiERC721()");
        require(assets.length == tokenIds.length, "ZivoeDAO::pullMultiERC721() assets.length != tokenIds.length");
        require(tokenIds.length == data.length, "ZivoeDAO::pullMultiERC721() tokenIds.length != data.length");

        emit PulledMultiERC721(locker, assets, tokenIds, data);
        for (uint256 i = 0; i < assets.length; i++) {
            emit PulledERC721(locker, assets[i], tokenIds[i], data[i]);
        }
        IERC104_DAO(locker).pullFromLockerMultiERC721(assets, tokenIds, data);
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
        require(IZivoeGlobals_DAO(GBL).isLocker(locker), "ZivoeDAO::pushERC1155Batch() !IZivoeGlobals_DAO(GBL).isLocker(locker)");
        require(ids.length == amounts.length, "ZivoeDAO::pushERC1155Batch() ids.length != amounts.length");
        require(IERC104_DAO(locker).canPushERC1155(), "ZivoeDAO::pushERC1155Batch() !IERC104_DAO(locker).canPushERC1155()");

        emit PushedERC1155(locker, asset, ids, amounts, data);
        IERC1155_DAO(asset).setApprovalForAll(locker, true);
        IERC104_DAO(locker).pushToLockerERC1155(asset, ids, amounts, data);
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
        require(IERC104_DAO(locker).canPullERC1155(), "ZivoeDAO::pullERC1155Batch() !IERC104_DAO(locker).canPullERC1155()");
        require(ids.length == amounts.length, "ZivoeDAO::pullERC1155Batch() ids.length != amounts.length");

        emit PulledERC1155(locker, asset, ids, amounts, data);
        IERC104_DAO(locker).pullFromLockerERC1155(asset, ids, amounts, data);
    }

}
