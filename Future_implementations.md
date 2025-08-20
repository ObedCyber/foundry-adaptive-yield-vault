# Core protocol gaps

* **End-to-end accounting:**

  * Strict ERC-4626 compliance (rounding modes, `preview*` vs `*` parity, share/asset conversions under zero/low liquidity, totalAssets including strategy balances).
  * **Idle+strategy TVL source of truth** in the vault (pull from StrategyManager on `totalAssets()` or keep a cached value with push/pull updates).
* **Withdrawal liquidity model:**

  * Withdrawal queue / buffer %; partial withdrawals pull from strategies; “shortfall” handling with events.
  * Anti-sandwich/MEV on deposits/withdrawals (per-tx min shares/assets, which you started).
* **Fee model:**

  * Performance & management fees (with high-watermark and crystallization), fee recipient, share mint vs skim.
  * Accrual cadence + unit tests around fee math.
* **Strategy lifecycle & limits:**

  * Per-strategy caps, per-vault TVL cap, min APY threshold already considered—also **cooldown** and **allocation rate limits**.
  * Strategy health checks & “sick” flag to auto-block deposits.
* **Rebalance policy:**

  * Your APYGap idea is good—also add **min rebalancing notional** and **cooldown window** to avoid thrash.
  * Gas-aware rebalance (skip if benefit < estimated gas/withdrawal penalty).

# Security & safety rails

* **Role design:**

  * Vault: `PAUSER`, `FEE_MANAGER`, `STRATEGY_SETTER`, `KEEPER` (for Automation).
  * StrategyManager: `OWNER` (governance), `VAULT_ONLY` calls, timelocked parameter changes.
  * Multisig + Timelock for anything dangerous.
* **Circuit breakers:**

  * `Pausable` on vault & manager; **guarded withdrawals** (global and per-user rate limits).
  * **Loss socialization switch** (stop deposits if strategies report loss > X bps).
  * **Oracle sanity checks** (reduce APY spikes; clamp to \[min,max], require multiple feeds or median of sources).
* **Reentrancy & approvals:**

  * NonReentrant on all external state-changing paths (you started).
  * **Pull**-based approvals from vault to strategies (no unbounded approvals), and revoke on deactivation.
* **Invariant thinking:**

  * Shares monotonicity, `totalSupply > 0 ⇒ pricePerShare = totalAssets/totalSupply`, conservation when moving assets vault↔strategy, fees never make PPS go down incorrectly, no negative balances.
* **Emergency playbook:**

  * `emergencyWithdraw()` on strategies with rate limits and snapshot events.
  * Global shutdown mode (withdrawals enabled, deposits disabled), upgrade freeze switch.

# Testing & verification (Foundry)

* **Spec tests:**

  * ERC-4626 reference tests (deposit/withdraw/preview/mint/redeem, rounding).
  * StrategyManager flows: add/activate/deactivate, allocate/withdraw, rebalance (APYGap, cooldown, min notional).
  * **Liquidity shortfall path** from vault (pull from strategies).
  * Fee accrual (time travel), high-watermark, edge rounding.
* **Fuzz + invariants:**

  * Invariants: totalAssets equals idle+strategies (±fees), shares monotonic rules, can’t rebalance to inactive, APY clamps.
  * Fuzz time-based behavior (interest accrual, withdrawal delay).
* **Property tools:**

  * Foundry `invariant` tests, echidna/halmos optional.
  * Gas snapshots (`forge snapshot`) and budget regressions.

# Tooling & CI

* **Static analysis:** Slither, Mythril (optional), `solhint`, `prettier-solidity`.
* **CI:** GitHub Actions running `forge build`, `forge test -vvv`, `slither . --config slither.config.json`, gas report, lints, and formatting checks on PRs.
* **Coverage & badges:** `forge coverage` with threshold fail (e.g., >90%).
* **Security policy:** `SECURITY.md`, responsible disclosure, contacts.

# Docs & DX

* **README that sells it:** what it is, threat model, fee policy, APY math, rebalance rules, withdrawal liquidity model, supported networks.
* **/docs**:

  * `workflow.md` (you have), **architecture diagram**, **state machine diagrams** for Vault and Manager, **sequence diagrams** for deposit/withdraw/rebalance.
  * `access-control.md` (you have), **risk disclosures**, **parameters & defaults**, **operations runbook** (how keepers run, how to pause, how to emergency withdraw).
  * API reference (NatSpec exported with `forge doc` or mdbook).
* **Examples & scripts:**

  * Deploy scripts per network (Foundry `script/`), environment sample `.env.example`, quickstart.
  * Demo UIs (minimal React or foundry-cast examples) to deposit/withdraw.

# Production features to consider

* **Keeper integration:** Chainlink Automation (time-based for APY refresh; logic-based for rebalance when `bestAPY-currentAPY ≥ APYGap` & notional > min).
* **Oracle resilience:** median of sources (Chainlink, in-protocol rates), fallback behavior, staleness checks.
* **Accounting polish:**

  * Withdrawal delay already in vault—add **per-user cool-down** and **queue** (optional) to smooth liquidity.
  * **Deposit/withdrawal fees** (optional) to cover gas and rebalance costs.
* **Upgrade pattern:** UUPS or Transparent proxy with storage gaps & upgrade tests; **proxy admin** timelocked to governance.
* **Strategy SDK:** abstract BaseStrategy with hooks (`beforeDeposit/afterDeposit/harvest`) and **health reports** (gain/loss, lastReport).
* **Real strategies:** add one real integration (e.g., Aave ERC4626 wrapper) behind a cap and guarded parameters.

# Repo hygiene

* `foundry.toml` with compiler settings (via-ir, optimizations), remappings, gas reports.
* `.editorconfig`, `.gitattributes` (LF), `.gitignore` (keep build artifacts out).
* `LICENSE` (MIT or AGPL consistent with deps).
* Versioning & `CHANGELOG.md`.
* Example env + secrets docs.
* `CODEOWNERS` and PR templates.

# Concrete next steps (do these next)

1. **Lock down accounting:** implement `totalAssets()` = idle + StrategyManager total (or cached with update). Make all ERC-4626 previews consistent.
2. **Liquidity policy:** implement buffer %, withdrawal queue, and the “pull extra % when refilling vault” logic you described.
3. **Rebalance guardrails:** `APYGap`, min rebalance notional, cooldown; emit detailed events.
4. **Fees:** add performance & management fee with tests.
5. **Hardening:** pausable, timelock + multisig, per-strategy caps, oracle clamps.
6. **Tests:** add ERC4626 reference tests, fuzz/invariants, and gas snapshots.
7. **CI + Slither config** and badges.
8. **Docs:** expand README, add diagrams and ops runbook.
