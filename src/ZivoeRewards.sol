// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "./libraries/OpenZeppelin/IERC20.sol";
import "./libraries/OpenZeppelin/Math.sol";
import "./libraries/OpenZeppelin/Ownable.sol";
import "./libraries/OpenZeppelin/ReentrancyGuard.sol";
import "./libraries/OpenZeppelin/SafeERC20.sol";
import "./libraries/OpenZeppelin/SafeMath.sol";

import { IZivoeGlobals } from "./misc/InterfacesAggregated.sol";

/// @dev    This contract facilitates staking and yield distribution.
///         This contract has the following responsibilities:
///           - Allows staking and unstaking of modular "stakingToken".
///           - Allows claiming yield distributed / "deposited" to this contract.
///           - Allows multiple assets to be added as "rewardToken" for distributions.
///           - Vests rewardTokens linearly overtime to stakers.
contract ZivoeRewards is ReentrancyGuard, Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    struct Reward {
        uint256 rewardsDuration;        /// @dev How long rewards take to vest, e.g. 30 days.
        uint256 periodFinish;           /// @dev When current rewards will finish vesting.
        uint256 rewardRate;             /// @dev Rewards emitted per second.
        uint256 lastUpdateTime;         /// @dev Last time this data struct was updated.
        uint256 rewardPerTokenStored;   /// @dev Last snapshot of rewardPerToken taken.
    }

    address public immutable GBL;       /// @dev Zivoe globals contract.

    address[] public rewardTokens;      /// @dev Array of ERC20 tokens distributed as rewards (if present).

    uint256 private _totalSupply;       /// @dev Total supply of (non-transferrable) LP tokens for reards contract.

    mapping(address => Reward) public rewardData;   /// @dev Contains rewards information for each rewardToken.

    mapping(address => mapping(address => uint256)) public rewards;                 /// The order is account -> rewardAsset -> amount.
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;  /// The order is account -> rewardAsset -> amount.

    mapping(address => uint256) private _balances;  /// @dev Contains LP token balance of each user (is 1:1 ratio with amount deposited).

    IERC20 public stakingToken;         /// @dev IERC20 wrapper for the stakingToken (deposited to receive LP tokens).



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeRewards.sol contract.
    /// @param _stakingToken The ERC20 asset deposited to mint LP tokens (and returned when burning LP tokens).
    /// @param _GBL The ZivoeGlobals contract.
    constructor(
        address _stakingToken,
        address _GBL
    ) {
        stakingToken = IERC20(_stakingToken);
        GBL = _GBL;
    }



    // ------------
    //    Events
    // ------------

    /// @notice This event is emitted when addReward() is called.
    /// @param  reward The asset that's being distributed.
    event RewardAdded(address reward);

    /// @notice This event is emitted when depositReward() is called.
    /// @param  reward The asset that's being deposited.
    /// @param  amount The amout deposited.
    /// @param  depositor The _msgSender() who deposited said reward.
    event RewardDeposited(address reward, uint256 amount, address indexed depositor);

    /// @notice This event is emitted when stake() is called.
    /// @param  user The account staking "stakingToken".
    /// @param  amount The amount of  "stakingToken" staked.
    event Staked(address indexed user, uint256 amount);

    /// @notice This event is emitted when withdraw() is called.
    /// @param  user The account withdrawing "stakingToken".
    /// @param  amount The amount of "stakingToken" withdrawn.
    event Withdrawn(address indexed user, uint256 amount);

    /// @notice This event is emitted when getRewardAt() is called.
    /// @param  user The account receiving a reward.
    /// @param  rewardsToken The asset that's being distributed.
    /// @param  reward The amount of "rewardsToken" distributed.
    event RewardDistributed(address indexed user, address indexed rewardsToken, uint256 reward);

    event Log(uint256);

    // ---------------
    //    Modifiers
    // ---------------

    /// @notice This modifier ensures user rewards information is updated BEFORE mutative actions.
    /// @param account The account to update personal rewards information if account != address(0).
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

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function viewRewards(address account, address rewardAsset) external view returns (uint256) {
        return rewards[account][rewardAsset];
    }

    function viewUserRewardPerTokenPaid(address account, address rewardAsset) external view returns (uint256) {
        return userRewardPerTokenPaid[account][rewardAsset];
    }
    
    /// @notice Returns the total amount of rewards being distributed to everyone for current rewardsDuration.
    /// @param  _rewardsToken The asset that's being distributed.
    function getRewardForDuration(address _rewardsToken) external view returns (uint256) {
        return rewardData[_rewardsToken].rewardRate.mul(rewardData[_rewardsToken].rewardsDuration);
    }

    /// @notice Provides information on the rewards available for claim.
    /// @param account The account to view information of.
    /// @param _rewardsToken The asset that's being distributed.
    function earned(address account, address _rewardsToken) public view returns (uint256) {
        return _balances[account].mul(rewardPerToken(_rewardsToken).sub(
            userRewardPerTokenPaid[account][_rewardsToken])
        ).div(1e18).add(rewards[account][_rewardsToken]);
    }

    /// @notice Helper function for assessing distribution timelines.
    /// @param _rewardsToken The asset that's being distributed.
    function lastTimeRewardApplicable(address _rewardsToken) public view returns (uint256) {
        return Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    /// @notice Cumulative amount of rewards distributed per LP token.
    /// @param _rewardsToken The asset that's being distributed.
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

    /// @notice Adds a new asset as a reward to this contract.
    /// @param _rewardsToken The asset that's being distributed.
    /// @param _rewardsDuration How long rewards take to vest, e.g. 30 days (denoted in seconds).
    function addReward(address _rewardsToken, uint256 _rewardsDuration) external onlyOwner {
        require(rewardData[_rewardsToken].rewardsDuration == 0, "ZivoeRewards::addReward() rewardData[_rewardsToken].rewardsDuration != 0");
        require(rewardTokens.length < 10, "ZivoeRewards::addReward() rewardTokens.length >= 10");
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        emit RewardAdded(_rewardsToken);
    }

    /// @notice Deposits a reward to this contract for distribution.
    /// @param _rewardsToken The asset that's being distributed.
    /// @param reward The amount of the _rewardsToken to deposit.
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
        emit RewardDeposited(_rewardsToken, reward, _msgSender());
    }

    /// @notice Simultaneously calls withdraw() and getRewards() for convenience.
    function fullWithdraw() external {
        withdraw(_balances[_msgSender()]);
        getRewards();
    }

    /// @notice Stakes the specified amount of stakingToken to this contract.
    /// @param amount The amount of the _rewardsToken to deposit.
    function stake(uint256 amount) external nonReentrant updateReward(_msgSender()) {
        require(amount > 0, "ZivoeRewards::addReward() amount == 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[_msgSender()] = _balances[_msgSender()].add(amount);
        stakingToken.safeTransferFrom(_msgSender(), address(this), amount);
        emit Staked(_msgSender(), amount);
    }
    
    /// @notice Claim rewards for all possible _rewardTokens.
    function getRewards() public nonReentrant updateReward(_msgSender()) {
        for (uint i; i < rewardTokens.length; i++) { getRewardAt(i); }
    }
    
    /// @notice Claim rewards for a specific _rewardToken.
    /// @param index The index to claim, corresponds to a given index of rewardToken[].
    function getRewardAt(uint256 index) public updateReward(_msgSender()) {
        address _rewardsToken = rewardTokens[index];
        uint256 reward = rewards[_msgSender()][_rewardsToken];
        if (reward > 0) {
            rewards[_msgSender()][_rewardsToken] = 0;
            IERC20(_rewardsToken).safeTransfer(_msgSender(), reward);
            emit RewardDistributed(_msgSender(), _rewardsToken, reward);
        }
    }

    /// @notice Withdraws the specified amount of stakingToken from this contract.
    /// @param amount The amount of the _rewardsToken to withdraw.
    function withdraw(uint256 amount) public nonReentrant updateReward(_msgSender()) {
        require(amount > 0, "ZivoeRewards::addReward() amount == 0");
        _totalSupply = _totalSupply.sub(amount);
        _balances[_msgSender()] = _balances[_msgSender()].sub(amount);
        stakingToken.safeTransfer(_msgSender(), amount);
        emit Withdrawn(_msgSender(), amount);
    }

}
