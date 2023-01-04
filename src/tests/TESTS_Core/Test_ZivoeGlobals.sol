// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCG/OCG_Defaults.sol";

contract Test_ZivoeGlobals is Utility {

    OCG_Defaults GenericDefaultsLocker;

    function setUp() public {
        deployCore(false);
    }

    // Validate restrictions of increaseDefaults() / decreaseDefaults().
    // This includes:
    //  - _msgSender() must be a whitelisted ZivoeLocker.
    //  - Undeflow checks.

    function test_ZivoeGlobals_restrictions_increaseDefaults_directly() public {
        // Ensure non-whitelisted address may not call increase default, directly via ZivoeGlobals.sol.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::increaseDefaults() !isLocker[_msgSender()]");
        GBL.increaseDefaults(100 ether);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_increaseDefaults_indirectly() public {
        // Create GenericDefaults locker, with default adjustment capability, add this to whitelist.
        GenericDefaultsLocker = new OCG_Defaults(address(DAO), address(GBL));
        assert(zvl.try_updateIsLocker(address(GBL), address(GenericDefaultsLocker), true));

        // Ensure non-whitelisted address may not call increase default, directly via ZivoeGlobals.sol.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCG_Defaults::onlyGovernance() _msgSender!= IZivoeGlobals_OCG_Defaults(GBL).TLC()");
        GenericDefaultsLocker.increaseDefaults(100 ether);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_decreaseDefaults_directly() public {
        // Ensure non-whitelisted address may not call decrease default, directly via ZivoeGlobals.sol.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::decreaseDefaults() !isLocker[_msgSender()]");
        GBL.decreaseDefaults(100 ether);
        hevm.stopPrank();
    }
    
    function test_ZivoeGlobals_restrictions_decreaseDefaults_indirectly() public {
        // Create GenericDefaults locker, with default adjustment capability, add this to whitelist.
        GenericDefaultsLocker = new OCG_Defaults(address(DAO), address(GBL));
        assert(zvl.try_updateIsLocker(address(GBL), address(GenericDefaultsLocker), true));

        // Ensure non-whitelisted address may not call decrease default, directly via ZivoeGlobals.sol.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCG_Defaults::onlyGovernance() _msgSender!= IZivoeGlobals_OCG_Defaults(GBL).TLC()");
        GenericDefaultsLocker.decreaseDefaults(100 ether);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_decreaseDefaults_underflow() public {
        // Create GenericDefaults locker, with default adjustment capability, add this to whitelist.
        GenericDefaultsLocker = new OCG_Defaults(address(DAO), address(GBL));
        assert(zvl.try_updateIsLocker(address(GBL), address(GenericDefaultsLocker), true));
        // Ensure non-whitelisted address may not call increase default, directly via ZivoeGlobals.sol.
        assertEq(GBL.defaults(), 0);
        hevm.startPrank(address(GenericDefaultsLocker));
        hevm.expectRevert(stdError.arithmeticError);
        GBL.decreaseDefaults(1 ether);
        hevm.stopPrank();
    }
    
    // Validate state changes of increaseDefaults() / decreaseDefaults().

    function test_ZivoeGlobals_increase_or_decreaseDefaults_state(uint96 increaseAmountIn) public {
        
        uint256 increaseAmount = uint256(increaseAmountIn);

        // Create GenericDefaults locker, with default adjustment capability, add this to whitelist.
        GenericDefaultsLocker = new OCG_Defaults(address(DAO), address(GBL));
        assert(zvl.try_updateIsLocker(address(GBL), address(GenericDefaultsLocker), true));

        // Pre-state.
        assertEq(GBL.defaults(), 0);

        assert(god.try_increaseDefaults(address(GenericDefaultsLocker), increaseAmount));

        // Post-state, increaseDefaults().
        assertEq(GBL.defaults(), increaseAmount);

        assert(god.try_decreaseDefaults(address(GenericDefaultsLocker), increaseAmount));

        // Post-state, decreaseDefaults().
        assertEq(GBL.defaults(), 0);

    }

    // Validate restrictions updateIsKeeper() / updateIsLocker() / updateStablecoinWhitelist().
    // Validate state changes updateIsKeeper() / updateIsLocker() / updateStablecoinWhitelist().
    // Note: These functions are managed by Zivoe Lab / Dev entity ("ZVL").

    function test_ZivoeGlobals_restrictions_onlyZVL_updateIsKeeper() public {
        
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::onlyZVL() _msgSender() != ZVL");
        GBL.updateIsKeeper(address(1), true);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_onlyZVL_updateIsLocker() public {

        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::onlyZVL() _msgSender() != ZVL");
        GBL.updateIsLocker(address(1), true);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_onlyZVL_updateStablecoinWhitelist() public {

        assert(!bob.try_updateStablecoinWhitelist(address(GBL), address(3), true));
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::onlyZVL() _msgSender() != ZVL");
        GBL.updateStablecoinWhitelist(address(1), true);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_onlyZVL_state(address entity) public {
        
        // updateIsKeeper() false => true.
        assert(!GBL.isKeeper(entity));
        assert(zvl.try_updateIsKeeper(address(GBL), address(entity), true));
        assert(GBL.isKeeper(entity));

        // updateIsLocker() false => true.
        assert(!GBL.isLocker(entity));
        assert(zvl.try_updateIsLocker(address(GBL), address(entity), true));
        assert(GBL.isLocker(entity));

        // updateStablecoinWhitelist() false => true.
        assert(!GBL.stablecoinWhitelist(entity));
        assert(zvl.try_updateStablecoinWhitelist(address(GBL), address(entity), true));
        assert(GBL.stablecoinWhitelist(entity));

        // updateIsKeeper() true => false.
        assert(GBL.isKeeper(entity));
        assert(zvl.try_updateIsKeeper(address(GBL), address(entity), false));
        assert(!GBL.isKeeper(entity));

        // updateIsLocker() true => false.
        assert(GBL.isLocker(entity));
        assert(zvl.try_updateIsLocker(address(GBL), address(entity), false));
        assert(!GBL.isLocker(entity));

        // updateStablecoinWhitelist() true => false.
        assert(GBL.stablecoinWhitelist(entity));
        assert(zvl.try_updateStablecoinWhitelist(address(GBL), address(entity), false));
        assert(!GBL.stablecoinWhitelist(entity));

    }

    // Validate restrictions on update functions (governance controlled).
    // Validate state changes on update functions (governance controlled).
    // This includes following functions:
    //  - updateMaxTrancheRatio()
    //  - updateMinZVEPerJTTMint()
    //  - updateMaxZVEPerJTTMint()
    //  - updateLowerRatioIncentive()
    //  - updateUpperRatioIncentives()

    function test_ZivoeGlobals_restrictions_governance_owner_updateMaxTrancheRatio() public {
        // Can't call this function unless "owner" (intended to be governance contract, GBL.TLC()).
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeOwnableLocked::_checkOwner owner() != _msgSender()");
        GBL.updateMaxTrancheRatio(3000);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_governance_owner_updateMinZVEPerJTTMint() public {
        // Can't call this function unless "owner" (intended to be governance contract, GBL.TLC()).
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeOwnableLocked::_checkOwner owner() != _msgSender()");
        GBL.updateMinZVEPerJTTMint(0.001 * 10**18);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_governance_owner_updateMaxZVEPerJTTMint() public {
        // Can't call this function unless "owner" (intended to be governance contract, GBL.TLC()).
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeOwnableLocked::_checkOwner owner() != _msgSender()");
        GBL.updateMaxZVEPerJTTMint(0.022 * 10**18);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_governance_owner_updateLowerRatioIncentive() public {
        // Can't call this function unless "owner" (intended to be governance contract, GBL.TLC()).
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeOwnableLocked::_checkOwner owner() != _msgSender()");
        GBL.updateLowerRatioIncentive(2000);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_governance_owner_updateUpperRatioIncentives() public {
        // Can't call this function unless "owner" (intended to be governance contract, GBL.TLC()).
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeOwnableLocked::_checkOwner owner() != _msgSender()");
        GBL.updateUpperRatioIncentives(2250);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_governance_greaterThan_updateMaxTrancheRatio() public {
        assert(god.try_updateMaxTrancheRatio(address(GBL), 3500));
        // Can't updateMaxTrancheRatio() greater than 3500.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeGlobals::updateMaxTrancheRatio() ratio > 3500");
        GBL.updateMaxTrancheRatio(3501);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_governance_greaterThan_updateUpperRatioIncentives() public {
        assert(god.try_updateUpperRatioIncentives(address(GBL), 2499));
        assert(god.try_updateUpperRatioIncentives(address(GBL), 2500));
        // Can't updateUpperRatioIncentives() > 2500.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeGlobals::updateUpperRatioIncentive() upperRatio > 2500");
        GBL.updateUpperRatioIncentives(2501);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_governance_greaterThan_updateMinZVEPerJTTMint() public {
        // Can't updateMinZVEPerJTTMint() greater than or equal to maxZVEPerJTTMint.
        // Note: Call updateMaxZVEPerJTTMint() here to enable increasing min, given max = 0 initially.
        assert(god.try_updateMaxZVEPerJTTMint(address(GBL), 0.005 * 10**18));
        // Two following calls should succeed as amount is less than MaxZVEPerJTTMint.
        assert(god.try_updateMinZVEPerJTTMint(address(GBL), 0.004 * 10**18));
        assert(god.try_updateMinZVEPerJTTMint(address(GBL), 0.00499 * 10**18));

        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeGlobals::updateMinZVEPerJTTMint() min >= maxZVEPerJTTMint");
        GBL.updateMinZVEPerJTTMint(0.005 * 10**18);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_governance_greaterThan_updateMaxZVEPerJTTMint() public {
        assert(god.try_updateMaxZVEPerJTTMint(address(GBL), 0.1 * 10**18 - 1));
        // Can't updateMaxZVEPerJTTMint() greater than 0.1 * 10 **18.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeGlobals::updateMaxZVEPerJTTMint() max >= 0.1 * 10**18");
        GBL.updateMaxZVEPerJTTMint(0.1 * 10**18);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_governance_lessThan_updateLowerRatioIncentive() public {
        assert(god.try_updateLowerRatioIncentive(address(GBL), 1001));
        assert(god.try_updateLowerRatioIncentive(address(GBL), 1000));
        // Can't updateLowerRatioIncentive() < 1000.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeGlobals::updateLowerRatioIncentive() lowerRatio < 1000");
        GBL.updateLowerRatioIncentive(999);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_governance_greaterThan_updateLowerRatioIncentive() public {
        assert(god.try_updateLowerRatioIncentive(address(GBL), 1999));
        // Can't updateLowerRatioIncentive() > upperRatioIncentive (initially 2000).
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeGlobals::updateLowerRatioIncentive() lowerRatio >= upperRatioIncentive");
        GBL.updateLowerRatioIncentive(2000);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_governance_state(
        uint256 maxTrancheRatioIn,
        uint256 minZVEPerJTTMintIn,
        uint256 maxZVEPerJTTMintIn,
        uint256 lowerRatioIncentiveIn,
        uint256 upperRatioIncentiveIn
    ) public {
        
        uint256 maxTrancheRatio = maxTrancheRatioIn % 3500;
        uint256 minZVEPerJTTMint = minZVEPerJTTMintIn % (0.01 * 10**18);
        uint256 maxZVEPerJTTMint = maxZVEPerJTTMintIn % (0.01 * 10**18) + 1;

        if (minZVEPerJTTMint >= maxZVEPerJTTMint) {
            minZVEPerJTTMint = maxZVEPerJTTMint - 1;
        }

        uint256 lowerRatioIncentive = lowerRatioIncentiveIn % 1500 + 1000;
        uint256 upperRatioIncentive = upperRatioIncentiveIn % 1499 + 1001;

        if (lowerRatioIncentive >= upperRatioIncentive) {
            lowerRatioIncentive = upperRatioIncentive - 1;
        }

        // Pre-state.
        assertEq(GBL.maxTrancheRatioBIPS(), 2000);
        assertEq(GBL.minZVEPerJTTMint(), 0);
        assertEq(GBL.maxZVEPerJTTMint(), 0);
        assertEq(GBL.lowerRatioIncentive(), 1000);
        assertEq(GBL.upperRatioIncentive(), 2000);

        assert(god.try_updateMaxTrancheRatio(address(GBL), maxTrancheRatio));
        assert(god.try_updateMaxZVEPerJTTMint(address(GBL), maxZVEPerJTTMint));
        assert(god.try_updateMinZVEPerJTTMint(address(GBL), minZVEPerJTTMint));
        assert(god.try_updateUpperRatioIncentives(address(GBL), upperRatioIncentive));
        assert(god.try_updateLowerRatioIncentive(address(GBL), lowerRatioIncentive));

        // Post-state.
        assertEq(GBL.maxTrancheRatioBIPS(), maxTrancheRatio);
        assertEq(GBL.maxZVEPerJTTMint(), maxZVEPerJTTMint);
        assertEq(GBL.minZVEPerJTTMint(), minZVEPerJTTMint);
        assertEq(GBL.lowerRatioIncentive(), lowerRatioIncentive);
        assertEq(GBL.upperRatioIncentive(), upperRatioIncentive);

    }

    
    // TODO: Experiment various values for two following functions.

    function test_ZivoeGlobals_standardize_view() public {
        
    }

    function test_ZivoeGlobals_adjustedSupplies_view() public {
        
    }
    
}
