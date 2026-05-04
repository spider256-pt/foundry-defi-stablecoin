# Decentralized Stablecoin Engine (DSC)

A Foundry-based implementation of a decentralized, over-collateralized stablecoin pegged to the US Dollar, featuring algorithmic price feeds, dynamic health factors, and liquidation security incentives.

## Core Features

- **Over-collateralization Model:** Users must deposit collateral exceeding the value of the minted stablecoin.
- **Chainlink Oracle Integration:** Uses live, decentralized price feeds to determine the correct collateral-to-debt ratio.
- **Security-First Architecture:** Includes automated invariants and integer safety controls to prevent insolvencies or bad debt accumulation.

## Getting Started

### Prerequisites

Ensure you have [Foundry](https://getfoundry.sh/) installed on your machine.

### Installation

Clone the repository and build the contracts:

```bash
git clone [https://github.com/your-username/foundry-defi-stablecoin](https://github.com/your-username/foundry-defi-stablecoin)
cd foundry-defi-stablecoin
forge build
