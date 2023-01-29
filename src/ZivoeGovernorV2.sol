// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./libraries/ZivoeGovernorTimelockControl.sol";
import "./libraries/ZivoeTimelockController.sol";

import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorSettings.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

contract ZivoeGovernor is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction, ZivoeGovernorTimelockControl {
    
    // -----------------
    //    Constructor
    // -----------------

    constructor(IVotes _token, ZivoeTimelockController _timelock)
        Governor("ZivoeGovernor")
        GovernorSettings(1, 45818, 125000 ether)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(10)
        ZivoeGovernorTimelockControl(_timelock)
    { }



    // ---------------
    //    Functions
    // ---------------

    /// @dev Utilize the ZivoeGovernorTimelockControl contract which supports "Queued" state.
    function state(uint256 proposalId) public view override(Governor, ZivoeGovernorTimelockControl) returns (ProposalState) {
        return ZivoeGovernorTimelockControl.state(proposalId);
    }

    /// @dev Utilize the GovernorSettings contract which defines _proposalThreshold.
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return GovernorSettings.proposalThreshold();
    }

    /// @dev Utilize the ZivoeGovernorTimelockControl contract which defines _executor as the TimelockController.
    function _executor() internal view override(Governor, ZivoeGovernorTimelockControl) returns (address) {
        return ZivoeGovernorTimelockControl._executor();
    }

    /// @dev Utilize the ZivoeGovernorTimelockControl contract which defines supportsInterface at highest-level and handles inherited contracts.
    function supportsInterface(bytes4 interfaceId) public view override(Governor, ZivoeGovernorTimelockControl) returns (bool) {
        return ZivoeGovernorTimelockControl.supportsInterface(interfaceId);
    }

    /// @dev Utilize the ZivoeGovernorTimelockControl contract which supports TimelockController.
    function _execute(
        uint256 proposalId, 
        address[] memory targets, 
        uint256[] memory values, 
        bytes[] memory calldatas, 
        bytes32 descriptionHash
    )
        internal
        override(Governor, ZivoeGovernorTimelockControl)
    {
        ZivoeGovernorTimelockControl._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @dev Utilize the ZivoeGovernorTimelockControl contract which supports TimelockController.
    function _cancel(
        address[] memory targets, 
        uint256[] memory values, 
        bytes[] memory calldatas, 
        bytes32 descriptionHash
    )
        internal
        override(Governor, ZivoeGovernorTimelockControl)
        returns (uint256)
    {
        return ZivoeGovernorTimelockControl._cancel(targets, values, calldatas, descriptionHash);
    }
}