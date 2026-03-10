// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAresTreasury} from "../interfaces/IAresTreasury.sol";

/**
 * @title AresTimelock
 * @notice Queue-based execution engine enforcing temporal delays securely.
 * @dev Protects against reentrancy, transaction replacement, and timestamp manipulation.
 */
contract AresTimelock is IAresTreasury {
    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    address public immutable treasuryCore;
    address public proposerModule;

    struct QueuedOperation {
        uint256 executeAfter;
        bool isQueued;
    }

    // operationId => QueuedOperation
    mapping(bytes32 => QueuedOperation) public queuedOperations;

    modifier onlyProposer() {
        if (msg.sender != proposerModule) revert Ares_Unauthorized();
        _;
    }

    modifier onlySelf() {
        if (msg.sender != address(this)) revert Ares_Unauthorized();
        _;
    }

    constructor(address _treasuryCore, address _proposerModule) {
        if (_treasuryCore == address(0)) revert Ares_Unauthorized();
        treasuryCore = _treasuryCore;
        proposerModule = _proposerModule;
    }

    /**
     * @notice Generates a unique operation ID based on target, value, data, and a predecessor.
     */
    function getOperationId(
        address target,
        uint256 value,
        bytes memory data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    /**
     * @notice Queues an operation to be executed after a delay.
     */
    function queueOperation(
        address target,
        uint256 value,
        bytes memory data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external onlyProposer returns (bytes32 operationId) {
        if (delay < MIN_DELAY || delay > MAX_DELAY) revert Ares_TimelockNotMet();

        operationId = getOperationId(target, value, data, predecessor, salt);

        if (queuedOperations[operationId].isQueued) revert Ares_ProposalAlreadyQueued();

        uint256 executeAfter = block.timestamp + delay;
        queuedOperations[operationId] = QueuedOperation({
            executeAfter: executeAfter,
            isQueued: true
        });

        emit ActionQueued(operationId, executeAfter);
    }

    /**
     * @notice Executes a queued operation.
     * @dev Removes from queue before execution (Checks-Effects-Interactions)
     */
    function executeOperation(
        address target,
        uint256 value,
        bytes memory data,
        bytes32 predecessor,
        bytes32 salt
    ) external payable returns (bytes memory) {
        bytes32 operationId = getOperationId(target, value, data, predecessor, salt);
        QueuedOperation memory op = queuedOperations[operationId];

        if (!op.isQueued) revert Ares_ProposalNotQueued();
        if (block.timestamp < op.executeAfter) revert Ares_TimelockNotMet();
        if (block.timestamp > op.executeAfter + GRACE_PERIOD) revert Ares_TimelockNotMet();
        
        // Enforce predecessor constraint if specified
        if (predecessor != bytes32(0) && queuedOperations[predecessor].isQueued) {
            revert Ares_TimelockNotMet();
        }

        // State change before external call (Reentrancy protection)
        delete queuedOperations[operationId];

        emit ActionExecuted(operationId);

        // Make the call to the Core to execute (which enforces limits)
        bytes memory callData = abi.encodeWithSignature(
            "executeTransaction(address,uint256,bytes)",
            target,
            value,
            data
        );
        (bool success, bytes memory returnData) = treasuryCore.call(callData);
        if (!success) {
            revert Ares_ActionFailed(0);
        }

        return returnData;
    }

    /**
     * @notice Cancels a queued operation
     */
    function cancelOperation(bytes32 operationId) external onlyProposer {
        if (!queuedOperations[operationId].isQueued) revert Ares_ProposalNotQueued();
        delete queuedOperations[operationId];
        emit ActionCancelled(operationId);
    }
}
