// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAresTreasury} from "../interfaces/IAresTreasury.sol";
import {EIP712Signer} from "../libraries/EIP712Signer.sol";
import {AresTimelock} from "./AresTimelock.sol";

/**
 * @title AresProposer
 * @notice Manages proposal lifecycle natively protecting against griefing and replay.
 */
contract AresProposer is IAresTreasury {
    bytes32 public immutable DOMAIN_SEPARATOR;
    AresTimelock public immutable timelock;

    uint256 public constant PROPOSAL_BOND = 0.1 ether;

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public nonces;

    constructor(address _timelock) {
        if (_timelock == address(0)) revert Ares_Unauthorized();
        timelock = AresTimelock(_timelock);
        DOMAIN_SEPARATOR = EIP712Signer.getDomainSeparator("ARES Proposal", "1", address(this));
    }

    /**
     * @notice Creates a proposal, requires a bond to prevent griefing.
     */
    function createProposal(
        address proposer,
        Action[] memory actions,
        bytes32 descriptionHash,
        bytes memory signature
    ) external payable returns (uint256 proposalId) {
        if (msg.value < PROPOSAL_BOND) revert Ares_InsufficientBond();

        uint256 nonce = nonces[proposer];

        bytes32 actionsHash = keccak256(abi.encode(actions));
        bytes32 digest = EIP712Signer.getProposalHash(
            DOMAIN_SEPARATOR, proposer, nonce, descriptionHash, actionsHash
        );

        if (!EIP712Signer.verifySignature(digest, signature, proposer)) {
            revert Ares_InvalidSignature();
        }

        nonces[proposer]++;

        proposalId = ++proposalCount;
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = proposer;
        newProposal.createdAt = block.timestamp;
        newProposal.state = ProposalState.Created;
        newProposal.descriptionHash = descriptionHash;

        for (uint256 i = 0; i < actions.length; ++i) {
            newProposal.actions.push(actions[i]);
        }

        emit ProposalCreated(proposalId, proposer, descriptionHash);
    }

    /**
     * @notice Queues a created proposal to the timelock.
     */
    function queueProposal(uint256 proposalId, uint256 delay) external {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.state != ProposalState.Created) revert Ares_ProposalNotCreated();

        // Push actions to timelock queue
        bytes32 predecessor = bytes32(0);
        
        for (uint256 i = 0; i < proposal.actions.length; ++i) {
            Action memory action = proposal.actions[i];
            
            // Note: queueOperation expects (target, value, data, predecessor, salt, delay)
            // Salt is derived from proposal state to be unique per action index
            bytes32 salt = keccak256(abi.encode(proposalId, i));
            
            timelock.queueOperation(
                action.target,
                action.value,
                action.data,
                predecessor,
                salt,
                delay
            );
            
            // Next action requires the current action to be executed first if sequential
            // Here, we just queue them independently but could link them via predecessor.
        }

        proposal.executeAfter = block.timestamp + delay;
        proposal.state = ProposalState.Queued;

        emit ProposalQueued(proposalId, proposal.executeAfter);
    }

    /**
     * @notice Executes a queued proposal via timelock if delay passed.
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.state != ProposalState.Queued) revert Ares_ProposalNotQueued();
        if (block.timestamp < proposal.executeAfter) revert Ares_TimelockNotMet();

        proposal.state = ProposalState.Executed;

        for (uint256 i = 0; i < proposal.actions.length; ++i) {
            Action memory action = proposal.actions[i];
            bytes32 salt = keccak256(abi.encode(proposalId, i));
            
            bytes32 predecessor = bytes32(0);

            // Calls the highly protected timelock contract to safely execute
            // Need a lower level way to do this if Timelock is the initiator
            timelock.executeOperation{value: 0}(
                action.target,
                action.value,
                action.data,
                predecessor,
                salt
            );
        }

        // Return bond to proposer
        (bool success, ) = proposal.proposer.call{value: PROPOSAL_BOND}("");
        require(success, "Bond return failed");

        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancels a proposal and forfeits the bond to the protocol.
     */
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.state == ProposalState.Executed || proposal.state == ProposalState.Cancelled) {
            revert Ares_ProposalAlreadyCancelled();
        }

        // Must be cancelled by proposer or after expiration
        if (msg.sender != proposal.proposer && block.timestamp < proposal.createdAt + 14 days) {
            revert Ares_Unauthorized();
        }

        proposal.state = ProposalState.Cancelled;

        for (uint256 i = 0; i < proposal.actions.length; ++i) {
            Action memory action = proposal.actions[i];
            bytes32 salt = keccak256(abi.encode(proposalId, i));
            bytes32 predecessor = bytes32(0);
            
            bytes32 operationId = timelock.getOperationId(action.target, action.value, action.data, predecessor, salt);
            timelock.cancelOperation(operationId);
        }

        emit ProposalCancelled(proposalId);
    }
}
