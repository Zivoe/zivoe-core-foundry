// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IZivoeGlobals_OCR {
    /// @notice Returns the address of the Timelock contract.
    function TLC() external view returns (address);

    /// @notice Returns the address of the $zJTT contract.
    function zJTT() external view returns (address);

    /// @notice Returns the address of the $zSTT contract.
    function zSTT() external view returns (address);

    /// @notice Returns total circulating supply of zSTT and zJTT, accounting for defaults via markdowns.
    /// @return zSTTSupply zSTT.totalSupply() adjusted for defaults.
    /// @return zJTTSupply zJTT.totalSupply() adjusted for defaults.
    function adjustedSupplies() external view returns (uint256 zSTTSupply, uint256 zJTTSupply);

    /// @notice Returns true if an address is whitelisted as a keeper.
    /// @return keeper Equals "true" if address is a keeper, "false" if not.
    function isKeeper(address) external view returns (bool keeper);
    
    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  amount The amount of a given "asset".
    /// @param  asset The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount The above amount standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);

    /// @notice Burns $zTT tokens.
    /// @param  amount The number of $zTT tokens to burn.
    function burn(uint256 amount) external;
}

/// @notice  OCR stands for "On-Chain Redemption".
///          This locker is responsible for handling redemptions of tranche tokens to stablecoins.
contract OCR_ModularV2 is ZivoeLocker, ReentrancyGuard {

    using SafeERC20 for IERC20;

    struct Request {
        address account;        /// @dev The account making the request.
        uint256 amount;         /// @dev The amount of the request ($zSTT or $zJTT).
        uint256 unlocks;        /// @dev The timestamp after which this request may be processed.
        bool seniorOrJunior;    /// @dev The tranche this request is for (true = Senior, false = Junior).
    }

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable stablecoin;            /// @dev The stablecoin redeemable in this contract.
    address public immutable GBL;                   /// @dev The ZivoeGlobals contract.   

    uint256 public requestCounter;                  /// @dev Increments with new requests.
    
    uint256 public redemptionsFee;                  /// @dev Fee for redemptions (in BIPS).

    uint256 public redemptionsAllowedJunior;
    uint256 public redemptionsAllowedSenior;

    uint256 public redemptionsQueuedJunior;
    uint256 public redemptionsQueuedSenior;

    uint256 public epochDiscountJunior;
    uint256 public epochDiscountSenior;

    /*
        rAS = 1,000,000
        rAJ = 1,000,000
        eDJ = 1000
        eDS = 0

        rAS = 1,000,000
        rAJ = 1,000,000
        eDJ = 0
        eDS = 0

        burnS == sB / (rAS + rAJ)
    */

    uint256 public epoch;                           /// @dev The timestamp of this epoch.

    mapping(uint256 => Request) public requests;    /// @dev Mapping of all requests.

    uint256 private constant BIPS = 10000;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCR_Modular contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _stablecoin The stablecoin redeemable in this OCR contract.
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _redemptionsFee Fee for redemptions (in BIPS).
    constructor(address DAO, address _stablecoin, address _GBL, uint16 _redemptionsFee) {
        transferOwnershipAndLock(DAO);
        stablecoin = _stablecoin;
        GBL = _GBL;
        redemptionsFee = _redemptionsFee;
        epoch = block.timestamp + 14 days;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during tickEpoch() and _tickEpoch().
    event EpochTicked();

    /// @notice Emitted during createRequest().
    event RequestCreated();

    /// @notice Emitted during destroyRequest().
    event RequestDestroyed();

    /// @notice Emitted during processRequest().
    event RequestProcessed();

    /// @notice Emitted during updateRedemptiosnFee().
    /// @param  oldFee The old value of redemptionFee.
    /// @param  newFee The new value of redemptionFee.
    event UpdatedRedemptionsFee(uint256 oldFee, uint256 newFee);



    // ---------------
    //    Modifiers
    // ---------------

    /// @notice This modifier ensures accounting is updated BEFORE mutative actions.
    modifier _tickEpoch() {
        tickEpoch();
        _;
    }



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice This pulls capital from the DAO.
    /// @param  asset The asset to pull from the DAO.
    /// @param  amount The amount of asset to pull from the DAO.
    /// @param  data Accompanying transaction data.
    function pushToLocker(address asset, uint256 amount, bytes calldata data) external override _tickEpoch onlyOwner nonReentrant {
        require(asset == stablecoin, "OCR_Modular::pushToLocker() asset != stablecoin");
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override _tickEpoch onlyOwner nonReentrant {
        require(
            asset != IZivoeGlobals_OCR(GBL).zJTT() &&
            asset != IZivoeGlobals_OCR(GBL).zSTT(),
            "OCR_Modular::pullFromLocker() asset == zJTT || asset == zSTT"
        );
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(address asset, uint256 amount, bytes calldata data) external override _tickEpoch onlyOwner nonReentrant {
        require(
            asset != IZivoeGlobals_OCR(GBL).zJTT() &&
            asset != IZivoeGlobals_OCR(GBL).zSTT(),
            "OCR_Modular::pullFromLockerPartial() asset == zJTT || asset == zSTT"
        );
        IERC20(asset).safeTransfer(owner(), amount);
    }

    /// @notice Ticks the epoch.
    function tickEpoch() public {
        if (block.timestamp > epoch) { 
            epoch += 14 days;
            redemptionsAllowedJunior += redemptionsQueuedJunior;
            redemptionsAllowedSenior += redemptionsQueuedSenior;
            redemptionsQueuedJunior = 0;
            redemptionsQueuedSenior = 0;
            // TODO: epochDiscountJunior
            // TODO: epochDiscountSenior
        }
    }

    /// @notice Updates the state variable "redemptionsFee".
    /// @param  _redemptionsFee The new value for redemptionsFee (in BIPS).
    function updateRedemptionsFee(uint256 _redemptionsFee) external _tickEpoch {
        require(_msgSender() == IZivoeGlobals_OCR(GBL).TLC(), "OCR_Modular::updateRedemptionsFee() _msgSender() != TLC()");
        require(
            _redemptionsFee <= 2000 && _redemptionsFee >= 250, 
            "OCR_Modular::updateRedemptionsFee() _redemptionsFee > 2000 && _redemptionsFee < 250"
        );
        emit UpdatedRedemptionsFee(redemptionsFee, _redemptionsFee);
        redemptionsFee = _redemptionsFee;
    }

}