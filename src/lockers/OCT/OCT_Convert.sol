// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IZivoeGlobals_OCT_Convert {
    /// @notice Returns true if an address is whitelisted as a keeper.
    /// @return keeper Equals "true" if address is a keeper, "false" if not.
    function isKeeper(address) external view returns (bool keeper);
    
    /// @notice Returns the address of the ZivoeTrancheToken ($zJTT) contract.
    function zJTT() external view returns (address);

    /// @notice Returns the address of the ZivoeTrancheToken ($zSTT) contract.
    function zSTT() external view returns (address);

    /// @notice Returns the address of the ZivoeTranches contract.
    function ZVT() external view returns (address);

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  amount              The amount of a given "asset".
    /// @param  asset               The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount  The input "amount" standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);
}

interface IZivoeTranches_OCT_Convert {
    /// @notice Deposit stablecoins into the senior tranche.
    function depositSenior(uint256 amount, address asset) external;
}

interface IERC20Burn_OCT_Convert {
    /// @notice Burns tokens.
    function burn(uint256 amount) external;
}

/// @notice This contract converts zJTT to zSTT, and allows zSTT withdrawals.
contract OCT_Convert is ZivoeLocker, ReentrancyGuard {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;               /// @dev The ZivoeGlobals contract.

    /// @dev Whitelist for converters, managed by keepers.
    mapping(address => bool) public isDepositor;


    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCT_YDL contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _GBL The ZivoeGlobals contract.
    constructor(address DAO, address _GBL) {
        transferOwnershipAndLock(DAO);
        GBL = _GBL;
    }



    // ------------
    //    Events   
    // ------------

    /// @notice Emitted during convertTranche().
    event TrancheConverted(
        address stablecoin,
        address caller,
        uint amount
    );

    /// @notice Emitted during withdrawTranche().
    event TrancheWithdrawn(
        address stablecoin,
        address caller,
        uint amount
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

    /// @notice Updates whitelist.
    /// @dev Restricted to keepers.
    /// @param user The address to add/remove from whitelist.
    /// @param status The new status of user (true = accepted, false = rejected).
    function updateWhitelist(address user, bool status) external {
        require(IZivoeGlobals_OCT_Convert(GBL).isKeeper(_msgSender()));
        isDepositor[user] = status;
    }

    /// @notice Converts zJTT to zSTT.
    /// @param amount The amount of stablecoin to use for conversion.
    /// @param stablecoin The stablecoin to use for conversion (will be transferred here from ZivoeDAO)
    function convertTranche(uint amount, address stablecoin) external nonReentrant {
        
        address caller = _msgSender();
        address zJTT = IZivoeGlobals_OCT_Convert(GBL).zJTT();
        address zSTT = IZivoeGlobals_OCT_Convert(GBL).zSTT();
        uint standardizedAmount = IZivoeGlobals_OCT_Convert(GBL).standardize(amount, stablecoin);

        // Whitelist check.
        require(isDepositor[caller]);

        // Transfer zJTT from user to locker
        IERC20(zJTT).safeTransferFrom(caller, address(this), standardizedAmount);

        // Burn zJTT
        IERC20Burn_OCT_Convert(zJTT).burn(standardizedAmount);

        // Mint zSTT with stablecoin specified (handle precision of stablecoin)
        address ZVT = IZivoeGlobals_OCT_Convert(GBL).ZVT();
        IZivoeTranches_OCT_Convert(ZVT).depositSenior(amount, stablecoin);

        // Transfer zSTT to user (alternatively, deposit to vault via router, then transfer to user)
        IERC20(zSTT).safeTransfer(caller, standardizedAmount);

        // Emit event log
        emit TrancheConverted(stablecoin, caller, amount);
    }

    /// @notice Converts zSTT to stablecoins.
    function withdrawTranche(uint amount, address stablecoin) external nonReentrant {
        
        address caller = _msgSender();
        address zSTT = IZivoeGlobals_OCT_Convert(GBL).zSTT();
        uint standardizedAmount = IZivoeGlobals_OCT_Convert(GBL).standardize(amount, stablecoin);

        // Transfer zSTT from user to locker
        IERC20(zSTT).safeTransferFrom(caller, address(this), standardizedAmount);

        // Burn zSTT
        IERC20Burn_OCT_Convert(zSTT).burn(standardizedAmount);

        // Transfer specified stablecoin to user
        IERC20(stablecoin).safeTransfer(caller, amount);

        // Emit event log
        emit TrancheWithdrawn(stablecoin, caller, amount);
    }

}