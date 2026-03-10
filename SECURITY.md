# ARES Protocol Treasury: Security Explained 

When we built the ARES Treasury, we looked at how other treasuries were hacked and designed our system specifically to stop those attacks. Here's a simple breakdown of how exactly we protect the money from common clever tricks.

### 1. Stopping "The Double-Dip" (Reentrancy)
**The Hacker Trick:** Imagine going to an ATM, asking for $100, and just right before the machine updates your balance, you quickly tell it to give you another $100. Hackers do this in crypto to drain money fast!
**How ARES Stops It:** We use a rule called "Check, Then Update, Then Send." When a proposal is ready to run, the Timelock instantly deletes it from the "waiting room" before doing anything else. If the hacker tries to quickly trigger it again, the Timelock says, "I have no record of this action," and blocks them.

### 2. Stopping "Fake Signatures"
**The Hacker Trick:** Hackers might try to steal someone's older digital signature and reuse it, or take a signature meant for a safe test network and trick the real network into accepting it.
**How ARES Stops It:** We give every user a "number ticket" (called a nonce). Once a signature with Ticket #1 is used, it gets tossed in the trash. The system will now only accept Ticket #2 from that person. Plus, our signatures are stamped with a unique network ID, meaning a test-network signature is literally useless on the real network.

### 3. Stopping "Claiming Rewards Twice"
**The Hacker Trick:** Finding a computer glitch to claim a community token drop multiple times.
**How ARES Stops It:** We use a super-efficient digital checklist. Imagine a massive wall of light switches that all start turned OFF. When you claim your reward, your specific switch is flipped ON. It's mathematically impossible to flip an ON switch ON again. If you try, the system just tells you, "You already claimed."

### 4. Stopping "Rushing the Waiting Room" (Timelock Bypass)
**The Hacker Trick:** Trying to skip the mandatory delay in the waiting room and force an action right now.
**How ARES Stops It:** The main Vault ONLY accepts instructions from the Waiting Room (Timelock). If anyone (even the creator of the contract) tries to talk to the Vault directly, the Vault simply ignores them. There are no secret backdoors or VIP passes.

### 5. Stopping "The Mega Drain" (Flash Loans)
**The Hacker Trick:** A hacker borrows $100 Million for exactly 5 seconds, uses it to "vote" and give themselves the entire treasury, and then returns the loaned money in the same breath.
**How ARES Stops It:** We added an unbreakable speed limit. No matter who votes, no matter how many people say "yes," the Vault will NEVER let more than **5% of the total money leave in a 7-day period**. An attacker could do all the fancy manipulating they want, but the most they can ever touch is 5%. The community then has weeks to pause the system and fix it.

### 6. Stopping "Spamming the System" (Griefing)
**The Hacker Trick:** Flooding the system with millions of garbage proposals to break it or hide a real attack.
**How ARES Stops It:** We charge a security deposit! Anyone who submits a proposal must lock up **0.1 ETH**. If the proposal is cancelled or identified as bad, the Protocol keeps their deposit. Spammers would go bankrupt trying to attack us.

---

### The Honest Truth (What we still have to trust)
No computer system is 100% perfect. We still rely on two things:
1. **People keeping their passwords safe:** If a legitimate user's computer is hacked and their private key is stolen, the hacker can make valid proposals. (However, the 7-day limits and waiting rooms will still minimize the damage).
2. **The Guardian's Honest Help:** The "Guardian" role can press the emergency pause button. If a bad guy took over the Guardian, they couldn't steal the money (they don't have withdrawal powers), but they could pause the contract forever, essentially freezing it.
