// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

import { IZivoeGBL } from "./interfaces/InterfacesAggregated.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { SafeMath } from "./OpenZeppelin/SafeMath.sol";
import { Math } from "./OpenZeppelin/Math.sol";
import { ReentrancyGuard } from "./OpenZeppelin/ReentrancyGuard.sol";

contract MultiRewardsVesting is ReentrancyGuard {

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

    // TODO: Refactor NatSpec below to @dev tags on corresponding line.
    /// @param startingUnix     The block.timestamp at which tokens will start vesting.
    /// @param cliffUnix        The block.timestamp at which tokens are first claimable.
    /// @param endingUnix       The block.timestamp at which tokens will stop vesting (finished).
    /// @param totalVesting     The total amount to vest.
    /// @param totalWithdrawn   The total amount withdrawn so far.
    /// @param vestingPerSecond The amount of vestingToken that vests per second.
    struct VestingSchedule {
        uint256 startingUnix;
        uint256 cliffUnix;
        uint256 endingUnix;
        uint256 totalVesting;
        uint256 totalWithdrawn;
        uint256 vestingPerSecond;
        bool revokable;
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

    // TODO: Refactor Governance instantiation, and transfer (?) - possibly not needed here, verify Governance.

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
    event RewardsDurationUpdated(address token, uint256 newDuration);

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
    function addReward(address _rewardsToken,uint256 _rewardsDuration) external {
        require(_rewardsToken != IZivoeGBL(GBL).ZVE());
        require(msg.sender == IZivoeGBL(GBL).ZVL());
        require(rewardData[_rewardsToken].rewardsDuration == 0);
        require(rewardTokens.length < 7);
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
    }

    // TODO: NatSpec
    function depositReward(address _rewardsToken, uint256 reward) external updateReward(address(0)) {

        // TODO: Consider attack vector(s) by removing below require() statement.
        // require(rewardData[_rewardsToken].rewardsDistributor == msg.sender);
        
        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        IERC20(_rewardsToken).safeTransferFrom(msg.sender, address(this), reward);

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
        getReward();
    }

    /// @notice Ends vesting schedule for a given account (if revokable).
    /// @dev    Only callable by ZVL.
    /// @param  account The acount to revoke a vesting schedule for.
    function revoke(address account) external updateReward(account) {
        require(msg.sender == IZivoeGBL(GBL).ZVL());
        require(vestingScheduleSet[account], "MultiRewardsVesting.sol::revoke() vesting schedule has not been set");
        require(vestingScheduleOf[account].revokable, "MultiRewardsVesting.sol::revoke() vesting schedule is not revokable");
        
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
    function vest(address account, uint256 daysToCliff, uint256 daysToVest, uint256 amountToVest, bool revokable) external {
        require(msg.sender == IZivoeGBL(GBL).ZVL());
        require(!vestingScheduleSet[account], "MultiRewardsVesting.sol::vest() vesting schedule has already been set");
        require(
            IERC20(vestingToken).balanceOf(address(this)) - vestingTokenAllocated >= amountToVest, 
            "MultiRewardsVesting.sol::vest() tokensNotAllocated < amountToVest"
        );
        require(daysToCliff <= daysToVest, "MultiRewardsVesting.sol::vest() vesting schedule has already been set");
        
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
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Staked(account, amount);
    }

    // TODO: NatSpec
    function getReward() public nonReentrant updateReward(msg.sender) {
        for (uint i; i < rewardTokens.length; i++) { getRewardAt(i); }
    }
    
    // TODO: NatSpec
    function getRewardAt(uint256 index) public updateReward(msg.sender) {
        address _rewardsToken = rewardTokens[index];
        uint256 reward = rewards[msg.sender][_rewardsToken];
        if (reward > 0) {
            rewards[msg.sender][_rewardsToken] = 0;
            IERC20(_rewardsToken).safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, _rewardsToken, reward);
        }
    }

    // TODO: NatSpec
    function withdraw() public nonReentrant updateReward(msg.sender) {

        uint256 amount = amountWithdrawable(msg.sender);

        require(amount > 0, "Cannot withdraw 0");
        
        vestingScheduleOf[msg.sender].totalWithdrawn += amount;
        vestingTokenAllocated -= amount;

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

}
