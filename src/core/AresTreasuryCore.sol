// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAresTreasuryCore} from "../interfaces/IAresTreasuryCore.sol";

contract AresTreasuryCore is IAresTreasuryCore {
    // The timelock contract that must approve all actions
    address public immutable timelock;
    // The guardian who can pause the contract if something goes wrong
    address public immutable guardian;

    // Is the contract paused?
    bool public isPaused;

    // Withdrawals are limited to 5% every 7 days (epoch)
    uint256 public constant EPOCH_LENGTH = 7 days;
    uint256 public constant MAX_WITHDRAWAL_BPS = 500; // 500 basis points = 5%

    // Tracking the 7-day windows and how much was successfully withdrawn
    uint256 public currentEpochStart;
    uint256 public epochWithdrawnAmount;

    // Events to let the outside world know what happened
    event CircuitBreakerTripped(address by);
    event CircuitBreakerReset(address by);
    event TransactionExecuted(address indexed target, uint256 value, bytes data);

    // Only allow the timelock to call
    modifier onlyTimelock() {
        if (msg.sender != timelock) revert Ares_Unauthorized();
        _;
    }

    // Only allow the guardian to call
    modifier onlyGuardian() {
        if (msg.sender != guardian) revert Ares_Unauthorized();
        _;
    }

    // Stop execution if the contract is paused
    modifier whenNotPaused() {
        if (isPaused) revert Ares_UnauthorizedExecution();
        _;
    }

    // Runs once when the contract is deployed
    constructor(address _timelock, address _guardian) {
        if (_timelock == address(0) || _guardian == address(0)) revert Ares_Unauthorized();
        timelock = _timelock;
        guardian = _guardian;
        currentEpochStart = block.timestamp;
    }

    // Emergency pause button
    function pause() external onlyGuardian {
        isPaused = true;
        emit CircuitBreakerTripped(msg.sender);
    }

    // Resume normal operations
    function unpause() external onlyGuardian {
        isPaused = false;
        emit CircuitBreakerReset(msg.sender);
    }

    // The function that actually sends funds or interacts with other contracts
    function executeTransaction(
        address destinationContract,
        uint256 ethAmount,
        bytes calldata payloadData
    ) external onlyTimelock whenNotPaused returns (bytes memory) {
        // Prevent calling this contract itself
        if (destinationContract == address(this)) revert Ares_InvalidActionTarget();
        
        // If 7 days have passed, reset the withdrawal limit tracking
        if (block.timestamp >= currentEpochStart + EPOCH_LENGTH) {
            currentEpochStart = block.timestamp;
            epochWithdrawnAmount = 0;
        }

        // Limit how much ETH can be withdrawn in the 7-day period
        if (ethAmount > 0) {
            uint256 currentBalance = address(this).balance + ethAmount; // balance before this transaction
            uint256 maxAllowed = (currentBalance * MAX_WITHDRAWAL_BPS) / 10000;

            if (epochWithdrawnAmount + ethAmount > maxAllowed) {
                revert Ares_RateLimitExceeded();
            }
            epochWithdrawnAmount += ethAmount;
        }

        // Perform the actual call to the target contract
        (bool executionSuccessful, bytes memory actionReturnData) = destinationContract.call{value: ethAmount}(payloadData);
        if (!executionSuccessful) revert Ares_ActionFailed(0);

        emit TransactionExecuted(destinationContract, ethAmount, payloadData);
        return actionReturnData;
    }

    receive() external payable {}
}
