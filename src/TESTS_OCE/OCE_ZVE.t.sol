// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

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

    // function X_test_OCE_ZVE_0_pushToLocker_restrictions() public {
    //     // Can't push non-ZVE asset to OCE_ZVE.
    //     assert(!god.try_push(address(DAO), address(OCE_ZVE_0), address(FRAX), 10_000 ether));
    // }

    // function X_test_OCE_ZVE_0_pushToLocker_state_changes() public {
        
    //     // Pre-state check.
    //     assertEq(ZVE.balanceOf(address(stZVE)), 0);
    //     assertEq(ZVE.balanceOf(address(stSTT)), 0);
    //     assertEq(ZVE.balanceOf(address(stJTT)), 0);

    //     // Push 10,000 ZVE to OCE_ZVE.
    //     assert(god.try_push(address(DAO), address(OCE_ZVE_0), address(ZVE), 10_000 ether));

    //     // Post-state check.
    //     // NOTE: foundry-rs throws rational_const error if using "10_000 ether / 2 / 3" as values below.
    //     assertEq(ZVE.balanceOf(address(stZVE)), 1666666666666666666666);
    //     assertEq(ZVE.balanceOf(address(stSTT)), 1666666666666666666666);
    //     assertEq(ZVE.balanceOf(address(stJTT)), 1666666666666666666666);

    //     assertEq(OCE_ZVE_0.nextDistribution(),  block.timestamp + 360 days);
    //     assertEq(OCE_ZVE_0.distributionsMade(),                          1);
    // }

    // // Verify pullFromLocker() restrictions.
    // // Verify pullFromLockerPartial() restrictions.

    // function test_OCE_ZVE_0_pullFromLocker_restrictions() public {
    //     // Can't pull non-ZVE asset to OCE_ZVE.
    //     assert(!god.try_pull(address(DAO), address(OCE_ZVE_0), address(FRAX)));
    // }

    // function test_OCE_ZVE_0_pullFromLockerPartial_restrictions() public {
    //     // Can't pull non-ZVE asset to OCE_ZVE.
    //     assert(!god.try_pullPartial(address(DAO), address(OCE_ZVE_0), address(FRAX), 10_000 ether));
    // }

    // // Verify forwardEmissions() restrictions.
    // // Verify forwardEmissions() state changes.

    // function X_test_OCE_ZVE_0_forwardEmissions_restrictions() public {
        
    //     // Can't forwardEmissions() until initial push from DAO occurs.
    //     assert(!god.try_forwardEmissions(address(OCE_ZVE_0)));

    //     // Push 10,000 ZVE to OCE_ZVE.
    //     assert(god.try_push(address(DAO), address(OCE_ZVE_0), address(ZVE), 10_000 ether));
        
    //     // Warp 1 second before permissible forwardEmissions() call.
    //     hevm.warp(OCE_ZVE_0.nextDistribution());
    //     assert(!god.try_forwardEmissions(address(OCE_ZVE_0)));

    //     // Warp 1 second fruther.
    //     hevm.warp(OCE_ZVE_0.nextDistribution() + 1);
    //     assert(god.try_forwardEmissions(address(OCE_ZVE_0)));
    // }

    // function X_test_OCE_ZVE_0_forwardEmissions_state_changes() public {

    //     // Run initial deposit here (of 10,000 ZVE).
    //     X_test_OCE_ZVE_0_pushToLocker_state_changes();

    //     // Warp time to next permissible forwardEmissions() call (2nd distribution).
    //     hevm.warp(OCE_ZVE_0.nextDistribution() + 1);

    //     uint256 pre_nextDistribution = OCE_ZVE_0.nextDistribution();
    //     uint256 pre_distributionsMade = OCE_ZVE_0.distributionsMade();
    //     uint256 pre_ZVEBalance = ZVE.balanceOf(address(OCE_ZVE_0));

    //     OCE_ZVE_0.forwardEmissions();

    //     uint256 post_nextDistribution = OCE_ZVE_0.nextDistribution();
    //     uint256 post_distributionsMade = OCE_ZVE_0.distributionsMade();
    //     uint256 post_ZVEBalance = ZVE.balanceOf(address(OCE_ZVE_0));

    //     assertEq(post_nextDistribution - pre_nextDistribution,      360 days);
    //     assertEq(post_distributionsMade - pre_distributionsMade,           1);
    //     withinDiff(pre_ZVEBalance - post_ZVEBalance, pre_ZVEBalance / 2,   5);  // 50% distributed (5 wei diff max)
    //     assert(OCE_ZVE_0.canPush());

    //     // Confirm same information for 3rd and 4th distributions.
    //     hevm.warp(OCE_ZVE_0.nextDistribution() + 1);
        
    //     pre_nextDistribution = OCE_ZVE_0.nextDistribution();
    //     pre_distributionsMade = OCE_ZVE_0.distributionsMade();
    //     pre_ZVEBalance = ZVE.balanceOf(address(OCE_ZVE_0));

    //     OCE_ZVE_0.forwardEmissions();

    //     post_nextDistribution = OCE_ZVE_0.nextDistribution();
    //     post_distributionsMade = OCE_ZVE_0.distributionsMade();
    //     post_ZVEBalance = ZVE.balanceOf(address(OCE_ZVE_0));

    //     assertEq(post_nextDistribution - pre_nextDistribution,      360 days);
    //     assertEq(post_distributionsMade - pre_distributionsMade,           1);
    //     withinDiff(pre_ZVEBalance - post_ZVEBalance, pre_ZVEBalance / 2,   5);  // 50% distributed (5 wei diff max)
    //     assert(OCE_ZVE_0.canPush());

    //     hevm.warp(OCE_ZVE_0.nextDistribution() + 1);

    //     pre_nextDistribution = OCE_ZVE_0.nextDistribution();
    //     pre_distributionsMade = OCE_ZVE_0.distributionsMade();
    //     pre_ZVEBalance = ZVE.balanceOf(address(OCE_ZVE_0));

    //     OCE_ZVE_0.forwardEmissions();

    //     post_nextDistribution = OCE_ZVE_0.nextDistribution();
    //     post_distributionsMade = OCE_ZVE_0.distributionsMade();
    //     post_ZVEBalance = ZVE.balanceOf(address(OCE_ZVE_0));

    //     assertEq(post_nextDistribution - pre_nextDistribution,      360 days);
    //     assertEq(post_distributionsMade - pre_distributionsMade,           1);
    //     withinDiff(pre_ZVEBalance - post_ZVEBalance, pre_ZVEBalance / 2,   5);  // 50% distributed (5 wei diff max)
    //     assert(OCE_ZVE_0.canPush());

    //     // Confirm final (5th distribution) distributes all remaining ZVE.
    //     // Confirm that canPush() becomes false.
    //     hevm.warp(OCE_ZVE_0.nextDistribution() + 1);
        
    //     pre_nextDistribution = OCE_ZVE_0.nextDistribution();
    //     pre_distributionsMade = OCE_ZVE_0.distributionsMade();

    //     OCE_ZVE_0.forwardEmissions();

    //     post_nextDistribution = OCE_ZVE_0.nextDistribution();
    //     post_distributionsMade = OCE_ZVE_0.distributionsMade();

    //     assertEq(post_nextDistribution - pre_nextDistribution,   360 days);
    //     assertEq(post_distributionsMade - pre_distributionsMade,        1);
    //     withinDiff(pre_ZVEBalance - post_ZVEBalance, post_ZVEBalance,   5);  // 100% distributed (5 wei diff max, aka "dust" remains)
    //     assert(!OCE_ZVE_0.canPush());
    // }

    // Verify amountDistributable() values.

    function test_OCE_ZVE_0_amountDistributable_0() public {

        emit Debug('a', OCE_ZVE_0.cut());
        emit Debug('b', OCE_ZVE_0.amountDistributable(1000000 ether, 30 days * 12));
        emit Debug('b', OCE_ZVE_0.amountDistributable(1000000 ether, 30 days * 24));
        emit Debug('b', OCE_ZVE_0.amountDistributable(1000000 ether, 30 days * 36));
        emit Debug('b', OCE_ZVE_0.amountDistributable(1000000 ether, 30 days * 48));
        emit Debug('b', OCE_ZVE_0.amountDistributable(1000000 ether, 30 days * 60));

    }

}
