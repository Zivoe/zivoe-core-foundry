// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../lockers/OCG/OCG_ERC20.sol";
import "../../lockers/OCG/OCG_ERC721.sol";
import "../../lockers/OCG/OCG_ERC1155.sol";

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeDAO is Utility {

    OCG_ERC20 OCG_ERC20Locker;
    OCG_ERC721 OCG_ERC721Locker;
    OCG_ERC1155 OCG_ERC1155Locker;

    function setUp() public {

        deployCore(false);

        // Deploy 3 OCG (On-Chain Generic) lockers.
        OCG_ERC20Locker = new OCG_ERC20(address(DAO));
        OCG_ERC721Locker = new OCG_ERC721(address(DAO));
        OCG_ERC1155Locker = new OCG_ERC1155(address(DAO));

        // Whitelist OCG lockers.
        assert(zvl.try_updateIsLocker(address(GBL), address(OCG_ERC20Locker), true));
        assert(zvl.try_updateIsLocker(address(GBL), address(OCG_ERC721Locker), true));
        assert(zvl.try_updateIsLocker(address(GBL), address(OCG_ERC1155Locker), true));

        // Simulate ITO, supply ERC20 tokens to DAO.
        simulateITO(100_000_000 ether, 100_000_000 ether, 100_000_000 * USD, 100_000_000 * USD);

        // Create ERC721 contract for testing OCG_ERC721Locker interactions.


        // Create ERC1155 contract for testing OCG_ERC1155Locker interactions.
        
    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate initial state of OCG (On-Chain Generic) lockers.

    function test_ZivoeDAO_OCG_init() public {
        
        assert(GBL.isLocker(address(OCG_ERC20Locker)));
        assert(GBL.isLocker(address(OCG_ERC721Locker)));
        assert(GBL.isLocker(address(OCG_ERC1155Locker)));
        
        assert(OCG_ERC20Locker.canPush());
        assert(OCG_ERC20Locker.canPull());
        assert(OCG_ERC20Locker.canPullPartial());
        assert(OCG_ERC20Locker.canPushMulti());
        assert(OCG_ERC20Locker.canPullMulti());
        assert(OCG_ERC20Locker.canPullMultiPartial());

        assert(OCG_ERC721Locker.canPushERC721());
        assert(OCG_ERC721Locker.canPushMultiERC721());
        assert(OCG_ERC721Locker.canPullERC721());
        assert(OCG_ERC721Locker.canPullMultiERC721());

        assert(OCG_ERC1155Locker.canPushERC1155());
        assert(OCG_ERC1155Locker.canPullERC1155());

    }

    // Validate push() state changes.
    // Validate push() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - "locker" must have canPush() exposed as true value.

    function test_ZivoeDAO_push_restrictions() public {

        // Can't push to address(0), not whitelisted.
        assert(!god.try_push(address(DAO), address(0), address(DAI), 1000 ether));

        // Can't push to address(OCG_ERC721Locker), not whitelisted.
        assert(!god.try_push(address(DAO), address(OCG_ERC721Locker), address(DAI), 1000 ether));

    }

    function test_ZivoeDAO_push_state(uint96 random) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));

        uint256 modularity = uint256(random) % 4;

        if (modularity == 0) {

            // Pre-state.
            uint256[2] memory pre_DAI = [
                IERC20(DAI).balanceOf(address(DAO)), 
                IERC20(DAI).balanceOf(address(OCG_ERC20Locker))
            ];
            uint256[2] memory post_DAI = [
                uint256(0), 
                uint256(0)
            ];

            // push().
            assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(DAI), amt_DAI));

            // Post-state.
            post_DAI[0] = IERC20(DAI).balanceOf(address(DAO));
            post_DAI[1] = IERC20(DAI).balanceOf(address(OCG_ERC20Locker));

            assertEq(amt_DAI, pre_DAI[0] - post_DAI[0]);  // DAO balance decreases
            assertEq(amt_DAI, post_DAI[1] - pre_DAI[1]);  // OCG balance increases

            // Note: Important check, safeApprove() will break in future if this does not exist.
            // Note: safeApprove() reverts on non-ZERO to non-ZERO modification attempt.
            assertEq(IERC20(asset).allowance(address(DAO), address(OCG_ERC20Locker)), 0);

        } else if (modularity == 1) {

            // Pre-state.
            uint256[2] memory pre_FRAX = [
                IERC20(FRAX).balanceOf(address(DAO)), 
                IERC20(FRAX).balanceOf(address(OCG_ERC20Locker))
            ];
            uint256[2] memory post_FRAX = [
                uint256(0), 
                uint256(0)
            ];

            // push().
            assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(FRAX), amt_FRAX));

            // Post-state.
            post_FRAX[0] = IERC20(FRAX).balanceOf(address(DAO));
            post_FRAX[1] = IERC20(FRAX).balanceOf(address(OCG_ERC20Locker));

            assertEq(amt_FRAX, pre_FRAX[0] - post_FRAX[0]);  // DAO balance decreases
            assertEq(amt_FRAX, post_FRAX[1] - pre_FRAX[1]);  // OCG balance increases

            // Note: Important check, safeApprove() will break in future if this does not exist.
            // Note: safeApprove() reverts on non-ZERO to non-ZERO modification attempt.
            assertEq(IERC20(asset).allowance(address(DAO), address(OCG_ERC20Locker)), 0);

        } else if (modularity == 2) {

            // Pre-state.
            uint256[2] memory pre_USDC = [
                IERC20(USDC).balanceOf(address(DAO)), 
                IERC20(USDC).balanceOf(address(OCG_ERC20Locker))
            ];
            uint256[2] memory post_USDC = [
                uint256(0), 
                uint256(0)
            ];

            // push().
            assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(USDC), amt_USDC));

            // Post-state.
            post_USDC[0] = IERC20(USDC).balanceOf(address(DAO));
            post_USDC[1] = IERC20(USDC).balanceOf(address(OCG_ERC20Locker));

            assertEq(amt_USDC, pre_USDC[0] - post_USDC[0]);  // DAO balance decreases
            assertEq(amt_USDC, post_USDC[1] - pre_USDC[1]);  // OCG balance increases

            // Note: Important check, safeApprove() will break in future if this does not exist.
            // Note: safeApprove() reverts on non-ZERO to non-ZERO modification attempt.
            assertEq(IERC20(asset).allowance(address(DAO), address(OCG_ERC20Locker)), 0);

        } else if (modularity == 3) {

            // Pre-state.
            uint256[2] memory pre_USDT = [
                IERC20(USDT).balanceOf(address(DAO)), 
                IERC20(USDT).balanceOf(address(OCG_ERC20Locker))
            ];
            uint256[2] memory post_USDT = [
                uint256(0), 
                uint256(0)
            ];

            // push().
            assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(USDT), amt_USDT));

            // Post-state.
            post_USDT[0] = IERC20(USDT).balanceOf(address(DAO));
            post_USDT[1] = IERC20(USDT).balanceOf(address(OCG_ERC20Locker));

            assertEq(amt_USDT, pre_USDT[0] - post_USDT[0]);  // DAO balance decreases
            assertEq(amt_USDT, post_USDT[1] - pre_USDT[1]);  // OCG balance increases

            // Note: Important check, safeApprove() will break in future if this does not exist.
            // Note: safeApprove() reverts on non-ZERO to non-ZERO modification attempt.
            assertEq(IERC20(asset).allowance(address(DAO), address(OCG_ERC20Locker)), 0);

        } else { revert() ; }

    }

    // Validate pull() state changes.
    // Validate pull() restrictions.
    // This includes:
    //   - "locker" must have canPull() exposed as true value.

    function test_ZivoeDAO_pull_restrictions() public {

    }

    function test_ZivoeDAO_pull_state(uint96 random) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));

        // push() to locker initially.
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(DAI), amt_DAI));
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(FRAX), amt_FRAX));
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(USDC), amt_USDC));
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(USDT), amt_USDT));

        // Pre-state.
        // TODO

        // pull().
        assert(god.try_pull(address(DAO), address(OCG_ERC20Locker), address(DAI)));
        assert(god.try_pull(address(DAO), address(OCG_ERC20Locker), address(FRAX)));
        assert(god.try_pull(address(DAO), address(OCG_ERC20Locker), address(USDC)));
        assert(god.try_pull(address(DAO), address(OCG_ERC20Locker), address(USDT)));

        // Post-state.
        // TODO
        
    }

    // Validate pullPartial() state changes.
    // Validate pullPartial() restrictions.
    // This includes:
    //   - "locker" must have canPullPartial() exposed as true value.

    function test_ZivoeDAO_pullPartial_restrictions() public {

    }

    function test_ZivoeDAO_pullPartial_state(uint96 random) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));

        // push() to locker initially.
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(DAI), amt_DAI));
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(FRAX), amt_FRAX));
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(USDC), amt_USDC));
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(USDT), amt_USDT));

        // Pre-state.
        // TODO

        // pullPartial().
        // TODO

        // Post-state.
        // TODO
        
    }

    // Validate pushMulti() state changes.
    // Validate pushMulti() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - assets.length == amounts.length (length of input arrays must equal)
    //   - "locker" must have canPushMulti() exposed as true value.

    function test_ZivoeDAO_pushMulti_restrictions() public {

    }

    function test_ZivoeDAO_pushMulti_state(uint96 random) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));

        // Pre-state.
        // TODO

        // pushMulti().
        // TODO

        // Post-state.
        // TODO

    }

    // Validate pullMulti() state changes.
    // Validate pullMulti() restrictions.
    // This includes:
    //   - "locker" must have canPullMulti() exposed as true value.

    function test_ZivoeDAO_pullMulti_restrictions() public {

    }

    function test_ZivoeDAO_pullMulti_state(uint96 random) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));

        // pushMulti().
        // TODO

        // Pre-state.
        // TODO

        // pullMulti().
        // TODO

        // Post-state.
        // TODO
        
    }

    // Validate pullMultiPartial() state changes.
    // Validate pullMultiPartial() restrictions.
    // This includes:
    //   - "locker" must have canPullMultiPartial() exposed as true value.
    //   - assets.length == amounts.length (length of input arrays must equal)

    function test_ZivoeDAO_pullMultiPartial_restrictions() public {

    }

    function test_ZivoeDAO_pullMultiPartial_state(uint96 random) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));

        // pushMulti().
        // TODO

        // Pre-state.
        // TODO

        // pullMulti().
        // TODO

        // Post-state.
        // TODO
        
    }

    // Validate pushERC721() state changes.
    // Validate pushERC721() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - "locker" must have canPushERC721() exposed as true value.

    function test_ZivoeDAO_pushERC721_restrictions() public {

    }

    function test_ZivoeDAO_pushERC721_state() public {
        
        // mint()
        // TODO

        // Pre-state.
        // TODO

        // pushERC721().
        // TODO

        // Post-state.
        // TODO
        
    }

    // Validate pushMultiERC721() state changes.
    // Validate pushMultiERC721() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - assets.length == tokenIds.length (length of input arrays must equal)
    //   - tokenIds.length == data.length (length of input arrays must equal)
    //   - "locker" must have canPushMultiERC721() exposed as true value.

    function test_ZivoeDAO_pushMultiERC721_restrictions() public {

    }

    function test_ZivoeDAO_pushMultiERC721_state() public {
        
        // mint()
        // TODO

        // Pre-state.
        // TODO

        // pushERC721().
        // TODO

        // Post-state.
        // TODO
        
    }

    // Validate pullERC721() state changes.
    // Validate pullERC721() restrictions.
    // This includes:
    //   - "locker" must have canPullERC721() exposed as true value.

    function test_ZivoeDAO_pullERC721_restrictions() public {

    }

    function test_ZivoeDAO_pullERC721_state() public {
        
        // mint()
        // TODO

        // pushERC721().
        // TODO

        // Pre-state.
        // TODO

        // pullERC721().
        // TODO

        // Post-state.
        // TODO
        
    }

    // Validate pullMultiERC721() state changes.
    // Validate pullMultiERC721() restrictions.
    // This includes:
    //   - "locker" must have canPullMultiERC721() exposed as true value.
    //   - assets.length == tokenIds.length (length of input arrays must equal)
    //   - tokenIds.length == data.length (length of input arrays must equal)

    function test_ZivoeDAO_pullMultiERC721_restrictions() public {

    }

    function test_ZivoeDAO_pullMultiERC721_state() public {
        
        // mint()
        // TODO

        // pushERC721().
        // TODO

        // Pre-state.
        // TODO

        // pullMultiERC721().
        // TODO

        // Post-state.
        // TODO
        
    }

    // Validate pushERC1155Batch() state changes.
    // Validate pushERC1155Batch() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - ids.length == amounts.length (length of input arrays must equal)
    //   - "locker" must have canPushERC1155() exposed as true value.

    function test_ZivoeDAO_pushERC1155Batch_restrictions() public {

    }

    function test_ZivoeDAO_pushERC1155Batch_state() public {
        
        // mint()
        // TODO

        // Pre-state.
        // TODO

        // pushERC1155Batch().
        // TODO

        // Post-state.
        // TODO
        
    }

    // Validate pullERC1155Batch() state changes.
    // Validate pullERC1155Batch() restrictions.
    // This includes:
    //   - "locker" must have canPullERC1155() exposed as true value.
    //   - ids.length == amounts.length (length of input arrays must equal)

    function test_ZivoeDAO_pullERC1155Batch_restrictions() public {

    }

    function test_ZivoeDAO_pullERC1155Batch_state() public {
        
        // mint()
        // TODO

        // pushERC1155Batch().
        // TODO

        // Pre-state.
        // TODO

        // pullERC1155Batch().
        // TODO

        // Post-state.
        // TODO
        
    }

}
