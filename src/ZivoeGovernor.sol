// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./OpenZeppelin/Governance/Governor.sol";
import "./OpenZeppelin/Governance/GovernorSettings.sol";
import "./OpenZeppelin/Governance/GovernorCountingSimple.sol";
import "./OpenZeppelin/Governance/GovernorVotes.sol";
import "./OpenZeppelin/Governance/GovernorVotesQuorumFraction.sol";
import "./OpenZeppelin/Governance/GovernorTimelockControl.sol";

contract ZivoeGovernor is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction, GovernorTimelockControl {
    
    // -----------------
    //    Constructor
    // -----------------

    constructor(IVotes _token, TimelockController _timelock)
        Governor("ZivoeGovernor")
        GovernorSettings(1, 45818, 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(10)
        GovernorTimelockControl(_timelock)
    { }


    // TODO: Consider event logs here for specific actions / conversions (or verify via inherited contracts proper events exist, they should).

    // ---------------
    //    Functions
    // ---------------

    function votingDelay() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber) public view override(IGovernor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets, 
        uint256[] memory values, 
        bytes[] memory calldatas, 
        string memory description
    )
        public
        override(Governor, IGovernor)
        returns (uint256)
    {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function _execute(
        uint256 proposalId, 
        address[] memory targets, 
        uint256[] memory values, 
        bytes[] memory calldatas, 
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
    {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets, 
        uint256[] memory values, 
        bytes[] memory calldatas, 
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}