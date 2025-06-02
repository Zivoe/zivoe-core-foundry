// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IZivoeGlobals_OCR_Instant {
    /// @notice Returns true if an address is whitelisted as a keeper.
    /// @return keeper Equals "true" if address is a keeper, "false" if not.
    function isKeeper(address) external view returns (bool keeper);

    /// @notice This function will verify if a given stablecoin has been whitelisted for use throughout system.
    /// @param stablecoin address of the stablecoin to verify acceptance for.
    function stablecoinWhitelist(address stablecoin) external view returns (bool);

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  amount              The amount of a given "asset".
    /// @param  asset               The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount  The input "amount" standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);
}

interface IERC20Burn_OCR_Instant{
    /// @notice Burns tokens.
    function burn(uint256 amount) external;
}

interface IZivoeVault_OCR_Instant{
    /// @notice Withdraws underlying asset from vault token (burns vault token, sends underlying to receiver).
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
}

/// @notice This contract facilitates instant withdrawals via burning zVLT for stablecoins.
contract OCR_Instant is ZivoeLocker, ReentrancyGuard {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;               /// @dev The ZivoeGlobals contract.
    address public immutable zVLT;              /// @dev The ZivoeVault contract.
    address public immutable zSTT;              /// @dev The ZivoeTrancheToken contract.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCR_Instant contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _zVLT The ZivoeVault contract.
    /// @param  _zSTT The ZivoeTrancheToken contract.
    constructor(address DAO, address _GBL, address _zVLT, address _zSTT) {
        transferOwnershipAndLock(DAO);
        GBL = _GBL;
        zVLT = _zVLT;
        zSTT = _zSTT;
    }



    // ------------
    //    Events   
    // ------------

    /// @notice Emitted during withdraw().
    /// @param zVLTAmount The amount of zVLT burnt.
    /// @param stableAmount The amount of stablecoin returned.
    /// @param stablecoin The stablecoin returned.
    event Withdrawal(
        uint256 zVLTAmount,
        uint256 stableAmount,
        address stablecoin
    );


    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pushToLockerMulti().
    function canPushMulti() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerMulti().
    function canPullMulti() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerMultiPartial().
    function canPullMultiPartial() public override pure returns (bool) { return true; }

    /// @notice Redeem stablecoins by burning zVLT tokens.
    /// @dev Returns stablecoins on a 1:1 basis, accounts for stablecoin precision.
    /// @param amount The amount of zVLT to burn.
    /// @param stablecoin The stablecoin to redeem.
    function withdraw(uint amount, address stablecoin) external nonReentrant {
        
        // Check amount of stablecoin present.
        uint256 stableAmount = IERC20(stablecoin).balanceOf(address(this));
        uint256 convertedAmount = IZivoeGlobals_OCR_Instant(GBL).standardize(stableAmount, stablecoin);
        require(amount <= convertedAmount, "OCR_Instant::withdraw() amount > convertedAmount");

        // Transfer in zVLT, unwrap zVLT for zSTT, burn zVLT.
        IERC20(zVLT).safeTransferFrom(_msgSender(), address(this), amount);
        uint shares = IZivoeVault_OCR_Instant(zVLT).withdraw(amount, address(this), address(this));
        IERC20Burn_OCR_Instant(zSTT).burn(shares);

        // Return stablecoins to user.
        uint returnAmount = shares * 10 ** (18 - IERC20Metadata(stablecoin).decimals()); 
        IERC20(stablecoin).safeTransfer(_msgSender(), returnAmount);

        // Emit event.
        emit Withdrawal(amount, returnAmount, stablecoin);

    }

}