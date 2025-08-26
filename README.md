# Foundry Autonomous Token Allocator (Adaptive Yield Vault)

## Overview

This project implements a modular, extensible, and autonomous yield vault system in Solidity. The system is designed to maximize returns for depositors by dynamically allocating assets across multiple investment strategies based on their performance (APY). It is built using the Foundry framework and leverages OpenZeppelin contracts for security and upgradability.

**Key Features:**
- ERC4626-compliant vault (`RoboVault`) for user deposits and withdrawals
- Strategy manager (`StrategyManager`) to coordinate allocation and rebalancing
- Pluggable strategies (e.g., `MockStrategy`) for yield generation
- Automated APY tracking and best-strategy selection
- Withdrawal delay and slippage protection
- Extensive test suite with high coverage

---

## Contracts

### 1. RoboVault
- ERC4626-compliant vault for user deposits
- Handles slippage checks, withdrawal delays, and tracks user deposits
- Interacts with `StrategyManager` to allocate/withdraw funds
- Emits events for deposits and withdrawals

### 2. StrategyManager
- Manages a set of strategies
- Activates/deactivates strategies
- Allocates funds to the best APY strategy
- Handles rebalancing and withdrawal requests from the vault
- Tracks APY and balances across strategies

### 3. MockStrategy
- Example strategy for testing
- Simulates APY and interest accrual
- Handles deposits, withdrawals, and emergency withdrawals


### 4. RoboKeeper
- Automation contract responsible for monitoring and triggering rebalancing
- Periodically checks if vault funds are in the best APY strategy
- Calls `StrategyManager` to rebalance allocations when needed

---

## Directory Structure

```
├── src/
│   ├── RoboVault.sol
│   ├── StrategyManager.sol
│   ├── MockStrategy.sol
│   ├── interfaces/
│   ├── errors/
│   └── ...
├── test/
│   ├── unit/
│   │   ├── RoboVaultTest.t.sol
│   │   ├── StrategyManager.t.sol
│   │   ├── MockStrategyTest.t.sol
│   │   └── ...
│   └── integration/
├── lib/
│   └── ...
├── script/
├── foundry.toml
└── README.md
```

---

## Getting Started

### Prerequisites
- [Foundry](https://book.getfoundry.sh/)
- Git

### Installation
```bash
git clone (https://github.com/ObedCyber/foundry-adaptive-yield-vault)
cd foundry-adaptive-yield-vault
forge install
```

### Running Tests
```bash
forge test
```

### Checking Coverage
```bash
forge coverage
```

---

## Usage

### Depositing & Withdrawing
- Users deposit tokens into the vault using `depositWithSlippageCheck`
- Withdrawals are subject to a delay and slippage check
- Vault automatically allocates funds to the best strategy

---

## Key Functions

### RoboVault
- `depositWithSlippageCheck(uint256 amount, uint256 minShares)`
- `withdrawWithSlippageCheck(uint256 shares, uint256 minAssets)`
- `setStrategyManager(address)`
- `getTotalSharesOfUser(address)`
- `getUserDeposit(address)`

### StrategyManager
- `addStrategy(address)`
- `activateStrategy(uint256)` / `deactivateStrategy(uint256)`
- `getBestAPYStrategy()`
- `getTotalBalanceAcrossStrategies()`
- `getStrategyAPY(uint256)`
- `withdrawToVault(uint256)`


### RoboKeeper
- `checkUpkeep()` — Checks if rebalancing is needed
- `performUpkeep()` — Triggers rebalancing in the manager

### MockStrategy
- `deposit(uint256)`
- `withdraw(uint256)`
- `emergencyWithdraw()`
- `changeAPY(uint256)`
- `strategyName()`
- `estimateAPY()`

---

## Security Considerations
- Uses OpenZeppelin's `Ownable`, `ReentrancyGuard`, and ERC20 standards
- Slippage and withdrawal delay to protect users
- Only owner can add/activate/deactivate strategies
- Only vault can trigger certain manager functions

---

## Testing
- Unit tests for all core contracts and edge cases
- High coverage (90%+)
- Mock contracts for strategies and tokens

---

## Extending
- Add new strategies by implementing the `IStrategy` interface
- Plug new strategies into the manager and activate
- Adjust APY logic, withdrawal periods, or allocation rules as needed

---

## Authors
- Obed Okoh (ObedCyber)

## License
MIT

---

## Acknowledgements
- OpenZeppelin for secure contract libraries
- Foundry for fast Solidity development
