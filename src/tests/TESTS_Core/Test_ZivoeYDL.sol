// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../libraries/ZivoeMath.sol";

contract Test_ZivoeYDL is Utility {
    
    using ZivoeMath for uint256;

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

    function updateRecipients_restrictions_init() public pure returns (
        address[] memory zeroRecipients,
        uint256[] memory zeroProportions,
        address[] memory badRecipients,
        uint256[] memory badProportions,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
    ) 
    {
        zeroRecipients = new address[](0);
        zeroProportions = new uint256[](0);
        badRecipients = new address[](3);
        badProportions = new uint256[](4);
        goodRecipients = new address[](4);
        goodProportions = new uint256[](4);
        
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
    }

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate unlock() state changes.
    // Validate unlock() restrictions.
    // This includes:
    //  - Caller must be ITO

    function test_ZivoeYDL_unlock_restrictions() public {
        
        // Can't call if _msgSendeR() != ITO.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::unlock() _msgSender() != IZivoeGlobals_YDL(GBL).ITO()");
        YDL.unlock();
        hevm.stopPrank();
    }

    function test_ZivoeYDL_unlock_state(uint96 random) public {

        uint256 amount = uint256(random) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        // Pre-state.
        assertEq(YDL.emaSTT(), 0);
        assertEq(YDL.emaJTT(), 0);
        assertEq(YDL.emaYield(), 0);
        assertEq(YDL.lastDistribution(), 0);

        assert(!YDL.unlocked());

        // Simulating the ITO will "unlock" the YDL.
        simulateITO(amount, amount, amount / 10**12, amount / 10**12);

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

        uint256 amount = uint256(random);

        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::setTargetAPYBIPS() _msgSender() != TLC()");
        YDL.setTargetAPYBIPS(amount);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_setTargetAPYBIPS_state(uint96 random) public {

        uint256 amount = uint256(random);

        // Pre-state.
        assertEq(YDL.targetAPYBIPS(), 800);
        
        // setTargetAPYBIPS().
        assert(god.try_setTargetAPYBIPS(address(YDL), amount));

        // Post-state.
        assertEq(YDL.targetAPYBIPS(), amount);

    }

    // Validate setTargetRatioBIPS() state changes.
    // Validate setTargetRatioBIPS() restrictions.
    // This includes:
    //  - Caller must be TLC

    function test_ZivoeYDL_setTargetRatioBIPS_restrictions(uint96 random) public {
        
        uint256 amount = uint256(random);
        
        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::setTargetRatioBIPS() _msgSender() != TLC()");
        YDL.setTargetRatioBIPS(amount);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_setTargetRatioBIPS_state(uint96 random) public {

        uint256 amount = uint256(random);

        // Pre-state.
        assertEq(YDL.targetRatioBIPS(), 16250);
        
        // setTargetRatioBIPS().
        assert(god.try_setTargetRatioBIPS(address(YDL), amount));

        // Post-state.
        assertEq(YDL.targetRatioBIPS(), amount);

    }

    // Validate setProtocolEarningsRateBIPS() state changes.
    // Validate setProtocolEarningsRateBIPS() restrictions.
    // This includes:
    //  - Caller must be TLC
    //  - Amount must be <= 10000.

    function test_ZivoeYDL_setProtocolEarningsRateBIPS_restrictions_msgSender(uint96 random) public {
        
        uint256 amount = uint256(random);
        
        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::setProtocolEarningsRateBIPS() _msgSender() != TLC()");
        YDL.setProtocolEarningsRateBIPS(amount);
        hevm.stopPrank();

        // Example success.
        assert(god.try_setProtocolEarningsRateBIPS(address(YDL), 10000));
    }

    function test_ZivoeYDL_setProtocolEarningsRateBIPS_restrictions_max10000() public {
        
        // Can't call if > 10000.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::setProtocolEarningsRateBIPS() _protocolEarningsRateBIPS > 10000");
        YDL.setProtocolEarningsRateBIPS(10001);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_setProtocolEarningsRateBIPS_state(uint96 random) public {

        uint256 amount = uint256(random) % 10000;

        // Pre-state.
        assertEq(YDL.protocolEarningsRateBIPS(), 2000);
        
        // setProtocolEarningsRateBIPS().
        assert(god.try_setProtocolEarningsRateBIPS(address(YDL), amount));

        // Post-state.
        assertEq(YDL.protocolEarningsRateBIPS(), amount);

    }

    // Validate setDistributedAsset() state changes.
    // Validate setDistributedAsset() restrictions.
    // This includes:
    //  - _distributedAsset must be on stablecoinWhitelist
    //  - Caller must be TLC

    function test_ZivoeYDL_setDistributedAsset_restrictions_distributedAsset() public {
        
        // Can't call distributedAsset == _distributedAsset.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::setDistributedAsset() _distributedAsset == distributedAsset");
        YDL.setDistributedAsset(DAI);
        hevm.stopPrank();

        // Example success call.
        assert(god.try_setDistributedAsset(address(YDL), USDC));

    }

    function test_ZivoeYDL_setDistributedAsset_restrictions_msgSender() public {
        
        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::setDistributedAsset() _msgSender() != TLC()");
        YDL.setDistributedAsset(USDC);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_setDistributedAsset_restrictions_notWhitelisted() public {

        // Can't call if asset not whitelisted.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::setDistributedAsset() !IZivoeGlobals_YDL(GBL).stablecoinWhitelist(_distributedAsset)");
        YDL.setDistributedAsset(WETH);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_setDistributedAsset_state(uint96 random) public {

        uint256 amount = uint256(random);

        mint("DAI", address(YDL), amount);

        // Pre-state.
        assertEq(YDL.distributedAsset(), DAI);
        assertEq(IERC20(DAI).balanceOf(address(YDL)), amount);
        assertEq(IERC20(DAI).balanceOf(address(DAO)), 0);

        // Example success call.
        assert(god.try_setDistributedAsset(address(YDL), USDC));

        // Post-state.
        assertEq(YDL.distributedAsset(), USDC);
        assertEq(IERC20(DAI).balanceOf(address(YDL)), 0);
        assertEq(IERC20(DAI).balanceOf(address(DAO)), amount);
    }


    // Validate recoverAsset() state changes.
    // Validate recoverAsset() restrictions.
    // This includes:
    //  - Can not withdraw distributedAsset (asset != distributedAsset)

    function test_ZivoeYDL_recoverAsset_restrictions_locked() public {
        
        // Can't call recoverAsset() if !YDL.unlocked().
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::recoverAsset() !unlocked");
        YDL.recoverAsset(DAI);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_recoverAsset_restrictions_distributedAsset(uint96 random) public {

        uint256 amount = uint256(random);

        // Simulating the ITO will "unlock" the YDL, and allow calls to recoverAsset().
        simulateITO(amount, amount, amount / 10**12, amount / 10**12);

        mint("DAI", address(YDL), 1000 ether);

        // Can't call recoverAsset() if asset == distributedAsset().
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::recoverAsset() asset == distributedAsset");
        YDL.recoverAsset(DAI);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_recoverAsset_state(uint96 random) public {

        uint256 amount = uint256(random) + 100 * USD; // Minimum mint() settings.
        
        mint("WETH", address(YDL), amount);
        mint("WBTC", address(YDL), amount);
        mint("FRAX", address(YDL), amount);
        mint("USDC", address(YDL), amount);
        mint("USDT", address(YDL), amount);

        // Simulating the ITO will "unlock" the YDL, and allow calls to recoverAsset().
        simulateITO(amount, amount, amount / 10**12, amount / 10**12);

        // Pre-state.
        assertEq(IERC20(WETH).balanceOf(address(YDL)), amount);
        assertEq(IERC20(WBTC).balanceOf(address(YDL)), amount);
        assertEq(IERC20(FRAX).balanceOf(address(YDL)), amount);
        assertEq(IERC20(USDC).balanceOf(address(YDL)), amount);
        assertEq(IERC20(USDT).balanceOf(address(YDL)), amount);

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

        assertEq(IERC20(WETH).balanceOf(address(DAO)), _preDAO_WETH + amount);
        assertEq(IERC20(WBTC).balanceOf(address(DAO)), _preDAO_WBTC + amount);
        assertEq(IERC20(FRAX).balanceOf(address(DAO)), _preDAO_FRAX + amount);
        assertEq(IERC20(USDC).balanceOf(address(DAO)), _preDAO_USDC + amount);
        assertEq(IERC20(USDT).balanceOf(address(DAO)), _preDAO_USDT + amount);

    }

    // Validate updateProtocolRecipients() state changes.
    // Validate updateProtocolRecipients() restrictions.
    // This includes:
    //  - Input parameter arrays must have equal length (recipients.length == proportions.length)
    //  - Sum of proporitions values must equal 10000 (BIPS)
    //  - Caller must be TLC()

    function test_ZivoeYDL_updateProtocolRecipients_restrictions_msgSender() public {
        
        (,,,,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::updateProtocolRecipients() _msgSender() != TLC()");
        YDL.updateProtocolRecipients(goodRecipients, goodProportions);
        hevm.stopPrank();

    }

    function test_ZivoeYDL_updateProtocoRecipients_restrictions_length() public {
        
        (,,
        address[] memory badRecipients,
        ,,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        // Can't call if recipients.length == proportions.length.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateProtocolRecipients() recipients.length != proportions.length || recipients.length == 0");
        YDL.updateProtocolRecipients(badRecipients, goodProportions);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateProtocolRecipients_restrictions_recipientsLength0() public {
        
        (address[] memory zeroRecipients,
        uint256[] memory zeroProportions,
        ,,,
        ) = updateRecipients_restrictions_init();


        // Can't call if recipients.length == 0.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateProtocolRecipients() recipients.length != proportions.length || recipients.length == 0");
        YDL.updateProtocolRecipients(zeroRecipients, zeroProportions);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateProtocolRecipients_restrictions_locked() public {
        
        (,,,,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        // Can't call if !YDL.unlocked().
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateProtocolRecipients() !unlocked");
        YDL.updateProtocolRecipients(goodRecipients, goodProportions);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateProtocolRecipients_restrictions_maxProportions(uint96 random) public {
        
        (,,,
        uint256[] memory badProportions,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        uint256 amount = uint256(random);

        // Simulating the ITO will "unlock" the YDL, and allow calls to updateProtocolRecipients().
        simulateITO(amount, amount, amount / 10**12, amount / 10**12);

        // Can't call if proportions total != 10000 (BIPS).
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateProtocolRecipients() proportionTotal != BIPS (10,000)");
        YDL.updateProtocolRecipients(goodRecipients, badProportions);
        hevm.stopPrank();

        // Example success call.
        assert(god.try_updateProtocolRecipients(address(YDL), goodRecipients, goodProportions));
    }

    function test_ZivoeYDL_updateProtocolRecipients_state(uint96 random) public {

        uint256 amount = uint256(random) + 1000 ether; // Minimum amount $1,000 USD for each coin.

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

        proportions[0] += amount % 2500;
        proportions[1] += amount % 2500;
        proportions[2] += amount % 2500;
        proportions[3] += amount % 2500;

        if (proportions[0] + proportions[1] + proportions[2] + proportions[3] < 10000) {
            proportions[3] = 10000 - proportions[0] - proportions[1] - proportions[2];
        }

        // Simulating the ITO will "unlock" the YDL, and allow calls to updateProtocolRecipients().
        simulateITO(amount, amount, amount / 10**12, amount / 10**12);

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

    function test_ZivoeYDL_updateResidualRecipients_restrictions_msgSender() public {
        
        (,,,,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::updateResidualRecipients() _msgSender() != TLC()");
        YDL.updateResidualRecipients(goodRecipients, goodProportions);
        hevm.stopPrank();

    }

    function test_ZivoeYDL_updateResidualRecipients_restrictions_length() public {
        
        (,,
        address[] memory badRecipients,
        ,,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        // Can't call if recipients.length == proportions.length.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateResidualRecipients() recipients.length != proportions.length || recipients.length == 0");
        YDL.updateResidualRecipients(badRecipients, goodProportions);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateResidualRecipients_restrictions_recipientsLength0() public {
        
        (address[] memory zeroRecipients,
        uint256[] memory zeroProportions,
        ,,,
        ) = updateRecipients_restrictions_init();


        // Can't call if recipients.length == 0.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateResidualRecipients() recipients.length != proportions.length || recipients.length == 0");
        YDL.updateResidualRecipients(zeroRecipients, zeroProportions);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateResidualRecipients_restrictions_locked() public {
        
        (,,,,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        // Can't call if !YDL.unlocked().
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateResidualRecipients() !unlocked");
        YDL.updateResidualRecipients(goodRecipients, goodProportions);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateResidualRecipients_restrictions_maxProportions(uint96 random) public {
        
        (,,,
        uint256[] memory badProportions,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        uint256 amount = uint256(random);

        // Simulating the ITO will "unlock" the YDL, and allow calls to updateResidualRecipients().
        simulateITO(amount, amount, amount / 10**12, amount / 10**12);

        // Can't call if proportions total != 10000 (BIPS).
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateResidualRecipients() proportionTotal != BIPS (10,000)");
        YDL.updateResidualRecipients(goodRecipients, badProportions);
        hevm.stopPrank();

        // Example success call.
        assert(god.try_updateResidualRecipients(address(YDL), goodRecipients, goodProportions));
    }

    function test_ZivoeYDL_updateResidualRecipients_state(uint96 random) public {

        uint256 amount = uint256(random) + 1000 ether; // Minimum amount $1,000 USD for each coin.

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

        proportions[0] += amount % 2500;
        proportions[1] += amount % 2500;
        proportions[2] += amount % 2500;
        proportions[3] += amount % 2500;

        if (proportions[0] + proportions[1] + proportions[2] + proportions[3] < 10000) {
            proportions[3] = 10000 - proportions[0] - proportions[1] - proportions[2];
        }

        // Simulating the ITO will "unlock" the YDL, and offer initial settings.
        simulateITO(amount, amount, amount / 10**12, amount / 10**12);

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
    //  - YDL must be unlocked
    //  - block.timestamp >= lastDistribution + daysBetweenDistributions * 86400

    function test_ZivoeYDL_distributeYield_restrictions_locked() public {

        // Can't call distributeYield() if !YDL.unlocked().
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::distributeYield() !unlocked");
        YDL.distributeYield();
        hevm.stopPrank();
    }

    function test_ZivoeYDL_distributeYield_restrictions_distributionPeriod(
        uint96 randomSenior, 
        uint96 randomJunior
    ) 
    public
    {
        uint256 amtSenior = uint256(randomSenior) + 1000 ether; // Minimum amount $1,000 USD for each coin.
        uint256 amtJunior = uint256(randomJunior) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        // Simulating the ITO will "unlock" the YDL, and allow calls to recoverAsset().
        simulateITO_byTranche_stakeTokens(amtSenior, amtJunior);
        
        // Can't call distributeYield() if block.timestamp < lastDistribution + daysBetweenDistributions * 86400
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::distributeYield() block.timestamp < lastDistribution + daysBetweenDistributions * 86400");
        YDL.distributeYield();
        hevm.stopPrank();

        // Must warp forward to make successfull distributYield() call.
        hevm.warp(YDL.lastDistribution() + YDL.daysBetweenDistributions() * 86400);

        // mint().
        mint("DAI", address(YDL), uint256(randomSenior));

        // Example success.
        assert(bob.try_distributeYield(address(YDL)));
    }

    function test_ZivoeYDL_distributeYield_state(uint96 randomSenior, uint96 randomJunior) public {

        uint256 amtSenior = uint256(randomSenior) + 1000 ether; // Minimum amount $1,000 USD for each coin.
        uint256 amtJunior = uint256(randomJunior) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        // Simulating the ITO will "unlock" the YDL, and allow calls to recoverAsset().
        simulateITO_byTranche_stakeTokens(amtSenior, amtJunior);

        // Must warp forward to make successfull distributYield() call.
        hevm.warp(YDL.lastDistribution() + YDL.daysBetweenDistributions() * 86400);

        mint("DAI", address(YDL), uint256(amtSenior));

        (uint256 seniorSupp, uint256 juniorSupp) = GBL.adjustedSupplies();

        (
            uint256[] memory _protocol,
            uint256 _seniorTranche,
            uint256 _juniorTranche,
            uint256[] memory _residual
        ) = YDL.earningsTrancheuse(seniorSupp, juniorSupp);

        // Pre-state.
        assertEq(YDL.numDistributions(), 0);

        assertEq(YDL.emaYield(), 0);
        assertEq(YDL.emaSTT(), zSTT.totalSupply());
        assertEq(YDL.emaJTT(), zJTT.totalSupply());

        // distributeYield().
        YDL.distributeYield();

        // Post-state.
        assertEq(YDL.emaYield(), uint256(amtSenior));

        assertEq(YDL.emaSTT(), zSTT.totalSupply()); // Note: Shouldn't change unless deposits occured to ZVT.
        assertEq(YDL.emaJTT(), zJTT.totalSupply()); // Note: Shouldn't change unless deposits occured to ZVT.

        assertEq(YDL.numDistributions(), 1);

    }

    // Validate supplementYield() state changes.
    // Validate supplementYield() restrictions.
    // This includes:
    //  - YDL must be unlocked

    function test_ZivoeYDL_supplementYield_restrictions(uint96 random) public {
        
        // Can't call if !YDL.unlocked().
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::supplementYield() !unlocked");
        YDL.supplementYield(uint256(random));
        hevm.stopPrank();
    }

    function test_ZivoeYDL_supplementYield_state(uint96 randomSenior, uint96 randomJunior) public {

        uint256 amtSenior = uint256(randomSenior) + 1000 ether; // Minimum amount $1,000 USD for each coin.
        uint256 amtJunior = uint256(randomJunior) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        // Simulating the ITO will "unlock" the YDL, and allow calls to recoverAsset().
        simulateITO_byTranche_stakeTokens(amtSenior, amtJunior);

        uint256 deposit = uint256(randomSenior) + 10000 ether;
        mint("DAI", address(bob), deposit);

        // Pre-state.
        assertEq(IERC20(DAI).balanceOf(address(stSTT)), 0);
        assertEq(IERC20(DAI).balanceOf(address(stJTT)), 0);
        
        // supplementYield().
        assert(bob.try_approveToken(address(DAI), address(YDL), deposit));
        assert(bob.try_supplementYield(address(YDL), deposit));
        
        // Post-state.
        (uint256 seniorSupp,) = GBL.adjustedSupplies();
    
        uint256 seniorRate = YDL.seniorRateNominal_RAY(
            deposit, 
            seniorSupp, 
            YDL.targetAPYBIPS(), 
            YDL.daysBetweenDistributions()
        );
        uint256 toSenior = (deposit * seniorRate) / RAY;
        uint256 toJunior = deposit.zSub(toSenior);

        assertEq(IERC20(DAI).balanceOf(address(stSTT)), toSenior);
        assertEq(IERC20(DAI).balanceOf(address(stJTT)), toJunior);

    }

}
