
## ARES Treasury: Architectural Blueprint

### The "Blast Radius" Philosophy

The ARES Proctocol Treasury was not built as a monolith contract. Large, "do-it-all" smart contracts are honey pots for exploits. Instead, we’ve compartmentalized the protocol into four distinct zones. If one part breaks, the rest of the system acts as a bulkhead to keep the capital safe.

### 1. The Entry Point: `AresProposer.sol`

This is where everything starts. It’s a "thin" contract designed to handle the noise so the core doesn't have to.

* **What it does:** It takes off-chain signatures (EIP-712), checks the math via the `EIP712Signer` library, and keeps track of who is proposing what.
* **Security Stake:** To prevent "proposal spam," we require a **0.1 ETH bond**.
* **The Guardrail:** This contract **never** touches the main treasury funds. Even if an attacker found a way to spoof a proposal, they still have to face the Timelock.

### 2. The Waiting Room: `AresTimelock.sol`

Speed is the enemy of security. The Timelock is our "temporal buffer."

* **The Delay:** Every single action (except rewards) must sit in this queue for the `MIN_DELAY` period.
* **Execution:** It uses a "Checks-Effects-Interactions" pattern—meaning we delete the proposal from the queue *before* we trigger the code. This kills re-entrancy attacks in their tracks.
* **The "Wait and See" Factor:** This window gives the community and the **Circuit Breaker** (Guardian) time to spot a malicious payload before it ever touches the money.

### 3. The Vault: `AresTreasuryCore.sol`

This is the only place where the money actually lives. It is intentionally "dumb"—it doesn't care about voting or proposals; it only listens to the Timelock.

* **Rate Limiting:** Unlike most treasuries that allow a 100% drain in one transaction, the Core has an internal "speedometer." If a proposal tries to move too much capital in a single epoch, the Core triggers a hard stop.
* **Guardian Power:** A designated Guardian can pause the Core. They can’t steal the money, but they can "pull the fire alarm" to freeze everything if they see a drain in progress.

### 4. The Payouts: `AresRewardDistributor.sol`

We separated rewards from the main treasury to keep the "high-traffic" stuff away from the "high-value" stuff.

* **Mechanism:** It uses Merkle trees. We don't store 1,000 individual balances; we store one hash.
* **Safety:** The Distributor is "pre-funded." It only holds what it’s supposed to pay out. If there’s a bug in the reward logic, an attacker can only take the reward pool—the main Treasury Core remains untouched.

---

### Critical Trust Assumptions

Let's be realistic about where the risks lie:

1. **Key Management:** If a Proposer loses their private key, an attacker can push garbage into the Timelock. We rely on the `MIN_DELAY` to catch this.
2. **Guardian Integrity:** We trust the Guardian for **liveness** (keeping the system running) but not for **safety**. They can stop a heist, but they can't start one.
3. **Active Monitoring:** The system assumes people are actually watching the Timelock. If a malicious proposal is queued and everyone is asleep for 48 hours, the protocol will execute it.

