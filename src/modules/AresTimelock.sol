// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAresTimelock} from "../interfaces/IAresTimelock.sol";

contract AresTimelock is IAresTimelock {
    // Limits on how long something must wait
    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;
    // How long you have to execute it after the wait is over
    uint256 public constant GRACE_PERIOD = 14 days;

    // The core vault where the money actually is
    address public immutable treasuryCore;
    // The proposer contract that is allowed to send things here
    address public proposerModule;

    // Details about an action waiting in line
    struct QueuedOperation {
        uint256 executeAfter; // Timestamp it becomes ready
        bool isQueued;        // Is it currently in the waiting room?
    }

    // Looks up a queued action by its unique ID
    mapping(bytes32 => QueuedOperation) public queuedOperations;

    // Only allow the proposer contract to send things here
    modifier onlyProposer() {
        if (msg.sender != proposerModule) revert Ares_Unauthorized();
        _;
    }

    constructor(address _treasuryCore, address _proposerModule) {
        if (_treasuryCore == address(0)) revert Ares_Unauthorized();
        treasuryCore = _treasuryCore;
        proposerModule = _proposerModule;
    }

    // Creates a unique fingerprint (ID) for an action based on its contents
    function getOperationId(
        address destinationContract,
        uint256 ethAmount,
        bytes memory payloadData,
        bytes32 requiredPriorActionId,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(destinationContract, ethAmount, payloadData, requiredPriorActionId, salt));
    }

    // Adds a new action to the waiting room
    function queueOperation(
        address destinationContract,
        uint256 ethAmount,
        bytes memory payloadData,
        bytes32 requiredPriorActionId,
        bytes32 salt,
        uint256 timelockDelaySeconds
    ) external onlyProposer returns (bytes32 operationId) {
        // Check if the delay rules are followed
        if (timelockDelaySeconds < MIN_DELAY || timelockDelaySeconds > MAX_DELAY) revert Ares_TimelockNotMet();

        // Calculate the fingerprint
        operationId = getOperationId(destinationContract, ethAmount, payloadData, requiredPriorActionId, salt);

        // Don't add it twice
        if (queuedOperations[operationId].isQueued) revert Ares_ProposalAlreadyQueued();

        // Save it to the waiting room
        uint256 executeAfter = block.timestamp + timelockDelaySeconds;
        queuedOperations[operationId] = QueuedOperation({
            executeAfter: executeAfter,
            isQueued: true
        });

        emit ActionQueued(operationId, executeAfter);
    }

    // Runs the action if its waiting time has finished
    function executeOperation(
        address destinationContract,
        uint256 ethAmount,
        bytes memory payloadData,
        bytes32 requiredPriorActionId,
        bytes32 salt
    ) external payable returns (bytes memory) {
        bytes32 operationId = getOperationId(destinationContract, ethAmount, payloadData, requiredPriorActionId, salt);
        QueuedOperation memory queuedAction = queuedOperations[operationId];

        // Ensure it was actually queued
        if (!queuedAction.isQueued) revert Ares_ProposalNotQueued();
        // Ensure its wait time is over
        if (block.timestamp < queuedAction.executeAfter) revert Ares_TimelockNotMet();
        // Ensure it hasn't expired
        if (block.timestamp > queuedAction.executeAfter + GRACE_PERIOD) revert Ares_TimelockNotMet();
        
        // If it requires another action to happen first, check that
        if (requiredPriorActionId != bytes32(0) && queuedOperations[requiredPriorActionId].isQueued) {
            revert Ares_TimelockNotMet();
        }

        // Delete it from the waiting room BEFORE running it
        // This is extremely important to prevent hackers from running it twice!
        delete queuedOperations[operationId];

        emit ActionExecuted(operationId);

        // Tell the main vault to actually move the money or make the call
        bytes memory callData = abi.encodeWithSignature(
            "executeTransaction(address,uint256,bytes)",
            destinationContract,
            ethAmount,
            payloadData
        );
        (bool executionSuccessful, bytes memory actionReturnData) = treasuryCore.call(callData);
        if (!executionSuccessful) {
            revert Ares_ActionFailed(0);
        }

        return actionReturnData;
    }

    // Removes an action from the waiting room without running it
    function cancelOperation(bytes32 operationId) external onlyProposer {
        if (!queuedOperations[operationId].isQueued) revert Ares_ProposalNotQueued();
        delete queuedOperations[operationId];
        emit ActionCancelled(operationId);
    }
}
