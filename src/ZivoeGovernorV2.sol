// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "./libraries/ZivoeGTC.sol";
import "./libraries/ZivoeTLC.sol";

import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorSettings.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";


interface ZVG_IZivoeGlobals {
    /// @notice Returns the address of the RewardsVesting ($stZVE) vesting contract.
    function stZVE() external view returns (address);

    /// @notice Returns the address of the ZivoeRewardsVesting ($vestZVE) vesting contract.
    function vestZVE() external view returns (address);
}

interface ZVG_IZivoeRewards {
    /// @notice Returns the amount of tokens owned by "account", received when depositing via stake().
    /// @param account The account to view information of.
    /// @return amount The amount of tokens owned by "account".
    function balanceOf(address account) external view returns (uint256 amount);
}

interface ZVG_IZivoeRewardsVesting is ZVG_IZivoeRewards { }

/// @notice This contract is the governance contract.
///         This contract has the following responsibilities:
///          - Proposals are made here.
///          - Voting is conducted here.
///          - Increase voting power of stakers and vesters.
///          - Execute proposals.
///          - Interface with TimelockController (external contract) to facilitate execution.
contract ZivoeGovernorV2 is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction, ZivoeGTC {
    
    // ---------------------
    //    State Variables
    // ---------------------
    
    address public immutable GBL;   /// @dev The ZivoeGlobals contract.



    
    // -----------------
    //    Constructor
    // -----------------

    constructor(IVotes _token, ZivoeTLC _timelock, address _GBL)
        Governor("ZivoeGovernorV2") GovernorSettings(1, 45818, 125000 ether)
        GovernorVotes(_token) GovernorVotesQuorumFraction(10) ZivoeGTC(_timelock) { GBL = _GBL; }



    // ---------------
    //    Functions
    // ---------------

    /// @dev Utilize the ZivoeGTC contract which supports "Queued" state.
    function state(uint256 proposalId) public view override(Governor, ZivoeGTC) returns (ProposalState) {
        return ZivoeGTC.state(proposalId);
    }

    /// @dev Utilize the GovernorSettings contract which defines _proposalThreshold.
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return GovernorSettings.proposalThreshold();
    }

    /// @dev Utilize the ZivoeGTC contract which defines _executor as TimelockController.
    function _executor() internal view override(Governor, ZivoeGTC) returns (address) {
        return ZivoeGTC._executor();
    }

    /// @dev Utilize the ZivoeGTC contract which defines supportsInterface at highest-level and handles inherited contracts.
    function supportsInterface(bytes4 interfaceId) public view override(Governor, ZivoeGTC) returns (bool) {
        return ZivoeGTC.supportsInterface(interfaceId);
    }

    /// @dev Utilize the ZivoeGTC contract which supports TimelockController.
    function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal override(Governor, ZivoeGTC)
    {
        ZivoeGTC._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @dev Utilize the ZivoeGTC contract which supports TimelockController.
    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal override(Governor, ZivoeGTC) returns (uint256)
    {
        return ZivoeGTC._cancel(targets, values, calldatas, descriptionHash);
    }

    /// @dev Override voting weight from the token's built in snapshot mechanism, increase by $vestZVE and $stZVE balance.
    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory /*params*/
    ) internal view virtual override(Governor, GovernorVotes) returns (uint256) {
        return token.getPastVotes(account, blockNumber) + 
            ZVG_IZivoeRewardsVesting(ZVG_IZivoeGlobals(GBL).vestZVE()).balanceOf(account) +
            ZVG_IZivoeRewards(ZVG_IZivoeGlobals(GBL).stZVE()).balanceOf(account);
    }
}