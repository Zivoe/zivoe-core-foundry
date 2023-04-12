// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";
import "../../../lib/openzeppelin-contracts/contracts/utils/Context.sol";

/// Note: 
/// -Should we have separate claim timestamps for junior and senior ?

interface IZivoeGlobals_OCR {
    /// @notice Returns the address of the $zSTT contract.
    function zSTT() external view returns (address);
    /// @notice Returns the address of the $zJTT contract.
    function zJTT() external view returns (address);
}

/// @notice  OCR stands for "On-Chain Redemption".
///          This locker is responsible for handling redemptions of tranche tokens to stablecoins.
contract OCC_Modular is ZivoeLocker {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    uint16 public redemptionFee;             /// @dev Redemption fee on withdrawals via OCR (in BIPS).
    address public immutable stablecoin;     /// @dev The stablecoin redeemable in this contract.
    address public immutable GBL;            /// @dev The ZivoeGlobals contract.   
    uint256 public totalRedemptionsOnPeriod; /// @dev total amount of redemption requests for next distribution.
    uint256 public lastDistribution;         /// @dev Used for timelock constraint for redemptions.

    /// @dev Mapping of an address to a specific timestamp.   
    mapping (address => uint256) public userClaimTimestamp;   
    /// @dev Contains $zJTT token balance of each account (is 1:1 ratio with amount deposited)
    mapping(address => uint256) private juniorBalances;
    /// @dev Contains $zSTT token balance of each account (is 1:1 ratio with amount deposited).
    mapping(address => uint256) private seniorBalances; 


    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCR_Modular contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _stablecoin The stablecoin redeemable in this OCR contract.
    /// @param _GBL The yield distribution locker that collects and distributes capital for this OCR locker.
    constructor(address DAO, address _stablecoin, address _GBL) {
        transferOwnershipAndLock(DAO);
        stablecoin = _stablecoin;
        GBL = _GBL;
    }

    // ------------
    //    Events
    // ------------

    // ---------------
    //    Functions
    // ---------------    

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Initiates a redemption request for junior tranche tokens
    /// @param amount The amount of junior tranche tokens to redeem
    function redemptionRequestJunior(uint256 amount) external {
        require(IERC20(IZivoeGlobals_OCR(GBL).zJTT()).balanceOf(_msgSender()) >= amount,
        "OCR_Modular::redemptionRequestJunior() balanceOf(_msgSender()) < amount");
        IERC20(IZivoeGlobals_OCR(GBL).zJTT()).safeTransferFrom(_msgSender(), address(this), amount);
        juniorBalances[_msgSender()] += amount;
        userClaimTimestamp[_msgSender()] = block.timestamp;
    }

    /// @notice Initiates a redemption request for senior tranche tokens
    /// @param amount The amount of senior tranche tokens to redeem
    function redemptionRequestSenior(uint256 amount) external {
        require(IERC20(IZivoeGlobals_OCR(GBL).zSTT()).balanceOf(_msgSender()) >= amount,
        "OCR_Modular::redemptionRequestSenior() balanceOf(_msgSender()) < amount");
        IERC20(IZivoeGlobals_OCR(GBL).zSTT()).safeTransferFrom(_msgSender(), address(this), amount);
        seniorBalances[_msgSender()] += amount;
        userClaimTimestamp[_msgSender()] = block.timestamp;
    }

}