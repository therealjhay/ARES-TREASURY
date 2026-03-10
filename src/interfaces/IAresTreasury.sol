// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAresTreasury
 * @notice Core interface for the ARES Treasury System.
 */
interface IAresTreasury {
    // --- Structs ---

    struct Action {
        address target;
        uint256 value;
        string signature;
        bytes data;
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

    enum ActionState {
        Unqueued,
        Queued,
        Executed,
        Cancelled
    }

    enum ProposalState {
        None,
        Created,
        Queued,
        Executable, // Time delay has passed
        Executed,
        Cancelled
    }

    // --- Events ---

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, bytes32 descriptionHash);
    event ProposalQueued(uint256 indexed proposalId, uint256 executeAfter);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    event ActionQueued(bytes32 indexed actionId, uint256 executeAfter);
    event ActionExecuted(bytes32 indexed actionId);
    event ActionCancelled(bytes32 indexed actionId);

    // --- Errors ---

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
