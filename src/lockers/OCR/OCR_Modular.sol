// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface OCR_IZivoeGlobals {
    /// @notice Returns the address of the Timelock contract.
    function TLC() external view returns (address);

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

    address public immutable stablecoin;            /// @dev The stablecoin redeemable in this contract.
    address public immutable GBL;                   /// @dev The ZivoeGlobals contract.   

    uint256 public redemptionFee;                   /// @dev Redemption fee on withdrawals via OCR (in BIPS).

    uint256 public amountRedeemable;                /// @dev Total amount redeemable in epoch.
    uint256 public amountRedeemableQueued;          /// @dev Excess amount redeemable in next epoch.
    uint256 public redemptionsAllowed;              /// @dev Redemption requests for current epoch.
    uint256 public redemptionsRequested;            /// @dev Redemption requests for next epoch.
    uint256 public redemptionsUnclaimed;            /// @dev Unclaimed redemption requests.

    uint256 public nextEpoch;                       /// @dev Unix timestamp of next epoch.
    uint256 public currentEpoch;                    /// @dev Unix timestamp of current epoch.

    uint256 private constant BIPS = 10000;       

    /// @dev Unix timestamp of a redemption request for junior tranche tokens.
    mapping (address => uint256) public juniorRedemptionRequestedOn;

    /// @dev Unix timestamp of a redemption request for senior tranche tokens.
    mapping (address => uint256) public seniorRedemptionRequestedOn; 

    /// @dev Redemptions queued for next epoch, junior tranche tokens.
    mapping (address => uint256) public juniorRedemptionsQueued;

    /// @dev Redemptions queued for next epoch, senior tranche tokens.
    mapping (address => uint256) public seniorRedemptionsQueued;

    /// @dev Contains $zJTT token balance of each account (is 1:1 ratio with amount deposited)
    mapping(address => uint256) public juniorBalances;

    /// @dev Contains $zSTT token balance of each account (is 1:1 ratio with amount deposited).
    mapping(address => uint256) public seniorBalances; 



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCR_Modular contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _stablecoin The stablecoin redeemable in this OCR contract.
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _redemptionFee Redemption fee on withdrawals via OCR (in BIPS).
    constructor(address DAO, address _stablecoin, address _GBL, uint16 _redemptionFee) {
        transferOwnershipAndLock(DAO);
        stablecoin = _stablecoin;
        GBL = _GBL;
        redemptionFee = _redemptionFee;
        currentEpoch = block.timestamp;
        nextEpoch = block.timestamp + 30 days;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during setRedemptionFee().
    /// @param  oldValue The old value of redemptionFee.
    /// @param  newValue The new value of redemptionFee.
    event UpdatedRedemptionFee(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during redemptionRequestJunior().
    /// @param  account The account making the redemption request.
    /// @param  amount The amount of junior tranche tokens to redeem.
    event RequestedJunior(address indexed account, uint256 amount);

    /// @notice Emitted during redemptionRequestSenior().
    /// @param  account The account making the redemption request.
    /// @param  amount The amount of junior tranche tokens to redeem.
    event RequestedSenior(address indexed account, uint256 amount);

    /// @notice Emitted during redeemJunior().
    /// @param  account The account redeeming.
    /// @param  redeemablePreFee The amount of stablecoins effectively transferred.
    /// @param  fee The feed paid for redemption.   
    /// @param  defaults Proportional defaults of the protocol, if any, impacting the redeemable amount.  
    event RedeemedJunior(address indexed account, uint256 redeemablePreFee, uint256 fee, uint256 defaults);

    /// @notice Emitted during redeemSenior().
    /// @param  account The account redeeming.
    /// @param  redeemablePreFee The amount of stablecoins effectively transferred.
    /// @param  fee The feed paid for redemption.    
    /// @param  defaults Proportional defaults of the protocol, if any, impacting the redeemable amount. 
    event RedeemedSenior(address indexed account, uint256 redeemablePreFee, uint256 fee, uint256 defaults);

    /// @notice Emitted during cancelRedemptionJunior().
    /// @param  account The account cancelling a redemption request.
    /// @param  amount The amount of requested redemptions to cancel.
    event CancelledJunior(address indexed account, uint256 amount);

    /// @notice Emitted during cancelRedemptionSenior().
    /// @param  account The account cancelling a redemption request.
    /// @param  amount The amount of requested redemptions to cancel.
    event CancelledSenior(address indexed account, uint256 amount);



    // ---------------
    //    Functions
    // ---------------    

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice Updates the state variable "redemptionFee".
    /// @param  _redemptionFee The new value for redemptionFee (in BIPS).
    function setRedemptionFee(uint256 _redemptionFee) external {
        require(_msgSender() == OCR_IZivoeGlobals(GBL).TLC(), "OCR_Modular::setRedemptionFee() _msgSender() != TLC()");
        require(
            _redemptionFee <= 2000 && _redemptionFee >= 250, 
            "OCR_Modular::setRedemptionFee() _redemptionFee > 2000 && _redemptionFee < 250"
        );
        emit UpdatedRedemptionFee(redemptionFee, _redemptionFee);
        redemptionFee = _redemptionFee;
    }

    /// @notice This pulls capital from the DAO.
    /// @param  asset The asset to pull from the DAO.
    /// @param  amount The amount of asset to pull from the DAO.
    /// @param  data Accompanying transaction data.
    function pushToLocker(address asset, uint256 amount, bytes calldata data) external override onlyOwner nonReentrant {
        require(asset == stablecoin, "OCR_Modular::pushToLocker() asset != stablecoin");
        amountRedeemableQueued += amount;
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override onlyOwner nonReentrant {
        require(
            asset != OCR_IZivoeGlobals(GBL).zJTT() &&
            asset != OCR_IZivoeGlobals(GBL).zSTT(),
            "OCR_Modular::pullFromLocker() asset == zJTT || asset == zSTT"
        );

        if (asset == stablecoin) {
            amountRedeemable = 0;
            amountRedeemableQueued = 0;
        }

        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(address asset, uint256 amount, bytes calldata data) external override onlyOwner nonReentrant {
        require(
            asset != OCR_IZivoeGlobals(GBL).zJTT() &&
            asset != OCR_IZivoeGlobals(GBL).zSTT(),
            "OCR_Modular::pullFromLockerPartial() asset == zJTT || asset == zSTT"
        );

        if (amount > amountRedeemableQueued && asset == stablecoin) {
            amountRedeemable -= (amount - amountRedeemableQueued);
            amountRedeemableQueued = 0;
        } else if (asset == stablecoin) {
            amountRedeemableQueued -= amount;
        }

        IERC20(asset).safeTransfer(owner(), amount);
    }

    /// @notice Initiates a redemption request for junior tranche tokens
    /// @param  amount The amount of junior tranche tokens to redeem
    function redemptionRequestJunior(uint256 amount) external {
        IERC20(OCR_IZivoeGlobals(GBL).zJTT()).safeTransferFrom(_msgSender(), address(this), amount);

        emit RequestedJunior(_msgSender(), amount);

        // account for the total amount requested of account in latest epoch
        if (juniorBalances[_msgSender()] > 0 && juniorRedemptionRequestedOn[_msgSender()] < currentEpoch) {
            juniorRedemptionsQueued[_msgSender()] = amount;
        } else if (juniorBalances[_msgSender()] > 0 && juniorRedemptionRequestedOn[_msgSender()] >= currentEpoch) {
            juniorRedemptionsQueued[_msgSender()] += amount;
        } else if (juniorBalances[_msgSender()] == 0) {
            juniorRedemptionsQueued[_msgSender()] = amount;
        }

        juniorBalances[_msgSender()] += amount; 
        juniorRedemptionRequestedOn[_msgSender()] = block.timestamp;
        redemptionsRequested += amount;
    }

    /// @notice Initiates a redemption request for senior tranche tokens
    /// @param  amount The amount of senior tranche tokens to redeem
    function redemptionRequestSenior(uint256 amount) external {
        IERC20(OCR_IZivoeGlobals(GBL).zSTT()).safeTransferFrom(_msgSender(), address(this), amount);

        emit RequestedSenior(_msgSender(), amount);

        // account for the total amount requested of account in latest epoch
        if (seniorBalances[_msgSender()] > 0 && seniorRedemptionRequestedOn[_msgSender()] < currentEpoch) {
            seniorRedemptionsQueued[_msgSender()] = amount;
        } else if (seniorBalances[_msgSender()] > 0 && seniorRedemptionRequestedOn[_msgSender()] >= currentEpoch) {
            seniorRedemptionsQueued[_msgSender()] += amount;
        } else if (seniorBalances[_msgSender()] == 0) {
            seniorRedemptionsQueued[_msgSender()] = amount;
        }

        seniorBalances[_msgSender()] += amount;
        seniorRedemptionRequestedOn[_msgSender()] = block.timestamp;
        redemptionsRequested += amount;
    }

    /// @notice Cancels a redemption request of junior tranches
    /// @param  amount The amount of junior tranche tokens to cancel
    function cancelRedemptionJunior(uint256 amount) external {
        require(
            juniorBalances[_msgSender()] >= amount,
            "OCR_Modular::cancelRedemptionJunior() juniorBalances[_msgSender()] < amount"
        );

        emit CancelledJunior(_msgSender(), amount);

        if (juniorRedemptionsQueued[_msgSender()] > 0 && amount <= juniorRedemptionsQueued[_msgSender()]) {
            juniorRedemptionsQueued[_msgSender()] -= amount;
            redemptionsRequested -= amount;
        } else if (juniorRedemptionsQueued[_msgSender()] > 0 &&  amount >= juniorRedemptionsQueued[_msgSender()]) {
            redemptionsRequested -= juniorRedemptionsQueued[_msgSender()];
            redemptionsAllowed -= (amount - juniorRedemptionsQueued[_msgSender()]);
            juniorRedemptionsQueued[_msgSender()] = 0;
        } else if (juniorRedemptionsQueued[_msgSender()] == 0) {
            redemptionsAllowed -= amount;
        }

        juniorBalances[_msgSender()] -= amount;
        IERC20(OCR_IZivoeGlobals(GBL).zJTT()).safeTransfer(_msgSender(), amount);  
    }

    /// @notice Cancels a redemption request of senior tranches
    /// @param  amount The amount of senior tranche tokens to cancel
    function cancelRedemptionSenior(uint256 amount) external {
        require(
            seniorBalances[_msgSender()] >= amount,
            "OCR_Modular::cancelRedemptionSenior() seniorBalances[_msgSender()] < amount"
        );

        emit CancelledSenior(_msgSender(), amount);

        if (seniorRedemptionsQueued[_msgSender()] > 0 && amount <= seniorRedemptionsQueued[_msgSender()]) {
            seniorRedemptionsQueued[_msgSender()] -= amount;
            redemptionsRequested -= amount;
        } else if (seniorRedemptionsQueued[_msgSender()] > 0 && amount >= seniorRedemptionsQueued[_msgSender()]) {
            redemptionsRequested -= seniorRedemptionsQueued[_msgSender()];
            redemptionsAllowed -= (amount - seniorRedemptionsQueued[_msgSender()]);
            seniorRedemptionsQueued[_msgSender()] = 0;
        } else if (seniorRedemptionsQueued[_msgSender()] == 0) {
            redemptionsAllowed -= amount;
        }

        seniorBalances[_msgSender()] -= amount;
        IERC20(OCR_IZivoeGlobals(GBL).zSTT()).safeTransfer(_msgSender(), amount);  
    }

    /// @notice This function will start the transition to a new epoch
    function distributeEpoch() public {
        require(block.timestamp > nextEpoch, "OCR_Modular::distributeEpoch() block.timestamp <= nextEpoch");
        amountRedeemable = IERC20(stablecoin).balanceOf(address(this));
        currentEpoch = block.timestamp;
        nextEpoch = block.timestamp + 30 days;
        redemptionsAllowed = redemptionsRequested + redemptionsUnclaimed;
        redemptionsUnclaimed = redemptionsAllowed;
        redemptionsRequested = 0;
        amountRedeemableQueued = 0;
    }

    // todo: check if defaultsToAccountFor should be substracted
    // from protocol defaults (unresolved default bad for stSTT in the long run)

    /// @notice Redeem stablecoins by burning staked $zJTT tranche tokens.
    function redeemJunior() external {
        require(juniorBalances[_msgSender()] > 0, "OCR_Modular::redeemJunior() juniorBalances[_msgSender] == 0");
        require(
            juniorRedemptionRequestedOn[_msgSender()] < currentEpoch,
            "OCR_Modular::redeemJunior() juniorRedemptionRequestedOn[_msgSender()] >= currentEpoch"
        );
        require(amountRedeemable > 0, "OCR_Modular::redeemJunior() amountRedeemable == 0");

        (,uint256 aJTT) = OCR_IZivoeGlobals(GBL).adjustedSupplies();
        uint256 redeemablePreDefault;

        if (OCR_IZivoeGlobals(GBL).standardize(amountRedeemable, stablecoin) > redemptionsAllowed) {
            redeemablePreDefault = juniorBalances[_msgSender()];
        } else {
            redeemablePreDefault =
            (OCR_IZivoeGlobals(GBL).standardize(amountRedeemable, stablecoin) * juniorBalances[_msgSender()]) / 
            redemptionsAllowed;
        }

        uint256 defaultsToAccountFor = redeemablePreDefault - 
        ((redeemablePreDefault * aJTT) / IERC20(OCR_IZivoeGlobals(GBL).zJTT()).totalSupply());

        // decrease account balance of zJTT tokens
        juniorBalances[_msgSender()] -= redeemablePreDefault;

        // decrease amount of unclaimed withdraw requests
        redemptionsUnclaimed -= redeemablePreDefault;

        // substract the defaults from redeemable amount
        uint256 redeemable = redeemablePreDefault - defaultsToAccountFor;

        // set correct amount of decimals if "stablecoin" has less than 18 decimals
        if (IERC20Metadata(stablecoin).decimals() < 18) {
            redeemable /= 10 ** (18 - IERC20Metadata(stablecoin).decimals());
        }

        // calculate the redemption fee
        uint256 fee = (redeemable * redemptionFee) / BIPS;

        emit RedeemedJunior(_msgSender(), redeemable, fee, defaultsToAccountFor);

        // transfer stablecoins to account
        IERC20(stablecoin).safeTransfer(_msgSender(), redeemable - fee);

        // transfer fee to owner()
        IERC20(stablecoin).safeTransfer(owner(), fee);

        // burn Junior tranche tokens
        OCR_IZivoeGlobals(OCR_IZivoeGlobals(GBL).zJTT()).burn(redeemablePreDefault);
    }

    /// @notice This function will enable the redemption for senior tranche tokens.
    function redeemSenior() external {
        require(seniorBalances[_msgSender()] > 0, "OCR_Modular::redeemSenior() seniorBalances[_msgSender] == 0");
        require(
            seniorRedemptionRequestedOn[_msgSender()] < currentEpoch, 
            "OCR_Modular::redeemSenior() seniorRedemptionRequestedOn[_msgSender()] >= currentEpoch"
        );
        require(amountRedeemable > 0, "OCR_Modular::redeemJunior() amountRedeemable == 0");

        (uint256 aSTT,) = OCR_IZivoeGlobals(GBL).adjustedSupplies();
        uint256 redeemablePreDefault;

        if (OCR_IZivoeGlobals(GBL).standardize(amountRedeemable, stablecoin) > redemptionsAllowed) {
            redeemablePreDefault = seniorBalances[_msgSender()];
        } else {
            redeemablePreDefault =
            (OCR_IZivoeGlobals(GBL).standardize(amountRedeemable, stablecoin) * seniorBalances[_msgSender()]) / 
            redemptionsAllowed;
        }
        
        uint256 defaultsToAccountFor = redeemablePreDefault - 
        ((redeemablePreDefault * aSTT) / IERC20(OCR_IZivoeGlobals(GBL).zSTT()).totalSupply());

        // decrease account balance of zSTT tokens
        seniorBalances[_msgSender()] -= redeemablePreDefault;

        // decrease amount of unclaimed withdraw requests
        redemptionsUnclaimed -= redeemablePreDefault;
        
        // substract the defaults from redeemable amount
        uint256 redeemable = redeemablePreDefault - defaultsToAccountFor;

        // set correct amount of decimals if "stablecoin" has less than 18 decimals
        if (IERC20Metadata(stablecoin).decimals() < 18) {
            redeemable /= 10 ** (18 - IERC20Metadata(stablecoin).decimals());
        }

        // calculate the redemption fee
        uint256 fee = (redeemable * redemptionFee) / BIPS;

        emit RedeemedSenior(_msgSender(), redeemable, fee, defaultsToAccountFor);

        // transfer stablecoins to account
        IERC20(stablecoin).safeTransfer(_msgSender(), redeemable - fee);

        // transfer fee to owner()
        IERC20(stablecoin).safeTransfer(owner(), fee);

        // burn Senior tranche tokens
        OCR_IZivoeGlobals(OCR_IZivoeGlobals(GBL).zSTT()).burn(redeemablePreDefault);
    }

}