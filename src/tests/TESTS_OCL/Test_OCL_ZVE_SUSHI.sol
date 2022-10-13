// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCL/OCL_ZVE_SUSHI.sol";

contract Test_OCL_ZVE_SUSHI is Utility {

    using SafeERC20 for IERC20;

    OCL_ZVE_SUSHI OCL_ZVE_SUSHI_DAI;
    OCL_ZVE_SUSHI OCL_ZVE_SUSHI_FRAX;
    OCL_ZVE_SUSHI OCL_ZVE_SUSHI_USDC;
    OCL_ZVE_SUSHI OCL_ZVE_SUSHI_USDT;

    function setUp() public {

        deployCore(false);

        // Simulate ITO (10mm * 8 * 4), DAI/FRAX/USDC/USDT.
        simulateITO(10_000_000 ether, 10_000_000 ether, 10_000_000 * USD, 10_000_000 * USD);

        // Initialize and whitelist OCL_ZVE_SUSHI locker's.
        OCL_ZVE_SUSHI_DAI = new OCL_ZVE_SUSHI(address(DAO), address(GBL), DAI);
        OCL_ZVE_SUSHI_FRAX = new OCL_ZVE_SUSHI(address(DAO), address(GBL), FRAX);
        OCL_ZVE_SUSHI_USDC = new OCL_ZVE_SUSHI(address(DAO), address(GBL), USDC);
        OCL_ZVE_SUSHI_USDT = new OCL_ZVE_SUSHI(address(DAO), address(GBL), USDT);

        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_SUSHI_DAI), true);
        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_SUSHI_FRAX), true);
        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_SUSHI_USDC), true);
        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_SUSHI_USDT), true);

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function buyZVE(uint256 amt, address pairAsset) public {
        
        address SUSHI_ROUTER = OCL_ZVE_SUSHI_DAI.SUSHI_ROUTER();
        address[] memory path = new address[](2);
        path[1] = address(ZVE);

        if (pairAsset == DAI) {
            mint("DAI", address(this), amt);
            IERC20(DAI).safeApprove(SUSHI_ROUTER, amt);
            path[0] = DAI;
        }
        else if (pairAsset == FRAX) {
            mint("FRAX", address(this), amt);
            IERC20(FRAX).safeApprove(SUSHI_ROUTER, amt);
            path[0] = FRAX;
        }
        else if (pairAsset == USDC) {
            mint("USDC", address(this), amt);
            IERC20(USDC).safeApprove(SUSHI_ROUTER, amt);
            path[0] = USDC;
        }
        else if (pairAsset == USDT) {
            mint("USDT", address(this), amt);
            IERC20(USDT).safeApprove(SUSHI_ROUTER, amt);
            path[0] = USDT;
        }
        else { revert(); }

        // function swapExactTokensForTokens(
        //     uint amountIn,
        //     uint amountOutMin,
        //     address[] calldata path,
        //     address to,
        //     uint deadline
        // ) external returns (uint[] memory amounts);
        ISushiRouter(SUSHI_ROUTER).swapExactTokensForTokens(
            amt, 
            0, 
            path, 
            address(this), 
            block.timestamp + 5 days
        );
    }

    function sellZVE(uint256 amt, address pairAsset) public {
        
        address SUSHI_ROUTER = OCL_ZVE_SUSHI_DAI.SUSHI_ROUTER();
        address[] memory path = new address[](2);
        path[0] = address(ZVE);

        IERC20(address(ZVE)).safeApprove(SUSHI_ROUTER, amt);

        if (pairAsset == DAI) {
            path[1] = DAI;
        }
        else if (pairAsset == FRAX) {
            path[1] = FRAX;
        }
        else if (pairAsset == USDC) {
            path[1] = USDC;
        }
        else if (pairAsset == USDT) {
            path[1] = USDT;
        }
        else { revert(); }

        // function swapExactTokensForTokens(
        //     uint amountIn,
        //     uint amountOutMin,
        //     address[] calldata path,
        //     address to,
        //     uint deadline
        // ) external returns (uint[] memory amounts);
        ISushiRouter(SUSHI_ROUTER).swapExactTokensForTokens(
            amt, 
            0, 
            path, 
            address(this), 
            block.timestamp + 5 days
        );
    }


    function pushToLockerInitial(uint256 amountA, uint256 amountB, uint256 modularity) public {
        
        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[1] = address(ZVE);
        amounts[0] = amountA;
        amounts[1] = amountB;

        if (modularity == 0) {
            assets[0] = DAI;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_DAI.baseline(), 0);
            assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_DAI), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_SUSHI_DAI.baseline(), baseline);
            assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), block.timestamp + 30 days);
            
        }
        else if (modularity == 1) {
            assets[0] = FRAX;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_FRAX.baseline(), 0);
            assertEq(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_FRAX), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_SUSHI_FRAX.baseline(), baseline);
            assertEq(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 2) {
            assets[0] = USDC;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_USDC.baseline(), 0);
            assertEq(OCL_ZVE_SUSHI_USDC.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_USDC), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_SUSHI_USDC.baseline(), baseline);
            assertEq(OCL_ZVE_SUSHI_USDC.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 3) {
            assets[0] = USDT;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_USDT.baseline(), 0);
            assertEq(OCL_ZVE_SUSHI_USDT.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_USDT), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_SUSHI_USDT.baseline(), baseline);
            assertEq(OCL_ZVE_SUSHI_USDT.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else { revert(); }
    }


    // ----------------
    //    Unit Tests
    // ----------------

    function test_OCL_ZVE_SUSHI_init() public {
        
        // Adjustable variables based on constructor().
        assertEq(OCL_ZVE_SUSHI_DAI.pairAsset(), DAI);
        assertEq(OCL_ZVE_SUSHI_FRAX.pairAsset(), FRAX);
        assertEq(OCL_ZVE_SUSHI_USDC.pairAsset(), USDC);
        assertEq(OCL_ZVE_SUSHI_USDT.pairAsset(), USDT);

        assertEq(OCL_ZVE_SUSHI_DAI.owner(), address(DAO));
        assertEq(OCL_ZVE_SUSHI_FRAX.owner(), address(DAO));
        assertEq(OCL_ZVE_SUSHI_USDC.owner(), address(DAO));
        assertEq(OCL_ZVE_SUSHI_USDT.owner(), address(DAO));

        assertEq(OCL_ZVE_SUSHI_DAI.GBL(), address(GBL));
        assertEq(OCL_ZVE_SUSHI_FRAX.GBL(), address(GBL));
        assertEq(OCL_ZVE_SUSHI_USDC.GBL(), address(GBL));
        assertEq(OCL_ZVE_SUSHI_USDT.GBL(), address(GBL));

        // Constants check, only need to check one instance.
        assertEq(OCL_ZVE_SUSHI_DAI.SUSHI_ROUTER(), 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        assertEq(OCL_ZVE_SUSHI_DAI.SUSHI_FACTORY(), 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        assertEq(OCL_ZVE_SUSHI_DAI.baseline(), 0);
        assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), 0);
        assertEq(OCL_ZVE_SUSHI_DAI.amountForConversion(), 0);
        assertEq(OCL_ZVE_SUSHI_DAI.compoundingRateBIPS(), 5000);

        assert(OCL_ZVE_SUSHI_DAI.canPushMulti());
        assert(OCL_ZVE_SUSHI_DAI.canPull());
        assert(OCL_ZVE_SUSHI_DAI.canPullPartial());
    }


    // Validate pushToLockerMulti() state changes (initial call).
    // Validate pushToLockerMulti() state changes (subsequent calls).
    // Validate pushToLockerMulti() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.
    //  - Only callable if assets[0] == pairAsset && assets[1] == $ZVE

    function test_OCL_ZVE_SUSHI_pushToLockerMulti_restrictions() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = address(ZVE);
        assets[1] = DAI;
        amounts[0] = 0;
        amounts[1] = 0;

        // Can't push to contract if _msgSender() != OCL_ZVE_SUSHI.owner()
        assert(!bob.try_pushToLockerMulti_DIRECT(address(OCL_ZVE_SUSHI_DAI), assets, amounts));

        // Can't push if amounts[0] || amounts[1] < 10 * 10**6.
        assert(!god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_DAI), assets, amounts));
        amounts[0] = 10 * 10**6;
        assert(!god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_DAI), assets, amounts));

        amounts[1] = 10 * 10**6;
        assets[0] = DAI;
        assets[1] = address(ZVE);

        // Acceptable inputs now.
        assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_DAI), assets, amounts));

    }

    function test_OCL_ZVE_SUSHI_pushToLockerMulti_state_initial(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[1] = address(ZVE);
        amounts[0] = amountA;
        amounts[1] = amountB;

        if (modularity == 0) {
            assets[0] = DAI;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_DAI.baseline(), 0);
            assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_DAI), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
            assertGt(baseline, 0);
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_SUSHI_DAI.baseline(), baseline);
            assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), block.timestamp + 30 days);
            
        }
        else if (modularity == 1) {
            assets[0] = FRAX;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_FRAX.baseline(), 0);
            assertEq(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_FRAX), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();
            assertGt(baseline, 0);
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_SUSHI_FRAX.baseline(), baseline);
            assertEq(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 2) {
            assets[0] = USDC;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_USDC.baseline(), 0);
            assertEq(OCL_ZVE_SUSHI_USDC.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_USDC), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();
            assertGt(baseline, 0);
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_SUSHI_USDC.baseline(), baseline);
            assertEq(OCL_ZVE_SUSHI_USDC.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 3) {
            assets[0] = USDT;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_USDT.baseline(), 0);
            assertEq(OCL_ZVE_SUSHI_USDT.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_USDT), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();
            assertGt(baseline, 0);
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_SUSHI_USDT.baseline(), baseline);
            assertEq(OCL_ZVE_SUSHI_USDT.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else { revert(); }

    }

    function test_OCL_ZVE_SUSHI_pushToLockerMulti_state_subsequent(uint96 randomA, uint96 randomB) public {
        
        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[1] = address(ZVE);
        amounts[0] = amountA;
        amounts[1] = amountB;

        if (modularity == 0) {
            assets[0] = DAI;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_DAI), assets, amounts));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBaseline, _preBaseline);
            
        }
        else if (modularity == 1) {
            assets[0] = FRAX;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_FRAX), assets, amounts));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBaseline, _preBaseline);
        }
        else if (modularity == 2) {
            assets[0] = USDC;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_USDC), assets, amounts));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBaseline, _preBaseline);
        }
        else if (modularity == 3) {
            assets[0] = USDT;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_USDT), assets, amounts));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBaseline, _preBaseline);
        }
        else { revert(); }

    }

    // Validate pullFromLocker() state changes.
    // This includes:
    //  - Only the owner() of contract may call this.

    function test_OCL_ZVE_SUSHI_pullFromLocker_restrictions(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);

        // Can't pull if not owner().
        if (modularity == 0) {
            assert(!bob.try_pullFromLocker_DIRECT(address(OCL_ZVE_SUSHI_DAI), DAI));
        }
        else if (modularity == 1) {
            assert(!bob.try_pullFromLocker_DIRECT(address(OCL_ZVE_SUSHI_FRAX), FRAX));
        }
        else if (modularity == 2) {
            assert(!bob.try_pullFromLocker_DIRECT(address(OCL_ZVE_SUSHI_USDC), USDC));
        }
        else if (modularity == 3) {
            assert(!bob.try_pullFromLocker_DIRECT(address(OCL_ZVE_SUSHI_USDT), USDT));
        }
        else { revert(); }
        
    }

    // Note: This does not test the else-if or else branches.

    function test_OCL_ZVE_SUSHI_pullFromLocker_pair_state(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);
        
        if (modularity == 0) {
            
            address pair = ISushiFactory(OCL_ZVE_SUSHI_DAI.SUSHI_FACTORY()).getPair(DAI, address(ZVE));

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_SUSHI_DAI), pair));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
            assertEq(_postBaseline, 0);
            assertEq(_postLPTokens, 0);
            
        }
        else if (modularity == 1) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_FRAX.SUSHI_FACTORY()).getPair(FRAX, address(ZVE));

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_SUSHI_FRAX), pair));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();
            assertEq(_postBaseline, 0);
            assertEq(_postLPTokens, 0);
        }
        else if (modularity == 2) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_USDC.SUSHI_FACTORY()).getPair(USDC, address(ZVE));

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_SUSHI_USDC), pair));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();
            assertEq(_postBaseline, 0);
            assertEq(_postLPTokens, 0);
        }
        else if (modularity == 3) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_USDT.SUSHI_FACTORY()).getPair(USDT, address(ZVE));

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_SUSHI_USDT), pair));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();
            assertEq(_postBaseline, 0);
            assertEq(_postLPTokens, 0);
        }
        else { revert(); }

    }


    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.

    function test_OCL_ZVE_SUSHI_pullFromLockerPartial_restrictions(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);

        // Can't pull if not owner().
        if (modularity == 0) {
            assert(!bob.try_pullFromLockerPartial_DIRECT(address(OCL_ZVE_SUSHI_DAI), DAI, 10 * USD));
        }
        else if (modularity == 1) {
            assert(!bob.try_pullFromLockerPartial_DIRECT(address(OCL_ZVE_SUSHI_FRAX), FRAX, 10 * USD));
        }
        else if (modularity == 2) {
            assert(!bob.try_pullFromLockerPartial_DIRECT(address(OCL_ZVE_SUSHI_USDC), USDC, 10 * USD));
        }
        else if (modularity == 3) {
            assert(!bob.try_pullFromLockerPartial_DIRECT(address(OCL_ZVE_SUSHI_USDT), USDT, 10 * USD));
        }
        else { revert(); }

    }

    // Note: This does not test the else-if or else branches.

    function test_OCL_ZVE_SUSHI_pullFromLockerPartial_state(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);
        

        if (modularity == 0) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_DAI.SUSHI_FACTORY()).getPair(DAI, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_DAI)) * (randomA % 100 + 1) / 100;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_DAI)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_SUSHI_DAI), pair, partialAmount));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
            assertGt(_preBaseline - _postBaseline, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
            
        }
        else if (modularity == 1) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_FRAX.SUSHI_FACTORY()).getPair(FRAX, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_FRAX)) * (randomA % 100 + 1) / 100;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_FRAX)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_SUSHI_FRAX), pair, partialAmount));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();
            assertGt(_preBaseline - _postBaseline, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
        }
        else if (modularity == 2) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_USDC.SUSHI_FACTORY()).getPair(USDC, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_USDC)) * (randomA % 100 + 1) / 100;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_USDC)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_SUSHI_USDC), pair, partialAmount));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();
            assertGt(_preBaseline - _postBaseline, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
        }
        else if (modularity == 3) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_USDT.SUSHI_FACTORY()).getPair(USDT, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_USDT)) * (randomA % 100 + 1) / 100;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_USDT)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_SUSHI_USDT), pair, partialAmount));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();
            assertGt(_preBaseline - _postBaseline, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
        }
        else { revert(); }

    }

    // Validate updateCompoundingRateBIPS() state changes.
    // Validate updateCompoundingRateBIPS() restrictions.
    // This includes:
    //  - Only governance contract (TLC / "god") may call this function.
    //  - _compoundingRateBIPS <= 10000

    function test_OCL_ZVE_SUSHI_updateCompoundingRateBIPS_restrictions() public {
        
        // Can't call if not governance contract.
        assert(!bob.try_updateCompoundingRateBIPS(address(OCL_ZVE_SUSHI_DAI), 10000));
        
        // Can't call if > 10000.
        assert(!god.try_updateCompoundingRateBIPS(address(OCL_ZVE_SUSHI_DAI), 10001));

        // Example success.
        assert(god.try_updateCompoundingRateBIPS(address(OCL_ZVE_SUSHI_DAI), 10000));

    }

    function test_OCL_ZVE_SUSHI_updateCompoundingRateBIPS_state(uint96 random) public {

        uint256 val = uint256(random) % 10000;
        
        // Pre-state.
        assertEq(OCL_ZVE_SUSHI_DAI.compoundingRateBIPS(), 5000);

        assert(god.try_updateCompoundingRateBIPS(address(OCL_ZVE_SUSHI_DAI), val));

        // Pre-state.
        assertEq(OCL_ZVE_SUSHI_DAI.compoundingRateBIPS(), val);

    }

    // Validate forwardYield() state changes.
    // Validate forwardYield() restrictions.
    // This includes:
    //  - Time constraints based on isKeeper(_msgSender()) status.

    function test_OCL_ZVE_SUSHI_forwardYield_restrictions(uint96 randomA, uint96 randomB) public {
        
        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);

        if (modularity == 0) {
            buyZVE(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            assert(!bob.try_forwardYield(address(OCL_ZVE_SUSHI_DAI)));

            hevm.warp(OCL_ZVE_SUSHI_DAI.nextYieldDistribution());
            assert(!bob.try_forwardYield(address(OCL_ZVE_SUSHI_DAI)));

            hevm.warp(OCL_ZVE_SUSHI_DAI.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_DAI)));
        }
        else if (modularity == 1) {
            buyZVE(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            assert(!bob.try_forwardYield(address(OCL_ZVE_SUSHI_FRAX)));

            hevm.warp(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution());
            assert(!bob.try_forwardYield(address(OCL_ZVE_SUSHI_FRAX)));

            hevm.warp(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_FRAX)));
        }
        else if (modularity == 2) {
            buyZVE(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            assert(!bob.try_forwardYield(address(OCL_ZVE_SUSHI_USDC)));

            hevm.warp(OCL_ZVE_SUSHI_USDC.nextYieldDistribution());
            assert(!bob.try_forwardYield(address(OCL_ZVE_SUSHI_USDC)));

            hevm.warp(OCL_ZVE_SUSHI_USDC.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_USDC)));
        }
        else if (modularity == 3) {
            buyZVE(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            assert(!bob.try_forwardYield(address(OCL_ZVE_SUSHI_USDT)));

            hevm.warp(OCL_ZVE_SUSHI_USDT.nextYieldDistribution());
            assert(!bob.try_forwardYield(address(OCL_ZVE_SUSHI_USDT)));

            hevm.warp(OCL_ZVE_SUSHI_USDT.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_USDT)));
        }
        else { revert(); }

    }

    function test_OCL_ZVE_SUSHI_forwardYield_state(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        assert(zvl.try_updateIsKeeper(address(GBL), address(bob), true));

        pushToLockerInitial(amountA, amountB, modularity);

        if (modularity == 0) {
            // Pre-state.
            (uint256 _PAC_DAI,) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(DAI).balanceOf(address(OCL_ZVE_SUSHI_DAI));
            assertEq(_prePair, 0);
            assertEq(OCL_ZVE_SUSHI_DAI.amountForConversion(), 0);
 
            buyZVE(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_SUSHI_DAI.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_DAI)));
            
            // Post-state.
            assertEq(IERC20(DAI).balanceOf(address(OCL_ZVE_SUSHI_DAI)), 0);
            assertGt(IERC20(DAI).balanceOf(address(YDL)), _prePair); // Note: YDL.distributedAsset() == DAI
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            assertEq(OCL_ZVE_SUSHI_DAI.amountForConversion(), 0);
            assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), block.timestamp + 30 days);
            (_PAC_DAI,) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
        }
        else if (modularity == 1) {
            // Pre-state.
            (uint256 _PAC_FRAX,) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(FRAX).balanceOf(address(OCL_ZVE_SUSHI_FRAX));
            assertEq(_prePair, 0);
            assertEq(OCL_ZVE_SUSHI_FRAX.amountForConversion(), 0);

            buyZVE(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_FRAX)));

            // Post-state.
            assertGt(IERC20(FRAX).balanceOf(address(OCL_ZVE_SUSHI_FRAX)), 0);
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            assertEq(OCL_ZVE_SUSHI_FRAX.amountForConversion(), IERC20(FRAX).balanceOf(address(OCL_ZVE_SUSHI_FRAX)));
            assertEq(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution(), block.timestamp + 30 days);
            (_PAC_FRAX,) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();
        }
        else if (modularity == 2) {
            // Pre-state.
            (uint256 _PAC_USDC,) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(USDC).balanceOf(address(OCL_ZVE_SUSHI_USDC));
            assertEq(_prePair, 0);
            assertEq(OCL_ZVE_SUSHI_USDC.amountForConversion(), 0);

            buyZVE(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_SUSHI_USDC.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_USDC)));

            // Post-state.
            assertGt(IERC20(USDC).balanceOf(address(OCL_ZVE_SUSHI_USDC)), 0);
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            assertEq(OCL_ZVE_SUSHI_USDC.amountForConversion(), IERC20(USDC).balanceOf(address(OCL_ZVE_SUSHI_USDC)));
            assertEq(OCL_ZVE_SUSHI_USDC.nextYieldDistribution(), block.timestamp + 30 days);
            (_PAC_USDC,) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();
        }
        else if (modularity == 3) {
            // Pre-state.
            (uint256 _PAC_USDT,) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(USDT).balanceOf(address(OCL_ZVE_SUSHI_USDT));
            assertEq(_prePair, 0);
            assertEq(OCL_ZVE_SUSHI_USDT.amountForConversion(), 0);

            buyZVE(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_SUSHI_USDT.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_USDT)));

            // Post-state.
            assertGt(IERC20(USDT).balanceOf(address(OCL_ZVE_SUSHI_USDT)), 0);
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            assertEq(OCL_ZVE_SUSHI_USDT.amountForConversion(), IERC20(USDT).balanceOf(address(OCL_ZVE_SUSHI_USDT)));
            assertEq(OCL_ZVE_SUSHI_USDT.nextYieldDistribution(), block.timestamp + 30 days);
            (_PAC_USDT,) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();
        }
        else { revert(); }

    }

    // Check that pairAssetConvertible() return goes up when buying $ZVE (or selling).

    function test_OCL_ZVE_SUSHI_pairAssetConvertible_check(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);

        if (modularity == 0) {
            (uint256 _preAmt,) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
            
            buyZVE(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
            
            assertGt(_postAmt, _preAmt);

            sellZVE(IERC20(address(ZVE)).balanceOf(address(this)) / 2, DAI); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_SUSHI_DAI.pairAssetConvertible();
            
            assertLt(_postAmt2, _postAmt);
        }
        else if (modularity == 1) {
            (uint256 _preAmt,) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();

            buyZVE(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();
            
            assertGt(_postAmt, _preAmt);

            sellZVE(IERC20(address(ZVE)).balanceOf(address(this)) / 2, FRAX); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_SUSHI_FRAX.pairAssetConvertible();
            
            assertLt(_postAmt2, _postAmt);
        }
        else if (modularity == 2) {
            (uint256 _preAmt,) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();

            buyZVE(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();
            
            assertGt(_postAmt, _preAmt);

            sellZVE(IERC20(address(ZVE)).balanceOf(address(this)) / 2, USDC); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_SUSHI_USDC.pairAssetConvertible();
            
            assertLt(_postAmt2, _postAmt);
        }
        else if (modularity == 3) {
            (uint256 _preAmt,) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();

            buyZVE(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();
            
            assertGt(_postAmt, _preAmt);

            sellZVE(IERC20(address(ZVE)).balanceOf(address(this)) / 2, USDT); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_SUSHI_USDT.pairAssetConvertible();
            
            assertLt(_postAmt2, _postAmt);
        }
        else { revert(); }

    }

    // TODO: Validate forwardYieldKeeper() !

}
