// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCL/OCL_ZVE_UNIV2.sol";

contract Test_OCL_ZVE_UNIV2 is Utility {

    using SafeERC20 for IERC20;

    OCL_ZVE_UNIV2 OCL_ZVE_UNIV2_DAI;
    OCL_ZVE_UNIV2 OCL_ZVE_UNIV2_FRAX;
    OCL_ZVE_UNIV2 OCL_ZVE_UNIV2_USDC;
    OCL_ZVE_UNIV2 OCL_ZVE_UNIV2_USDT;

    function setUp() public {

        deployCore(false);

        // Simulate ITO (10mm * 8 * 4), DAI/FRAX/USDC/USDT.
        simulateITO(10_000_000 ether, 10_000_000 ether, 10_000_000 * USD, 10_000_000 * USD);

        // Initialize and whitelist OCL_ZVE_UNIV2 locker's.
        OCL_ZVE_UNIV2_DAI = new OCL_ZVE_UNIV2(address(DAO), address(GBL), DAI);
        OCL_ZVE_UNIV2_FRAX = new OCL_ZVE_UNIV2(address(DAO), address(GBL), FRAX);
        OCL_ZVE_UNIV2_USDC = new OCL_ZVE_UNIV2(address(DAO), address(GBL), USDC);
        OCL_ZVE_UNIV2_USDT = new OCL_ZVE_UNIV2(address(DAO), address(GBL), USDT);

        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_DAI), true);
        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_FRAX), true);
        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_USDC), true);
        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_USDT), true);

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function buyZVE(uint256 amount, address pairAsset) public {
        
        address UNIV2_ROUTER = OCL_ZVE_UNIV2_DAI.UNIV2_ROUTER();
        address[] memory path = new address[](2);
        path[1] = address(ZVE);

        if (pairAsset == DAI) {
            mint("DAI", address(this), amount);
            IERC20(DAI).safeApprove(UNIV2_ROUTER, amount);
            path[0] = DAI;
        }
        else if (pairAsset == FRAX) {
            mint("FRAX", address(this), amount);
            IERC20(FRAX).safeApprove(UNIV2_ROUTER, amount);
            path[0] = FRAX;
        }
        else if (pairAsset == USDC) {
            mint("USDC", address(this), amount);
            IERC20(USDC).safeApprove(UNIV2_ROUTER, amount);
            path[0] = USDC;
        }
        else if (pairAsset == USDT) {
            mint("USDT", address(this), amount);
            IERC20(USDT).safeApprove(UNIV2_ROUTER, amount);
            path[0] = USDT;
        }
        else { revert(); }

        // function swapExactTokensForTokens(
        //     uint256 amountIn,
        //     uint256 amountOutMin,
        //     address[] calldata path,
        //     address to,
        //     uint256 deadline
        // ) external returns (uint256[] memory amounts);
        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokens(
            amount, 
            0, 
            path, 
            address(this), 
            block.timestamp + 5 days
        );
    }

    function sellZVE(uint256 amount, address pairAsset) public {
        
        address UNIV2_ROUTER = OCL_ZVE_UNIV2_DAI.UNIV2_ROUTER();
        address[] memory path = new address[](2);
        path[0] = address(ZVE);

        IERC20(address(ZVE)).safeApprove(UNIV2_ROUTER, amount);

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
        //     uint256 amountIn,
        //     uint256 amountOutMin,
        //     address[] calldata path,
        //     address to,
        //     uint256 deadline
        // ) external returns (uint256[] memory amounts);
        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokens(
            amount, 
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
            assertEq(OCL_ZVE_UNIV2_DAI.baseline(), 0);
            assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_DAI), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_UNIV2_DAI.baseline(), baseline);
            assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), block.timestamp + 30 days);
            
        }
        else if (modularity == 1) {
            assets[0] = FRAX;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_FRAX.baseline(), 0);
            assertEq(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_FRAX), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_UNIV2_FRAX.baseline(), baseline);
            assertEq(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 2) {
            assets[0] = USDC;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_USDC.baseline(), 0);
            assertEq(OCL_ZVE_UNIV2_USDC.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_USDC), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_UNIV2_USDC.baseline(), baseline);
            assertEq(OCL_ZVE_UNIV2_USDC.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 3) {
            assets[0] = USDT;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_USDT.baseline(), 0);
            assertEq(OCL_ZVE_UNIV2_USDT.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_USDT), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_UNIV2_USDT.baseline(), baseline);
            assertEq(OCL_ZVE_UNIV2_USDT.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else { revert(); }
    }


    // ----------------
    //    Unit Tests
    // ----------------

    function test_OCL_ZVE_UNIV2_init() public {
        
        // Adjustable variables based on constructor().
        assertEq(OCL_ZVE_UNIV2_DAI.pairAsset(), DAI);
        assertEq(OCL_ZVE_UNIV2_FRAX.pairAsset(), FRAX);
        assertEq(OCL_ZVE_UNIV2_USDC.pairAsset(), USDC);
        assertEq(OCL_ZVE_UNIV2_USDT.pairAsset(), USDT);

        assertEq(OCL_ZVE_UNIV2_DAI.owner(), address(DAO));
        assertEq(OCL_ZVE_UNIV2_FRAX.owner(), address(DAO));
        assertEq(OCL_ZVE_UNIV2_USDC.owner(), address(DAO));
        assertEq(OCL_ZVE_UNIV2_USDT.owner(), address(DAO));

        assertEq(OCL_ZVE_UNIV2_DAI.GBL(), address(GBL));
        assertEq(OCL_ZVE_UNIV2_FRAX.GBL(), address(GBL));
        assertEq(OCL_ZVE_UNIV2_USDC.GBL(), address(GBL));
        assertEq(OCL_ZVE_UNIV2_USDT.GBL(), address(GBL));

        // Constants check, only need to check one instance.
        assertEq(OCL_ZVE_UNIV2_DAI.UNIV2_ROUTER(), 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        assertEq(OCL_ZVE_UNIV2_DAI.UNIV2_FACTORY(), 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        assertEq(OCL_ZVE_UNIV2_DAI.baseline(), 0);
        assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), 0);
        assertEq(OCL_ZVE_UNIV2_DAI.amountForConversion(), 0);
        assertEq(OCL_ZVE_UNIV2_DAI.compoundingRateBIPS(), 5000);

        assert(OCL_ZVE_UNIV2_DAI.canPushMulti());
        assert(OCL_ZVE_UNIV2_DAI.canPull());
        assert(OCL_ZVE_UNIV2_DAI.canPullPartial());
    }


    // Validate pushToLockerMulti() state changes (initial call).
    // Validate pushToLockerMulti() state changes (subsequent calls).
    // Validate pushToLockerMulti() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.
    //  - Only callable if assets[0] == pairAsset && assets[1] == $ZVE

    function test_OCL_ZVE_UNIV2_pushToLockerMulti_restrictions() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = address(ZVE);
        assets[1] = DAI;
        amounts[0] = 0;
        amounts[1] = 0;

        // Can't push to contract if _msgSender() != OCL_ZVE_UNIV2.owner()
        assert(!bob.try_pushToLockerMulti_DIRECT(address(OCL_ZVE_UNIV2_DAI), assets, amounts));

        // Can't push if amounts[0] || amounts[1] < 10 * 10**6.
        assert(!god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_DAI), assets, amounts));
        amounts[0] = 10 * 10**6;
        assert(!god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_DAI), assets, amounts));

        amounts[1] = 10 * 10**6;
        assets[0] = DAI;
        assets[1] = address(ZVE);

        // Acceptable inputs now.
        assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_DAI), assets, amounts));

    }

    function test_OCL_ZVE_UNIV2_pushToLockerMulti_state_initial(uint96 randomA, uint96 randomB) public {

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
            assertEq(OCL_ZVE_UNIV2_DAI.baseline(), 0);
            assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_DAI), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
            assertGt(baseline, 0);
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_UNIV2_DAI.baseline(), baseline);
            assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), block.timestamp + 30 days);
            
        }
        else if (modularity == 1) {
            assets[0] = FRAX;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_FRAX.baseline(), 0);
            assertEq(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_FRAX), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();
            assertGt(baseline, 0);
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_UNIV2_FRAX.baseline(), baseline);
            assertEq(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 2) {
            assets[0] = USDC;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_USDC.baseline(), 0);
            assertEq(OCL_ZVE_UNIV2_USDC.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_USDC), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();
            assertGt(baseline, 0);
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_UNIV2_USDC.baseline(), baseline);
            assertEq(OCL_ZVE_UNIV2_USDC.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 3) {
            assets[0] = USDT;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_USDT.baseline(), 0);
            assertEq(OCL_ZVE_UNIV2_USDT.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_USDT), assets, amounts));

            // Post-state.
            (uint256 baseline, uint256 lpTokens) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();
            assertGt(baseline, 0);
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_UNIV2_USDT.baseline(), baseline);
            assertEq(OCL_ZVE_UNIV2_USDT.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else { revert(); }

    }

    function test_OCL_ZVE_UNIV2_pushToLockerMulti_state_subsequent(uint96 randomA, uint96 randomB) public {
        
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
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_DAI), assets, amounts));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBaseline, _preBaseline);
            
        }
        else if (modularity == 1) {
            assets[0] = FRAX;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_FRAX), assets, amounts));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBaseline, _preBaseline);
        }
        else if (modularity == 2) {
            assets[0] = USDC;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_USDC), assets, amounts));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBaseline, _preBaseline);
        }
        else if (modularity == 3) {
            assets[0] = USDT;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_USDT), assets, amounts));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBaseline, _preBaseline);
        }
        else { revert(); }

    }

    // Validate pullFromLocker() state changes.
    // This includes:
    //  - Only the owner() of contract may call this.

    function test_OCL_ZVE_UNIV2_pullFromLocker_restrictions(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);

        // Can't pull if not owner().
        if (modularity == 0) {
            assert(!bob.try_pullFromLocker_DIRECT(address(OCL_ZVE_UNIV2_DAI), DAI));
        }
        else if (modularity == 1) {
            assert(!bob.try_pullFromLocker_DIRECT(address(OCL_ZVE_UNIV2_FRAX), FRAX));
        }
        else if (modularity == 2) {
            assert(!bob.try_pullFromLocker_DIRECT(address(OCL_ZVE_UNIV2_USDC), USDC));
        }
        else if (modularity == 3) {
            assert(!bob.try_pullFromLocker_DIRECT(address(OCL_ZVE_UNIV2_USDT), USDT));
        }
        else { revert(); }
        
    }

    // Note: This does not test the else-if or else branches.

    function test_OCL_ZVE_UNIV2_pullFromLocker_pair_state(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);
        
        if (modularity == 0) {
            
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_DAI.UNIV2_FACTORY()).getPair(DAI, address(ZVE));

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_UNIV2_DAI), pair));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
            assertEq(_postBaseline, 0);
            assertEq(_postLPTokens, 0);
            
        }
        else if (modularity == 1) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_FRAX.UNIV2_FACTORY()).getPair(FRAX, address(ZVE));

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_UNIV2_FRAX), pair));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();
            assertEq(_postBaseline, 0);
            assertEq(_postLPTokens, 0);
        }
        else if (modularity == 2) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_USDC.UNIV2_FACTORY()).getPair(USDC, address(ZVE));

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_UNIV2_USDC), pair));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();
            assertEq(_postBaseline, 0);
            assertEq(_postLPTokens, 0);
        }
        else if (modularity == 3) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_USDT.UNIV2_FACTORY()).getPair(USDT, address(ZVE));

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_UNIV2_USDT), pair));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();
            assertEq(_postBaseline, 0);
            assertEq(_postLPTokens, 0);
        }
        else { revert(); }

    }


    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.

    function test_OCL_ZVE_UNIV2_pullFromLockerPartial_restrictions(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);

        // Can't pull if not owner().
        if (modularity == 0) {
            assert(!bob.try_pullFromLockerPartial_DIRECT(address(OCL_ZVE_UNIV2_DAI), DAI, 10 * USD));
        }
        else if (modularity == 1) {
            assert(!bob.try_pullFromLockerPartial_DIRECT(address(OCL_ZVE_UNIV2_FRAX), FRAX, 10 * USD));
        }
        else if (modularity == 2) {
            assert(!bob.try_pullFromLockerPartial_DIRECT(address(OCL_ZVE_UNIV2_USDC), USDC, 10 * USD));
        }
        else if (modularity == 3) {
            assert(!bob.try_pullFromLockerPartial_DIRECT(address(OCL_ZVE_UNIV2_USDT), USDT, 10 * USD));
        }
        else { revert(); }

    }

    // Note: This does not test the else-if or else branches.

    function test_OCL_ZVE_UNIV2_pullFromLockerPartial_state(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);
        

        if (modularity == 0) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_DAI.UNIV2_FACTORY()).getPair(DAI, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_DAI)) * (randomA % 100 + 1) / 100;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_DAI)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_UNIV2_DAI), pair, partialAmount));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
            assertGt(_preBaseline - _postBaseline, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
            
        }
        else if (modularity == 1) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_FRAX.UNIV2_FACTORY()).getPair(FRAX, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_FRAX)) * (randomA % 100 + 1) / 100;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_FRAX)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_UNIV2_FRAX), pair, partialAmount));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();
            assertGt(_preBaseline - _postBaseline, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
        }
        else if (modularity == 2) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_USDC.UNIV2_FACTORY()).getPair(USDC, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_USDC)) * (randomA % 100 + 1) / 100;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_USDC)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_UNIV2_USDC), pair, partialAmount));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();
            assertGt(_preBaseline - _postBaseline, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
        }
        else if (modularity == 3) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_USDT.UNIV2_FACTORY()).getPair(USDT, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_USDT)) * (randomA % 100 + 1) / 100;

            // Pre-state.
            (uint256 _preBaseline, uint256 _preLPTokens) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();
            assertGt(_preBaseline, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_USDT)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_UNIV2_USDT), pair, partialAmount));

            // Post-state.
            (uint256 _postBaseline, uint256 _postLPTokens) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();
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

    function test_OCL_ZVE_UNIV2_updateCompoundingRateBIPS_restrictions() public {
        
        // Can't call if not governance contract.
        assert(!bob.try_updateCompoundingRateBIPS(address(OCL_ZVE_UNIV2_DAI), 10000));
        
        // Can't call if > 10000.
        assert(!god.try_updateCompoundingRateBIPS(address(OCL_ZVE_UNIV2_DAI), 10001));

        // Example success.
        assert(god.try_updateCompoundingRateBIPS(address(OCL_ZVE_UNIV2_DAI), 10000));

    }

    function test_OCL_ZVE_UNIV2_updateCompoundingRateBIPS_state(uint96 random) public {

        uint256 val = uint256(random) % 10000;
        
        // Pre-state.
        assertEq(OCL_ZVE_UNIV2_DAI.compoundingRateBIPS(), 5000);

        assert(god.try_updateCompoundingRateBIPS(address(OCL_ZVE_UNIV2_DAI), val));

        // Pre-state.
        assertEq(OCL_ZVE_UNIV2_DAI.compoundingRateBIPS(), val);

    }

    // Validate forwardYield() state changes.
    // Validate forwardYield() restrictions.
    // This includes:
    //  - Time constraints based on isKeeper(_msgSender()) status.

    function test_OCL_ZVE_UNIV2_forwardYield_restrictions(uint96 randomA, uint96 randomB) public {
        
        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);

        if (modularity == 0) {
            buyZVE(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_DAI)));

            hevm.warp(OCL_ZVE_UNIV2_DAI.nextYieldDistribution());
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_DAI)));

            hevm.warp(OCL_ZVE_UNIV2_DAI.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_DAI)));
        }
        else if (modularity == 1) {
            buyZVE(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_FRAX)));

            hevm.warp(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution());
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_FRAX)));

            hevm.warp(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_FRAX)));
        }
        else if (modularity == 2) {
            buyZVE(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDC)));

            hevm.warp(OCL_ZVE_UNIV2_USDC.nextYieldDistribution());
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDC)));

            hevm.warp(OCL_ZVE_UNIV2_USDC.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDC)));
        }
        else if (modularity == 3) {
            buyZVE(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDT)));

            hevm.warp(OCL_ZVE_UNIV2_USDT.nextYieldDistribution());
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDT)));

            hevm.warp(OCL_ZVE_UNIV2_USDT.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDT)));
        }
        else { revert(); }

    }

    function test_OCL_ZVE_UNIV2_forwardYield_state(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        assert(zvl.try_updateIsKeeper(address(GBL), address(bob), true));

        pushToLockerInitial(amountA, amountB, modularity);

        if (modularity == 0) {
            // Pre-state.
            (uint256 _PAC_DAI,) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(DAI).balanceOf(address(OCL_ZVE_UNIV2_DAI));
            assertEq(_prePair, 0);
            assertEq(OCL_ZVE_UNIV2_DAI.amountForConversion(), 0);
 
            buyZVE(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_UNIV2_DAI.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_DAI)));
            
            // Post-state.
            assertEq(IERC20(DAI).balanceOf(address(OCL_ZVE_UNIV2_DAI)), 0);
            assertGt(IERC20(DAI).balanceOf(address(YDL)), _prePair); // Note: YDL.distributedAsset() == DAI
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            assertEq(OCL_ZVE_UNIV2_DAI.amountForConversion(), 0);
            assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), block.timestamp + 30 days);
            (_PAC_DAI,) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
        }
        else if (modularity == 1) {
            // Pre-state.
            (uint256 _PAC_FRAX,) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(FRAX).balanceOf(address(OCL_ZVE_UNIV2_FRAX));
            assertEq(_prePair, 0);
            assertEq(OCL_ZVE_UNIV2_FRAX.amountForConversion(), 0);

            buyZVE(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_FRAX)));

            // Post-state.
            assertGt(IERC20(FRAX).balanceOf(address(OCL_ZVE_UNIV2_FRAX)), 0);
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            assertEq(OCL_ZVE_UNIV2_FRAX.amountForConversion(), IERC20(FRAX).balanceOf(address(OCL_ZVE_UNIV2_FRAX)));
            assertEq(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution(), block.timestamp + 30 days);
            (_PAC_FRAX,) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();
        }
        else if (modularity == 2) {
            // Pre-state.
            (uint256 _PAC_USDC,) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(USDC).balanceOf(address(OCL_ZVE_UNIV2_USDC));
            assertEq(_prePair, 0);
            assertEq(OCL_ZVE_UNIV2_USDC.amountForConversion(), 0);

            buyZVE(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_UNIV2_USDC.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDC)));

            // Post-state.
            assertGt(IERC20(USDC).balanceOf(address(OCL_ZVE_UNIV2_USDC)), 0);
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            assertEq(OCL_ZVE_UNIV2_USDC.amountForConversion(), IERC20(USDC).balanceOf(address(OCL_ZVE_UNIV2_USDC)));
            assertEq(OCL_ZVE_UNIV2_USDC.nextYieldDistribution(), block.timestamp + 30 days);
            (_PAC_USDC,) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();
        }
        else if (modularity == 3) {
            // Pre-state.
            (uint256 _PAC_USDT,) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(USDT).balanceOf(address(OCL_ZVE_UNIV2_USDT));
            assertEq(_prePair, 0);
            assertEq(OCL_ZVE_UNIV2_USDT.amountForConversion(), 0);

            buyZVE(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_UNIV2_USDT.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDT)));

            // Post-state.
            assertGt(IERC20(USDT).balanceOf(address(OCL_ZVE_UNIV2_USDT)), 0);
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            assertEq(OCL_ZVE_UNIV2_USDT.amountForConversion(), IERC20(USDT).balanceOf(address(OCL_ZVE_UNIV2_USDT)));
            assertEq(OCL_ZVE_UNIV2_USDT.nextYieldDistribution(), block.timestamp + 30 days);
            (_PAC_USDT,) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();
        }
        else { revert(); }

    }

    // Check that pairAssetConvertible() return goes up when buying $ZVE (or selling).

    function test_OCL_ZVE_UNIV2_pairAssetConvertible_check(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial(amountA, amountB, modularity);

        if (modularity == 0) {
            (uint256 _preAmt,) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
            
            buyZVE(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
            
            assertGt(_postAmt, _preAmt);

            sellZVE(IERC20(address(ZVE)).balanceOf(address(this)) / 2, DAI); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_UNIV2_DAI.pairAssetConvertible();
            
            assertLt(_postAmt2, _postAmt);
        }
        else if (modularity == 1) {
            (uint256 _preAmt,) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();

            buyZVE(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();
            
            assertGt(_postAmt, _preAmt);

            sellZVE(IERC20(address(ZVE)).balanceOf(address(this)) / 2, FRAX); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_UNIV2_FRAX.pairAssetConvertible();
            
            assertLt(_postAmt2, _postAmt);
        }
        else if (modularity == 2) {
            (uint256 _preAmt,) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();

            buyZVE(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();
            
            assertGt(_postAmt, _preAmt);

            sellZVE(IERC20(address(ZVE)).balanceOf(address(this)) / 2, USDC); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_UNIV2_USDC.pairAssetConvertible();
            
            assertLt(_postAmt2, _postAmt);
        }
        else if (modularity == 3) {
            (uint256 _preAmt,) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();

            buyZVE(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();
            
            assertGt(_postAmt, _preAmt);

            sellZVE(IERC20(address(ZVE)).balanceOf(address(this)) / 2, USDT); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_UNIV2_USDT.pairAssetConvertible();
            
            assertLt(_postAmt2, _postAmt);
        }
        else { revert(); }

    }

    // TODO: Validate forwardYieldKeeper() !

}
