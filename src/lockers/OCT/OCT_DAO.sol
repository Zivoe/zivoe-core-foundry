// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../Utility/ZivoeSwapper.sol";

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface OCT_DAO_IZivoeGlobals {
    /// @notice Returns true if an address is whitelisted as a keeper.
    /// @return keeper Equals "true" if address is a keeper, "false" if not.
    function isKeeper(address) external view returns (bool keeper);

    /// @notice Returns the address of ZivoeDAO.
    function DAO() external view returns (address);
}

/// @notice This contract converts assets and directs them to the DAO.
contract OCT_DAO is ZivoeLocker, ZivoeSwapper, ReentrancyGuard {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;               /// @dev The ZivoeGlobals contract.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCT_YDL contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address DAO, address _GBL) {
        transferOwnership(DAO);
        GBL = _GBL;
    }



    // ------------
    //    Events   
    // ------------

    /// @notice Emitted during forwardconvertAndForwardYieldKeeper().
    /// @param  asset The "asset" being converted.
    /// @param  distributedAsset The "asset" being distributed, based on YDL.distributedAsset().
    /// @param  amountFrom The amount converted.
    /// @param  amountTo The amount distributed.
    event AssetConvertedForwarded(address indexed asset, address indexed distributedAsset, uint256 amountFrom, uint256 amountTo);



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pullFromLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPushMulti() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerMulti().
    function canPullMulti() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerMultiPartial().
    function canPullMultiPartial() public override pure returns (bool) { return true; }

    /// @notice Converts an asset and forwards it.
    /// @param  asset The asset to convert.
    /// @param  toAsset The asset to convert to.
    /// @param  data The payload containing conversion data, consumed by 1INCH_V5.
    function convertAndForward(address asset, address toAsset, bytes calldata data) external nonReentrant {
        require(OCT_DAO_IZivoeGlobals(GBL).isKeeper(_msgSender()), "OCT_DAO::convertAndForward !isKeeper(_msgSender())");
        uint256 amountFrom = IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeApprove(router1INCH_V5, amountFrom);
        convertAsset(asset, toAsset, amountFrom, data);
        emit AssetConvertedForwarded(asset, toAsset, amountFrom, IERC20(toAsset).balanceOf(address(this)));
        IERC20(toAsset).safeTransfer(OCT_DAO_IZivoeGlobals(GBL).DAO(), IERC20(toAsset).balanceOf(address(this)));
    }

}