// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeTranches is Utility {
    
    function setUp() public {

        deployCore(false);

        // Move 2.5mm ZVE from DAO to ZVT.
        assert(god.try_push(address(DAO), address(ZVT), address(ZVE), 2500000 ether));

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate pushToLocker() state, restrictions.
    // This includes:
    //  - "asset" must be $ZVE.

    function test_ZivoeTranches_pushToLocker_restrictions_nonZVE() public {

        // Can't push non-ZVE asset to ZVT.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeTranches::pushToLocker() asset != IZivoeGlobals_Tranches(GBL).ZVE()");
        DAO.push(address(ZVT), address(FRAX), 10_000 ether);
        hevm.stopPrank();
    }

    function test_ZivoeTranches_pushToLocker_state(uint96 random) public {

        uint256 amount = uint256(random) % 2500000 ether;

        // Pre-state.
        uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(ZVT));

        assert(god.try_push(address(DAO), address(ZVT), address(ZVE), amount));
        
        // Post-state.
        assertEq(IERC20(address(ZVE)).balanceOf(address(ZVT)), _preZVE + amount);
    }

    // Validate depositJunior() state.
    // Validate depositJunior() restrictions.
    // This includes:
    //  - asset must be whitelisted
    //  - unlocked must be true
    //  - isJuniorOpen(amount, asset) must return true

    function test_ZivoeTranches_depositJunior_restrictions_notWhitelisted() public {
        
        mint("WETH", address(bob), 100 ether);
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        assert(bob.try_approveToken(address(WETH), address(ZVT), 100 ether));

        // Can't call depositJunior() if asset not whitelisted.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::depositJunior() !IZivoeGlobals_Tranches(GBL).stablecoinWhitelist(asset)");
        ZVT.depositJunior(100 ether, address(WETH));
        hevm.stopPrank();
    }

    function test_ZivoeTranches_depositJunior_restrictions_notOpen() public {
        
        mint("WETH", address(bob), 100 ether);
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        assert(bob.try_approveToken(address(WETH), address(ZVT), 100 ether));
        
        simulateITO(100_000_000 ether, 100_000_000 ether, 100_000_000 * USD, 100_000_000 * USD);

        // Can't call depositJunior() if !isJuniorOpen()
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::depositJunior() !isJuniorOpen(amount, asset)");
        ZVT.depositJunior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeTranches_depositJunior_restrictions_locked() public {
        
        mint("WETH", address(bob), 100 ether);
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        assert(bob.try_approveToken(address(WETH), address(ZVT), 100 ether));
        
        simulateITO(100_000_000 ether, 100_000_000 ether, 100_000_000 * USD, 100_000_000 * USD);

        // Can't call depositJunior() if not unlocked (deploy new ZVT contract to test).
        ZVT = new ZivoeTranches(address(GBL));

        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));

        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::depositJunior() !tranchesUnlocked");
        ZVT.depositJunior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeTranches_depositJunior_state(uint96 random) public {
        
        simulateITO(100_000_000 ether, 100_000_000 ether, 100_000_000 * USD, 100_000_000 * USD);
        
        // Deposit large amount into depositSenior() to open isJuniorOpen().
        mint("DAI", address(sam), 10_000_000_000 ether);

        assert(sam.try_approveToken(address(DAI), address(ZVT), 10_000_000_000 ether));
        assert(sam.try_depositSenior(address(ZVT), 10_000_000_000 ether, address(DAI)));

        // Calculate maximum amount depositable in junior tranche.
        (uint256 seniorSupp, uint256 juniorSupp) = GBL.adjustedSupplies();
        
        uint256 maximumAmount = (seniorSupp * GBL.maxTrancheRatioBIPS() / BIPS - juniorSupp) / 3;

        uint256 maximumAmount_18 = uint256(random) % maximumAmount;
        uint256 maximumAmount_6 = maximumAmount_18 /= 10**12;

        // Mint amounts for depositJunior() calls.
        mint("DAI", address(jim), maximumAmount_18);
        mint("USDC", address(jim), maximumAmount_6);
        mint("USDT", address(jim), maximumAmount_6);
        assert(jim.try_approveToken(address(DAI), address(ZVT), maximumAmount_18));
        assert(jim.try_approveToken(address(USDC), address(ZVT), maximumAmount_6));
        assert(jim.try_approveToken(address(USDT), address(ZVT), maximumAmount_6));

        {
            uint256 _rewardZVE = ZVT.rewardZVEJuniorDeposit(maximumAmount_18);
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(jim));
            uint256 _preJTT = IERC20(address(zJTT)).balanceOf(address(jim));
            assert(jim.try_depositJunior(address(ZVT), maximumAmount_18, address(DAI)));
            assertEq(IERC20(address(ZVE)).balanceOf(address(jim)), _preZVE + _rewardZVE);
            assertEq(IERC20(address(zJTT)).balanceOf(address(jim)), _preJTT + maximumAmount_18);
        }

        {
            uint256 _rewardZVE = ZVT.rewardZVEJuniorDeposit(GBL.standardize(maximumAmount_6, USDC));
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(jim));
            uint256 _preJTT = IERC20(address(zJTT)).balanceOf(address(jim));
            assert(jim.try_depositJunior(address(ZVT), maximumAmount_6, address(USDC)));
            assertEq(IERC20(address(ZVE)).balanceOf(address(jim)), _preZVE + _rewardZVE);
            assertEq(IERC20(address(zJTT)).balanceOf(address(jim)), _preJTT + GBL.standardize(maximumAmount_6, USDC));
        }

        {
            uint256 _rewardZVE = ZVT.rewardZVEJuniorDeposit(GBL.standardize(maximumAmount_6, USDT));
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(jim));
            uint256 _preJTT = IERC20(address(zJTT)).balanceOf(address(jim));
            assert(jim.try_depositJunior(address(ZVT), maximumAmount_6, address(USDT)));
            assertEq(IERC20(address(ZVE)).balanceOf(address(jim)), _preZVE + _rewardZVE);
            assertEq(IERC20(address(zJTT)).balanceOf(address(jim)), _preJTT + GBL.standardize(maximumAmount_6, USDT));
        }

    }

    // Validate depositSenior() state.
    // Validate depositSenior() restrictions.
    // This includes:
    //  - asset must be whitelisted
    //  - ZVT contact must be unlocked

    function test_ZivoeTranches_depositSenior_restrictions_notWhitelisted() public {
        
        mint("WETH", address(bob), 100 ether);
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        assert(bob.try_approveToken(address(WETH), address(ZVT), 100 ether));

        // Can't call depositSenior() if asset not whitelisted.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::depositSenior() !IZivoeGlobals_Tranches(GBL).stablecoinWhitelist(asset)");
        ZVT.depositSenior(100 ether, address(WETH));
        hevm.stopPrank();
    }

    function test_ZivoeTranches_depositSenior_restrictions_locked() public {
        
        mint("WETH", address(bob), 100 ether);
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        assert(bob.try_approveToken(address(WETH), address(ZVT), 100 ether));

        // Can't call depositSenior() if not unlocked (deploy new ZVT contract to test).
        ZVT = new ZivoeTranches(address(GBL));

        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::depositSenior() !tranchesUnlocked");
        ZVT.depositSenior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeTranches_depositSenior_state(uint96 random) public {

        simulateITO(100_000_000 ether, 100_000_000 ether, 100_000_000 * USD, 100_000_000 * USD);

        uint256 amount_18 = uint256(random);
        uint256 amount_6 = amount_18 /= 10**12;

        // Mint amounts for depositSenior() calls.
        mint("DAI", address(sam), amount_18);
        mint("USDC", address(sam), amount_6);
        mint("USDT", address(sam), amount_6);
        assert(sam.try_approveToken(address(DAI), address(ZVT), amount_18));
        assert(sam.try_approveToken(address(USDC), address(ZVT), amount_6));
        assert(sam.try_approveToken(address(USDT), address(ZVT), amount_6));

        {
            uint256 _rewardZVE = ZVT.rewardZVESeniorDeposit(amount_18);
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(sam));
            uint256 _preSTT = IERC20(address(zSTT)).balanceOf(address(sam));
            assert(sam.try_depositSenior(address(ZVT), amount_18, address(DAI)));
            assertEq(IERC20(address(ZVE)).balanceOf(address(sam)), _preZVE + _rewardZVE);
            assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), _preSTT + amount_18);
        }

        {
            uint256 _rewardZVE = ZVT.rewardZVESeniorDeposit(GBL.standardize(amount_6, USDC));
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(sam));
            uint256 _preSTT = IERC20(address(zSTT)).balanceOf(address(sam));
            assert(sam.try_depositSenior(address(ZVT), amount_6, address(USDC)));
            assertEq(IERC20(address(ZVE)).balanceOf(address(sam)), _preZVE + _rewardZVE);
            assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), _preSTT + GBL.standardize(amount_6, USDC));
        }

        {
            uint256 _rewardZVE = ZVT.rewardZVESeniorDeposit(GBL.standardize(amount_6, USDT));
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(sam));
            uint256 _preSTT = IERC20(address(zSTT)).balanceOf(address(sam));
            assert(sam.try_depositSenior(address(ZVT), amount_6, address(USDT)));
            assertEq(IERC20(address(ZVE)).balanceOf(address(sam)), _preZVE + _rewardZVE);
            assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), _preSTT + GBL.standardize(amount_6, USDT));
        }
    } 
}