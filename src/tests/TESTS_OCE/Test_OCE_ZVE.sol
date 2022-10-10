// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCE/OCE_ZVE.sol";

contract Test_OCE_ZVE is Utility {

    OCE_ZVE OCE_ZVE_Live;

    function setUp() public {

        deployCore(false);

        simulateITO(10_000_000 * WAD, 10_000_000 * WAD, 10_000_000 * USD, 10_000_000 * USD);

        // TODO: Implement in Utility.sol, a staking simulation after ITO simulation.
        claimITO_and_stakeTokens();

        // Initialize and whitelist OCE_ZVE_Live locker.
        OCE_ZVE_Live = new OCE_ZVE(address(DAO), address(GBL));
        assert(zvl.try_updateIsLocker(address(GBL), address(OCE_ZVE_Live), true));
        
        // DAO pushes 100k $ZVE to OCE_ZVE_Live.
        assert(god.try_push(address(DAO), address(OCE_ZVE_Live), address(ZVE), 100_000 ether));

    }

    function test_OCE_ZVE_Live_init() public {

        // Ownership.
        assertEq(OCE_ZVE_Live.owner(), address(DAO));

        // State variables.
        assertEq(OCE_ZVE_Live.GBL(), address(GBL));
        assertEq(OCE_ZVE_Live.owner(), address(DAO));
        assertEq(OCE_ZVE_Live.lastDistribution(), block.timestamp);
        assertEq(OCE_ZVE_Live.exponentialDecayPerSecond(), RAY * 99999998 / 100000000);

        assert(OCE_ZVE_Live.canPush());
        assert(!OCE_ZVE_Live.canPull());

        // $ZVE balance 100k from setUp().
        assertEq(IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live)), 100_000 ether);

    }

    // Verify pushToLocker() restrictions.
    // This includes:
    //  - The asset pushed from DAO => OCE_ZVE must be $ZVE.

    function test_OCE_ZVE_Live_pushToLocker_restrictions() public {

        // $ZVE balance 100k from setUp().
        assertEq(IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live)), 100_000 ether);

        // Can't push non-ZVE asset to OCE_ZVE.
        assert(!god.try_push(address(DAO), address(OCE_ZVE_Live), address(FRAX), 10_000 ether));
    }


    // Verify forwardEmissions() state changes.

    function test_OCE_ZVE_Live_forwardEmissions_state_changes() public {

        // Supply the OCE_ZVE locker with 1,000,000 ZVE from DAO.
        assert(god.try_push(address(DAO), address(OCE_ZVE_Live), address(ZVE), 1_000_000 ether));

        emit Debug('a', OCE_ZVE_Live.decayAmount(IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live)), 30 days));

        // Warp forward 30 days and call forwardEmissions().
        hevm.warp(block.timestamp + 30 days);

        // TODO: Update this fully for state.

        // Pre-state check.
        assertEq(OCE_ZVE_Live.lastDistribution(), block.timestamp - 30 days);

        OCE_ZVE_Live.forwardEmissions();

        // Post-state check.
        assertEq(OCE_ZVE_Live.lastDistribution(), block.timestamp);

    }

    // Verify amountDistributable() values.

    function test_OCE_ZVE_Live_amountDistributable_example_schedule() public {

        emit Debug('a', OCE_ZVE_Live.exponentialDecayPerSecond());
        emit Debug('b', OCE_ZVE_Live.decayAmount(100000 ether, 30 days * 12));
        emit Debug('b', OCE_ZVE_Live.decayAmount(100000 ether, 30 days * 24));
        emit Debug('b', OCE_ZVE_Live.decayAmount(100000 ether, 30 days * 36));
        emit Debug('b', OCE_ZVE_Live.decayAmount(100000 ether, 30 days * 48));
        emit Debug('b', OCE_ZVE_Live.decayAmount(100000 ether, 30 days * 60));

    }

}
