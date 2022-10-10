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
        assertEq(OCE_ZVE_Live.lastDistribution(), block.timestamp);
        assertEq(OCE_ZVE_Live.exponentialDecayPerSecond(), RAY * 99999998 / 100000000);

        uint256[3] memory _preDistribution;
        _preDistribution[0] = OCE_ZVE_Live.distributionRatioBIPS(0);
        _preDistribution[1] = OCE_ZVE_Live.distributionRatioBIPS(1);
        _preDistribution[2] = OCE_ZVE_Live.distributionRatioBIPS(2);

        assertEq(OCE_ZVE_Live.distributionRatioBIPS(0), 0);
        assertEq(OCE_ZVE_Live.distributionRatioBIPS(1), 0);
        assertEq(OCE_ZVE_Live.distributionRatioBIPS(2), 0);

        assert(OCE_ZVE_Live.canPush());
        assert(!OCE_ZVE_Live.canPull());

        // $ZVE balance 100k from setUp().
        assertEq(IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live)), 100_000 ether);

    }

    // Validate pushToLocker() restrictions.
    // This includes:
    //  - The asset pushed from DAO => OCE_ZVE must be $ZVE.

    function test_OCE_ZVE_Live_pushToLocker_restrictions() public {

        // Can't push non-ZVE asset to OCE_ZVE.
        assert(!god.try_push(address(DAO), address(OCE_ZVE_Live), address(FRAX), 10_000 ether));
    }

    // Validate updateDistributionRatioBIPS() state changes.
    // Validate updateDistributionRatioBIPS() restrictions.
    // This includes:
    //  - Sum of all values in _distributionRatioBIPS must equal 10000.
    //  - _msgSender() must equal TLC (governance contract, "god").

    function test_OCE_ZVE_Live_updateDistributionRatioBIPS_restrictions() public {

        // Sum must equal 10000 (a.k.a. BIPS).
        uint256[3] memory initDistribution = [uint256(0), uint256(0), uint256(0)];
        assert(!god.try_updateDistributionRatioBIPS(address(OCE_ZVE_Live), initDistribution));

        // Sum must equal 10000 (a.k.a. BIPS).
        initDistribution = [uint256(4999), uint256(5000), uint256(0)];
        assert(!god.try_updateDistributionRatioBIPS(address(OCE_ZVE_Live), initDistribution));

        // Does work for 10000 (a.k.a. BIPS).
        initDistribution = [uint256(4999), uint256(5000), uint256(1)];
        assert(god.try_updateDistributionRatioBIPS(address(OCE_ZVE_Live), initDistribution));

        // Caller must be TLC.
        initDistribution = [uint256(4999), uint256(5000), uint256(1)];
        assert(!bob.try_updateDistributionRatioBIPS(address(OCE_ZVE_Live), initDistribution));

    }

    function test_OCE_ZVE_Live_updateDistributionRatioBIPS_state(uint256 random) public {

        uint256 random_0 = random % 10000;
        uint256 random_1 = random % (10000 - random_0);
        uint256 random_2 = 10000 - random_0 - random_1;

        // Pre-state.
        uint256[3] memory _preDistribution;
        _preDistribution[0] = OCE_ZVE_Live.distributionRatioBIPS(0);
        _preDistribution[1] = OCE_ZVE_Live.distributionRatioBIPS(1);
        _preDistribution[2] = OCE_ZVE_Live.distributionRatioBIPS(2);

        assertEq(OCE_ZVE_Live.distributionRatioBIPS(0), 0);
        assertEq(OCE_ZVE_Live.distributionRatioBIPS(1), 0);
        assertEq(OCE_ZVE_Live.distributionRatioBIPS(2), 0);

        _preDistribution[0] = random_0;
        _preDistribution[1] = random_1;
        _preDistribution[2] = random_2;

        assertEq(random_0 + random_1 + random_2, 10000);

        assert(god.try_updateDistributionRatioBIPS(address(OCE_ZVE_Live), _preDistribution));

        // Post-state.
        uint256[3] memory _postDistribution;
        _postDistribution[0] = OCE_ZVE_Live.distributionRatioBIPS(0);
        _postDistribution[1] = OCE_ZVE_Live.distributionRatioBIPS(1);
        _postDistribution[2] = OCE_ZVE_Live.distributionRatioBIPS(2);

        assertEq(_postDistribution[0] + _postDistribution[1] + _postDistribution[2], 10000);

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

        uint256 amountDecaying = 100000 ether;
        uint256 amountDecayed = 0;

        amountDecayed = OCE_ZVE_Live.decayAmount(amountDecaying, 30 days * 12);
        amountDecaying -= amountDecayed;

        emit Debug('a', amountDecayed);
        emit Debug('a', amountDecayed);

        amountDecayed = OCE_ZVE_Live.decayAmount(amountDecaying, 30 days * 12);
        amountDecaying -= amountDecayed;

        emit Debug('a', amountDecayed);
        emit Debug('a', amountDecayed);

        amountDecayed = OCE_ZVE_Live.decayAmount(amountDecaying, 30 days * 12);
        amountDecaying -= amountDecayed;

        emit Debug('a', amountDecayed);
        emit Debug('a', amountDecayed);

        amountDecayed = OCE_ZVE_Live.decayAmount(amountDecaying, 30 days * 12);
        amountDecaying -= amountDecayed;

        emit Debug('a', amountDecayed);
        emit Debug('a', amountDecayed);

        amountDecayed = OCE_ZVE_Live.decayAmount(amountDecaying, 30 days * 12);
        amountDecaying -= amountDecayed;

        emit Debug('a', amountDecayed);
        emit Debug('a', amountDecayed);

    }

}
