# ARES Treasury: How It Works

Imagine a high-security bank vault. You wouldn't want one person or one key to have the power to instantly empty the entire bank. Instead, you'd want several layers of security: a front desk to check identities, a waiting period before large withdrawals, and an alarm system to pull the plug if someone tries to rob it.

The ARES Protocol Treasury is built just like this. Instead of one giant, complicated program (which hackers love to target), we split the treasury into four simple, separate parts. 

### 1. The Front Desk: `AresProposer.sol`
This is where everything starts. If someone wants the treasury to spend money or do something, they come here.
* **What it does:** It checks their "ID" (digital signatures) to make sure they are who they say they are.
* **The "Spam" filter:** To stop people from flooding the system with fake requests, anyone proposing an action has to lock up **0.1 ETH** as a deposit. 
* **Safety first:** This contract **never touches the actual money**. Even if a hacker broke into the front desk, they still can't access the vault.

### 2. The Waiting Room: `AresTimelock.sol`
In crypto, speed is dangerous. Hackers love to steal money instantly before anyone notices. The Timelock forces every proposal to wait in a "waiting room" for at least a few days.
* **The Delay:** Every single action must sit here. It gives the community time to review the proposal and make sure it's safe.
* **Checks and Balances:** When it's time to execute, the Timelock always deletes the proposal from the waiting room *before* it runs it. This stops a clever hacker trick (called "reentrancy") where they try to run the code multiple times in a row fast enough to confuse it.

### 3. The Bank Vault: `AresTreasuryCore.sol`
This is the only contract that actually holds the money. It's designed to be very simple and strictly follows orders from the Timelock.
* **Speed Limits:** Unlike other treasuries that let you drain 100% of the money at once, the Vault has a strict speed limit. It will only ever allow **5% of the money to be moved every 7 days**. If a hacker tries to take it all, the vault just says "no."
* **The Emergency Button:** A trusted Guardian can pause the vault if a robbery is in progress. They can't steal the money themselves, they can only lock the doors to protect it.

### 4. The Payroll Desk: `AresRewardDistributor.sol`
We keep the everyday rewards separate from the billions in the main vault.
* **How it works:** Instead of storing a massive list of thousands of users and their balances, it uses a math trick (called a Merkle Tree) to store just a single fingerprint of the data. 
* **Safety:** The Payroll Desk only holds the exact amount of money it needs to pay people out. If there's a problem here, the main vault remains completely safe.

### Summary
By splitting the system into four parts, a hacker has to bypass the front desk's signature checks, wait patiently in the waiting room for days without anyone noticing, and even then, they can only steal 5% of the money max because of the vault's speed limit!
