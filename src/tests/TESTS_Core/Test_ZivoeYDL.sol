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

    // Validate setTargetAPYBIPS() state changes.
    // Validate setTargetAPYBIPS() restrictions.
    // This includes:
    //  - Caller must be owner() of YDL

    // Validate setTargetRatioBIPS() state changes.
    // Validate setTargetRatioBIPS() restrictions.
    // This includes:
    //  - Caller must be owner() of YDL

    // Validate setProtocolEarningsRateBIPS() state changes.
    // Validate setProtocolEarningsRateBIPS() restrictions.
    // This includes:
    //  - Caller must be owner() of YDL

    // Validate setDistributedAsset() state changes.
    // Validate setDistributedAsset() restrictions.
    // This includes:
    //  - _distributedAsset must be on stablecoinWhitelist
    //  - Caller must be owner() of YDL

    // Validate recoverAsset() state changes.
    // Validate recoverAsset() restrictions.
    // This includes:
    //  - Caller must be owner() of YDL ... TODO: Consider this ??
    //  - Can not withdraw distributedAsset (asset != distributedAsset)

    // Validate unlock() state changes.
    // Validate unlock() restrictions.
    // This includes:
    //  - Caller must be ITO

    // Validate updateProtocolRecipients() state changes.
    // Validate updateProtocolRecipients() restrictions.
    // This includes:
    //  - Input parameter arrays must have equal length (recipients.length == proportions.length)
    //  - Sum of proporitions values must equal 10000 (BIPS)
    //  - Caller must be owner() of YDL

    // Validate updateResidualRecipients() state changes.
    // Validate updateResidualRecipients() restrictions.
    // This includes:
    //  - Input parameter arrays must have equal length (recipients.length == proportions.length)
    //  - Sum of proporitions values must equal 10000 (BIPS)
    //  - Caller must be owner() of YDL

    // Validate distributeYield() state changes.
    // Validate distributeYield() restrictions.
    // This includes:
    //  - Caller must be owner() of YDL

    // Validate supplementYield() state changes.
    // Validate supplementYield() restrictions.
    // This includes:
    //  - YDL must be unlocked

}
