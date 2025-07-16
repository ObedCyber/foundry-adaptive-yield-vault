We're working with **5 core smart contracts** for the MVP version of your **Autonomous Token Allocator (DeFi Robo-Vault)**. Here's the breakdown:

---

### 🧱 Core Contracts (MVP)

|   # | Contract Name           | Purpose                                                                                                                                  |
| --: | ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| 1️⃣ | **RoboVault.sol**       | Main vault — accepts user deposits/withdrawals (ERC-4626), manages strategy selection and delegation.                                    |
| 2️⃣ | **BaseStrategy.sol**    | Abstract contract or interface that all strategy plugins must implement. Defines `deposit()`, `withdraw()`, `estimateAPY()`.             |
| 3️⃣ | **MockStrategy.sol**    | A simple strategy that pretends to yield a fixed APY (for demo/testing). Helps test rebalancing logic without real protocols.            |
| 4️⃣ | **StrategyManager.sol** | Contains logic for selecting the optimal strategy based on estimated APY, fees, or gas cost. Called by the vault or keeper.              |
| 5️⃣ | **RoboKeeper.sol**      | Chainlink Automation-compatible contract to periodically trigger `rebalance()` on the vault using `checkUpkeep()` and `performUpkeep()`. |

---

### 🧪 Optional Additions (for extra time or polish)

|   # | Contract Name                               | Purpose                                                                           |
| --: | ------------------------------------------- | --------------------------------------------------------------------------------- |
| 6️⃣ | **AaveStrategy.sol / CompoundStrategy.sol** | Real strategy plugins that interact with Aave or Compound using their interfaces. |
| 7️⃣ | **VaultFactory.sol**                        | Allows deploying multiple RoboVaults per asset (multi-token support).             |
| 8️⃣ | **AccessManager.sol**                       | Optional RBAC module (e.g., only allow whitelisted strategies, emergency pause).  |
| 9️⃣ | **Events.sol / Errors.sol**                 | Common errors/events file for modularity and gas savings.                         |

---

### ✅ Minimum Viable Contracts (Start Here)

To make it hackathon-ready fast:

* Start with contracts 1️⃣ to 3️⃣ (vault + base strategy + mock strategy)
* Add 4️⃣ for modular rebalancing
* Use 5️⃣ only if Chainlink Automation is in scope

---

Would you like me to now:

* Provide a suggested **folder + file structure**?
* Drop the base interface for `IStrategy`?
* Set your **first task goal** to build?

Let’s start building when you're ready.
