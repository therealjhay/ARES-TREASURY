// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAresProposer {
    struct Action {
        address destinationContract;
        uint256 ethAmount;
        string signature;
        bytes payloadData;
    }

    struct Proposal {
        uint256 id;
        address proposer;
        Action[] actions;
        uint256 createdAt;
        uint256 executeAfter;
        ProposalState state;
        bytes32 descriptionHash;
    }

    enum ProposalState { None, Created, Queued, Executable, Executed, Cancelled }

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, bytes32 descriptionHash);
    event ProposalQueued(uint256 indexed proposalId, uint256 executeAfter);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    error Ares_InvalidSignature();
    error Ares_InsufficientBond();
    error Ares_ProposalNotCreated();
    error Ares_ProposalAlreadyCancelled();
    error Ares_ProposalNotQueued();
    error Ares_TimelockNotMet();
    error Ares_Unauthorized();

    function createProposal(
        address proposer,
        Action[] memory actions,
        bytes32 descriptionHash,
        bytes memory signature
    ) external payable returns (uint256 proposalId);

    function queueProposal(uint256 proposalId, uint256 timelockDelaySeconds) external;
    function executeProposal(uint256 proposalId) external;
    function cancelProposal(uint256 proposalId) external;
}
