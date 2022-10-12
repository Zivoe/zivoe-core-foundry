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

    function test_ZivoeTranches_pushToLocker_restrictions() public {

        // Can't push non-ZVE asset to ZVT.
        assert(!god.try_push(address(DAO), address(ZVT), address(FRAX), 10_000 ether));

    }

    function test_ZivoeTranches_pushToLocker_state(uint96 random) public {

        uint256 amt = uint256(random) % 25000000 ether;

        // Pre-state.
        uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(ZVT));

        assert(!god.try_push(address(DAO), address(ZVT), address(FRAX), amt));
        
        // Post-state.
        uint256 _postZVE = IERC20(address(ZVE)).balanceOf(address(ZVT));
    }

    // Validate depositJunior() state.
    // Validate depositJunior() restrictions.
    // This includes:
    //  - asset must be whitelisted
    //  - unlocked must be true
    //  - isJuniorOpen(amount, asset) must return true

    function test_ZivoeTranches_depositJunior_restrictions() public {
        
        mint("WETH", address(bob), 100 ether);
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        assert(bob.try_approveToken(address(WETH), address(ZVT), 100 ether));

        // Can't call depositJunior() if asset not whitelisted.
        assert(!bob.try_depositJunior(address(ZVT), 100 ether, address(WETH)));
        
        simulateITO(100_000_000 ether, 100_000_000 ether, 100_000_000 * USD, 100_000_000 * USD);

        // Can't call depositJunior() if !isJuniorOpen()
        assert(!bob.try_depositJunior(address(ZVT), 100 ether, address(DAI)));

        // Can't call depositJunior() if not unlocked (deploy new ZVT contract to test).
        ZVT = new ZivoeTranches(address(GBL));

        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        assert(!bob.try_depositJunior(address(ZVT), 100 ether, address(DAI)));

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

    function test_ZivoeTranches_depositSenior_restrictions() public {
        
    }

    function test_ZivoeTranches_depositSenior_state() public {

    } 

}