// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Note: 
// -To rethink if DAO canPull() because could lead to problems
// -If not redeemed in epoch, should cancel request and start a new request 
// (otherwise lost coins will be bad) (think of extending this in later version)

interface OCR_IZivoeGlobals {
    /// @notice Returns the address of the $zSTT contract.
    function zSTT() external view returns (address);

    /// @notice Returns the address of the $zJTT contract.
    function zJTT() external view returns (address);

    /// @notice Returns true if an address is whitelisted as a keeper.
    /// @return keeper Equals "true" if address is a keeper, "false" if not.
    function isKeeper(address) external view returns (bool keeper);

    /// @notice Returns total circulating supply of zSTT and zJTT, accounting for defaults via markdowns.
    /// @return zSTTSupply zSTT.totalSupply() adjusted for defaults.
    /// @return zJTTSupply zJTT.totalSupply() adjusted for defaults.
    function adjustedSupplies() external view returns (uint256 zSTTSupply, uint256 zJTTSupply);
    
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
contract OCR_Modular is ZivoeLocker, ReentrancyGuard {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable stablecoin;          /// @dev The stablecoin redeemable in this contract.
    address public immutable GBL;                 /// @dev The ZivoeGlobals contract.   

    uint16 public redemptionFee;                  /// @dev Redemption fee on withdrawals via OCR (in BIPS).

    uint256 public withdrawRequestsEpoch;         /// @dev total amount of redemption requests for current epoch.
    uint256 public withdrawRequestsNextEpoch;     /// @dev total amount of redemption requests for next epoch.
    uint256 public amountWithdrawableInEpoch;     /// @dev total amount withdrawable in epoch.

    uint256 public nextEpochDistribution;         /// @dev Used for timelock constraint for redemptions.
    uint256 public currentEpochDistribution;      /// @dev Used for timelock constraint for redemptions.
    uint256 public previousEpochDistribution;     /// @dev Used for timelock constraint for redemptions.

    /// @dev Mapping of an address to a specific timestamp.   
    mapping (address => uint256) public userClaimTimestampJunior;

    /// @dev Mapping of an address to a specific timestamp.   
    mapping (address => uint256) public userClaimTimestampSenior; 

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



    // ---------------
    //    Functions
    // ---------------    

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override onlyOwner nonReentrant {
        require(
            asset != OCR_IZivoeGlobals(GBL).zJTT() &&
            asset != OCR_IZivoeGlobals(GBL).zSTT(),
            "OCR_Modular::pullFromLocker() asset == zJTT || asset == zSTT"
        );
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Initiates a redemption request for junior tranche tokens
    /// @param amount The amount of junior tranche tokens to redeem
    function redemptionRequestJunior(uint256 amount) external {
        IERC20(OCR_IZivoeGlobals(GBL).zJTT()).safeTransferFrom(_msgSender(), address(this), amount);
        juniorBalances[_msgSender()] += amount;
        userClaimTimestampJunior[_msgSender()] = block.timestamp;
        withdrawRequestsNextEpoch += amount;
    }

    /// @notice Initiates a redemption request for senior tranche tokens
    /// @param amount The amount of senior tranche tokens to redeem
    function redemptionRequestSenior(uint256 amount) external {
        IERC20(OCR_IZivoeGlobals(GBL).zSTT()).safeTransferFrom(_msgSender(), address(this), amount);
        seniorBalances[_msgSender()] += amount;
        userClaimTimestampSenior[_msgSender()] = block.timestamp;
        withdrawRequestsNextEpoch += amount;
    }

    /// @notice This function will start the transition to a new epoch
    function distributeEpoch() public {
        require(block.timestamp > nextEpochDistribution, "OCR_Modular::distributeEpoch() block.timestamp <= nextEpochDistribution");
        amountWithdrawableInEpoch = IERC20(stablecoin).balanceOf(address(this));
        nextEpochDistribution = block.timestamp + 30 days;
        previousEpochDistribution = currentEpochDistribution;
        currentEpochDistribution = block.timestamp;
        withdrawRequestsEpoch = withdrawRequestsNextEpoch;
        withdrawRequestsNextEpoch = 0;
    }

    // todo: Here we'll have to extend claiming period for 90 days + check if defaultsToAccountFor should be substracted
    // from protocol defaults in some way
    // todo: double check if there's a risk of having ">= previousEpochDistribution" (specially the "=" sign)

    /// @notice Redeem stablecoins by burning staked $zJTT tranche tokens.
    function redeemJunior() external {
        require(juniorBalances[_msgSender()] > 0, "OCR_Modular::redeemJunior() juniorBalances[_msgSender] == 0");
        require(
            userClaimTimestampJunior[_msgSender()] < currentEpochDistribution,
            "OCR_Modular::redeemJunior() userClaimTimestampJunior[_msgSender()] >= currentEpochDistribution"
        );
        require(
            userClaimTimestampJunior[_msgSender()] >= previousEpochDistribution,
            "OCR_Modular::redeemJunior() userClaimTimestampJunior[_msgSender()] < previousEpochDistribution"
        );

        (,uint256 asJTT) = OCR_IZivoeGlobals(GBL).adjustedSupplies();
        uint256 redeemablePreDefault = (withdrawRequestsEpoch * juniorBalances[_msgSender()]) / 
        OCR_IZivoeGlobals(GBL).standardize(amountWithdrawableInEpoch, stablecoin);
        uint256 defaultsToAccountFor = redeemablePreDefault - 
        ((redeemablePreDefault * asJTT) / IERC20(OCR_IZivoeGlobals(GBL).zJTT()).totalSupply());

        // decrease account balance of zJTT tokens
        juniorBalances[_msgSender()] -= redeemablePreDefault;
        // set "userClaimTimestamp" to 0 todo: double check if really needed
        if (juniorBalances[_msgSender()] == 0) {
            userClaimTimestampJunior[_msgSender()] = 0;
        } else {
            userClaimTimestampJunior[_msgSender()] = block.timestamp;
        }
        // substract the defaults from redeemable amount
        uint256 redeemable = redeemablePreDefault - defaultsToAccountFor;

        // set correct amount of decimals if "stablecoin" has less than 18 decimals
        if (IERC20Metadata(stablecoin).decimals() < 18) {
            redeemable /= 10 ** (18 - IERC20Metadata(stablecoin).decimals());
        }
        // transfer stablecoins to account
        IERC20(stablecoin).safeTransfer(_msgSender(), redeemable);
        // burn Junior tranche tokens
        OCR_IZivoeGlobals(OCR_IZivoeGlobals(GBL).zJTT()).burn(redeemablePreDefault);
    }

    // Here we'll have to extend claiming period for 90 days + check if defaultsToAccountFor should be substracted
    // from protocol defaults in some way
    /// @notice This function will enable the redemption for senior tranche tokens.
    function redeemSenior() external {
        require(seniorBalances[_msgSender()] > 0, "OCR_Modular::redeemSenior() seniorBalances[_msgSender] == 0");
        require(
            userClaimTimestampSenior[_msgSender()] < currentEpochDistribution, 
            "OCR_Modular::redeemSenior() userClaimTimestampSenior[_msgSender()] > currentEpochDistribution"
        );
        require(
            userClaimTimestampSenior[_msgSender()] >= previousEpochDistribution, 
            "OCR_Modular::redeemSenior() userClaimTimestampSenior[_msgSender()] < previousEpochDistribution"
        );

        (uint256 asSTT,) = OCR_IZivoeGlobals(GBL).adjustedSupplies();
        uint256 redeemablePreDefault = (withdrawRequestsEpoch * seniorBalances[_msgSender()]) / 
        OCR_IZivoeGlobals(GBL).standardize(amountWithdrawableInEpoch, stablecoin);
        uint256 defaultsToAccountFor = redeemablePreDefault - 
        ((redeemablePreDefault * asSTT) / IERC20(OCR_IZivoeGlobals(GBL).zSTT()).totalSupply());

        // decrease account balance of zSTT tokens
        seniorBalances[_msgSender()] -= redeemablePreDefault;
        // set "userClaimTimestamp" to 0 todo: double check if really needed
        if (seniorBalances[_msgSender()] == 0) {
            userClaimTimestampSenior[_msgSender()] = 0;
        } else {
            userClaimTimestampSenior[_msgSender()] = block.timestamp;
        }
        // substract the defaults from redeemable amount
        uint256 redeemable = redeemablePreDefault - defaultsToAccountFor;

        // set correct amount of decimals if "stablecoin" has less than 18 decimals
        if (IERC20Metadata(stablecoin).decimals() < 18) {
            redeemable /= 10 ** (18 - IERC20Metadata(stablecoin).decimals());
        }
        // transfer stablecoins to account
        IERC20(stablecoin).safeTransfer(_msgSender(), redeemable);
        // burn Senior tranche tokens
        OCR_IZivoeGlobals(OCR_IZivoeGlobals(GBL).zSTT()).burn(redeemablePreDefault);
    }


}