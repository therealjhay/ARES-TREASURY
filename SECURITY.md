# ARES Protocol Treasury: Security Explained (For Beginners)

When we built the ARES Treasury, we looked at how other treasuries were hacked and designed our system specifically to stop those attacks. Here's a simple breakdown of how exactly we protect the money from common clever tricks.

### 1. Stopping "The Double-Dip" (Reentrancy)

**The Hacker Trick:** Imagine going to an ATM, asking for $100, and just right before the machine updates your balance, you quickly tell it to give you another $100. Hackers do this in crypto to drain money fast!
**How ARES Stops It:** We use a rule called "Check, Then Update, Then Send." When a proposal is ready to run, the Timelock instantly deletes it from the "waiting room" before doing anything else. If the hacker tries to quickly trigger it again, the Timelock says, "I have no record of this action," and blocks them.

### 2.2 Signature Replay & Malleability

**Threat:** Attackers intercept a valid EIP-712 signature from a proposer and replay it to queue identical payloads redundantly. Furthermore, cross-chain replay or contract-level malleability could allow signatures intended for testnets or other deployments to execute on the mainnet repository.
**Mitigation:** The `EIP712Signer` library incorporates a multi-tiered cryptographic defense:

1.  **Nonce Management:** Each `proposer` address is mapped to a strictly incrementing `nonce`. A signature is tied directly to the current nonce. Once a proposal is successfully created, the nonce increments, instantly rendering the intercepted signature mathematically invalid for future use.
2.  **Domain Separator:** The EIP-712 domain hash tightly binds the signature to the specific `block.chainid` and the explicit address of the `AresProposer` contract. Cross-chain replays and cross-contract replays will fail signature recovery.

### 2.3 Double Claim Attacks

**Threat:** Users exploit latency or logic flaws to submit valid Merkle proofs multiple times to the Reward Distributor, draining the allocated supply.
**Mitigation:** The `AresRewardDistributor` utilizes highly gas-efficient algorithmic bitmap tracking (`claimedBitMap`). Each user is assigned an index derived from the Merkle tree. When a claim occurs, the protocol calculates the exact bit within a 256-bit storage slot and sets it to `1`. Because rewriting a `1` bit over an existing `1` bit is structurally impossible, the `isClaimed` check provides mathematically guaranteed double-claim prevention at an optimal gas cost.

### 2.4 Timelock Bypass & Premature Execution

**Threat:** Attackers manipulate timestamps or find execution pathways that bypass the designated queuing delay, allowing them to force through malicious payloads before the community can react.
**Mitigation:** The delay is mathematically bound to the `operationId` during the `queueOperation` phase. `executeOperation` performs a hard check: `if (block.timestamp < op.executeAfter) revert Ares_TimelockNotMet();`. Most importantly, the `AresTreasuryCore` (which holds the funds) operates on an allowlist paradigm (`onlyTimelock`). Direct calls to the core bypass the Timelock are blocked natively, making the Timelock the only unbypassable portal to capital.

### 2.5 Governance Flash-Loan Drains & Manipulation

**Threat:** An attacker uses a flash loan or sudden massive voting power accumulation to unilaterally push through a governance proposal that drains the entire treasury in a single transaction.
**Mitigation:** The `AresTreasuryCore` implements an immutable **Epoch Rate Limit**. Regardless of who queued the proposal or how much voting power approved it, the Core contract structurally limits total outflows to `500 BPS` (5%) of its total balance per 7-day epoch. If a flash-loan attacker successfully queues a 100% drain proposal, the execution will revert with `Ares_RateLimitExceeded`. This mathematically guarantees that 95% of the treasury survives any sudden single-epoch attack, buying the community weeks to respond.

### 2.6 Protocol Griefing

**Threat:** Attackers spam the proposal queue with thousands of junk operations, inflating the state and delaying legitimate governance actions.
**Mitigation:** `AresProposer` enforces a strict economic penalty. Every proposal creation requires a hardcoded `PROPOSAL_BOND` (e.g., 0.1 ETH). The bond is only refunded upon successful execution. If a proposal is queued maliciously and ultimately cancelled by governance, the bond is forfeited to the protocol, rendering widespread griefing economically unviable.

## 3. Residual Risks & Trust Dependencies

While the architecture severely restricts systemic risks, absolute security is a paradox. The following residual risks are acknowledged:

1.  **Guardian Compromise:** The `AresTreasuryCore` relies on a `guardian` address to trigger the `Circuit Breaker` during emergencies. While the guardian cannot steal funds (no execution privileges), a compromised guardian could theoretically trigger a permanent Denial of Service (DoS) by unconditionally pausing the vault.
2.  **Proposer Private Key Theft:** If a governance proposer's private key is physically or digitally compromised, an attacker can generate mathematically authentic EIP-712 signatures. While the `Timelock` and `Epoch Rate Limit` will still cap the damage, the protocol cannot differentiate between a legitimate signer and a thief holding the correct key.
3.  **Smart Contract Complexity:** Despite modularity, the `AresTimelock` handles arbitrary data payloads (`target.call(data)`). If a target contract has unforeseen interactions or delegatecall complexities, the execution sandbox could behave unpredictably.

## 4. Conclusion

The modular boundary design, coupled with explicit state constraints like the Epoch Rate Limit and Bitmap Claim tracking, establishes ARES as an incredibly resilient treasury execution engine. It accepts the reality that governance layers can be breached, and therefore relies on absolute, immutable, on-chain mathematical limits to preserve capital regardless of off-chain consensus states.
