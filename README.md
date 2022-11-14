![Web_Official_Dark](https://user-images.githubusercontent.com/26582141/201743461-87df24c4-80fd-4abe-baf8-7cf6a85e0fba.png)

# Zivoe Finance (_zivoe-core-foundry_)

[![Docs](https://img.shields.io/badge/docs-%F0%9F%93%84-blue)](https://blog.gitbook.com/product-updates/gitbook-3.0-document-everything-from-start-to-ship)
[![License](https://img.shields.io/badge/License-GPLv3-green.svg)](https://www.gnu.org/licenses/gpl-3.0)

This repository contains the core Zivoe Finance v1 smart contracts.

For a high-level introduction to Zivoe Finance, see [Generic Medium Post](https://medium.com/balancer-protocol/balancer-v2-generalizing-amms-16343c4563ff).

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

- `src/ZivoeDAO.sol`: ZivoeDAO escrows capital from liquidity providers, which governance then allocates across various lockers.

- `src/ZivoeGlobals.sol`: ZivoeGlobals stores global values accessed and referenced by all core contracts.

- `src/ZivoeGovernor.sol`: ZivoeGovernor implements governance modules from OpenZeppelin for governing the protocol.

- `src/ZivoeITO.sol`: ZivoeITO conducts the Initial Tranche Offering ("ITO"), the first liquidity provision offering for ZivoeDAO.

- `src/ZivoeLocker.sol`: ZivoeLocker is an abstract, modular contract, intended to be inherited by all lockers in `src/lockers`.

- `src/ZivoeRewards.sol`: ZivoeRewards is a multi-rewards staking contract, similar to crv.fi multi-staking rewards.

- `src/ZivoeRewardsVesting.sol`: ZivoeRewardsVesting is a multi-rewards staking contract for internal $ZVE vesting schedules.

- `src/ZivoeToken.sol`: ZivoeToken, $ZVE, is the native protocol token, utilized for governance and staking (to collect rewards).

- `src/ZivoeTranches.sol`: ZivoeTranches handles ongoing deposits to the DAO in exchange for ZivoeTrancheToken's ($zSTT/$zJTT).

- `src/ZivoeTrancheToken.sol`: ZivoeTrancheToken is utilized to launch two tranche tokens (senior and junior, $zSTT/$zJTT).

- `src/ZivoeYDL.sol`: ZivoeYDL handles yield distribution accounting for the Zivoe protocol.

## Setup & Environment

Install [foundry-rs](https://github.com/foundry-rs/foundry).

Generate a main-net RPC-URL from [Infura](https://www.infura.io/).

```
git clone <repo>
git submodule update --init --recursive
forge test --rpc-url <RPC_URL_MAINNET>
```
