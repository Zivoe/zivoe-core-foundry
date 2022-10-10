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

    function assignRandomDistributionRatio(uint256 random) public returns (uint256[3] memory settings) {

        uint256 random_0 = random % 10000;
        uint256 random_1 = random % (10000 - random_0);
        uint256 random_2 = 10000 - random_0 - random_1;

        settings[0] = random_0;
        settings[1] = random_1;
        settings[2] = random_2;

        assert(god.try_updateDistributionRatioBIPS(address(OCE_ZVE_Live), settings));

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

    function test_OCE_ZVE_Live_forwardEmissions_state(uint256 random) public {
        
        uint256[3] memory settings = assignRandomDistributionRatio(random);

        uint256 amountDecaying = IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live));
        uint256 amountDecayed = 0;
        uint256 i = 0;

        uint256 interval = 1 days;
        uint256 intervals = 360;

        uint256[6] memory balanceData = [
            IERC20(address(ZVE)).balanceOf(address(stZVE)),
            IERC20(address(ZVE)).balanceOf(address(stZVE)),
            IERC20(address(ZVE)).balanceOf(address(stJTT)),
            IERC20(address(ZVE)).balanceOf(address(stJTT)),
            IERC20(address(ZVE)).balanceOf(address(stSTT)),
            IERC20(address(ZVE)).balanceOf(address(stSTT))
        ];

        while (i < intervals) {

            // Warp forward 1 interval.
            hevm.warp(block.timestamp + interval);

            // Pre-state.
            assertEq(OCE_ZVE_Live.lastDistribution(), block.timestamp - interval);
            assertEq(IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live)), amountDecaying);
            balanceData[0] = IERC20(address(ZVE)).balanceOf(address(stZVE));
            balanceData[2] = IERC20(address(ZVE)).balanceOf(address(stSTT));
            balanceData[4] = IERC20(address(ZVE)).balanceOf(address(stJTT));

            amountDecayed = amountDecaying - OCE_ZVE_Live.decay(amountDecaying, interval);

            OCE_ZVE_Live.forwardEmissions();

            // Post-state.
            balanceData[1] = IERC20(address(ZVE)).balanceOf(address(stZVE));
            balanceData[3] = IERC20(address(ZVE)).balanceOf(address(stSTT));
            balanceData[5] = IERC20(address(ZVE)).balanceOf(address(stJTT));

            assertEq(OCE_ZVE_Live.lastDistribution(), block.timestamp);
            withinDiff(
                IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live)), 
                OCE_ZVE_Live.decay(amountDecaying, interval),
                3
            );
            withinDiff(
                balanceData[1] - balanceData[0],
                amountDecayed * settings[0] / 10000,
                3
            );
            withinDiff(
                balanceData[3] - balanceData[2],
                amountDecayed * settings[1] / 10000,
                3
            );
            withinDiff(
                balanceData[5] - balanceData[4],
                amountDecayed * settings[2] / 10000,
                3
            );

            amountDecaying = IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live));

            i++;
        }

    }

    // Verify amountDistributable() values.

    function test_OCE_ZVE_Live_amountDistributable_schedule_hourlyEmissions() public {

        uint256 amountDecaying = 100000 ether;
        uint256 amountDecayed = 0;
        uint256 i = 0;

        uint256 interval = 1 hours;
        uint256 intervals = 360 * 24;

        while (i < intervals) {
            amountDecayed = amountDecaying - OCE_ZVE_Live.decay(amountDecaying, interval);
            amountDecaying = OCE_ZVE_Live.decay(amountDecaying, interval);
            emit Debug('a', amountDecaying);
            emit Debug('a', amountDecayed);
            i++;
        }

        // After 360 days ... 53682667269999381549237 remains (53.68k $ZVE).

    }

    function test_OCE_ZVE_Live_amountDistributable_schedule_dailyEmissions() public {

        uint256 amountDecaying = 100000 ether;
        uint256 amountDecayed = 0;
        uint256 i = 0;

        uint256 interval = 1 days;
        uint256 intervals = 360;

        while (i < intervals) {
            amountDecayed = amountDecaying - OCE_ZVE_Live.decay(amountDecaying, interval);
            amountDecaying = OCE_ZVE_Live.decay(amountDecaying, interval);
            emit Debug('a', amountDecaying);
            emit Debug('a', amountDecayed);
            i++;
        }

        // After 360 days ... 53682667269999381552324 (53.68k $ZVE)

    }

}
