// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";

import { IZivoeGBL } from "./interfaces/InterfacesAggregated.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { SafeMath } from "./OpenZeppelin/SafeMath.sol";
import { Math } from "./OpenZeppelin/Math.sol";
import { ReentrancyGuard } from "./OpenZeppelin/ReentrancyGuard.sol";

contract ZivoeRewards is ReentrancyGuard, Ownable {

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

    address public immutable GBL;      /// @dev Zivoe globals contract.

    // TODO: NatSpec
    address[] public rewardTokens;

    // TODO: NatSpec
    uint256 private _totalSupply;

    // TODO: NatSpec
    mapping(address => Reward) public rewardData;

    mapping(address => mapping(address => uint256)) public rewards;                 /// The order is account -> rewardAsset -> amount.
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;  /// The order is account -> rewardAsset -> amount.

    // TODO: NatSpec
    mapping(address => uint256) private _balances;

    // TODO: NatSpec
    IERC20 public stakingToken;



    // -----------------
    //    Constructor
    // -----------------

    // TODO: NatSpec
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

    // TODO: NatSpec
    // TODO: Consider carefully other event logs to expose here.

    event RewardAdded(uint256 reward);

    event Staked(address indexed user, uint256 amount);

    event Withdrawn(address indexed user, uint256 amount);

    event RewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);



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
    function addReward(address _rewardsToken, uint256 _rewardsDuration) external onlyOwner {
        require(rewardData[_rewardsToken].rewardsDuration == 0, "ZivoeRewards::addReward() rewardData[_rewardsToken].rewardsDuration != 0");
        require(rewardTokens.length < 10, "ZivoeRewards::addReward() rewardTokens.length >= 10");
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
        withdraw(_balances[_msgSender()]);
        getRewards();
    }

    // TODO: NatSpec
    function stake(uint256 amount) external nonReentrant updateReward(_msgSender()) {
        require(amount > 0, "ZivoeRewards::addReward() amount == 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[_msgSender()] = _balances[_msgSender()].add(amount);
        stakingToken.safeTransferFrom(_msgSender(), address(this), amount);
        emit Staked(_msgSender(), amount);
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
    function withdraw(uint256 amount) public nonReentrant updateReward(_msgSender()) {
        require(amount > 0, "ZivoeRewards::addReward() amount == 0");
        _totalSupply = _totalSupply.sub(amount);
        _balances[_msgSender()] = _balances[_msgSender()].sub(amount);
        stakingToken.safeTransfer(_msgSender(), amount);
        emit Withdrawn(_msgSender(), amount);
    }

}
