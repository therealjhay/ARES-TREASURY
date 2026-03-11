// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAresTimelock {
    event ActionQueued(bytes32 indexed actionId, uint256 executeAfter);
    event ActionExecuted(bytes32 indexed actionId);
    event ActionCancelled(bytes32 indexed actionId);

    error Ares_TimelockNotMet();
    error Ares_ProposalAlreadyQueued();
    error Ares_ProposalNotQueued();
    error Ares_Unauthorized();
    error Ares_ActionFailed(uint256 index);

    function queueOperation(
        address destinationContract,
        uint256 ethAmount,
        bytes memory payloadData,
        bytes32 requiredPriorActionId,
        bytes32 salt,
        uint256 timelockDelaySeconds
    ) external returns (bytes32 operationId);

    function executeOperation(
        address destinationContract,
        uint256 ethAmount,
        bytes memory payloadData,
        bytes32 requiredPriorActionId,
        bytes32 salt
    ) external payable returns (bytes memory);

    function cancelOperation(bytes32 operationId) external;

    function getOperationId(
        address destinationContract,
        uint256 ethAmount,
        bytes memory payloadData,
        bytes32 requiredPriorActionId,
        bytes32 salt
    ) external pure returns (bytes32);
}
