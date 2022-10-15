// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeYDL is Utility {
    
    function setUp() public {

        deployCore(false);
        
    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate unlock() state changes.
    // Validate unlock() restrictions.
    // This includes:
    //  - Caller must be ITO

    function test_ZivoeYDL_unlock_restrictions() public {
        
    }

    function test_ZivoeYDL_unlock_state(uint96 random) public {

        uint256 amt = uint256(random) + 1000 * USD; // Minimum amount for ITO of each coin.

        // Pre-state.
        assertEq(YDL.emaSTT(), 0);
        assertEq(YDL.emaJTT(), 0);
        assertEq(YDL.emaYield(), 0);
        assertEq(YDL.lastDistribution(), 0);

        // (address[] memory p_recipients, int256[] memory p_proportion) = YDL.protocolRecipients();
        // (address[] memory r_recipients, int256[] memory r_proportion) = YDL.residualRecipients();

        // (address[] memory p_recipients, int256[] memory p_proportion) = YDL.protocolRecipients();
        // (address[] memory r_recipients, int256[] memory r_proportion) = YDL.residualRecipients();

        assert(!YDL.unlocked());

        // Simulating the ITO will "unlock" the YDL.
        simulateITO(amt, amt, amt /= 10**12, amt /= 10**12);

        // Stake tokens to view downstream YDL accounting effects.
        claimITO_and_approveTokens_and_stakeTokens(true);

        // Post-state.
        assertEq(YDL.lastDistribution(), block.timestamp);

        assertEq(YDL.emaSTT(), zSTT.totalSupply());
        assertEq(YDL.emaJTT(), zSTT.totalSupply());
        assertEq(YDL.emaYield(), 0);

        assert(YDL.unlocked());

    }

    // Validate setTargetAPYBIPS() state changes.
    // Validate setTargetAPYBIPS() restrictions.
    // This includes:
    //  - Caller must be owner() of YDL

    function test_ZivoeYDL_setTargetAPYBIPS_restrictions() public {

    }

    function test_ZivoeYDL_setTargetAPYBIPS_state() public {

    }

    // Validate setTargetRatioBIPS() state changes.
    // Validate setTargetRatioBIPS() restrictions.
    // This includes:
    //  - Caller must be owner() of YDL

    function test_ZivoeYDL_setTargetRatioBIPS_restrictions() public {
        
    }

    function test_ZivoeYDL_setTargetRatioBIPS_state() public {

    }

    // Validate setProtocolEarningsRateBIPS() state changes.
    // Validate setProtocolEarningsRateBIPS() restrictions.
    // This includes:
    //  - Caller must be owner() of YDL

    function test_ZivoeYDL_setProtocolEarningsRateBIPS_restrictions() public {
        
    }

    function test_ZivoeYDL_setProtocolEarningsRateBIPS_state() public {

    }

    // Validate setDistributedAsset() state changes.
    // Validate setDistributedAsset() restrictions.
    // This includes:
    //  - _distributedAsset must be on stablecoinWhitelist
    //  - Caller must be owner() of YDL

    function test_ZivoeYDL_setDistributedAsset_restrictions() public {
        
    }

    function test_ZivoeYDL_setDistributedAsset_state() public {

    }


    // Validate recoverAsset() state changes.
    // Validate recoverAsset() restrictions.
    // This includes:
    //  - Caller must be owner() of YDL ... TODO: Consider this ??
    //  - Can not withdraw distributedAsset (asset != distributedAsset)

    function test_ZivoeYDL_recoverAsset_restrictions() public {
        
    }

    function test_ZivoeYDL_recoverAsset_state() public {

    }

    // Validate updateProtocolRecipients() state changes.
    // Validate updateProtocolRecipients() restrictions.
    // This includes:
    //  - Input parameter arrays must have equal length (recipients.length == proportions.length)
    //  - Sum of proporitions values must equal 10000 (BIPS)
    //  - Caller must be owner() of YDL

    function test_ZivoeYDL_updateProtocolRecipients_restrictions() public {
        
    }

    function test_ZivoeYDL_updateProtocolRecipients_state() public {

    }

    // Validate updateResidualRecipients() state changes.
    // Validate updateResidualRecipients() restrictions.
    // This includes:
    //  - Input parameter arrays must have equal length (recipients.length == proportions.length)
    //  - Sum of proporitions values must equal 10000 (BIPS)
    //  - Caller must be owner() of YDL

    function test_ZivoeYDL_updateResidualRecipients_restrictions() public {
        
    }

    function test_ZivoeYDL_updateResidualRecipients_state() public {

    }

    // Validate distributeYield() state changes.
    // Validate distributeYield() restrictions.
    // This includes:
    //  - Caller must be owner() of YDL

    function test_ZivoeYDL_distributeYield_restrictions() public {
        
    }

    function test_ZivoeYDL_distributeYield_state() public {

    }

    // Validate supplementYield() state changes.
    // Validate supplementYield() restrictions.
    // This includes:
    //  - YDL must be unlocked

    function test_ZivoeYDL_supplementYield_restrictions() public {
        
    }

    function test_ZivoeYDL_supplementYield_state() public {

    }

}
