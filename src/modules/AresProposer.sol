// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAresProposer} from "../interfaces/IAresProposer.sol";
import {EIP712Signer} from "../libraries/EIP712Signer.sol";
import {IAresTimelock} from "../interfaces/IAresTimelock.sol";

contract AresProposer is IAresProposer {
    // Unique identifier for signatures on this specific contract
    bytes32 public immutable DOMAIN_SEPARATOR;
    // The timelock contract where approved proposals go to wait
    IAresTimelock public immutable timelock;

    // Users must lock up 0.1 ETH to create a proposal (prevents spam)
    uint256 public constant PROPOSAL_BOND = 0.1 ether;

    // Tracks total proposals created
    uint256 public totalProposalsCreated;
    // Looks up a proposal by its ID number
    mapping(uint256 => Proposal) public proposals;
    // Keeps track of how many proposals a user has made (prevents signature reuse)
    mapping(address => uint256) public nonces;

    // Runs once when deployed
    constructor(address _timelock) {
        if (_timelock == address(0)) revert Ares_Unauthorized();
        timelock = IAresTimelock(_timelock);
        // Setup signature requirements
        DOMAIN_SEPARATOR = EIP712Signer.getDomainSeparator("ARES Proposal", "1", address(this));
    }

    // Creates a new proposal. The user must send ETH (the bond) to call this.
    function createProposal(
        address proposer,
        Action[] memory actions,
        bytes32 descriptionHash,
        bytes memory signature
    ) external payable returns (uint256 proposalId) {
        // Stop if they didn't send enough ETH as a bond
        if (msg.value < PROPOSAL_BOND) revert Ares_InsufficientBond();

        // Get the current nonce for the proposer to verify their signature
        uint256 nonce = nonces[proposer];

        // Hash the actual actions to securely pack them into the signature
        bytes32 actionsHash = keccak256(abi.encode(actions));
        bytes32 digest = EIP712Signer.getProposalHash(
            DOMAIN_SEPARATOR, proposer, nonce, descriptionHash, actionsHash
        );

        // Check if the signature is valid
        if (!EIP712Signer.verifySignature(digest, signature, proposer)) {
            revert Ares_InvalidSignature();
        }

        // Increase their nonce so this signature can never be used again
        nonces[proposer]++;

        // Create the new proposal
        proposalId = ++totalProposalsCreated;
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = proposer;
        newProposal.createdAt = block.timestamp;
        newProposal.state = ProposalState.Created;
        newProposal.descriptionHash = descriptionHash;

        // Save all the proposed actions
        for (uint256 i = 0; i < actions.length; ++i) {
            newProposal.actions.push(actions[i]);
        }

        emit ProposalCreated(proposalId, proposer, descriptionHash);
    }

    // Sends a created proposal to the timelock so it can wait the required days before execution
    function queueProposal(uint256 proposalId, uint256 timelockDelaySeconds) external {
        Proposal storage proposal = proposals[proposalId];
        
        // Ensure it's in the correct state
        if (proposal.state != ProposalState.Created) revert Ares_ProposalNotCreated();

        bytes32 requiredPriorActionId = bytes32(0);
        
        // Send each action to the timelock's waiting room
        for (uint256 i = 0; i < proposal.actions.length; ++i) {
            Action memory action = proposal.actions[i];
            
            // Create a unique salt for this specific action in the sequence
            bytes32 salt = keccak256(abi.encode(proposalId, i));
            
            timelock.queueOperation(
                action.destinationContract,
                action.ethAmount,
                action.payloadData,
                requiredPriorActionId,
                salt,
                timelockDelaySeconds
            );
        }

        // Record when it will be ready
        proposal.executeAfter = block.timestamp + timelockDelaySeconds;
        proposal.state = ProposalState.Queued;

        emit ProposalQueued(proposalId, proposal.executeAfter);
    }

    // Finally executes a queued proposal if its waiting time is up
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        // Ensure it has been queued
        if (proposal.state != ProposalState.Queued) revert Ares_ProposalNotQueued();
        // Ensure the waiting time has actually passed
        if (block.timestamp < proposal.executeAfter) revert Ares_TimelockNotMet();

        proposal.state = ProposalState.Executed;

        // Tell the timelock to actually run the actions
        for (uint256 i = 0; i < proposal.actions.length; ++i) {
            Action memory action = proposal.actions[i];
            bytes32 salt = keccak256(abi.encode(proposalId, i));
            bytes32 requiredPriorActionId = bytes32(0);

            timelock.executeOperation{value: 0}(
                action.destinationContract,
                action.ethAmount,
                action.payloadData,
                requiredPriorActionId,
                salt
            );
        }

        // Give the proposer their ETH bond back since the proposal succeeded
        (bool success, ) = proposal.proposer.call{value: PROPOSAL_BOND}("");
        require(success, "Bond return failed");

        emit ProposalExecuted(proposalId);
    }

    // Cancels a proposal. The protocol keeps the bond to punish bad proposals!
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.state == ProposalState.Executed || proposal.state == ProposalState.Cancelled) {
            revert Ares_ProposalAlreadyCancelled();
        }

        // Only the person who made it can cancel, UNLESS 14 days have passed
        if (msg.sender != proposal.proposer && block.timestamp < proposal.createdAt + 14 days) {
            revert Ares_Unauthorized();
        }

        proposal.state = ProposalState.Cancelled;

        // Remove the actions from the timelock queue
        for (uint256 i = 0; i < proposal.actions.length; ++i) {
            Action memory action = proposal.actions[i];
            bytes32 salt = keccak256(abi.encode(proposalId, i));
            bytes32 requiredPriorActionId = bytes32(0);
            
            bytes32 operationId = timelock.getOperationId(action.destinationContract, action.ethAmount, action.payloadData, requiredPriorActionId, salt);
            timelock.cancelOperation(operationId);
        }

        emit ProposalCancelled(proposalId);
    }
}
