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

    function test_ZivoeGlobals_increase_or_decreaseDefaults_restrictions() public {
        
        // Create GenericDefaults locker, with default adjustment capability, add this to whitelist.
        GenericDefaultsLocker = new OCG_Defaults(address(DAO), address(GBL));
        assert(zvl.try_updateIsLocker(address(GBL), address(GenericDefaultsLocker), true));

        // Ensure non-whitelisted address may not call increase/decrease default, directly via ZivoeGlobals.sol.
        assert(!bob.try_increaseDefaults(address(GBL), 100 ether));
        assert(!bob.try_decreaseDefaults(address(GBL), 100 ether));

        // Ensure non-whitelisted address may not call increase/decrease default, indirectly via OCG_Defaults.sol.
        assert(!bob.try_increaseDefaults(address(GenericDefaultsLocker), 100 ether));
        assert(!bob.try_decreaseDefaults(address(GenericDefaultsLocker), 100 ether));

        // Ensure underflow is not permitted.
        assertEq(GBL.defaults(), 0);
        assert(!god.try_decreaseDefaults(address(GenericDefaultsLocker), 1));

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

    function test_ZivoeGlobals_onlyZVL_restrictions() public {
        
        assert(!bob.try_updateIsKeeper(address(GBL), address(1), true));
        assert(!bob.try_updateIsLocker(address(GBL), address(2), true));
        assert(!bob.try_updateStablecoinWhitelist(address(GBL), address(3), true));

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

    function test_ZivoeGlobals_governance_restrictions() public {
        
        // Can't call these functions unless "owner" (intended to be governance contract, GBL.TLC()).
        assert(!bob.try_updateMaxTrancheRatio(address(GBL), 3000));
        assert(!bob.try_updateMinZVEPerJTTMint(address(GBL), 0.001 * 10**18));
        assert(!bob.try_updateMaxZVEPerJTTMint(address(GBL), 0.022 * 10**18));
        assert(!bob.try_updateLowerRatioIncentive(address(GBL), 1250));
        assert(!bob.try_updateUpperRatioIncentives(address(GBL), 2250));

        // Can't updateMaxTrancheRatio() greater than 3500.
        assert(god.try_updateMaxTrancheRatio(address(GBL), 3499));
        assert(god.try_updateMaxTrancheRatio(address(GBL), 3500));
        assert(!god.try_updateMaxTrancheRatio(address(GBL), 3501));

        // Note: Call updateMaxZVEPerJTTMint() here to enable increasing min, given max = 0 initially.
        assert(god.try_updateMaxZVEPerJTTMint(address(GBL), 0.005 * 10**18));
        
        // Can't updateMinZVEPerJTTMint() greater than or equal to maxZVEPerJTTMint.
        assert(god.try_updateMinZVEPerJTTMint(address(GBL), 0.004 * 10**18));
        assert(god.try_updateMinZVEPerJTTMint(address(GBL), 0.00499 * 10**18));
        assert(!god.try_updateMinZVEPerJTTMint(address(GBL), 0.005 * 10**18));

        // Can't updateMaxZVEPerJTTMint() greater than 0.1 * 10 **18.
        assert(god.try_updateMaxZVEPerJTTMint(address(GBL), 0.1 * 10**18 - 1));
        assert(!god.try_updateMaxZVEPerJTTMint(address(GBL), 0.1 * 10**18));

        // Can't updateLowerRatioIncentive() < 1000.
        // Can't updateLowerRatioIncentive() > upperRatioIncentive (initially 2000).
        assert(god.try_updateLowerRatioIncentive(address(GBL), 1001));
        assert(god.try_updateLowerRatioIncentive(address(GBL), 1000));
        assert(!god.try_updateLowerRatioIncentive(address(GBL), 999));
        assert(god.try_updateLowerRatioIncentive(address(GBL), 1999));
        assert(!god.try_updateLowerRatioIncentive(address(GBL), 2000));

        // Can't updateUpperRatioIncentives() > 2500.
        assert(god.try_updateUpperRatioIncentives(address(GBL), 2499));
        assert(god.try_updateUpperRatioIncentives(address(GBL), 2500));
        assert(!god.try_updateUpperRatioIncentives(address(GBL), 2501));

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

    
    // TODO: Implement unit testing for the following two view functions below.

    function test_ZivoeGlobals_standardize_view() public {
        
    }

    function test_ZivoeGlobals_adjustedSupplies_view() public {
        
    }
    
}
