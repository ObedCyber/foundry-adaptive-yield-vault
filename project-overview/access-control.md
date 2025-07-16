# Access Control & Security Privileges for RoboVault

> **Purpose:** Describe internal trust boundaries and permission layers between contracts and roles

---

## 🔐 Overview

This vault system consists of several interdependent contracts. Some of them are **only allowed to be called by specific actors** (contracts or EOA roles) to **enforce modularity, minimize attack surface**, and **prevent privilege escalation**.

---

## 🧱 Contracts & Their Access Assumptions

| Contract                      | Privileged Callers                   | Reason                                                |
| ----------------------------- | ------------------------------------ | ----------------------------------------------------- |
| `RoboVault.sol`               | Anyone (for public deposit/withdraw) | ERC4626 standard interface                            |
| `BaseStrategy.sol`            | Only the Vault (`RoboVault`)         | Prevents unauthorized deposits/withdrawals            |
| `MockStrategy.sol`            | Only the Vault                       | Prevent misuse of yield simulation logic              |
| `StrategyManager.sol`         | Only the Vault                       | Ensures strategy scoring isn't manipulated externally |
| `RoboKeeper.sol`              | Chainlink Automation Registry        | Only Chainlink performs `performUpkeep()`             |
| `VaultFactory.sol` (optional) | Owner or Governance                  | Prevent spam vault deployments                        |

---

## 👤 Roles and Responsibilities

| Role                       | Permissions                                                                     |
| -------------------------- | ------------------------------------------------------------------------------- |
| **User (Depositor)**       | Can call: `deposit()`, `withdraw()`, `redeem()`                                 |
| **Vault (RoboVault.sol)**  | Can call: `strategy.deposit()`, `strategy.withdraw()`, `strategy.estimateAPY()` |
| **StrategyManager**        | Can call: internal `estimateBestStrategy()`                                     |
| **RoboKeeper / Chainlink** | Can call: `RoboVault.rebalance()` via `performUpkeep()`                         |
| **Owner/Governance**       | (Optional) Can pause/unpause, set fee params, register strategies               |

---

## 🔐 Function-Level Access Control

### 🧹 `MockStrategy.sol` / `BaseStrategy.sol`

```solidity
modifier onlyVault() {
    require(msg.sender == vault, "NotVault");
    _;
}

function deposit(uint256 amount) external onlyVault { ... }
function withdraw(uint256 amount) external onlyVault { ... }
```

📅 Prevents **malicious actors** from funding or draining strategies directly.

---

### 🖠️ `StrategyManager.sol`

```solidity
function getBestStrategy() external view onlyVault returns (address) {
    ...
}
```

📅 Prevents front-running or gaming of strategy selection by keeping scoring logic internal.

---

### 🔁 `RoboVault.sol`

```solidity
function rebalance() external onlyKeeper {
    ...
}
```

📅 Protects rebalance logic from abuse; optionally allows:

```solidity
modifier onlyKeeper() {
    require(msg.sender == keeper || msg.sender == owner(), "NotKeeper");
    _;
}
```

Or allows **Chainlink Upkeep only**:

```solidity
modifier onlyUpkeep() {
    require(msg.sender == automationRegistry, "NotChainlink");
    _;
}
```

---

## 🧰 Suggested Pattern: Central AccessManager (Optional)

To make it modular and upgrade-safe:

* Create a shared `AccessManager.sol`

  * Stores vault address
  * Stores keeper/owner roles
  * Can be reused by all strategies and managers
  * Emits access change events

---

## 🔐 Security Summary

| Threat                       | Mitigation                                     |
| ---------------------------- | ---------------------------------------------- |
| 💥 External strategy deposit | `onlyVault` modifiers                          |
| 💰 Unauthorized rebalance    | `onlyKeeper` or Chainlink-only                 |
| 🤑 Sybil strategy spam       | Optional allowlist / governance                |
| 🪳 Emergency situations      | `pause()` function (optional with `Pausable`)  |
| ⚙️ Deployment privilege      | `onlyOwner` for vault factory or admin scripts |

---

## 📌 Final Notes

* Always **assume external actors are malicious**
* Validate **msg.sender** in every privileged function
* Consider using **OpenZeppelin AccessControl**, `Ownable`, or `Pausable` for upgrades
* Log events for **auditability** of critical changes
