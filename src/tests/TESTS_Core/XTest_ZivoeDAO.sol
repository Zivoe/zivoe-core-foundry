// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCY/OCY_Generic_ERC20.sol";

contract Test_ZivoeDAO is Utility {

    OCY_Generic_ERC20 ZVL;

    function setUp() public {

        deployCore(false);
        
        // Generic ZivoeLocker for ZivoeDAO test purposes.
        ZVL = new OCY_Generic_ERC20(address(DAO));

        // Add locker to whitelist.
        assert(god.try_updateIsLocker(address(GBL), address(ZVL), true));
    }

    // Verify initial state of DAO (ZivoeDAO.sol).
    // Verify initial state of ZVL (OCY_Generic.sol, generic inheritance of ZivoeLocker.sol).

    function xtest_ZivoeDAO_init() public {
        assertEq(DAO.owner(), address(god));
        assert(ZVL.canPush());
        assert(ZVL.canPushMulti());
        assert(ZVL.canPull());
        assert(ZVL.canPullPartial());
        assert(ZVL.canPullMulti());
        assert(ZVL.canPullMultiPartial());
        assert(!ZVL.canPullERC721());
        assert(!ZVL.canPushERC721());
        assert(!ZVL.canPullMultiERC721());
        assert(!ZVL.canPushMultiERC721());
        assert(!ZVL.canPullERC1155());
        assert(!ZVL.canPushERC1155());
    }

    // TODO: Test pushMulti() ... pullPartial() ... pullMulti() ... pullMultiPartial()

    // Verify push() state changes.
    // Verify push() restrictions.

    function xtest_ZivoeDAO_push_state_changes() public {

        // Pre-state check.
        assertEq(IERC20(USDC).balanceOf(address(DAO)), 2000000 * 10**6);
        assertEq(IERC20(USDC).balanceOf(address(ZVL)), 0);

        // Push capital to locker.
        assert(god.try_push(address(DAO), address(ZVL), address(USDC), 2000000 * 10**6));

        // Post-state check.
        assertEq(IERC20(USDC).balanceOf(address(DAO)), 0);
        assertEq(IERC20(USDC).balanceOf(address(ZVL)), 2000000 * 10**6);
    }

    function xtest_ZivoeDAO_push_restrictions() public {

        // User "bob" is unable to call push (only "god" is allowed).
        assert(!bob.try_push(address(DAO), address(ZVL), USDC, 2000000 * 10**6));
    }

    // Verify pull() state changes.
    // Verify pull() restrictions.

    function xtest_ZivoeDAO_pull_state_changes() public {

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

    function xtest_ZivoeDAO_pull_restrictions() public {

        // Push some initial capital to locker (to ensure capital is present).
        assert(god.try_push(address(DAO), address(ZVL), USDC, 2000000 * 10**6));

        // User "bob" is unable to call pull (only "god" is allowed).
        assert(!bob.try_pull(address(DAO), address(ZVL), USDC));
    }
    
}