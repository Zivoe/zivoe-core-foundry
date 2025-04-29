# Zivoe (_zivoe-core-foundry_)

[![Docs](https://img.shields.io/badge/docs-%F0%9F%93%84-blue)](https://docs.zivoe.com)

This repository contains the core Zivoe v1 smart contracts.

For a high-level introduction to Zivoe, see [Public Docs](https://docs.zivoe.com).

<i>audited by</i>

Runtime Audit Report - [Core](https://github.com/runtimeverification/publications/blob/main/reports/smart-contracts/Zivoe_Core_Contracts.pdf)

Runtime Audit Report - [Lockers](https://github.com/runtimeverification/publications/blob/main/reports/smart-contracts/Zivoe_Locker_Contracts.pdf)

Sherlock Audit Report - [Competition Report](https://github.com/sherlock-protocol/sherlock-reports/blob/main/audits/2024.04.25%20-%20Final%20-%20Zivoe%20Audit%20Report.pdf)

## Structure

This is a forge (foundry-rs) repository, with libraries in the `lib` folder, core contracts in the `src` folder, and lockers in the `lockers` folder.

## Core-Contracts

All core contracts for the Zivoe protocol are in the root `src` folder.

**`ZivoeDAO.sol`** - escrows capital from liquidity providers, governance then allocates this to lockers.

**`ZivoeGlobals.sol`** - stores global values utilized by all core contracts.

**`ZivoeGovernorV2.sol`** - implements governance modules from OpenZeppelin for governance.

**`ZivoeITO.sol`** - conducts the Initial Tranche Offering ("ITO").

**`ZivoeLocker.sol`** - an abstract base contract, inherited by all lockers in `src/lockers`.

**`ZivoeMath.sol`** - a mathematics contract, which handles accounting features in tandem with ZivoeYDL.

**`ZivoeRewards.sol`** - a multi-rewards staking contract for $zJTT/$zSTT/$ZVE.

**`ZivoeRewardsVesting.sol`** - a multi-rewards staking contract for internal $ZVE vesting schedules.

**`ZivoeToken.sol`** - $ZVE, the native protocol token, used for governance and staking.

**`ZivoeTranches.sol`** - handles ongoing deposits to the DAO in exchange for $zJTT/$zSTT.

**`ZivoeTrancheToken.sol`** - utilized to launch two tranche tokens (senior and junior, $zSTT/$zJTT).

**`ZivoeYDL.sol`** -  handles yield distribution accounting for the Zivoe protocol.

Within the `src` directory are the following sub-directories:

- `libraries`: Custom libraries implemented or adapted for Zivoe.
  - `libraries/FloorMath.sol`: Custom mathematics library for floor math.
  - `libraries/OwnableLocked.sol`: Custom Ownable implementation with immutability.
  - `libraries/ZivoeGTC.sol`: Custom GovernorTimelockController implementation.
  - `libraries/ZivoeTLC.sol`: Custom TimelockController implementation.

- `lockers`: Custom lockers which facilitate ZivoeDAO capital allocations.
  - `lockers/OCC`: **O**n **C**hain **C**redit (_direct loans_)
  - `lockers/OCE`: **O**n **C**hain **E**xponential (_exponentially decaying $ZVE emissions schedule_)
  - `lockers/OCG`: **O**n **C**hain **G**eneric (_for test purposes_)
  - `lockers/OCL`: **O**n **C**hain **L**iquidity (_for liquidity provisioning_)
  - `lockers/OCR`: **O**n **C**hain **R**edemptions (_for redeeming capital_)
  - `lockers/OCT`: **O**n **C**hain **T**reasury (_for asset conversions_)
  - `lockers/OCY`: **O**n **C**hain **Y**ield (_for yield generation_)
  - `lockers/Utility`: Helper contracts (_for utility purposes_)
 
- `misc`: Utility files (templates, suites, et cetera).

## Contact

Website: [zivoe.com](https://zivoe.com/)

Twitter: [@ZivoeProtocol](https://twitter.com/ZivoeProtocol)

Contact: [john@zivoe.com](mailto:john@zivoe.com?subject=[GitHub:zivoe-core-foundry]%20Source%20Han%20San)
