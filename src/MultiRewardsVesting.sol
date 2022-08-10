// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

import "./OpenZeppelin/OwnableGovernance.sol";

library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * This test is non-exhaustive, and there may be false-negatives: during the
     * execution of a contract's constructor, its address will be reported as
     * not containing a contract.
     *
     * > It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor () {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "ReentrancyGuard: reentrant call");
    }
}


library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves.

        // A Solidity high level call has three parts:
        //  1. The target address is checked to verify it contains contract code
        //  2. The call itself is made, and success asserted
        //  3. The return value is decoded, which in turn checks the size of the returned data.
        // solhint-disable-next-line max-line-length
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

import { IZivoeGBL } from "./interfaces/InterfacesAggregated.sol";

contract MultiRewardsVesting is ReentrancyGuard, OwnableGovernance {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    struct Reward {
        address rewardsDistributor;
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    IERC20 public stakingToken;

    mapping(address => Reward) public rewardData;

    address[] public rewardTokens;

    // user -> reward token -> amount
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;

    uint256 private _totalSupply;
    
    mapping(address => uint256) private _balances;

    // ---------------
    // State Variables
    // ---------------

    address public GBL; /// @notice Zivoe globals.

    address public vestingToken;    /// @notice The token vesting, in this case ZivoeToken.sol ($ZVE).

    /// @notice The amount of vestingToken currently allocated.
    /// @dev    This variable is used to calculate amount of vestingToken that HAS NOT been allocated yet.
    ///         IERC20(vestingToken).balanceOf(address(this)) - vestingTokenAllocated = amountNotAllocatedYet
    uint256 public vestingTokenAllocated;

    mapping(address => bool) public vestingScheduleSet; /// @notice Tracks if a wallet has been assigned a schedule.

    mapping(address => VestingSchedule) public vestingScheduleOf;  /// @notice Tracks the vesting schedule of accounts.

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

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _stakingToken,
        address _GBL
    ) {
        stakingToken = IERC20(_stakingToken);
        vestingToken = _stakingToken;
        GBL = _GBL;
        transferOwnershipOnce(IZivoeGBL(_GBL).ZVL());
    }

    function addReward(
        address _rewardsToken,
        address _rewardsDistributor,
        uint256 _rewardsDuration
    ) public onlyGovernance {
        require(rewardData[_rewardsToken].rewardsDuration == 0);
        require(rewardTokens.length < 7);
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable(address _rewardsToken) public view returns (uint256) {
        return Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

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

    function earned(address account, address _rewardsToken) public view returns (uint256) {
        return _balances[account].mul(rewardPerToken(_rewardsToken).sub(
            userRewardPerTokenPaid[account][_rewardsToken])
        ).div(1e18).add(rewards[account][_rewardsToken]);
    }

    function getRewardForDuration(address _rewardsToken) external view returns (uint256) {
        return rewardData[_rewardsToken].rewardRate.mul(rewardData[_rewardsToken].rewardsDuration);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    // TODO: Consider attack vector(s) of this function.
    // function setRewardsDistributor(address _rewardsToken, address _rewardsDistributor) external onlyGovernance {
    //     rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
    // }

    /// @notice Sets the vestingSchedule for an account.
    /// @param  account The user vesting $ZVE.
    /// @param  daysToCliff The number of days before vesting is claimable (a.k.a. cliff period).
    /// @param  daysToVest The number of days for the entire vesting period, from beginning to end.
    /// @param  amountToVest The amount of tokens being vested.
    /// @param  revokable If the vested amount can be revoked.
    function vest(address account, uint256 daysToCliff, uint256 daysToVest, uint256 amountToVest, bool revokable) public onlyGovernance {
        require(!vestingScheduleSet[account], "MultiRewardsVesting.sol::vest() vesting schedule has already been set");
        require(IERC20(vestingToken).balanceOf(address(this)) - vestingTokenAllocated >= amountToVest, "ZivoeVesting.sol::vest() tokensNotAllocated < amountToVest");
        require(daysToCliff <= daysToVest, "MultiRewardsVesting.sol::vest() vesting schedule has already been set");
        
        emit VestingScheduleAdded(account, amountToVest);

        // TODO: Consider overflow/overlap of existing $ZVE within this account as it relates to vest and _stake() accounting.

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

    /// @notice Ends vesting schedule for a given account (if revokable).
    /// @dev    Only callable by ZVL.
    /// @param  account The acount to revoke a vesting schedule for.
    function revoke(address account) public onlyGovernance updateReward(account) {
        require(vestingScheduleSet[account], "MultiRewardsVesting.sol::revoke() vesting schedule has not been set");
        require(vestingScheduleOf[account].revokable, "MultiRewardsVesting.sol::revoke() vesting schedule is not revokable");
        
        uint256 amountRevoked;
        uint256 amountRetained;
        emit VestingScheduleRevoked(account, amountRevoked, amountRetained);

        // vestingTokenAllocated -= amountRevoked;
        // vestingScheduleOf[account].revokable = false;
        // _totalSupply = _totalSupply.sub(amountRevoked);
        // _balances[msg.sender] = _balances[msg.sender].sub(amountRevoked);
        
        // ??? 
        
        // vestingScheduleOf[account].startingUnix = block.timestamp;
        // vestingScheduleOf[account].cliffUnix = block.timestamp + daysToCliff * 1 days;
        // vestingScheduleOf[account].endingUnix = block.timestamp;
        // vestingScheduleOf[account].totalVesting = amountRetained;
        // vestingScheduleOf[account].vestingPerSecond = amountToVest / (daysToVest * 1 days);
        // vestingScheduleOf[account].revokable = revokable;
    }

    function withdraw() public nonReentrant updateReward(msg.sender) {

        uint256 amount = amountWithdrawable(msg.sender);

        require(amount > 0, "Cannot withdraw 0");
        require(_totalSupply.sub(amount) > vestingScheduleOf[msg.sender].totalVesting - vestingScheduleOf[msg.sender].totalWithdrawn);
        
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);

        // vestingTokenAllocated -= amount;

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        for (uint i; i < rewardTokens.length; i++) {
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[msg.sender][_rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][_rewardsToken] = 0;
                IERC20(_rewardsToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, _rewardsToken, reward);
            }
        }
    }

    function exit() external {
        withdraw();
        getReward();
    }
    
    function viewSchedule(
        address account
    ) public view returns(
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

    /// @notice Returns the amount of $ZVE tokens a user can withdraw.
    /// @param  account The account to be withdrawn from.
    function amountWithdrawable(address account) public view returns(uint256) {
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

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(address _rewardsToken, uint256 reward) external updateReward(address(0)) {

        require(rewardData[_rewardsToken].rewardsDistributor == msg.sender);
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

    function setRewardsDuration(address _rewardsToken, uint256 _rewardsDuration) external {
        require(
            block.timestamp > rewardData[_rewardsToken].periodFinish,
            "Reward period still active"
        );
        require(rewardData[_rewardsToken].rewardsDistributor == msg.sender);
        require(_rewardsDuration > 0, "Reward duration must be non-zero");
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(_rewardsToken, rewardData[_rewardsToken].rewardsDuration);
    }

    /* ========== MODIFIERS ========== */

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

    /* ========== EVENTS ========== */

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

}
