![Web_Official_Dark](https://user-images.githubusercontent.com/26582141/201743461-87df24c4-80fd-4abe-baf8-7cf6a85e0fba.png)

# Zivoe Finance (_zivoe-core-foundry_)

[![Docs](https://img.shields.io/badge/docs-%F0%9F%93%84-blue)](https://blog.gitbook.com/product-updates/gitbook-3.0-document-everything-from-start-to-ship)
[![License](https://img.shields.io/badge/License-GPLv3-green.svg)](https://www.gnu.org/licenses/gpl-3.0)

This repository contains the core Zivoe Finance v1 smart contracts.

For a high-level introduction to Zivoe Finance, see [Public Docs](https://zivoe-finance.gitbook.io/public-docs/).

## Structure

This is a forge (foundry-rs) repository, with libraries in the `lib` folder, core contracts in the `src` folder, and tests in the `src/tests` folder.

Within the `src` directory are the following sub-directories:
- `libraries`: Custom libraries implemented for the Zivoe protocol.

- `lockers`: Custom lockers which facilitate ZivoeDAO capital allocations.
  - `lockers/OCC`: **O**n **C**hain **C**redit (_direct loans_)
  - `lockers/OCE`: **O**n **C**hain **E**xponential (_exponentially decaying $ZVE emissions schedule_)
  - `lockers/OCG`: **O**n **C**hain **G**eneric (_for test purposes_)
  - `lockers/OCL`: **O**n **C**hain **L**iquidity (_for liquidity provisioning_)
  - `lockers/OCY`: **O**n **C**hain **Y**ield (_for yield generation_)
  - `lockers/Utility`: Helper contracts (_for utility purposes_)
 
- `misc`: Utility files (templates, suites, et cetera).

- `tests`: Unit and fuzz testing contracts, implemented in Solidity within `forge test` context.

## Core-Contracts

All core contracts for the Zivoe protocol are in the root `src` folder.

**`ZivoeDAO.sol`** - escrows capital from liquidity providers, governance then allocates this to lockers.

**`ZivoeGlobals.sol`** - stores global values utilized by all core contracts.

**`ZivoeGovernor.sol`** - implements governance modules from OpenZeppelin for governance.

**`ZivoeITO.sol`** - conducts the Initial Tranche Offering ("ITO").

**`ZivoeLocker.sol`** - an abstract base contract, inherited by all lockers in `src/lockers`.

**`ZivoeRewards.sol`** - a multi-rewards staking contract for $zJTT/$zSTT/$ZVE.

**`ZivoeRewardsVesting.sol`** - a multi-rewards staking contract for internal $ZVE vesting schedules.

**`ZivoeToken.sol`** - $ZVE, the native protocol token, used for governance and staking.

**`ZivoeTranches.sol`** - handles ongoing deposits to the DAO in exchange for $zJTT/$zSTT.

**`ZivoeTrancheToken.sol`** - utilized to launch two tranche tokens (senior and junior, $zSTT/$zJTT).

**`ZivoeYDL.sol`** -  handles yield distribution accounting for the Zivoe protocol.

## Setup & Environment

Install [foundry-rs](https://github.com/foundry-rs/foundry).

Generate a main-net RPC-URL from [Infura](https://www.infura.io/).

```
git clone <repo>
git submodule update --init --recursive
forge test --rpc-url <RPC_URL_MAINNET>
```
