// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAresTreasuryCore {
    event CircuitBreakerTripped(address by);
    event CircuitBreakerReset(address by);
    event TransactionExecuted(address indexed destinationContract, uint256 ethAmount, bytes payloadData);

    error Ares_RateLimitExceeded();
    error Ares_UnauthorizedExecution();
    error Ares_InvalidActionTarget();
    error Ares_ActionFailed(uint256 index);
    error Ares_Unauthorized();

    function pause() external;
    function unpause() external;
    function executeTransaction(
        address destinationContract,
        uint256 ethAmount,
        bytes calldata payloadData
    ) external returns (bytes memory);
}
