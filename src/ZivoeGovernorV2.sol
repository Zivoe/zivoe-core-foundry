// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "./libraries/ZivoeGTC.sol";
import "./libraries/ZivoeTLC.sol";

import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorSettings.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

// TODO: NatSpec here.
contract ZivoeGovernorV2 is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction, ZivoeGTC {
    
    // -----------------
    //    Constructor
    // -----------------

    constructor(IVotes _token, ZivoeTLC _timelock)
        Governor("ZivoeGovernorV2") GovernorSettings(1, 45818, 125000 ether)
        GovernorVotes(_token) GovernorVotesQuorumFraction(10) ZivoeGTC(_timelock) { }



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

    /// @dev Utilize the ZivoeGTC contract which defines _executor as the TimelockController.
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
}