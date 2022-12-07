// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../lockers/OCG/OCG_ERC20.sol";
import "../../lockers/OCG/OCG_ERC721.sol";
import "../../lockers/OCG/OCG_ERC1155.sol";

import "../../tests/TESTS_Utility/generic_tokens/ERC721_Generic.sol";
import "../../tests/TESTS_Utility/generic_tokens/ERC1155_Generic.sol";

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeDAO is Utility {

    OCG_ERC20 OCG_ERC20Locker;
    OCG_ERC721 OCG_ERC721Locker;
    OCG_ERC1155 OCG_ERC1155Locker;

    ERC721_Generic ZivoeNFT;
    ERC1155_Generic ZivoeERC1155;

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

    function launchERC1155() public {

        ZivoeERC1155 = new ERC1155_Generic(address(DAO));

        assertEq(ZivoeERC1155.balanceOf(address(DAO), 0), 10**18);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 1), 10**27);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 2), 1);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 3), 10**9);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 4), 10**9);
    }

    function pushMultiRestrictions(uint96 random) public view returns (
        address[] memory _assets_bad,
        address[] memory _assets_good,
        uint256[] memory _amounts
    ) 
    {
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

        return (assets_bad, assets_good, amounts);
    }

    function pullMultiERC721Restrictions() public returns (
        address[] memory bad_assets,
        address[] memory good_assets,
        uint256[] memory bad_tokenIds,
        uint256[] memory good_tokenIds,
        bytes[] memory bad_data,
        bytes[] memory good_data
    )
    {
        // mint().
        launchERC721();

        bad_assets = new address[](2);
        good_assets = new address[](4);
        bad_tokenIds = new uint256[](3);
        good_tokenIds = new uint256[](4);
        bad_data = new bytes[](1);
        good_data = new bytes[](4);

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
    }

    function pushMultiERC721Restrictions() public returns (
        address[] memory bad_assets,
        address[] memory good_assets,
        uint256[] memory bad_tokenIds,
        uint256[] memory good_tokenIds,
        bytes[] memory bad_data,
        bytes[] memory good_data
    )
    {
        // mint().
        launchERC721();

        bad_assets = new address[](2);
        good_assets = new address[](4);
        bad_tokenIds = new uint256[](3);
        good_tokenIds = new uint256[](4);
        bad_data = new bytes[](1);
        good_data = new bytes[](4);

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
    }

    function pushERC1155BatchRestrictions() public returns (
        uint256[] memory bad_ids,
        uint256[] memory good_ids,
        uint256[] memory amounts
    ) 
    {
        bad_ids = new uint256[](4);
        good_ids = new uint256[](5);
        amounts = new uint256[](5);

        bad_ids[0] = 0;
        bad_ids[1] = 1;
        bad_ids[2] = 2;
        bad_ids[3] = 3;

        good_ids[0] = 0;
        good_ids[1] = 1;
        good_ids[2] = 2;
        good_ids[3] = 3;
        good_ids[4] = 4;

        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;
        amounts[3] = 1;
        amounts[4] = 1;

        // mint()
        launchERC1155();
    }

    function pullERC1155BatchRestrictions() public returns (
        uint256[] memory bad_ids,
        uint256[] memory good_ids,
        uint256[] memory amounts
    ) 
    {
        bad_ids = new uint256[](4);
        good_ids = new uint256[](5);
        amounts = new uint256[](5);

        bad_ids[0] = 0;
        bad_ids[1] = 1;
        bad_ids[2] = 2;
        bad_ids[3] = 3;

        good_ids[0] = 0;
        good_ids[1] = 1;
        good_ids[2] = 2;
        good_ids[3] = 3;
        good_ids[4] = 4;

        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;
        amounts[3] = 1;
        amounts[4] = 1;

        // mint()
        launchERC1155();
    }

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate initial state of OCG (On-Chain Generic) lockers.

    function test_ZivoeDAO_OCG_init() public view {
        
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

    function test_ZivoeDAO_push_restrictions_whitelisted() public {

        // Can't push to address(0), not whitelisted.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::push() !IZivoeGlobals_P_5(GBL).isLocker(locker)");
        DAO.push(address(0), address(DAI), 1000 ether);
        hevm.stopPrank();
    }

    function test_ZivoeDAO_push_restrictions_ERC721Locker() public {

        // Can't push to address(OCG_ERC721Locker), does not expose canPush().
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::push() !IERC104_P_0(locker).canPush()");
        DAO.push(address(OCG_ERC721Locker), address(DAI), 1000 ether);
        hevm.stopPrank();
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
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pull() !IERC104_P_0(locker).canPull()");
        DAO.pull(address(OCG_ERC721Locker), address(DAI));
        hevm.stopPrank();
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
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pullPartial() !IERC104_P_0(locker).canPullPartial()");
        DAO.pullPartial(address(OCG_ERC721Locker), address(DAI), 1000 ether);
        hevm.stopPrank();
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

    function test_ZivoeDAO_pushMulti_restrictions_whitelisted(uint96 random) public {

        (,
         address[] memory assets_good,
         uint256[] memory amounts
        ) = pushMultiRestrictions(random);

        // Can't push to address(0), not whitelisted.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pushMulti() !IZivoeGlobals_P_5(GBL).isLocker(locker)");
        DAO.pushMulti(address(0), assets_good, amounts);
        hevm.stopPrank();
    }


    function test_ZivoeDAO_pushMulti_restrictions_arrayLenght(uint96 random) public {

        (address[] memory assets_bad,
         ,
         uint256[] memory amounts
        ) = pushMultiRestrictions(random);

        // Can't push with assets_bad / amounts due to mismatch array length.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pushMulti() assets.length != amounts.length");
        DAO.pushMulti(address(OCG_ERC20Locker), assets_bad, amounts);
        hevm.stopPrank();
    }


    function test_ZivoeDAO_pushMulti_restrictions_ERC721Locker(uint96 random) public {

        (,
         address[] memory assets_good,
         uint256[] memory amounts
        ) = pushMultiRestrictions(random);

        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pushMulti() !IERC104_P_0(locker).canPushMulti()");
        DAO.pushMulti(address(OCG_ERC721Locker), assets_good, amounts);
        hevm.stopPrank();
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
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pullMulti() !IERC104_P_0(locker).canPullMulti()");
        DAO.pullMulti(address(OCG_ERC721Locker), assets);
        hevm.stopPrank();
    }

    function test_ZivoeDAO_pullMulti_state(uint96 random) public {

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

    function test_ZivoeDAO_pullMultiPartial_restrictions_canPullMultiPartial(uint96 random) public {

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
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pullMultiPartial() !IERC104_P_0(locker).canPullMultiPartial()");
        DAO.pullMultiPartial(address(OCG_ERC721Locker), assets_bad, amounts);
        hevm.stopPrank();
    }

    function test_ZivoeDAO_pullMultiPartial_restrictions_assetsLength(uint96 random) public {

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

        // Can't pull from address(OCG_ERC20Locker), assets_bad.length != amounts.length.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pullMultiPartial() assets.length != amounts.length");
        DAO.pullMultiPartial(address(OCG_ERC20Locker), assets_bad, amounts);
        hevm.stopPrank();

    }



    function test_ZivoeDAO_pullMultiPartial_state(uint96 random, uint96 pull) public {

        uint256 amt_DAI = uint256(random) % IERC20(DAI).balanceOf(address(DAO));
        uint256 amt_FRAX = uint256(random) % IERC20(FRAX).balanceOf(address(DAO));
        uint256 amt_USDC = uint256(random) % IERC20(USDC).balanceOf(address(DAO));
        uint256 amt_USDT = uint256(random) % IERC20(USDT).balanceOf(address(DAO));
        
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

    function test_ZivoeDAO_pushERC721_restrictions_whitelist() public {

        // mint().
        launchERC721();

        // Can't push NFT to address(0), locker not whitelisted.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pushERC721() !IZivoeGlobals_P_5(GBL).isLocker(locker)");
        DAO.pushERC721(address(0), address(ZivoeNFT), 0, "");
        hevm.stopPrank();

        // Example success call.
        assert(god.try_pushERC721(address(DAO), address(OCG_ERC721Locker), address(ZivoeNFT), 0, ""));
    }

    function test_ZivoeDAO_pushERC721_restrictions_canPushERC721() public {

        // mint().
        launchERC721();

        // Can't push NFT to address(OCG_ERC20Locker), does not expose canPushERC721().
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pushERC721() !IERC104_P_0(locker).canPushERC721()");
        DAO.pushERC721(address(OCG_ERC20Locker), address(ZivoeNFT), 0, "");
        hevm.stopPrank();

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

    function test_ZivoeDAO_pushMultiERC721_restrictions_whitelist() public {

        (,
        address[] memory good_assets,
        ,
        uint256[] memory good_tokenIds,
        ,
        bytes[] memory good_data
        ) = pushMultiERC721Restrictions();


        // Can't pushMulti NFT to address(0), locker not whitelisted.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pushMultiERC721() !IZivoeGlobals_P_5(GBL).isLocker(locker)");
        DAO.pushMultiERC721(address(0), good_assets, good_tokenIds, good_data);
        hevm.stopPrank();

        // Example success call.
        assert(god.try_pushMultiERC721(address(DAO), address(OCG_ERC721Locker), good_assets, good_tokenIds, good_data));

    }

    function test_ZivoeDAO_pushMultiERC721_restrictions_assetsLength() public {

        (address[] memory bad_assets,
        ,
        uint256[] memory bad_tokenIds,
        ,
        bytes[] memory bad_data,
        
        ) = pushMultiERC721Restrictions();


        // Can't pushMulti NFT to address(OCG_ERC721Locker), assets.length != tokenIds.length.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pushMultiERC721() assets.length != tokenIds.length");
        DAO.pushMultiERC721(address(OCG_ERC721Locker), bad_assets, bad_tokenIds, bad_data);
        hevm.stopPrank();     
    }

    function test_ZivoeDAO_pushMultiERC721_restrictions_tokenIdsLength() public {

        (,
        address[] memory good_assets,
        ,
        uint256[] memory good_tokenIds,
        bytes[] memory bad_data,
        
        ) = pushMultiERC721Restrictions();


        // Can't pushMulti NFT to address(OCG_ERC721Locker), tokenIds.length != data.length.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pushMultiERC721() tokenIds.length != data.length");
        DAO.pushMultiERC721(address(OCG_ERC721Locker), good_assets, good_tokenIds, bad_data);
        hevm.stopPrank();   
    }

    function test_ZivoeDAO_pushMultiERC721_restrictions_canPushMultiERC721() public {

        (,
        address[] memory good_assets,
        ,
        uint256[] memory good_tokenIds,
        ,
        bytes[] memory good_data
        ) = pushMultiERC721Restrictions();

        // Can't pushMulti NFT to address(OCG_ERC20Locker), does not expose canPushMultiERC721().
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pushMultiERC721() !IERC104_P_0(locker).canPushMultiERC721()");
        DAO.pushMultiERC721(address(OCG_ERC20Locker), good_assets, good_tokenIds, good_data);
        hevm.stopPrank();   
    }


    function test_ZivoeDAO_pushMultiERC721_state() public {
        
        // mint().
        launchERC721();

        address[] memory assets = new address[](4);
        uint256[] memory tokenIds = new uint256[](4);
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
        
        // mint()
        launchERC721();

        // Can't pull if canPullERC721() not exposed as true.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pullERC721() !IERC104_P_0(locker).canPullERC721()");
        DAO.pullERC721(address(OCG_ERC20Locker), address(ZivoeNFT), 0, '');
        hevm.stopPrank();          
    }

    function test_ZivoeDAO_pullERC721_state() public {
        
        // mint()
        launchERC721();

        address[] memory assets = new address[](4);
        uint256[] memory tokenIds = new uint256[](4);
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

        // pushMultiERC721().
        assert(god.try_pushMultiERC721(address(DAO), address(OCG_ERC721Locker), assets, tokenIds, data));

        // Pre-state.
        assertEq(ZivoeNFT.balanceOf(address(OCG_ERC721Locker)), 4);
        assertEq(ZivoeNFT.balanceOf(address(DAO)), 0);
        assertEq(ZivoeNFT.ownerOf(0), address(OCG_ERC721Locker));
        assertEq(ZivoeNFT.getApproved(0), address(0));

        // pullERC721().
        assert(god.try_pullERC721(address(DAO), address(OCG_ERC721Locker), address(ZivoeNFT), 0, ''));

        // Post-state.
        assertEq(ZivoeNFT.balanceOf(address(OCG_ERC721Locker)), 3);
        assertEq(ZivoeNFT.balanceOf(address(DAO)), 1);
        assertEq(ZivoeNFT.ownerOf(0), address(DAO));
        assertEq(ZivoeNFT.getApproved(0), address(0));
        
    }

    // Validate pullMultiERC721() state changes.
    // Validate pullMultiERC721() restrictions.
    // This includes:
    //   - "locker" must have canPullMultiERC721() exposed as true value.
    //   - assets.length == tokenIds.length (length of input arrays must equal)
    //   - tokenIds.length == data.length (length of input arrays must equal)

    function test_ZivoeDAO_pullMultiERC721_restrictions_canPullMultiERC721() public {
        (,
        address[] memory good_assets,
        ,
        uint256[] memory good_tokenIds,
        ,
        bytes[] memory good_data
        ) = pullMultiERC721Restrictions();

        // pushMultiERC721().
        assert(god.try_pushMultiERC721(address(DAO), address(OCG_ERC721Locker), good_assets, good_tokenIds, good_data));

        // Can't pullMulti NFT from address(OCG_ERC20Locker), does not expose canPullMultiERC721().
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pullMultiERC721() !IERC104_P_0(locker).canPullMultiERC721()");
        DAO.pullMultiERC721(address(OCG_ERC20Locker), good_assets, good_tokenIds, good_data);
        hevm.stopPrank();          
    
        // Example success call.
        assert(god.try_pullMultiERC721(address(DAO), address(OCG_ERC721Locker), good_assets, good_tokenIds, good_data));
    }

    function test_ZivoeDAO_pullMultiERC721_restrictions_assetsLength() public {
        (address[] memory bad_assets,
        address[] memory good_assets,
        uint256[] memory bad_tokenIds,
        uint256[] memory good_tokenIds,
        bytes[] memory bad_data,
        bytes[] memory good_data
        ) = pullMultiERC721Restrictions();

        // pushMultiERC721().
        assert(god.try_pushMultiERC721(address(DAO), address(OCG_ERC721Locker), good_assets, good_tokenIds, good_data));

        // Can't pullMulti NFT from address(OCG_ERC721Locker), assets.length != tokenIds.length.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pullMultiERC721() assets.length != tokenIds.length");
        DAO.pullMultiERC721(address(OCG_ERC721Locker), bad_assets, bad_tokenIds, bad_data);
        hevm.stopPrank();   
    }

    function test_ZivoeDAO_pullMultiERC721_restrictions_tokenIdLength() public {
        (,
        address[] memory good_assets,
        ,
        uint256[] memory good_tokenIds,
        bytes[] memory bad_data,
        bytes[] memory good_data
        ) = pullMultiERC721Restrictions();

        // pushMultiERC721().
        assert(god.try_pushMultiERC721(address(DAO), address(OCG_ERC721Locker), good_assets, good_tokenIds, good_data));

        // Can't pullMulti NFT from address(OCG_ERC721Locker), tokenIds.length != data.length.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pullMultiERC721() tokenIds.length != data.length");
        DAO.pullMultiERC721(address(OCG_ERC721Locker), good_assets, good_tokenIds, bad_data);
        hevm.stopPrank();   
    }



    function test_ZivoeDAO_pullMultiERC721_state() public {
        
        // mint()
        launchERC721();

        address[] memory assets = new address[](4);
        uint256[] memory tokenIds = new uint256[](4);
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

        // pushERC721().
        assert(god.try_pushMultiERC721(address(DAO), address(OCG_ERC721Locker), assets, tokenIds, data));

        // Pre-state.
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

        // pullMultiERC721().
        assert(god.try_pullMultiERC721(address(DAO), address(OCG_ERC721Locker), assets, tokenIds, data));

        // Post-state.
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
        
    }

    // Validate pushERC1155Batch() state changes.
    // Validate pushERC1155Batch() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - ids.length == amounts.length (length of input arrays must equal)
    //   - "locker" must have canPushERC1155() exposed as true value.

    function test_ZivoeDAO_pushERC1155Batch_restrictions_whitelist() public {

        (,
        uint256[] memory good_ids,
        uint256[] memory amounts
        ) = pushERC1155BatchRestrictions();

        // Can't pushERC1155Batch() if locker not whitelisted.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pushERC1155Batch() !IZivoeGlobals_P_5(GBL).isLocker(locker)");
        DAO.pushERC1155Batch(address(0), address(ZivoeERC1155), good_ids, amounts, '');
        hevm.stopPrank();  

        // Example success.
        assert(god.try_pushERC1155Batch(
            address(DAO), address(OCG_ERC1155Locker), address(ZivoeERC1155), good_ids, amounts, ''
        ));  
    }

    function test_ZivoeDAO_pushERC1155Batch_restrictions_IdsLength() public {

        (uint256[] memory bad_ids,
        ,
        uint256[] memory amounts
        ) = pushERC1155BatchRestrictions();

        // Can't pushERC1155Batch() if ids.length != amounts.length.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pushERC1155Batch() ids.length != amounts.length");
        DAO.pushERC1155Batch(address(OCG_ERC1155Locker), address(ZivoeERC1155), bad_ids, amounts, '');
        hevm.stopPrank();  
    }

    function test_ZivoeDAO_pushERC1155Batch_restrictions_canPushERC1155() public {

        (,
        uint256[] memory good_ids,
        uint256[] memory amounts
        ) = pushERC1155BatchRestrictions();

        // Can't pushERC1155Batch() if canPushERC1155() not exposed as true.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pushERC1155Batch() !IERC104_P_0(locker).canPushERC1155()");
        DAO.pushERC1155Batch(address(OCG_ERC721Locker), address(ZivoeERC1155), good_ids, amounts, '');
        hevm.stopPrank();  
    }

    function test_ZivoeDAO_pushERC1155Batch_state() public {
        
        uint256[] memory ids = new uint256[](5);
        uint256[] memory amounts = new uint256[](5);

        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;
        ids[3] = 3;
        ids[4] = 4;

        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;
        amounts[3] = 1;
        amounts[4] = 1;

        // mint()
        launchERC1155();

        // Pre-state.
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 0), 10**18);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 1), 10**27);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 2), 1);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 3), 10**9);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 4), 10**9);

        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 0), 0);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 1), 0);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 2), 0);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 3), 0);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 4), 0);

        // pushERC1155Batch().
        assert(god.try_pushERC1155Batch(
            address(DAO), address(OCG_ERC1155Locker), address(ZivoeERC1155), ids, amounts, ''
        ));

        // Post-state.
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 0), 10**18 - 1);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 1), 10**27 - 1);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 2), 1 - 1);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 3), 10**9 - 1);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 4), 10**9 - 1);

        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 0), 1);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 1), 1);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 2), 1);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 3), 1);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 4), 1);
        
    }

    // Validate pullERC1155Batch() state changes.
    // Validate pullERC1155Batch() restrictions.
    // This includes:
    //   - "locker" must have canPullERC1155() exposed as true value.
    //   - ids.length == amounts.length (length of input arrays must equal)

    function test_ZivoeDAO_pullERC1155Batch_restrictions_canPullERC1155() public {
       (,
        uint256[] memory good_ids,
        uint256[] memory amounts
        ) = pullERC1155BatchRestrictions();

        assert(god.try_pushERC1155Batch(
            address(DAO), address(OCG_ERC1155Locker), address(ZivoeERC1155), good_ids, amounts, ''
        ));

        // Can't pullERC1155Batch() if canPullERC1155() not exposed as true.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pullERC1155Batch() !IERC104_P_0(locker).canPullERC1155()");
        DAO.pullERC1155Batch(address(OCG_ERC721Locker), address(ZivoeERC1155), good_ids, amounts, '');
        hevm.stopPrank();  

        // Example success.
        assert(god.try_pullERC1155Batch(
            address(DAO), address(OCG_ERC1155Locker), address(ZivoeERC1155), good_ids, amounts, ''
        ));
    }

    function test_ZivoeDAO_pullERC1155Batch_restrictions_IdsLength() public {
        (uint256[] memory bad_ids,
        uint256[] memory good_ids,
        uint256[] memory amounts
        ) = pullERC1155BatchRestrictions();

        assert(god.try_pushERC1155Batch(
            address(DAO), address(OCG_ERC1155Locker), address(ZivoeERC1155), good_ids, amounts, ''
        ));

        // Can't pullERC1155Batch() if ids.length != amounts.length.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeDAO::pullERC1155Batch() ids.length != amounts.length");
        DAO.pullERC1155Batch(address(OCG_ERC1155Locker), address(ZivoeERC1155), bad_ids, amounts, '');
        hevm.stopPrank();  
    }

    function test_ZivoeDAO_pullERC1155Batch_state() public {
        
        uint256[] memory ids = new uint256[](5);
        uint256[] memory amounts = new uint256[](5);
        
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;
        ids[3] = 3;
        ids[4] = 4;

        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;
        amounts[3] = 1;
        amounts[4] = 1;

        // mint()
        // pushERC1155Batch().
        launchERC1155();
        assert(god.try_pushERC1155Batch(
            address(DAO), address(OCG_ERC1155Locker), address(ZivoeERC1155), ids, amounts, ''
        ));

        // Pre-state.
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 0), 10**18 - 1);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 1), 10**27 - 1);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 2), 1 - 1);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 3), 10**9 - 1);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 4), 10**9 - 1);

        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 0), 1);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 1), 1);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 2), 1);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 3), 1);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 4), 1);

        // pullERC1155Batch().
        assert(god.try_pullERC1155Batch(
            address(DAO), address(OCG_ERC1155Locker), address(ZivoeERC1155), ids, amounts, ''
        ));

        // Post-state.
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 0), 10**18);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 1), 10**27);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 2), 1);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 3), 10**9);
        assertEq(ZivoeERC1155.balanceOf(address(DAO), 4), 10**9);

        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 0), 0);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 1), 0);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 2), 0);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 3), 0);
        assertEq(ZivoeERC1155.balanceOf(address(OCG_ERC1155Locker), 4), 0);
        
    }

}
