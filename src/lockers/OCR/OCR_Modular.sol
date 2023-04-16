// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";
import "../Utility/ZivoeSwapper.sol";
import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

/// Note: 
/// -Should we have separate claim timestamps for junior and senior ?
/// -To rethink if DAO canPull() because could lead to problems
/// -If not redeemed in epoch, should cancel request and start a new request (otherwise lost coins will be bad) (think of extending this)
/// -Should it be ZivoeSwapper and able to convert other stablecoins to (beware of funds not being blocked in the contract)


interface OCR_IZivoeGlobals {
    /// @notice Returns the address of the $zSTT contract.
    function zSTT() external view returns (address);
    /// @notice Returns the address of the $zJTT contract.
    function zJTT() external view returns (address);
    /// @notice Returns true if an address is whitelisted as a keeper.
    /// @return keeper Equals "true" if address is a keeper, "false" if not.
    function isKeeper(address) external view returns (bool keeper);

}

/// @notice  OCR stands for "On-Chain Redemption".
///          This locker is responsible for handling redemptions of tranche tokens to stablecoins.
contract OCR_Modular is ZivoeLocker, ZivoeSwapper, ReentrancyGuard {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    uint16 public redemptionFee;                  /// @dev Redemption fee on withdrawals via OCR (in BIPS).
    address public immutable stablecoin;          /// @dev The stablecoin redeemable in this contract.
    address public immutable GBL;                 /// @dev The ZivoeGlobals contract.   
    uint256 public withdrawRequestsEpoch;         /// @dev total amount of redemption requests for current epoch.
    uint256 public withdrawRequestsNextEpoch;     /// @dev total amount of redemption requests for next epoch.
    uint256 public amountWithdrawableInEpoch;     /// @dev total amount withdrawable in epoch.

    uint256 public nextEpochDistribution;    /// @dev Used for timelock constraint for redemptions.
    uint256 public currentEpochDistribution; /// @dev Used for timelock constraint for redemptions.

    /// @dev Mapping of an address to a specific timestamp.   
    mapping (address => uint256) public userClaimTimestamp;   
    /// @dev Contains $zJTT token balance of each account (is 1:1 ratio with amount deposited)
    mapping(address => uint256) public juniorBalances;
    /// @dev Contains $zSTT token balance of each account (is 1:1 ratio with amount deposited).
    mapping(address => uint256) public seniorBalances; 


    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCR_Modular contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _stablecoin The stablecoin redeemable in this OCR contract.
    /// @param _GBL The yield distribution locker that collects and distributes capital for this OCR locker.
    /// @param _redemptionFee Redemption fee on withdrawals via OCR (in BIPS).
    constructor(address DAO, address _stablecoin, address _GBL, uint16 _redemptionFee) {
        transferOwnershipAndLock(DAO);
        stablecoin = _stablecoin;
        GBL = _GBL;
        redemptionFee = _redemptionFee;
        currentEpochDistribution = block.timestamp;
        nextEpochDistribution = block.timestamp + 30 days;
    }

    // ------------
    //    Events
    // ------------

    /// @notice Emitted during convert().
    /// @param  fromAsset The asset converted from.
    /// @param  amountConverted The amount of "fromAsset" specified for conversion. 
    /// @param  amountReceived The amount of "stablecoin" received while converting.
    event AssetConverted(address indexed fromAsset, uint256 amountConverted, uint256 amountReceived);


    // ---------------
    //    Functions
    // ---------------    

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

/*     /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; } */

    /// @notice Initiates a redemption request for junior tranche tokens
    /// @param amount The amount of junior tranche tokens to redeem
    function redemptionRequestJunior(uint256 amount) external {
        require(IERC20(OCR_IZivoeGlobals(GBL).zJTT()).balanceOf(_msgSender()) >= amount,
        "OCR_Modular::redemptionRequestJunior() balanceOf(_msgSender()) < amount");
        IERC20(OCR_IZivoeGlobals(GBL).zJTT()).safeTransferFrom(_msgSender(), address(this), amount);
        juniorBalances[_msgSender()] += amount;
        userClaimTimestamp[_msgSender()] = block.timestamp;
        withdrawRequestsNextEpoch += amount;
    }

    /// @notice Initiates a redemption request for senior tranche tokens
    /// @param amount The amount of senior tranche tokens to redeem
    function redemptionRequestSenior(uint256 amount) external {
        require(IERC20(OCR_IZivoeGlobals(GBL).zSTT()).balanceOf(_msgSender()) >= amount,
        "OCR_Modular::redemptionRequestSenior() balanceOf(_msgSender()) < amount");
        IERC20(OCR_IZivoeGlobals(GBL).zSTT()).safeTransferFrom(_msgSender(), address(this), amount);
        seniorBalances[_msgSender()] += amount;
        userClaimTimestamp[_msgSender()] = block.timestamp;
        withdrawRequestsNextEpoch += amount;
    }

    /// @notice This function will start the transition to a new epoch
    function distributeEpoch() public {
        require(block.timestamp > nextEpochDistribution, "OCR_Modular::distributeEpoch() block.timestamp < nextEpochDistribution");
        amountWithdrawableInEpoch = IERC20(stablecoin).balanceOf(address(this));
        nextEpochDistribution = block.timestamp + 30 days;
        currentEpochDistribution = block.timestamp;
        withdrawRequestsEpoch = withdrawRequestsNextEpoch;
        withdrawRequestsNextEpoch = 0;

    }

    /// @notice This function converts any arbitrary asset to this locker's redeemable stablecoin.
    /// @param  assetToConvert The asset to convert to redeemable stablecoin.
    /// @param  amount The data retrieved from 1inch API in order to execute the swap.
    /// @param  data The data retrieved from 1inch API in order to execute the swap.
    function convert(address assetToConvert, uint256 amount, bytes calldata data) external nonReentrant {
        require(OCR_IZivoeGlobals(GBL).isKeeper(_msgSender()), "OCR_Modular::convert() !OCR_IZivoeGlobals(GBL).isKeeper(_msgSender())");
        require(assetToConvert != stablecoin && assetToConvert != OCR_IZivoeGlobals(GBL).zJTT()
        && assetToConvert != OCR_IZivoeGlobals(GBL).zSTT(), "OCR_Modular::convert() assetToConvert == stablecoin || zSTT || zJTT");
    
        uint256 preBalance = IERC20(stablecoin).balanceOf(address(this));

        // Swap specified amount of "assetToConvert" to OCR_Modular.stablecoin().
        convertAsset(assetToConvert, stablecoin, amount, data);

        emit AssetConverted(assetToConvert, amount, IERC20(stablecoin).balanceOf(address(this)) - preBalance);
    }


}