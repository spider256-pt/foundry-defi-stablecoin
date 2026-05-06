# Decentralised Stablecoin Protocol (DSC)

[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.18-blue)](https://soliditylang.org/)

A collateral-backed decentralised stablecoin protocol 
inspired by MakerDAO's DAI. Built and security-tested 
with Foundry.

---

## Overview

DSC is an algorithmic stablecoin pegged to $1 USD, 
backed by overcollateralized WETH and WBTC deposits. 
The protocol maintains solvency through a liquidation 
mechanism that incentivises external liquidators to 
maintain system health.

**Core Properties:**
- Exogenously collateralised (WETH + WBTC)
- USD pegged ($1 per DSC)
- Algorithmically stabilised via liquidation engine
- 200% minimum collateralisation ratio

---

## Architecture

├── DSCEngine.sol          # Core protocol logic
│   ├── depositCollateral  # Lock WETH/WBTC as collateral
│   ├── mintDsc            # Mint DSC against collateral
│   ├── burnDsc            # Burn DSC to reduce debt
│   ├── redeemCollateral   # Withdraw collateral
│   └── liquidate          # Liquidate undercollateralised positions
│
└── DecentralisedStableCoin.sol

script/
├── DeployScript.s.sol     # Deployment script
└── HelperConfig.s.sol  

test/
├── mocks/
│   └── ERC20Mock.sol      
│   └── MockV3Aggregator.sol
└── fuzz/
│    ├── OpenInvariants.t.sol   # Invariant test suite
│    └── Handler.t.sol   # Foundry handler contract
│    └── Invarients.t.sol
└──TestDSC.t.sol    # Unit test suite

---

## Security & Testing

This protocol has a comprehensive test suite built 
with Foundry covering three layers of testing:

### Unit Tests
Tests covering all core functions:
- Collateral deposit and redemption
- DSC minting and burning
- Price feed accuracy
- Health factor calculations
- Liquidation mechanics

### Invariant Tests
Stateful fuzz testing using a Handler pattern.

**Core Invariant:**
> The total value of collateral deposited must always 
> exceed the total supply of DSC minted

```solidity
function invariant_protocolMustHaveMoreValueThanTotalSupply() 
    public view {
    uint256 totalSupply = dsc.totalSupply();
    uint256 wethValue = dsce.getUsdValue(weth, 
        IERC20(weth).balanceOf(address(dsce)));
    uint256 wbtcValue = dsce.getUsdValue(wbtc, 
        IERC20(wbtc).balanceOf(address(dsce)));

    assert(totalSupply <= wethValue + wbtcValue);
}
```

The Handler contract bounds all inputs to valid ranges 
and tracks which users have deposited collateral, 
ensuring the fuzzer explores realistic state spaces 
across 10,000+ randomised runs.

---

## Installation

```bash
# Clone the repo
git clone https://github.com/spider256-pt/foundry-defi-stablecoin
cd foundry-defi-stablecoin

# Install dependencies
forge install

# Build
forge build
```

---

## Usage

```bash
# Deploy to local Anvil chain
anvil
forge script script/DeployScript.s.sol --rpc-url http://localhost:8545 --broadcast
```

---

## Running Tests

```bash
# Run all tests
forge test

# Run unit tests only
forge test --match-path test/unit/*

# Run invariant tests only
forge test --match-path test/invariant/*

# Run with verbosity
forge test -vvvv

# Run invariant tests with more runs
forge test --match-path test/invariant/* --fuzz-runs 10000
```

---

## Key Concepts

**Health Factor**
Each user has a health factor calculated as:
    healthFactor = (collateralValueUSD * liquidationThreshold)
/ totalDscMinted

If health factor drops below 1e18, the position 
can be liquidated.

**Liquidation**
Liquidators repay a user's DSC debt and receive 
their collateral plus a 10% bonus incentive.

---

## Author

**Pratik Das** — spider256-pt  
Blockchain Security Auditor | Penetration Tester  
[GitHub](https://github.com/spider256-pt) · 
[LinkedIn](https://linkedin.com/in/pratik-das-057a412a9) · 
[Medium](https://spider-256.medium.com)

---

## License

MIT
