// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";

import { IERC20 } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract will escrow $ZVE and facilitate vesting.
///         This contract will vest $ZVE on a per-second basis.
///         This contract will support claiming $ZVE over-time as $ZVE vests.
///         This contract will support delegating $ZVE voting power to addresses vesting $ZVE.
contract ZivoeVesting is Ownable {

    // ---------------
    // State Variables
    // ---------------

    address public vestingToken;    /// @notice The token vesting, in this case ZivoeToken.sol ($ZVE).

    /// @notice The amount of vestingToken currently allocated.
    /// @dev    This variable is used to calculate amount of vestingToken that HAS NOT been allocated yet.
    ///         IERC20(vestingToken).balanceOf(address(this)) - vestingTokenAllocated = amountNotAllocatedYet
    uint256 public vestingTokenAllocated;

    mapping(address => bool) public vestingScheduleSet; /// @notice Tracks whether a wallet has been set with it's schedule has been set.

    mapping(address => VestingSchedule) public vestingScheduleOf;  /// @notice Tracks the vesting schedule of accounts.

    /// @param startingUnix     The block.timestamp at which tokens will start vesting.
    /// @param cliffUnix        The block.timestamp at which tokens are first claimable.
    /// @param endingUnix       The block.timestamp at which tokens will stop vesting (finished).
    /// @param totalVesting     The total amount to vest.
    /// @param totalClaimed     The total amount claimed so far.
    /// @param vestingPerSecond The amount of vestingToken that vests per second.
    struct VestingSchedule {
        uint256 startingUnix;
        uint256 cliffUnix;
        uint256 endingUnix;
        uint256 totalVesting;
        uint256 totalClaimed;
        uint256 vestingPerSecond;
    }



    // -----------
    // Constructor
    // -----------

    /// @notice Initialize the ZivoeVesting.sol contract.
    /// @param  _vestingToken  The token to vest.
    constructor (address _vestingToken) {
        vestingToken = _vestingToken;
    }



    // ------
    // Events
    // ------

    /// @notice This event is emitted during claim().
    /// @param  account The account that claimed tokens.
    /// @param  amount The amount of tokens claimed.
    event ZVEClaimed(address indexed account, uint256 amount);

    /// @notice This event is emitted during vest().
    /// @param  account The account that was given a vesting schedule.
    /// @param  amount The amount of tokens that will be vested.
    event VestingScheduleAdded(address account, uint256 amount);



    // ---------
    // Functions
    // ---------

    /// @notice Sets the vestingSchedule for an account.
    /// @param  account The user vesting $ZVE.
    /// @param  daysToCliff The number of days before vesting is claimable (a.k.a. cliff period).
    /// @param  daysToVest The number of days for the entire vesting period, from beginning to end.
    /// @param  amountToVest The amount of tokens being vested.
    function vest(address account, uint256 daysToCliff, uint256 daysToVest, uint256 amountToVest) public onlyOwner {
        require(!vestingScheduleSet[account], "ZivoeVesting.sol::vest() vesting schedule has already been set");
        require(IERC20(vestingToken).balanceOf(address(this)) - vestingTokenAllocated >= amountToVest, "ZivoeVesting.sol::vest() tokensNotAllocated < amountToVest");
        
        require(daysToCliff <= daysToVest, "ZivoeVesting.sol::vest() vesting schedule has already been set");
        
        emit VestingScheduleAdded(account, amountToVest);

        vestingScheduleSet[account] = true;
        vestingTokenAllocated += amountToVest;
        
        vestingScheduleOf[account].startingUnix = block.timestamp;
        vestingScheduleOf[account].cliffUnix = block.timestamp + daysToCliff * 1 days;
        vestingScheduleOf[account].endingUnix = block.timestamp + daysToVest * 1 days;
        vestingScheduleOf[account].totalVesting = amountToVest;
        vestingScheduleOf[account].vestingPerSecond = amountToVest / (daysToVest * 1 days);
    }

    /// @notice Claim all vested tokens.
    /// @param  account The account to claim tokens, receives the tokens.
    function claim(address account) public {
        require(vestingScheduleSet[account], "ZivoeVesting.sol::claim() no vesting schedule for account");
        uint256 claimAmount = amountClaimable(account);
        require(claimAmount > 0, "ZivoeVesting.sol::claim() no amount claimable at this time");

        emit ZVEClaimed(account, claimAmount);
        
        vestingTokenAllocated -= claimAmount;
        vestingScheduleOf[account].totalClaimed += claimAmount;
        IERC20(vestingToken).transfer(account, claimAmount);
    }

    /// @notice Returns the amount of $ZVE tokens a user can claim.
    /// @param  account The user with a claim for $ZVE.
    function amountClaimable(address account) public view returns(uint256) {
        if (block.timestamp < vestingScheduleOf[account].cliffUnix) {
            return 0;
        }
        if (block.timestamp >= vestingScheduleOf[account].cliffUnix && block.timestamp < vestingScheduleOf[account].endingUnix) {
            return (
                vestingScheduleOf[account].vestingPerSecond * (block.timestamp - vestingScheduleOf[account].startingUnix)
            ) - vestingScheduleOf[account].totalClaimed;
        }
        else if (block.timestamp >= vestingScheduleOf[account].endingUnix) {
            return vestingScheduleOf[account].totalVesting - vestingScheduleOf[account].totalClaimed;
        }
        else {
            return 0;
        }
    }

}
