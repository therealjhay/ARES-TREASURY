// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// The main interface for the ARES Treasury System.
interface IAresTreasury {

    // A single action to be executed by the treasury
    struct Action {
        address target; // The contract to call
        uint256 value;  // The amount of ETH to send
        string signature; // Function signature (if any)
        bytes data; // Extra data for the call
    }

    // A proposal contains a list of actions securely
    struct Proposal {
        uint256 id;
        address proposer;
        Action[] actions;
        uint256 createdAt;
        uint256 executeAfter; // Timestamp when it can be executed
        ProposalState state;
        bytes32 descriptionHash;
    }

    // Possible states for an action
    enum ActionState { Unqueued, Queued, Executed, Cancelled }

    // Possible states for a proposal
    enum ProposalState { None, Created, Queued, Executable, Executed, Cancelled }

    // Events to track what happens
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, bytes32 descriptionHash);
    event ProposalQueued(uint256 indexed proposalId, uint256 executeAfter);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    
    event ActionQueued(bytes32 indexed actionId, uint256 executeAfter);
    event ActionExecuted(bytes32 indexed actionId);
    event ActionCancelled(bytes32 indexed actionId);

    // Custom errors for saving gas instead of require strings
    error Ares_InvalidSignature();
    error Ares_SignatureReplayed();
    error Ares_ProposalNotCreated();
    error Ares_ProposalNotQueued();
    error Ares_ProposalNotExecutable();
    error Ares_ProposalAlreadyExecuted();
    error Ares_ProposalAlreadyQueued();
    error Ares_ProposalAlreadyCancelled();
    error Ares_RateLimitExceeded();
    error Ares_ActionFailed(uint256 index);
    error Ares_Unauthorized();
    error Ares_InsufficientBond();
    error Ares_AlreadyClaimed();
    error Ares_InvalidProof();
    error Ares_TimelockNotMet();
    error Ares_UnauthorizedExecution();
    error Ares_InvalidActionTarget();
}
