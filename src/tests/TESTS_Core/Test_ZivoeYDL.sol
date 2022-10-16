// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeYDL is Utility {
    
    struct Recipients {
        address[] recipients;
        uint256[] proportion;
    }

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
        
        // Can't call if _msgSendeR() != ITO.
        assert(!bob.try_unlock(address(YDL)));

    }

    function test_ZivoeYDL_unlock_state(uint96 random) public {

        uint256 amt = uint256(random) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        // Pre-state.
        assertEq(YDL.emaSTT(), 0);
        assertEq(YDL.emaJTT(), 0);
        assertEq(YDL.emaYield(), 0);
        assertEq(YDL.lastDistribution(), 0);

        assert(!YDL.unlocked());

        // Simulating the ITO will "unlock" the YDL.
        simulateITO(amt, amt, amt / 10**12, amt / 10**12);

        // Stake tokens to view downstream YDL accounting effects.
        claimITO_and_approveTokens_and_stakeTokens(true);

        // Post-state.
        assertEq(YDL.lastDistribution(), block.timestamp);

        assertEq(YDL.emaSTT(), zSTT.totalSupply());
        assertEq(YDL.emaJTT(), zSTT.totalSupply());
        assertEq(YDL.emaYield(), 0);

        assert(YDL.unlocked());

        (
            address[] memory protocolEarningsRecipients,
            uint256[] memory protocolEarningsProportion,
            address[] memory residualEarningsRecipients,
            uint256[] memory residualEarningsProportion
        ) = YDL.viewDistributions();

        assertEq(protocolEarningsRecipients[0], address(DAO));
        assertEq(protocolEarningsRecipients[1], address(stZVE));
        assertEq(protocolEarningsRecipients.length, 2);

        assertEq(protocolEarningsProportion[0], 7500);
        assertEq(protocolEarningsProportion[1], 2500);
        assertEq(protocolEarningsProportion.length, 2);

        assertEq(residualEarningsRecipients[0], address(stJTT));
        assertEq(residualEarningsRecipients[1], address(stSTT));
        assertEq(residualEarningsRecipients[2], address(stZVE));
        assertEq(residualEarningsRecipients[3], address(DAO));
        assertEq(residualEarningsRecipients.length, 4);

        assertEq(residualEarningsProportion[0], 2500);
        assertEq(residualEarningsProportion[1], 2500);
        assertEq(residualEarningsProportion[2], 2500);
        assertEq(residualEarningsProportion[3], 2500);
        assertEq(residualEarningsProportion.length, 4);

    }

    // Validate setTargetAPYBIPS() state changes.
    // Validate setTargetAPYBIPS() restrictions.
    // This includes:
    //  - Caller must be TLC

    function test_ZivoeYDL_setTargetAPYBIPS_restrictions(uint96 random) public {

        uint256 amt = uint256(random);

        // Can't call if _msgSender() != TLC.
        assert(!bob.try_setTargetAPYBIPS(address(YDL), amt));
        
    }

    function test_ZivoeYDL_setTargetAPYBIPS_state() public {

    }

    // Validate setTargetRatioBIPS() state changes.
    // Validate setTargetRatioBIPS() restrictions.
    // This includes:
    //  - Caller must be TLC

    function test_ZivoeYDL_setTargetRatioBIPS_restrictions(uint96 random) public {
        
        uint256 amt = uint256(random);
        
        // Can't call if _msgSender() != TLC.
        assert(!bob.try_setTargetRatioBIPS(address(YDL), amt));

    }

    function test_ZivoeYDL_setTargetRatioBIPS_state() public {

    }

    // Validate setProtocolEarningsRateBIPS() state changes.
    // Validate setProtocolEarningsRateBIPS() restrictions.
    // This includes:
    //  - Caller must be TLC

    function test_ZivoeYDL_setProtocolEarningsRateBIPS_restrictions(uint96 random) public {
        
        uint256 amt = uint256(random);
        
        // Can't call if _msgSender() != TLC.
        assert(!bob.try_setProtocolEarningsRateBIPS(address(YDL), amt));

    }

    function test_ZivoeYDL_setProtocolEarningsRateBIPS_state() public {

    }

    // Validate setDistributedAsset() state changes.
    // Validate setDistributedAsset() restrictions.
    // This includes:
    //  - _distributedAsset must be on stablecoinWhitelist
    //  - Caller must be TLC

    function test_ZivoeYDL_setDistributedAsset_restrictions() public {
        
    }

    function test_ZivoeYDL_setDistributedAsset_state() public {

    }


    // Validate recoverAsset() state changes.
    // Validate recoverAsset() restrictions.
    // This includes:
    //  - Can not withdraw distributedAsset (asset != distributedAsset)

    function test_ZivoeYDL_recoverAsset_restrictions(uint96 random) public {
        
        // Can't call recoverAsset() if !YDL.unlocked().
        assert(!bob.try_recoverAsset(address(YDL), DAI));

        uint256 amt = uint256(random);

        // Simulating the ITO will "unlock" the YDL, and allow calls to recoverAsset().
        simulateITO(amt, amt, amt / 10**12, amt / 10**12);

        mint("DAI", address(YDL), 1000 ether);

        // Can't call recoverAsset() if asset == distributedAsset().
        assert(!bob.try_recoverAsset(address(YDL), DAI));

    }

    function test_ZivoeYDL_recoverAsset_state(uint96 random) public {

        uint256 amt = uint256(random) + 100 * USD; // Minimum mint() settings.
        
        mint("WETH", address(YDL), amt);
        mint("WBTC", address(YDL), amt);
        mint("FRAX", address(YDL), amt);
        mint("USDC", address(YDL), amt);
        mint("USDT", address(YDL), amt);

        // Simulating the ITO will "unlock" the YDL, and allow calls to recoverAsset().
        simulateITO(amt, amt, amt / 10**12, amt / 10**12);

        // Pre-state.
        assertEq(IERC20(WETH).balanceOf(address(YDL)), amt);
        assertEq(IERC20(WBTC).balanceOf(address(YDL)), amt);
        assertEq(IERC20(FRAX).balanceOf(address(YDL)), amt);
        assertEq(IERC20(USDC).balanceOf(address(YDL)), amt);
        assertEq(IERC20(USDT).balanceOf(address(YDL)), amt);

        uint256 _preDAO_WETH = IERC20(WETH).balanceOf(address(DAO));
        uint256 _preDAO_WBTC = IERC20(WBTC).balanceOf(address(DAO));
        uint256 _preDAO_FRAX = IERC20(FRAX).balanceOf(address(DAO));
        uint256 _preDAO_USDC = IERC20(USDC).balanceOf(address(DAO));
        uint256 _preDAO_USDT = IERC20(USDT).balanceOf(address(DAO));

        // recoverAsset().
        assert(bob.try_recoverAsset(address(YDL), WETH));
        assert(bob.try_recoverAsset(address(YDL), WBTC));
        assert(bob.try_recoverAsset(address(YDL), FRAX));
        assert(bob.try_recoverAsset(address(YDL), USDC));
        assert(bob.try_recoverAsset(address(YDL), USDT));

        // Post-state.
        assertEq(IERC20(WETH).balanceOf(address(YDL)), 0);
        assertEq(IERC20(WBTC).balanceOf(address(YDL)), 0);
        assertEq(IERC20(FRAX).balanceOf(address(YDL)), 0);
        assertEq(IERC20(USDC).balanceOf(address(YDL)), 0);
        assertEq(IERC20(USDT).balanceOf(address(YDL)), 0);

        assertEq(IERC20(WETH).balanceOf(address(DAO)), _preDAO_WETH + amt);
        assertEq(IERC20(WBTC).balanceOf(address(DAO)), _preDAO_WBTC + amt);
        assertEq(IERC20(FRAX).balanceOf(address(DAO)), _preDAO_FRAX + amt);
        assertEq(IERC20(USDC).balanceOf(address(DAO)), _preDAO_USDC + amt);
        assertEq(IERC20(USDT).balanceOf(address(DAO)), _preDAO_USDT + amt);

    }

    // Validate updateProtocolRecipients() state changes.
    // Validate updateProtocolRecipients() restrictions.
    // This includes:
    //  - Input parameter arrays must have equal length (recipients.length == proportions.length)
    //  - Sum of proporitions values must equal 10000 (BIPS)
    //  - Caller must be TLC()

    function test_ZivoeYDL_updateProtocolRecipients_restrictions(uint96 random) public {
        
        address[] memory zeroRecipients = new address[](0);
        uint256[] memory zeroProportions = new uint256[](0);
        address[] memory badRecipients = new address[](3);
        uint256[] memory badProportions = new uint256[](4);
        address[] memory goodRecipients = new address[](4);
        uint256[] memory goodProportions = new uint256[](4);
        
        badRecipients[0] = address(0);
        badRecipients[1] = address(1);
        badRecipients[2] = address(2);
        
        badProportions[0] = 2500;
        badProportions[1] = 2500;
        badProportions[2] = 2500;
        badProportions[3] = 2501;

        goodRecipients[0] = address(0);
        goodRecipients[1] = address(1);
        goodRecipients[2] = address(2);
        goodRecipients[3] = address(3);
        
        goodProportions[0] = 2500;
        goodProportions[1] = 2500;
        goodProportions[2] = 2500;
        goodProportions[3] = 2500;

        // Can't call if _msgSender() != TLC.
        assert(!bob.try_updateProtocolRecipients(address(YDL), goodRecipients, goodProportions));

        // Can't call if recipients.length == proportions.length.
        assert(!god.try_updateProtocolRecipients(address(YDL), badRecipients, goodProportions));

        // Can't call if recipients.length == 0.
        assert(!god.try_updateProtocolRecipients(address(YDL), zeroRecipients, zeroProportions));

        // Can't call if !YDL.unlocked().
        assert(!god.try_updateProtocolRecipients(address(YDL), goodRecipients, goodProportions));

        uint256 amt = uint256(random);

        // Simulating the ITO will "unlock" the YDL, and allow calls to updateProtocolRecipients().
        simulateITO(amt, amt, amt / 10**12, amt / 10**12);

        // Can't call if proportions total != 10000 (BIPS).
        assert(!god.try_updateProtocolRecipients(address(YDL), goodRecipients, badProportions));

        // Example success call.
        assert(god.try_updateProtocolRecipients(address(YDL), goodRecipients, goodProportions));

    }

    function test_ZivoeYDL_updateProtocolRecipients_state(uint96 random) public {

        uint256 amt = uint256(random) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        address[] memory recipients = new address[](4);
        uint256[] memory proportions = new uint256[](4);

        recipients[0] = address(1);
        recipients[1] = address(2);
        recipients[2] = address(3);
        recipients[3] = address(4);

        proportions[0] = 1;
        proportions[1] = 1;
        proportions[2] = 1;
        proportions[3] = 1;

        proportions[0] += amt % 2500;
        proportions[1] += amt % 2500;
        proportions[2] += amt % 2500;
        proportions[3] += amt % 2500;

        if (proportions[0] + proportions[1] + proportions[2] + proportions[3] < 10000) {
            proportions[3] = 10000 - proportions[0] - proportions[1] - proportions[2];
        }

        // Simulating the ITO will "unlock" the YDL, and allow calls to updateProtocolRecipients().
        simulateITO(amt, amt, amt / 10**12, amt / 10**12);

        // Pre-state.
        (
            address[] memory protocolEarningsRecipients,
            uint256[] memory protocolEarningsProportion,
            ,
        ) = YDL.viewDistributions();

        assertEq(protocolEarningsRecipients[0], address(DAO));
        assertEq(protocolEarningsRecipients[1], address(stZVE));
        assertEq(protocolEarningsRecipients.length, 2);

        assertEq(protocolEarningsProportion[0], 7500);
        assertEq(protocolEarningsProportion[1], 2500);
        assertEq(protocolEarningsProportion.length, 2);

        // updateProtocolRecipients().        
        assert(god.try_updateProtocolRecipients(address(YDL), recipients, proportions));

        // Post-state.
        (
            protocolEarningsRecipients,
            protocolEarningsProportion,
            ,
        ) = YDL.viewDistributions();

        assertEq(protocolEarningsRecipients[0], address(1));
        assertEq(protocolEarningsRecipients[1], address(2));
        assertEq(protocolEarningsRecipients[2], address(3));
        assertEq(protocolEarningsRecipients[3], address(4));
        assertEq(protocolEarningsRecipients.length, 4);

        assertEq(protocolEarningsProportion[0], proportions[0]);
        assertEq(protocolEarningsProportion[1], proportions[1]);
        assertEq(protocolEarningsProportion[2], proportions[2]);
        assertEq(protocolEarningsProportion[3], proportions[3]);
        assertEq(protocolEarningsProportion.length, 4);

    }

    // Validate updateResidualRecipients() state changes.
    // Validate updateResidualRecipients() restrictions.
    // This includes:
    //  - Input parameter arrays must have equal length (recipients.length == proportions.length)
    //  - Sum of proporitions values must equal 10000 (BIPS)
    //  - Caller must be TLC

    function test_ZivoeYDL_updateResidualRecipients_restrictions(uint96 random) public {
        
        address[] memory zeroRecipients = new address[](0);
        uint256[] memory zeroProportions = new uint256[](0);
        address[] memory badRecipients = new address[](3);
        uint256[] memory badProportions = new uint256[](4);
        address[] memory goodRecipients = new address[](4);
        uint256[] memory goodProportions = new uint256[](4);
        
        badRecipients[0] = address(0);
        badRecipients[1] = address(1);
        badRecipients[2] = address(2);
        
        badProportions[0] = 2500;
        badProportions[1] = 2500;
        badProportions[2] = 2500;
        badProportions[3] = 2501;

        goodRecipients[0] = address(0);
        goodRecipients[1] = address(1);
        goodRecipients[2] = address(2);
        goodRecipients[3] = address(3);
        
        goodProportions[0] = 2500;
        goodProportions[1] = 2500;
        goodProportions[2] = 2500;
        goodProportions[3] = 2500;

        // Can't call if _msgSender() != TLC.
        assert(!bob.try_updateResidualRecipients(address(YDL), goodRecipients, goodProportions));

        // Can't call if recipients.length == proportions.length.
        assert(!god.try_updateResidualRecipients(address(YDL), badRecipients, goodProportions));

        // Can't call if recipients.length == 0.
        assert(!god.try_updateResidualRecipients(address(YDL), zeroRecipients, zeroProportions));

        // Can't call if !YDL.unlocked().
        assert(!god.try_updateResidualRecipients(address(YDL), goodRecipients, goodProportions));

        uint256 amt = uint256(random);

        // Simulating the ITO will "unlock" the YDL, and allow calls to updateProtocolRecipients().
        simulateITO(amt, amt, amt / 10**12, amt / 10**12);

        // Can't call if proportions total != 10000 (BIPS).
        assert(!god.try_updateResidualRecipients(address(YDL), goodRecipients, badProportions));

        // Example success call.
        assert(god.try_updateResidualRecipients(address(YDL), goodRecipients, goodProportions));
        
    }

    function test_ZivoeYDL_updateResidualRecipients_state(uint96 random) public {

        uint256 amt = uint256(random) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        address[] memory recipients = new address[](4);
        uint256[] memory proportions = new uint256[](4);

        recipients[0] = address(1);
        recipients[1] = address(2);
        recipients[2] = address(3);
        recipients[3] = address(4);

        proportions[0] = 1;
        proportions[1] = 1;
        proportions[2] = 1;
        proportions[3] = 1;

        proportions[0] += amt % 2500;
        proportions[1] += amt % 2500;
        proportions[2] += amt % 2500;
        proportions[3] += amt % 2500;

        if (proportions[0] + proportions[1] + proportions[2] + proportions[3] < 10000) {
            proportions[3] = 10000 - proportions[0] - proportions[1] - proportions[2];
        }

        // Simulating the ITO will "unlock" the YDL, and offer initial settings.
        simulateITO(amt, amt, amt / 10**12, amt / 10**12);

        // Pre-state.
        (
            ,
            ,
            address[] memory residualEarningsRecipients,
            uint256[] memory residualEarningsProportion
        ) = YDL.viewDistributions();

        assertEq(residualEarningsRecipients[0], address(stJTT));
        assertEq(residualEarningsRecipients[1], address(stSTT));
        assertEq(residualEarningsRecipients[2], address(stZVE));
        assertEq(residualEarningsRecipients[3], address(DAO));
        assertEq(residualEarningsRecipients.length, 4);

        assertEq(residualEarningsProportion[0], 2500);
        assertEq(residualEarningsProportion[1], 2500);
        assertEq(residualEarningsProportion[2], 2500);
        assertEq(residualEarningsProportion[3], 2500);
        assertEq(residualEarningsProportion.length, 4);

        // updateProtocolRecipients().        
        assert(god.try_updateResidualRecipients(address(YDL), recipients, proportions));

        // Post-state.
        (
            ,
            ,
            residualEarningsRecipients,
            residualEarningsProportion
        ) = YDL.viewDistributions();

        assertEq(residualEarningsRecipients[0], address(1));
        assertEq(residualEarningsRecipients[1], address(2));
        assertEq(residualEarningsRecipients[2], address(3));
        assertEq(residualEarningsRecipients[3], address(4));
        assertEq(residualEarningsRecipients.length, 4);

        assertEq(residualEarningsProportion[0], proportions[0]);
        assertEq(residualEarningsProportion[1], proportions[1]);
        assertEq(residualEarningsProportion[2], proportions[2]);
        assertEq(residualEarningsProportion[3], proportions[3]);
        assertEq(residualEarningsProportion.length, 4);

    }

    // Validate distributeYield() state changes.
    // Validate distributeYield() restrictions.
    // This includes:
    //  - Caller must be TLC

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
