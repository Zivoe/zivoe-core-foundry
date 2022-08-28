// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";

import { IZivoeGlobals } from "./interfaces/InterfacesAggregated.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { SafeMath } from "./OpenZeppelin/SafeMath.sol";
import { Math } from "./OpenZeppelin/Math.sol";
import { ReentrancyGuard } from "./OpenZeppelin/ReentrancyGuard.sol";

contract ZivoeRewardsVesting is ReentrancyGuard, Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    // TODO: NatSpec
    struct Reward {
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    struct VestingSchedule {
        uint256 startingUnix;       /// @dev The block.timestamp at which tokens will start vesting.
        uint256 cliffUnix;          /// @dev The block.timestamp at which tokens are first claimable.
        uint256 endingUnix;         /// @dev The block.timestamp at which tokens will stop vesting (finished).
        uint256 totalVesting;       /// @dev The total amount to vest.
        uint256 totalWithdrawn;     /// @dev The total amount withdrawn so far.
        uint256 vestingPerSecond;   /// @dev The amount of vestingToken that vests per second.
        bool revokable;             /// @dev Whether or not this vesting schedule can be revoked.
    }

    address public vestingToken;    /// The token vesting, in this case ZivoeToken.sol ($ZVE).
    
    address public immutable GBL;   /// Zivoe globals contract.

    address[] public rewardTokens;  /// The rewards tokens.
    
    uint256 public vestingTokenAllocated;   /// The amount of vestingToken currently allocated.

    // TODO: NatSpec
    uint256 private _totalSupply;

    // TODO: NatSpec
    IERC20 public stakingToken;

    mapping(address => bool) public vestingScheduleSet; /// Tracks if a wallet has been assigned a schedule.

    mapping(address => VestingSchedule) public vestingScheduleOf;  /// Tracks the vesting schedule of accounts.

    // TODO: NatSpec
    mapping(address => Reward) public rewardData;

    // TODO: NatSpec
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) public rewards;                 /// The order is account -> rewardAsset -> amount.
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;  /// The order is account -> rewardAsset -> amount.

    

    // -----------------
    //    Constructor
    // -----------------

    // TODO: NatSpec
    constructor(
        address _stakingToken,
        address _GBL
    ) {
        stakingToken = IERC20(_stakingToken);
        vestingToken = _stakingToken;
        GBL = _GBL;
    }



    // ------------
    //    Events
    // ------------

    // TODO: Consider carefully other event logs to expose here.
    // TODO: NatSpec

    event RewardAdded(uint256 reward);

    event Staked(address indexed user, uint256 amount);

    event Withdrawn(address indexed user, uint256 amount);

    event RewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);

    /// @notice This event is emitted during vest().
    /// @param  account The account that was given a vesting schedule.
    /// @param  amount The amount of tokens that will be vested.
    event VestingScheduleAdded(address account, uint256 amount);

    /// @notice This event is emitted during revoke().
    /// @param  account The account that was revoked a vesting schedule.
    /// @param  amountRevoked The amount of tokens revoked.
    /// @param  amountRetained The amount of tokens retained within this staking contract (that had already vested prior).
    event VestingScheduleRevoked(address account, uint256 amountRevoked, uint256 amountRetained);



    // ---------------
    //    Modifiers
    // ---------------

    // TODO: NatSpec
    modifier updateReward(address account) {
        for (uint i; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = rewardData[token].rewardPerTokenStored;
            }
        }
        _;
    }



    // ---------------
    //    Functions
    // ---------------

    // TODO: Consider carefully other view functions to expose here.

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    // TODO: NatSpec
    function getRewardForDuration(address _rewardsToken) external view returns (uint256) {
        return rewardData[_rewardsToken].rewardRate.mul(rewardData[_rewardsToken].rewardsDuration);
    }

    /// @notice Returns the amount of $ZVE tokens a user can withdraw.
    /// @param  account The account to be withdrawn from.
    function amountWithdrawable(address account) public view returns (uint256) {
        if (block.timestamp < vestingScheduleOf[account].cliffUnix) {
            return 0;
        }
        if (block.timestamp >= vestingScheduleOf[account].cliffUnix && block.timestamp < vestingScheduleOf[account].endingUnix) {
            return (
                vestingScheduleOf[account].vestingPerSecond * (block.timestamp - vestingScheduleOf[account].startingUnix)
            ) - vestingScheduleOf[account].totalWithdrawn;
        }
        else if (block.timestamp >= vestingScheduleOf[account].endingUnix) {
            return vestingScheduleOf[account].totalVesting - vestingScheduleOf[account].totalWithdrawn;
        }
        else {
            return 0;
        }
    }

    // TODO: NatSpec
    function earned(address account, address _rewardsToken) public view returns (uint256) {
        return _balances[account].mul(rewardPerToken(_rewardsToken).sub(
            userRewardPerTokenPaid[account][_rewardsToken])
        ).div(1e18).add(rewards[account][_rewardsToken]);
    }

    // TODO: NatSpec
    function lastTimeRewardApplicable(address _rewardsToken) public view returns (uint256) {
        return Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    // TODO: NatSpec
    function rewardPerToken(address _rewardsToken) public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardData[_rewardsToken].rewardPerTokenStored;
        }
        return rewardData[_rewardsToken].rewardPerTokenStored.add(
            lastTimeRewardApplicable(_rewardsToken).sub(
                rewardData[_rewardsToken].lastUpdateTime
            ).mul(rewardData[_rewardsToken].rewardRate).mul(1e18).div(_totalSupply)
        );
    }
    
    // TODO: NatSpec
    function viewSchedule(address account) public view returns (
        uint256 startingUnix, 
        uint256 cliffUnix, 
        uint256 endingUnix, 
        uint256 totalVesting, 
        uint256 totalWithdrawn, 
        uint256 vestingPerSecond, 
        bool revokable
    ) {
        startingUnix = vestingScheduleOf[account].startingUnix;
        cliffUnix = vestingScheduleOf[account].cliffUnix;
        endingUnix = vestingScheduleOf[account].endingUnix;
        totalVesting = vestingScheduleOf[account].totalVesting;
        totalWithdrawn = vestingScheduleOf[account].totalWithdrawn;
        vestingPerSecond = vestingScheduleOf[account].vestingPerSecond;
        revokable = vestingScheduleOf[account].revokable;
    }

    // TODO: NatSpec
    function addReward(address _rewardsToken,uint256 _rewardsDuration) external onlyOwner {
        require(_rewardsToken != IZivoeGlobals(GBL).ZVE(), "ZivoeRewardsVesting::addReward() _rewardsToken == IZivoeGlobals(GBL).ZVE()");
        require(rewardData[_rewardsToken].rewardsDuration == 0, "ZivoeRewardsVesting::addReward() rewardData[_rewardsToken].rewardsDuration != 0");
        require(rewardTokens.length < 10, "ZivoeRewardsVesting::addReward() rewardTokens.length >= 10");
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
    }

    // TODO: NatSpec
    function depositReward(address _rewardsToken, uint256 reward) external updateReward(address(0)) {

        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        IERC20(_rewardsToken).safeTransferFrom(_msgSender(), address(this), reward);

        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate = reward.div(rewardData[_rewardsToken].rewardsDuration);
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardData[_rewardsToken].rewardRate);
            rewardData[_rewardsToken].rewardRate = reward.add(leftover).div(rewardData[_rewardsToken].rewardsDuration);
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish = block.timestamp.add(rewardData[_rewardsToken].rewardsDuration);
        emit RewardAdded(reward);
    }

    // TODO: NatSpec
    function fullWithdraw() external {
        withdraw();
        getRewards();
    }

    /// @notice Ends vesting schedule for a given account (if revokable).
    /// @param  account The acount to revoke a vesting schedule for.
    function revoke(address account) external updateReward(account) onlyOwner {
        require(vestingScheduleSet[account], "ZivoeRewardsVesting::revoke() !vestingScheduleSet[account]");
        require(vestingScheduleOf[account].revokable, "ZivoeRewardsVesting::revoke() !vestingScheduleOf[account].revokable");
        
        uint256 amount = amountWithdrawable(account);
        uint256 vestingAmount = vestingScheduleOf[account].totalVesting;

        vestingTokenAllocated -= vestingAmount;

        vestingScheduleOf[account].totalVesting = amount;
        vestingScheduleOf[account].totalWithdrawn += amount;
        vestingScheduleOf[account].cliffUnix = block.timestamp - 1;
        vestingScheduleOf[account].endingUnix = block.timestamp;

        _totalSupply = _totalSupply.sub(vestingAmount);
        _balances[account] = 0;
        stakingToken.safeTransfer(account, amount);

        vestingScheduleOf[account].revokable = false;

        emit VestingScheduleRevoked(account, vestingAmount - amount, amount);
    }

    /// @notice Sets the vestingSchedule for an account.
    /// @param  account The user vesting $ZVE.
    /// @param  daysToCliff The number of days before vesting is claimable (a.k.a. cliff period).
    /// @param  daysToVest The number of days for the entire vesting period, from beginning to end.
    /// @param  amountToVest The amount of tokens being vested.
    /// @param  revokable If the vested amount can be revoked.
    function vest(address account, uint256 daysToCliff, uint256 daysToVest, uint256 amountToVest, bool revokable) external onlyOwner {
        require(!vestingScheduleSet[account], "ZivoeRewardsVesting::vest() vestingScheduleSet[account]");
        require(
            IERC20(vestingToken).balanceOf(address(this)) - vestingTokenAllocated >= amountToVest, 
            "ZivoeRewardsVesting::vest() amountToVest > IERC20(vestingToken).balanceOf(address(this)) - vestingTokenAllocated"
        );
        require(daysToCliff <= daysToVest, "ZivoeRewardsVesting::vest() daysToCliff > daysToVest");
        
        emit VestingScheduleAdded(account, amountToVest);

        vestingScheduleSet[account] = true;
        vestingTokenAllocated += amountToVest;
        
        vestingScheduleOf[account].startingUnix = block.timestamp;
        vestingScheduleOf[account].cliffUnix = block.timestamp + daysToCliff * 1 days;
        vestingScheduleOf[account].endingUnix = block.timestamp + daysToVest * 1 days;
        vestingScheduleOf[account].totalVesting = amountToVest;
        vestingScheduleOf[account].vestingPerSecond = amountToVest / (daysToVest * 1 days);
        vestingScheduleOf[account].revokable = revokable;

        _stake(amountToVest, account);
    }

    function _stake(uint256 amount, address account) private nonReentrant updateReward(account) {
        require(amount > 0, "ZivoeRewardsVesting::_stake() amount == 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Staked(account, amount);
    }

    // TODO: NatSpec
    function getRewards() public nonReentrant updateReward(_msgSender()) {
        for (uint i; i < rewardTokens.length; i++) { getRewardAt(i); }
    }
    
    // TODO: NatSpec
    function getRewardAt(uint256 index) public updateReward(_msgSender()) {
        address _rewardsToken = rewardTokens[index];
        uint256 reward = rewards[_msgSender()][_rewardsToken];
        if (reward > 0) {
            rewards[_msgSender()][_rewardsToken] = 0;
            IERC20(_rewardsToken).safeTransfer(_msgSender(), reward);
            emit RewardPaid(_msgSender(), _rewardsToken, reward);
        }
    }

    // TODO: NatSpec
    function withdraw() public nonReentrant updateReward(_msgSender()) {

        uint256 amount = amountWithdrawable(_msgSender());

        require(amount > 0, "ZivoeRewardsVesting::withdraw() amountWithdrawable(_msgSender()) == 0");
        
        vestingScheduleOf[_msgSender()].totalWithdrawn += amount;
        vestingTokenAllocated -= amount;

        _totalSupply = _totalSupply.sub(amount);
        _balances[_msgSender()] = _balances[_msgSender()].sub(amount);
        stakingToken.safeTransfer(_msgSender(), amount);

        emit Withdrawn(_msgSender(), amount);
    }

}
