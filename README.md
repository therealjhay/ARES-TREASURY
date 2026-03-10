# ARES Protocol Treasury

ARES Protocol Treasury is a highly resilient, modular execution vault designed to securely hold over $500M+ in capital. It introduces strict protocol boundaries, cryptographic isolation, and hardcoded epoch rate limits to solve systemic vulnerabilities in modern decentralized governance frameworks.

## 🚀 Getting Started

Build the contracts, generate the interfaces, and run the comprehensive test suite (which includes both functional and explicit exploit paths).

```bash
# Install Foundy if not already installed
curl -L https://foundry.paradigm.xyz | bash

# Ensure dependencies are up-to-date
forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Build the project
forge build

# Run the Functional and Exploit suites
forge test -vvv
```

## 📜 Protocol Lifecycle Specification

The ARES Protocol operates via an exclusive, deterministic lifecycle that guarantees security at every transitional step. A proposal must traverse four stages before capital moves: `Created` -> `Queued` -> `Executable` -> `Executed`.

### Phase 1: Off-Chain Intent Structuring
A governance participant off-chain hashes the intended actions (target, value, data) and signs them using structured data (EIP-712).
*   **Security:** This generates a nonce-backed, domain-specific digest that protects against cross-chain and cross-contract replays.

### Phase 2: Proposal Creation (`createProposal`)
The user invokes `createProposal` on the `AresProposer` module, supplying the actions, description hash, and the EIP-712 signature. They must attach a `PROPOSAL_BOND` (in ETH).
*   **Security:** A bad signature immediately reverts (`Ares_InvalidSignature`). If valid, the proposer's nonce iterates permanently. The bond enforces economic resistance against queue griefing.
*   **Transition:** State becomes `Created`.

### Phase 3: Temporal Isolation (`queueProposal`)
Once successfully verified, the community (or the proposer) triggers `queueProposal`. This extracts the disparate execution actions and marshals them into the highly protected `AresTimelock` queue.
*   **Security:** A cryptographically unique `operationId` is generated per action, combining the target, value, payload, and unique salt. The execute timestamp is locked to `block.timestamp + delay`.
*   **Transition:** State becomes `Queued`.

### Phase 4: Execution Clearance (`executeProposal`)
After the mandatory temporal delay passes—and assuming the Guardian has not triggered the `pause` Circuit Breaker on the Core Vault—the proposer executes the operation via the Proposer, which proxies to the Timelock.
*   **Security:** 
    1.  The Timelock deletes the `operationId` from its queue *before* delegation, terminating reentrancy vectors.
    2.  The `AresTreasuryCore` receives the `executeTransaction` payload. It calculates the requested value outflow against the rolling 7-day Epoch Rate Limit. 
    3.  If the transaction pushes the total drawn beyond 5% of the total balance, execution reverts, neutralizing flash loan drains.
*   **Transition:** State becomes `Executed`. The user's anti-spam bond is refunded securely.

### Alternative Phase: Cancellation (`cancelProposal`)
If a proposal is identified as malicious during the temporal isolation window, or the creator changes their mind, `cancelProposal` can be called.
*   **Security:** The Proposer removes the associated `operationId`s from the Timelock. The proposal's `PROPOSAL_BOND` is confiscated by the protocol to deter subsequent spam, effectively burning the attacker's capital.
*   **Transition:** State becomes `Cancelled`.

## 🛡️ Documentation Deliverables
The rationale driving these mechanics and the explicit exploitation test coverage are outlined in the accompanying documents:
*   [ARCHITECTURE.md](./ARCHITECTURE.md) - System layout, module interaction, and fundamental boundaries.
*   [SECURITY.md](./SECURITY.md) - Detailed mapping of mitigation controls versus observed DeFi vulnerability vectors.
