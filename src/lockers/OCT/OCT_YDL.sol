// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../Utility/ZivoeSwapper.sol";

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface OCT_YDL_IZivoeYDL {
    /// @notice Returns the "stablecoin" that will be distributed via YDL.
    /// @return asset The address of the "stablecoin" that will be distributed via YDL.
    function distributedAsset() external view returns (address asset);
}

interface OCT_YDL_IZivoeGlobals {
    /// @notice Returns true if an address is whitelisted as a keeper.
    /// @return keeper Equals "true" if address is a keeper, "false" if not.
    function isKeeper(address) external view returns (bool keeper);

    /// @notice Returns the address of the ZivoeYDL contract.
    function YDL() external view returns (address);
}

/// @notice This contract converts assets and forwards them to the YDL.
contract OCT_YDL is ZivoeLocker, ZivoeSwapper, ReentrancyGuard {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;               /// @dev The ZivoeGlobals contract.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCT_YDL contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _GBL The ZivoeGlobals contract.
    constructor(address DAO, address _GBL) {
        transferOwnership(DAO);
        GBL = _GBL;
    }



    // ------------
    //    Events   
    // ------------

    /// @notice Emitted during convertAndForward().
    /// @param  asset The "asset" being converted.
    /// @param  distributedAsset The ERC20 that we are converting "asset" to, based on YDL.distributedAsset().
    /// @param  amountFrom The amount being converted.
    /// @param  amountTo The amount being converted.
    event AssetConvertedForwarded(
        address indexed asset, 
        address indexed distributedAsset, 
        uint256 amountFrom, 
        uint256 amountTo
    );



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerMulti().
    function canPullMulti() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerMultiPartial().
    function canPullMultiPartial() public override pure returns (bool) { return true; }

    /// @notice Converts an asset to YDL.distributedAsset() and forwards it.
    /// @param  asset The asset to convert.
    /// @param  data The payload containing conversion data, consumed by 1INCH_V5.
    function convertAndForward(address asset, bytes calldata data) external nonReentrant {
        require(
            OCT_YDL_IZivoeGlobals(GBL).isKeeper(_msgSender()),
            "OCT_YDL::convertAndForward !isKeeper(_msgSender())"
        );
        address distributedAsset = OCT_YDL_IZivoeYDL(OCT_YDL_IZivoeGlobals(GBL).YDL()).distributedAsset();
        uint256 amountFrom = IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeApprove(router1INCH_V5, amountFrom);
        convertAsset(asset, distributedAsset, amountFrom, data);
        emit AssetConvertedForwarded(
            asset, 
            distributedAsset, 
            amountFrom, 
            IERC20(distributedAsset).balanceOf(address(this))
        );
        IERC20(distributedAsset).safeTransfer(
            OCT_YDL_IZivoeGlobals(GBL).YDL(), IERC20(distributedAsset).balanceOf(address(this))
        );
    }

}