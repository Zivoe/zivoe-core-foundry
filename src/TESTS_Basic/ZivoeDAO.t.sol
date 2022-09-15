// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "./Utility.sol";

import "../ZivoeOCYLockers/OCY_Generic.sol";

contract ZivoeDAOTest is Utility {

    OCY_Generic ZVL;

    function setUp() public {

        setUpFundedDAO();
        
        // Generic ZivoeLocker for ZivoeDAO test purposes.
        ZVL = new OCY_Generic(address(DAO));

        // Add locker to whitelist.
        assert(god.try_modifyLockerWhitelist(address(DAO), address(ZVL), true));
    }

    // Verify initial state of DAO (ZivoeDAO.sol).
    // Verify initial state of ZVL (OCY_Generic.sol, generic inheritance of ZivoeLocker.sol).

    function test_ZivoeDAO_init() public {
        assertEq(DAO.owner(), address(god));
        assert(ZVL.canPull());
        assert(ZVL.canPush());
        assert(!ZVL.canPullMulti());
        assert(!ZVL.canPushMulti());
        assert(!ZVL.canPullERC721());
        assert(!ZVL.canPushERC721());
        assert(!ZVL.canPullERC1155());
        assert(!ZVL.canPushERC1155());
    }

    // Verify modifyLockerWhitelist() state changes.
    // Verify modifyLockerWhitelist() restrictions.

    function test_ZivoeDAO_modifyLockerWhitelist_state_changes() public {

        // Pre-state check.
        assert(!DAO.lockerWhitelist(address(0)));

        // Add locker to whitelist.
        assert(god.try_modifyLockerWhitelist(address(DAO), address(0), true));

        // Post-state check.
        assert(DAO.lockerWhitelist(address(0)));

        // Remove locker from whitelist.
        assert(god.try_modifyLockerWhitelist(address(DAO), address(0), false));

        // Post-state check.
        assert(!DAO.lockerWhitelist(address(0)));
    }

    function test_ZivoeDAO_modifyLockerWhitelist_restrictions() public {

        // User "bob" is unable to modify whitelist (only "god" is allowed).
        assert(!bob.try_modifyLockerWhitelist(address(DAO), address(0), true));
    }

    // Verify push() state changes.
    // Verify push() restrictions.

    function test_ZivoeDAO_push_state_changes() public {

        // Pre-state check.
        assertEq(IERC20(USDC).balanceOf(address(DAO)), 2000000 * 10**6);
        assertEq(IERC20(USDC).balanceOf(address(ZVL)), 0);

        // Push capital to locker.
        assert(god.try_push(address(DAO), address(ZVL), address(USDC), 2000000 * 10**6));

        // Post-state check.
        assertEq(IERC20(USDC).balanceOf(address(DAO)), 0);
        assertEq(IERC20(USDC).balanceOf(address(ZVL)), 2000000 * 10**6);
    }

    function test_ZivoeDAO_push_restrictions() public {

        // User "bob" is unable to call push (only "god" is allowed).
        assert(!bob.try_push(address(DAO), address(ZVL), USDC, 2000000 * 10**6));
    }

    // Verify pull() state changes.
    // Verify pull() restrictions.

    function test_ZivoeDAO_pull_state_changes() public {

        // Push capital to locker.
        assert(god.try_push(address(DAO), address(ZVL), address(USDC), 2000000 * 10**6));

        // Pre-state check.
        assertEq(IERC20(USDC).balanceOf(address(DAO)), 0);
        assertEq(IERC20(USDC).balanceOf(address(ZVL)), 2000000 * 10**6);

        // Pull capital to locker.
        assert(god.try_pull(address(DAO), address(ZVL), address(USDC)));

        // Post-state check.
        assertEq(IERC20(USDC).balanceOf(address(DAO)), 2000000 * 10**6);
        assertEq(IERC20(USDC).balanceOf(address(ZVL)), 0);

    }

    function test_ZivoeDAO_pull_restrictions() public {

        // Push some initial capital to locker (to ensure capital is present).
        assert(god.try_push(address(DAO), address(ZVL), USDC, 2000000 * 10**6));

        // User "bob" is unable to call pull (only "god" is allowed).
        assert(!bob.try_pull(address(DAO), address(ZVL), USDC));
    }
    
}
