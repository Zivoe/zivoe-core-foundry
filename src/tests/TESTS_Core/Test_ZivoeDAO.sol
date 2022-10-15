// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../lockers/OCG/OCG_ERC20.sol";
import "../../lockers/OCG/OCG_ERC721.sol";
import "../../lockers/OCG/OCG_ERC1155.sol";

import "../../tests/TESTS_Utility/generic_tokens/ERC721_Generic.sol";

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeDAO is Utility {

    OCG_ERC20 OCG_ERC20Locker;
    OCG_ERC721 OCG_ERC721Locker;
    OCG_ERC1155 OCG_ERC1155Locker;

    ERC721_Generic ZivoeNFT;

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

    function launchERC721() public {

        ZivoeNFT = new ERC721_Generic();

        ZivoeNFT.mintGenericNFT(address(DAO), "0.jpeg");
        ZivoeNFT.mintGenericNFT(address(DAO), "1.jpeg");
        ZivoeNFT.mintGenericNFT(address(DAO), "2.jpeg");
        ZivoeNFT.mintGenericNFT(address(DAO), "3.jpeg");

        assertEq(ZivoeNFT.name(), "ZivoeNFT");
        assertEq(ZivoeNFT.symbol(), "ZFT");

        assertEq(ZivoeNFT.tokenURI(0), "ipfs::0.jpeg");
        assertEq(ZivoeNFT.tokenURI(1), "ipfs::1.jpeg");
        assertEq(ZivoeNFT.tokenURI(2), "ipfs::2.jpeg");
        assertEq(ZivoeNFT.tokenURI(3), "ipfs::3.jpeg");

        assertEq(ZivoeNFT.balanceOf(address(DAO)), 4);
        assertEq(ZivoeNFT.ownerOf(0), address(DAO));
        assertEq(ZivoeNFT.ownerOf(1), address(DAO));
        assertEq(ZivoeNFT.ownerOf(2), address(DAO));
        assertEq(ZivoeNFT.ownerOf(3), address(DAO));

    }

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

        // Can't push to address(OCG_ERC721Locker), does not expose canPush().
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
            assertEq(IERC20(DAI).allowance(address(DAO), address(OCG_ERC20Locker)), 0);

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
            assertEq(IERC20(FRAX).allowance(address(DAO), address(OCG_ERC20Locker)), 0);

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
            assertEq(IERC20(USDC).allowance(address(DAO), address(OCG_ERC20Locker)), 0);

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
            assertEq(IERC20(USDT).allowance(address(DAO), address(OCG_ERC20Locker)), 0);

        } else { revert() ; }

    }

    // Validate pull() state changes.
    // Validate pull() restrictions.
    // This includes:
    //   - "locker" must have canPull() exposed as true value.

    function test_ZivoeDAO_pull_restrictions() public {

        // Can't pull from address(OCG_ERC721Locker), does not expose canPull().
        assert(!god.try_pull(address(DAO), address(OCG_ERC721Locker), address(DAI)));
    }

    function test_ZivoeDAO_pull_state(uint96 random) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));
        uint256 modularity = uint256(random) % 4;

        // push() to locker initially.
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(DAI), amt_DAI));
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(FRAX), amt_FRAX));
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(USDC), amt_USDC));
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(USDT), amt_USDT));

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

            // pull().
            assert(god.try_pull(address(DAO), address(OCG_ERC20Locker), address(DAI)));

            // Post-state.
            post_DAI[0] = IERC20(DAI).balanceOf(address(DAO));
            post_DAI[1] = IERC20(DAI).balanceOf(address(OCG_ERC20Locker));

            assertEq(amt_DAI, post_DAI[0] - pre_DAI[0]);  // DAO balance increases
            assertEq(amt_DAI, pre_DAI[1] - post_DAI[1]);  // OCG balance decreases
            assertEq(post_DAI[1], 0);                     // 0 balance remaining in OCG locker

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

            // pull().
            assert(god.try_pull(address(DAO), address(OCG_ERC20Locker), address(FRAX)));

            // Post-state.
            post_FRAX[0] = IERC20(FRAX).balanceOf(address(DAO));
            post_FRAX[1] = IERC20(FRAX).balanceOf(address(OCG_ERC20Locker));

            assertEq(amt_FRAX, post_FRAX[0] - pre_FRAX[0]);  // DAO balance increases
            assertEq(amt_FRAX, pre_FRAX[1] - post_FRAX[1]);  // OCG balance decreases
            assertEq(post_FRAX[1], 0);                       // 0 balance remaining in OCG locker

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

            // pull().
            assert(god.try_pull(address(DAO), address(OCG_ERC20Locker), address(USDC)));

            // Post-state.
            post_USDC[0] = IERC20(USDC).balanceOf(address(DAO));
            post_USDC[1] = IERC20(USDC).balanceOf(address(OCG_ERC20Locker));

            assertEq(amt_USDC, post_USDC[0] - pre_USDC[0]);  // DAO balance increases
            assertEq(amt_USDC, pre_USDC[1] - post_USDC[1]);  // OCG balance decreases
            assertEq(post_USDC[1], 0);                       // 0 balance remaining in OCG locker
            
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

            // pull().
            assert(god.try_pull(address(DAO), address(OCG_ERC20Locker), address(USDT)));

            // Post-state.
            post_USDT[0] = IERC20(USDT).balanceOf(address(DAO));
            post_USDT[1] = IERC20(USDT).balanceOf(address(OCG_ERC20Locker));

            assertEq(amt_USDT, post_USDT[0] - pre_USDT[0]);  // DAO balance increases
            assertEq(amt_USDT, pre_USDT[1] - post_USDT[1]);  // OCG balance decreases
            assertEq(post_USDT[1], 0);                       // 0 balance remaining in OCG locker
            
        } else { revert(); }

        
    }

    // Validate pullPartial() state changes.
    // Validate pullPartial() restrictions.
    // This includes:
    //   - "locker" must have canPullPartial() exposed as true value.

    function test_ZivoeDAO_pullPartial_restrictions() public {

        // Can't pull from address(OCG_ERC721Locker), does not expose canPullPartial().
        assert(!god.try_pullPartial(address(DAO), address(OCG_ERC721Locker), address(DAI), 1000 ether));

    }

    function test_ZivoeDAO_pullPartial_state(uint96 random) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));
        uint256 modularity = uint256(random) % 4;

        // push() to locker initially.
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(DAI), amt_DAI));
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(FRAX), amt_FRAX));
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(USDC), amt_USDC));
        assert(god.try_push(address(DAO), address(OCG_ERC20Locker), address(USDT), amt_USDT));

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

            // pullPartial().
            assert(god.try_pullPartial(address(DAO), address(OCG_ERC20Locker), address(DAI), amt_DAI));

            // Post-state.
            post_DAI[0] = IERC20(DAI).balanceOf(address(DAO));
            post_DAI[1] = IERC20(DAI).balanceOf(address(OCG_ERC20Locker));

            assertEq(amt_DAI, post_DAI[0] - pre_DAI[0]);  // DAO balance increases
            assertEq(amt_DAI, pre_DAI[1] - post_DAI[1]);  // OCG balance decreases


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

            // pullPartial().
            assert(god.try_pullPartial(address(DAO), address(OCG_ERC20Locker), address(FRAX), amt_FRAX));

            // Post-state.
            post_FRAX[0] = IERC20(FRAX).balanceOf(address(DAO));
            post_FRAX[1] = IERC20(FRAX).balanceOf(address(OCG_ERC20Locker));

            assertEq(amt_FRAX, post_FRAX[0] - pre_FRAX[0]);  // DAO balance increases
            assertEq(amt_FRAX, pre_FRAX[1] - post_FRAX[1]);  // OCG balance decreases

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

            // pullPartial().
            assert(god.try_pullPartial(address(DAO), address(OCG_ERC20Locker), address(USDC), amt_USDC));

            // Post-state.
            post_USDC[0] = IERC20(USDC).balanceOf(address(DAO));
            post_USDC[1] = IERC20(USDC).balanceOf(address(OCG_ERC20Locker));

            assertEq(amt_USDC, post_USDC[0] - pre_USDC[0]);  // DAO balance increases
            assertEq(amt_USDC, pre_USDC[1] - post_USDC[1]);  // OCG balance decreases
            
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

            // pullPartial().
            assert(god.try_pullPartial(address(DAO), address(OCG_ERC20Locker), address(USDT), amt_USDT));

            // Post-state.
            post_USDT[0] = IERC20(USDT).balanceOf(address(DAO));
            post_USDT[1] = IERC20(USDT).balanceOf(address(OCG_ERC20Locker));

            assertEq(amt_USDT, post_USDT[0] - pre_USDT[0]);  // DAO balance increases
            assertEq(amt_USDT, pre_USDT[1] - post_USDT[1]);  // OCG balance decreases
            
        } else { revert(); }
        
    }

    // Validate pushMulti() state changes.
    // Validate pushMulti() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - assets.length == amounts.length (length of input arrays must equal)
    //   - "locker" must have canPushMulti() exposed as true value.

    function test_ZivoeDAO_pushMulti_restrictions(uint96 random) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));
        
        address[] memory assets_bad = new address[](3);
        address[] memory assets_good = new address[](4);
        uint256[] memory amounts = new uint256[](4);

        assets_bad[0] = DAI;
        assets_bad[1] = FRAX;
        assets_bad[2] = USDC;

        assets_good[0] = DAI;
        assets_good[1] = FRAX;
        assets_good[2] = USDC;
        assets_good[3] = USDT;

        amounts[0] = amt_DAI;
        amounts[1] = amt_FRAX;
        amounts[2] = amt_USDC;
        amounts[3] = amt_USDT;

        // Can't push to address(0), not whitelisted.
        assert(!god.try_pushMulti(address(DAO), address(0), assets_good, amounts));

        // Can't push with assets_bad / amounts due to mismatch array length.
        assert(!god.try_pushMulti(address(DAO), address(OCG_ERC20Locker), assets_bad, amounts));

        // Can't push to address(OCG_ERC721Locker), does not expose canPushMulti().
        assert(!god.try_pushMulti(address(DAO), address(OCG_ERC721Locker), assets_good, amounts));

    }

    function test_ZivoeDAO_pushMulti_state(uint96 random) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));
        
        address[] memory assets = new address[](4);
        uint256[] memory amounts = new uint256[](4);

        assets[0] = DAI;
        assets[1] = FRAX;
        assets[2] = USDC;
        assets[3] = USDT;

        amounts[0] = amt_DAI;
        amounts[1] = amt_FRAX;
        amounts[2] = amt_USDC;
        amounts[3] = amt_USDT;

        // Pre-state.
        assertEq(IERC20(DAI).balanceOf(address(OCG_ERC20Locker)), 0);
        assertEq(IERC20(FRAX).balanceOf(address(OCG_ERC20Locker)), 0);
        assertEq(IERC20(USDC).balanceOf(address(OCG_ERC20Locker)), 0);
        assertEq(IERC20(USDT).balanceOf(address(OCG_ERC20Locker)), 0);

        uint256[4] memory pre_balances = [
            IERC20(DAI).balanceOf(address(DAO)), 
            IERC20(FRAX).balanceOf(address(DAO)),
            IERC20(USDC).balanceOf(address(DAO)),
            IERC20(USDT).balanceOf(address(DAO))
        ];

        // pushMulti().
        assert(god.try_pushMulti(address(DAO), address(OCG_ERC20Locker), assets, amounts));

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(OCG_ERC20Locker)), amt_DAI);
        assertEq(IERC20(FRAX).balanceOf(address(OCG_ERC20Locker)), amt_FRAX);
        assertEq(IERC20(USDC).balanceOf(address(OCG_ERC20Locker)), amt_USDC);
        assertEq(IERC20(USDT).balanceOf(address(OCG_ERC20Locker)), amt_USDT);

        uint256[4] memory post_balances = [
            IERC20(DAI).balanceOf(address(DAO)), 
            IERC20(FRAX).balanceOf(address(DAO)),
            IERC20(USDC).balanceOf(address(DAO)),
            IERC20(USDT).balanceOf(address(DAO))
        ];

        assertEq(pre_balances[0] - post_balances[0], amt_DAI);
        assertEq(pre_balances[1] - post_balances[1], amt_FRAX);
        assertEq(pre_balances[2] - post_balances[2], amt_USDC);
        assertEq(pre_balances[3] - post_balances[3], amt_USDT);

    }

    // Validate pullMulti() state changes.
    // Validate pullMulti() restrictions.
    // This includes:
    //   - "locker" must have canPullMulti() exposed as true value.

    function test_ZivoeDAO_pullMulti_restrictions() public {

        address[] memory assets = new address[](4);

        assets[0] = DAI;
        assets[1] = FRAX;
        assets[2] = USDC;
        assets[3] = USDT;

        // Can't pull from address(OCG_ERC721Locker), does not expose canPullMulti().
        assert(!god.try_pullMulti(address(DAO), address(OCG_ERC721Locker), assets));

    }

    function test_ZivoeDAO_pullMulti_state(uint96 random, uint96 lower) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));
        uint256 modularity = uint256(random) % 4;
        
        address[] memory assets = new address[](4);
        uint256[] memory amounts = new uint256[](4);

        assets[0] = DAI;
        assets[1] = FRAX;
        assets[2] = USDC;
        assets[3] = USDT;

        amounts[0] = amt_DAI;
        amounts[1] = amt_FRAX;
        amounts[2] = amt_USDC;
        amounts[3] = amt_USDT;

        // pushMulti().
        assert(god.try_pushMulti(address(DAO), address(OCG_ERC20Locker), assets, amounts));

        // Pre-state.
        assertEq(IERC20(DAI).balanceOf(address(OCG_ERC20Locker)), amt_DAI);
        assertEq(IERC20(FRAX).balanceOf(address(OCG_ERC20Locker)), amt_FRAX);
        assertEq(IERC20(USDC).balanceOf(address(OCG_ERC20Locker)), amt_USDC);
        assertEq(IERC20(USDT).balanceOf(address(OCG_ERC20Locker)), amt_USDT);

        uint256[4] memory pre_DAO = [
            IERC20(DAI).balanceOf(address(DAO)), 
            IERC20(FRAX).balanceOf(address(DAO)),
            IERC20(USDC).balanceOf(address(DAO)),
            IERC20(USDT).balanceOf(address(DAO))
        ];

        // pullMulti().
        assert(god.try_pullMulti(address(DAO), address(OCG_ERC20Locker), assets));

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(OCG_ERC20Locker)), 0);
        assertEq(IERC20(FRAX).balanceOf(address(OCG_ERC20Locker)), 0);
        assertEq(IERC20(USDC).balanceOf(address(OCG_ERC20Locker)), 0);
        assertEq(IERC20(USDT).balanceOf(address(OCG_ERC20Locker)), 0);

        assertEq(IERC20(DAI).balanceOf(address(DAO)), pre_DAO[0] + amt_DAI);
        assertEq(IERC20(FRAX).balanceOf(address(DAO)), pre_DAO[1] + amt_FRAX);
        assertEq(IERC20(USDC).balanceOf(address(DAO)), pre_DAO[2] + amt_USDC);
        assertEq(IERC20(USDT).balanceOf(address(DAO)), pre_DAO[3] + amt_USDT);
        
    }

    // Validate pullMultiPartial() state changes.
    // Validate pullMultiPartial() restrictions.
    // This includes:
    //   - "locker" must have canPullMultiPartial() exposed as true value.
    //   - assets.length == amounts.length (length of input arrays must equal)

    function test_ZivoeDAO_pullMultiPartial_restrictions(uint96 random) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));
        
        address[] memory assets_bad = new address[](3);
        uint256[] memory amounts = new uint256[](4);

        assets_bad[0] = DAI;
        assets_bad[1] = FRAX;
        assets_bad[2] = USDC;

        amounts[0] = amt_DAI;
        amounts[1] = amt_FRAX;
        amounts[2] = amt_USDC;
        amounts[3] = amt_USDT;

        // Can't pull from address(OCG_ERC721Locker), does not expose canPushMulti().
        assert(!god.try_pullMultiPartial(address(DAO), address(OCG_ERC721Locker), assets_bad, amounts));

        // Can't pull from address(OCG_ERC20Locker), assets_bad.length != amounts.length.
        assert(!god.try_pullMultiPartial(address(DAO), address(OCG_ERC20Locker), assets_bad, amounts));

    }

    function test_ZivoeDAO_pullMultiPartial_state(uint96 random, uint96 pull) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));
        uint256 modularity = uint256(random) % 4;
        
        if (amt_USDC < 10 * USD) {
            amt_DAI += 10 ether;
            amt_FRAX += 10 ether;
            amt_USDC += 10 * USD;
            amt_USDT += 10 * USD;
        }

        address[] memory assets = new address[](4);
        uint256[] memory amounts = new uint256[](4);
        uint256[] memory amounts_partial = new uint256[](4);

        assets[0] = DAI;
        assets[1] = FRAX;
        assets[2] = USDC;
        assets[3] = USDT;

        amounts[0] = amt_DAI;
        amounts[1] = amt_FRAX;
        amounts[2] = amt_USDC;
        amounts[3] = amt_USDT;

        // pushMulti().
        assert(god.try_pushMulti(address(DAO), address(OCG_ERC20Locker), assets, amounts));

        amounts_partial[0] = pull % IERC20(DAI).balanceOf(address(OCG_ERC20Locker));
        amounts_partial[0] = pull % IERC20(FRAX).balanceOf(address(OCG_ERC20Locker));
        amounts_partial[0] = pull % IERC20(USDC).balanceOf(address(OCG_ERC20Locker));
        amounts_partial[0] = pull % IERC20(USDT).balanceOf(address(OCG_ERC20Locker));

        // Pre-state.
        assertEq(IERC20(DAI).balanceOf(address(OCG_ERC20Locker)), amt_DAI);
        assertEq(IERC20(FRAX).balanceOf(address(OCG_ERC20Locker)), amt_FRAX);
        assertEq(IERC20(USDC).balanceOf(address(OCG_ERC20Locker)), amt_USDC);
        assertEq(IERC20(USDT).balanceOf(address(OCG_ERC20Locker)), amt_USDT);

        uint256[4] memory pre_DAO = [
            IERC20(DAI).balanceOf(address(DAO)), 
            IERC20(FRAX).balanceOf(address(DAO)),
            IERC20(USDC).balanceOf(address(DAO)),
            IERC20(USDT).balanceOf(address(DAO))
        ];

        // pullMultiPartial().
        assert(god.try_pullMultiPartial(address(DAO), address(OCG_ERC20Locker), assets, amounts_partial));

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(OCG_ERC20Locker)), amt_DAI - amounts_partial[0]);
        assertEq(IERC20(FRAX).balanceOf(address(OCG_ERC20Locker)), amt_FRAX - amounts_partial[1]);
        assertEq(IERC20(USDC).balanceOf(address(OCG_ERC20Locker)), amt_USDC - amounts_partial[2]);
        assertEq(IERC20(USDT).balanceOf(address(OCG_ERC20Locker)), amt_USDT - amounts_partial[3]);

        assertEq(IERC20(DAI).balanceOf(address(DAO)), pre_DAO[0] + amounts_partial[0]);
        assertEq(IERC20(FRAX).balanceOf(address(DAO)), pre_DAO[1] + amounts_partial[1]);
        assertEq(IERC20(USDC).balanceOf(address(DAO)), pre_DAO[2] + amounts_partial[2]);
        assertEq(IERC20(USDT).balanceOf(address(DAO)), pre_DAO[3] + amounts_partial[3]);
        
    }

    // Validate pushERC721() state changes.
    // Validate pushERC721() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - "locker" must have canPushERC721() exposed as true value.

    function test_ZivoeDAO_pushERC721_restrictions() public {

        // mint().
        launchERC721();

        // Can't push NFT to address(0), locker not whitelisted.
        assert(!god.try_pushERC721(address(DAO), address(0), address(ZivoeNFT), 0, ""));

        // Can't push NFT to address(OCG_ERC20Locker), does not expose canPushERC721().
        assert(!god.try_pushERC721(address(DAO), address(OCG_ERC20Locker), address(ZivoeNFT), 0, ""));

        // Example success call.
        assert(god.try_pushERC721(address(DAO), address(OCG_ERC721Locker), address(ZivoeNFT), 0, ""));

    }

    function test_ZivoeDAO_pushERC721_state() public {
        
        // mint().
        launchERC721();

        // Pre-state.
        assertEq(ZivoeNFT.balanceOf(address(OCG_ERC721Locker)), 0);
        assertEq(ZivoeNFT.balanceOf(address(DAO)), 4);
        assertEq(ZivoeNFT.ownerOf(0), address(DAO));
        assertEq(ZivoeNFT.getApproved(0), address(0));

        // pushERC721().
        assert(god.try_pushERC721(address(DAO), address(OCG_ERC721Locker), address(ZivoeNFT), 0, ""));

        // Post-state.
        assertEq(ZivoeNFT.balanceOf(address(OCG_ERC721Locker)), 1);
        assertEq(ZivoeNFT.balanceOf(address(DAO)), 3);
        assertEq(ZivoeNFT.ownerOf(0), address(OCG_ERC721Locker));
        assertEq(ZivoeNFT.getApproved(0), address(0));
        
    }

    // Validate pushMultiERC721() state changes.
    // Validate pushMultiERC721() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - assets.length == tokenIds.length (length of input arrays must equal)
    //   - tokenIds.length == data.length (length of input arrays must equal)
    //   - "locker" must have canPushMultiERC721() exposed as true value.

    function test_ZivoeDAO_pushMultiERC721_restrictions() public {

        // mint().
        launchERC721();

        address[] memory bad_assets = new address[](2);
        address[] memory good_assets = new address[](4);
        uint[] memory bad_tokenIds = new uint[](3);
        uint[] memory good_tokenIds = new uint[](4);
        bytes[] memory bad_data = new bytes[](1);
        bytes[] memory good_data = new bytes[](4);

        bad_assets[0] = address(ZivoeNFT);
        bad_assets[1] = address(ZivoeNFT);

        good_assets[0] = address(ZivoeNFT);
        good_assets[1] = address(ZivoeNFT);
        good_assets[2] = address(ZivoeNFT);
        good_assets[3] = address(ZivoeNFT);

        bad_tokenIds[0] = 0;
        bad_tokenIds[1] = 1;
        bad_tokenIds[2] = 2;

        good_tokenIds[0] = 0;
        good_tokenIds[1] = 1;
        good_tokenIds[2] = 2;
        good_tokenIds[3] = 3;

        bad_data[0] = '';

        good_data[0] = '';
        good_data[1] = '';
        good_data[2] = '';
        good_data[3] = '';

        // Can't pushMulti NFT to address(0), locker not whitelisted.
        assert(!god.try_pushMultiERC721(address(DAO), address(0), good_assets, good_tokenIds, bad_data));

        // Can't pushMulti NFT to address(OCG_ERC721Locker), assets.length != tokenIds.length.
        assert(!god.try_pushMultiERC721(address(DAO), address(OCG_ERC721Locker), bad_assets, bad_tokenIds, bad_data));

        // Can't pushMulti NFT to address(OCG_ERC721Locker), tokenIds.length != data.length.
        assert(!god.try_pushMultiERC721(address(DAO), address(OCG_ERC721Locker), good_assets, good_tokenIds, bad_data));

        // Can't pushMulti NFT to address(OCG_ERC20Locker), does not expose canPushMultiERC721().
        assert(!god.try_pushMultiERC721(address(DAO), address(OCG_ERC20Locker), good_assets, good_tokenIds, good_data));

        // Example success call.
        assert(god.try_pushMultiERC721(address(DAO), address(OCG_ERC721Locker), good_assets, good_tokenIds, good_data));

    }

    function test_ZivoeDAO_pushMultiERC721_state() public {
        
        // mint().
        launchERC721();

        address[] memory assets = new address[](4);
        uint[] memory tokenIds = new uint[](4);
        bytes[] memory data = new bytes[](4);

        assets[0] = address(ZivoeNFT);
        assets[1] = address(ZivoeNFT);
        assets[2] = address(ZivoeNFT);
        assets[3] = address(ZivoeNFT);

        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        tokenIds[3] = 3;

        data[0] = '';
        data[1] = '';
        data[2] = '';
        data[3] = '';

        // Pre-state.
        assertEq(ZivoeNFT.balanceOf(address(OCG_ERC721Locker)), 0);
        assertEq(ZivoeNFT.balanceOf(address(DAO)), 4);
        assertEq(ZivoeNFT.ownerOf(0), address(DAO));
        assertEq(ZivoeNFT.ownerOf(1), address(DAO));
        assertEq(ZivoeNFT.ownerOf(2), address(DAO));
        assertEq(ZivoeNFT.ownerOf(3), address(DAO));
        assertEq(ZivoeNFT.getApproved(0), address(0));
        assertEq(ZivoeNFT.getApproved(1), address(0));
        assertEq(ZivoeNFT.getApproved(2), address(0));
        assertEq(ZivoeNFT.getApproved(3), address(0));

        // pushERC721().
        assert(god.try_pushMultiERC721(address(DAO), address(OCG_ERC721Locker), assets, tokenIds, data));

        // Post-state.
        assertEq(ZivoeNFT.balanceOf(address(OCG_ERC721Locker)), 4);
        assertEq(ZivoeNFT.balanceOf(address(DAO)), 0);
        assertEq(ZivoeNFT.ownerOf(0), address(OCG_ERC721Locker));
        assertEq(ZivoeNFT.ownerOf(1), address(OCG_ERC721Locker));
        assertEq(ZivoeNFT.ownerOf(2), address(OCG_ERC721Locker));
        assertEq(ZivoeNFT.ownerOf(3), address(OCG_ERC721Locker));
        assertEq(ZivoeNFT.getApproved(0), address(0));
        assertEq(ZivoeNFT.getApproved(1), address(0));
        assertEq(ZivoeNFT.getApproved(2), address(0));
        assertEq(ZivoeNFT.getApproved(3), address(0));
        
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
