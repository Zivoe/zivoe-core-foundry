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

    function test_ZivoeTranches_depositJunior_state() public {

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

    // Validate unlock() restrictions.
    // This includes:
    //  - Caller must be ITO contract.
    //  - Should only be callable once.

    function test_ZivoeTranches_unlock_restrictions() public {
        
    }

    function test_ZivoeTranches_unlock_state() public {

    }

}