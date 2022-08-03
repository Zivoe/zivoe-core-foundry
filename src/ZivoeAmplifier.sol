// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Context.sol";

import { IERC20 } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract handles the accounting and state management for "amplification" within the Zivoe protocol.
///         The term "amplification" indicates how much voting power an individual is given based on having tokens locked in other contracts.
///         This amplified voting power value is consumed by <Governor.sol> to conduct on-chain proposals and vote tallying.
contract ZivoeAmplifier is Context {
    
    // ---------------
    // State Variables
    // ---------------

    address public ZVE; /// @notice The ZivoeToken.sol contract address.

    mapping(address => mapping(address => uint)) private _dispersedAmplification;  /// @notice Tracks amplification "disperesed" by an account to others.

    mapping(address => uint) private _amplification;  /// @notice Tracks "net" amplification of an individual account.

    mapping(address => bool) private _whitelistedAmplifiers; /// @notice Tracks whitelisted amplifier contracts.



    // -----------
    // Constructor
    // -----------

    /// @notice Initialize the ZivoeVotingPower.sol contract.
    /// @param  staking The $ZVE staking contract.
    /// @param  vesting The $ZVE vesting contract.
    /// @param  _ZVE The ZivoeToken.sol contract.
    constructor (
        address staking,
        address vesting,
        address _ZVE
    ) {
        _whitelistedAmplifiers[staking] = true;
        _whitelistedAmplifiers[vesting] = true;
        ZVE = _ZVE;
    }



    // ------
    // Events
    // ------

    /// @notice This event is emitted during increaseAmplification().
    /// @param  provider The account providing amplification.
    /// @param  receiver The account receiving amplification.
    /// @param  amount The increase in amplification amount.
    event AmplificationIncreased(address indexed provider, address indexed receiver, uint256 amount);

    /// @notice This event is emitted during decreaseAmplification().
    /// @param  provider The account withdrawing amplification.
    /// @param  receiver The account losing amplification.
    /// @param  amount The decrease in amplification amount.
    event AmplificationDecreased(address indexed provider, address indexed receiver, uint256 amount);



    // ---------
    // Functions
    // ---------

    /// @notice View function to expose private mapping _dispersedAmplification.
    /// @param  account The account providing amplification.
    /// @param  to The account receiving amplification.
    function dispersedAmplification(address account, address to) external view returns(uint256) {
        return _dispersedAmplification[account][to];
    }

    /// @notice View function to expose private mapping _amplification.
    /// @param  account The account to view "net" amplification of.
    function amplification(address account) external view returns(uint256) {
        return _amplification[account];
    }

    /// @notice View function to expose private mapping _whitelistedAmplifiers.
    /// @param  account The account to view whitelist status of.
    function isWhitelistedAmplifier(address account) external view returns(bool) {
        return _whitelistedAmplifiers[account];
    }
    
    /// @notice Increase amplification for an account.
    /// @dev    Only callable if _whitelistedAmplifiers[_msgSender()] == true.
    /// @param  account The account to increase amplification of.
    /// @param  amount The amount to increase amplification by.
    function increaseAmplification(address account, uint256 amount) public {
        address provider = _msgSender();
        require(_whitelistedAmplifiers[provider], "ZivoeAmplifier.sol::increaseAmplification() _msgSender() not whitelisted");
        _dispersedAmplification[provider][account] += amount;
        _amplification[account] += amount;
        emit AmplificationIncreased(provider, account, amount);
    }

    /// @notice Decrease amplification for an account.
    /// @dev    Only callable if _whitelistedAmplifiers[_msgSender()] == true.
    /// @param  account The account to decrease amplification of.
    /// @param  amount The amount to decrease amplification by.
    function decreaseAmplification(address account, uint256 amount) public {
        address provider = _msgSender();
        require(_whitelistedAmplifiers[provider], "ZivoeAmplifier.sol::increaseAmplification() _msgSender() not whitelisted");
        _dispersedAmplification[provider][account] -= amount;
        _amplification[account] -= amount;
        emit AmplificationDecreased(provider, account, amount);
    }

    /// @notice Get current voting power of an account.
    /// @param  account The account to view.
    function getVotes(address account) public view returns(uint256) {
        return _amplification[account] + IERC20(ZVE).balanceOf(account);
    }

}
