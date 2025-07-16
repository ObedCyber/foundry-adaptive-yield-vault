## Vault Economics: Share Allocation and Yield Behavior

This document illustrates how ERC4626 vault math works in RoboVault — specifically, how shares are calculated during deposits and how yield impacts the value of user-held shares.

---

### 📊 Scenario Overview

We will walk through the following sequence:

1. Alice deposits 1000 USDC
2. Bob deposits 500 USDC after Alice
3. The vault earns 100 USDC in yield
4. Mary deposits 1000 USDC after the yield has accrued

---

### 📈 Initial State

* Vault is empty:
  `totalAssets = 0`, `totalShares = 0`

---

### ✅ Step 1: Alice Deposits 1000 USDC

Since vault is empty, Alice receives 1000 shares (1:1 share\:asset ratio).

**Vault state after Alice:**

* `totalAssets = 1000`
* `totalShares = 1000`
* `sharePrice = 1.0`

---

### ✅ Step 2: Bob Deposits 500 USDC

Current share price is still 1.0. Bob receives:

```
shares = 500 * 1000 / 1000 = 500 shares
```

**Vault state after Bob:**

* `totalAssets = 1500`
* `totalShares = 1500`
* `sharePrice = 1.0`

---

### ✅ Step 3: Vault Earns 100 USDC in Yield

Now the vault grows to 1600 USDC without minting new shares.

**Vault state:**

* `totalAssets = 1600`
* `totalShares = 1500`
* `sharePrice = 1600 / 1500 = 1.06666...`

#### User Balances:

* **Alice:** 1000 shares → `1066.66 USDC`
* **Bob:** 500 shares → `533.33 USDC`

---

### ✅ Step 4: Mary Deposits 1000 USDC (After Yield)

Now, share price is 1.06666. Mary receives:

```
shares = 1000 * 1500 / 1600 = 937.5 shares
```

**New Vault State:**

* `totalAssets = 2600`
* `totalShares = 2437.5`
* `sharePrice = 2600 / 2437.5 = 1.06666...`

#### Final Balances:

| User  | Shares | Deposited | Current Value (Assets) | Yield Gained |
| ----- | ------ | --------- | ---------------------- | ------------ |
| Alice | 1000   | 1000      | `1066.66`              | `+66.66`     |
| Bob   | 500    | 500       | `533.33`               | `+33.33`     |
| Mary  | 937.5  | 1000      | `1000.0`               | `+0.00`      |

---

### 🧰 Takeaways

* Depositors receive **fewer shares** when the vault has grown.
* Share price reflects **total yield accrued**.
* Yield benefits are proportional to share ownership.
* ERC4626 ensures fair entry pricing to prevent latecomers from extracting unearned gains.

---

For a real implementation, refer to `previewDeposit()` and `convertToShares()` in your vault logic.
