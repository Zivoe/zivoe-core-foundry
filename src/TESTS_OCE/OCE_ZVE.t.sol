// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Basic/Utility.sol";

import "../ZivoeOCELockers/OCE_ZVE.sol";

contract OCL_ZVE_CRV_0Test is Utility {

    OCE_ZVE OCE_ZVE_0;

    function setUp() public {

        setUpFundedDAO();

        // Initialize and whitelist OCELocker
        OCE_ZVE_0 = new OCE_ZVE(address(DAO), address(GBL));
        god.try_modifyLockerWhitelist(address(DAO), address(OCE_ZVE_0), true);

    }

    function test_OCE_ZVE_0_init() public {
        assertEq(OCE_ZVE_0.owner(),     address(DAO));
        assertEq(OCE_ZVE_0.GBL(),       address(GBL));

        assert(OCE_ZVE_0.canPush());
    }

    // // Verify pushToLocker() restrictions.
    // // Verify pushToLocker() state changes.

    function test_OCE_ZVE_0_pushToLocker_restrictions() public {
        // Can't push non-ZVE asset to OCE_ZVE.
        assert(!god.try_push(address(DAO), address(OCE_ZVE_0), address(FRAX), 10_000 ether));
    }

    // Verify forwardEmissions() state changes.

    function test_OCE_ZVE_0_forwardEmissions_state_changes() public {

        // Supply the OCE_ZVE locker with 1,000,000 ZVE from DAO.
        assert(god.try_push(address(DAO), address(OCE_ZVE_0), address(ZVE), 1_000_000 ether));

        emit Debug('a', OCE_ZVE_0.decayAmount(IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_0)), 30 days));

        // Warp forward 30 days and call forwardEmissions().
        hevm.warp(block.timestamp + 30 days);

        // Pre-state check.
        assertEq(OCE_ZVE_0.lastDistribution(), block.timestamp - 30 days);

        OCE_ZVE_0.forwardEmissions();

        // Post-state check.
        assertEq(OCE_ZVE_0.lastDistribution(), block.timestamp);

    }

    // Verify amountDistributable() values.

    function test_OCE_ZVE_0_amountDistributable_example_schedule() public {

        emit Debug('a', OCE_ZVE_0.exponentialDecayPerSecond());
        emit Debug('b', OCE_ZVE_0.decayAmount(1000000 ether, 30 days * 12));
        emit Debug('b', OCE_ZVE_0.decayAmount(1000000 ether, 30 days * 24));
        emit Debug('b', OCE_ZVE_0.decayAmount(1000000 ether, 30 days * 36));
        emit Debug('b', OCE_ZVE_0.decayAmount(1000000 ether, 30 days * 48));
        emit Debug('b', OCE_ZVE_0.decayAmount(1000000 ether, 30 days * 60));

    }

}
