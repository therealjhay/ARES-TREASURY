// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAresTreasury} from "../interfaces/IAresTreasury.sol";

// Main contract for the Ares Treasury, handling secure fund management with timelock and guardian controls.
contract AresTreasuryCore is IAresTreasury {
    // Immutable addresses for timelock (delays actions) and guardian (emergency controls).
    address public immutable timelock;
    address public immutable guardian;

    // Flag to pause the contract in emergencies.
    bool public isPaused;

    // Constants for epoch length (7 days) and max withdrawal per epoch (5%).
    uint256 public constant EPOCH_LENGTH = 7 days;
    uint256 public constant MAX_WITHDRAWAL_BPS = 500; // 5% max per epoch

    // Tracks the start of the current epoch and how much has been withdrawn this epoch.
    uint256 public currentEpochStart;
    uint256 public epochWithdrawnAmount;

    // Events for logging pauses, resets, and executed transactions.
    event CircuitBreakerTripped(address by);
    event CircuitBreakerReset(address by);
    event TransactionExecuted(address indexed target, uint256 value, bytes data);

    // Modifier to restrict access to timelock only.
    modifier onlyTimelock() {
        if (msg.sender != timelock) revert Ares_Unauthorized();
        _;
    }

    // Modifier to restrict access to guardian only.
    modifier onlyGuardian() {
        if (msg.sender != guardian) revert Ares_Unauthorized();
        _;
    }

    // Modifier to prevent actions when the contract is paused.
    modifier whenNotPaused() {
        if (isPaused) revert Ares_UnauthorizedExecution();
        _;
    }

    // Constructor sets up the timelock and guardian, and initializes the epoch.
    constructor(address _timelock, address _guardian) {
        if (_timelock == address(0) || _guardian == address(0)) revert Ares_Unauthorized();
        timelock = _timelock;
        guardian = _guardian;
        currentEpochStart = block.timestamp;
    }

    // Function to pause the contract, callable by guardian.
    function pause() external onlyGuardian {
        isPaused = true;
        emit CircuitBreakerTripped(msg.sender);
    }

    // Function to unpause the contract, callable by guardian.
    function unpause() external onlyGuardian {
        isPaused = false;
        emit CircuitBreakerReset(msg.sender);
    }

    // Main function to execute transactions, with checks for epoch limits and pauses.
    function executeTransaction(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyTimelock whenNotPaused returns (bytes memory) {
        // Prevent self-calls for security.
        if (target == address(this)) revert Ares_InvalidActionTarget();
        
        // Reset the epoch if the current one has ended.
        if (block.timestamp >= currentEpochStart + EPOCH_LENGTH) {
            currentEpochStart = block.timestamp;
            epochWithdrawnAmount = 0;
        }

        // Check and enforce withdrawal limits for ETH.
        if (value > 0) {
            uint256 currentBalance = address(this).balance + value; // balance before this tx
            uint256 maxAllowed = (currentBalance * MAX_WITHDRAWAL_BPS) / 10000;

            if (epochWithdrawnAmount + value > maxAllowed) {
                revert Ares_RateLimitExceeded();
            }
            epochWithdrawnAmount += value;
        }

        // Perform the actual transaction call.
        (bool success, bytes memory returnData) = target.call{value: value}(data);
        if (!success) revert Ares_ActionFailed(0);

        emit TransactionExecuted(target, value, data);
        return returnData;
    }

    // Fallback to receive ETH.
    receive() external payable {}
}
