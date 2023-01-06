// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeITO is Utility {

    function setUp() public {
        deployCore(false);
    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    // Note: This helper function ends with time warped to exactly 1 second after ITO starts.
    function depositJunior(address asset, uint256 amount) public {
        
        if (asset == DAI) {
            mint("DAI", address(jim), amount);
        }
        else if (asset == FRAX) {
            mint("FRAX", address(jim), amount);
        }
        else if (asset == USDC) {
            mint("USDC", address(jim), amount);
        }
        else if (asset == USDT) {
            mint("USDT", address(jim), amount);
        }
        else { revert(); }

        hevm.warp(ITO.start() + 1 seconds);

        assert(jim.try_approveToken(asset, address(ITO), amount));
        assert(jim.try_depositJunior(address(ITO), amount, asset));

    }

    // Note: This helper function ends with time warped to exactly 1 second after ITO starts.
    function depositSenior(address asset, uint256 amount) public {
        
        if (asset == DAI) {
            mint("DAI", address(sam), amount);
        }
        else if (asset == FRAX) {
            mint("FRAX", address(sam), amount);
        }
        else if (asset == USDC) {
            mint("USDC", address(sam), amount);
        }
        else if (asset == USDT) {
            mint("USDT", address(sam), amount);
        }
        else { revert(); }

        hevm.warp(ITO.start() + 1 seconds);

        assert(sam.try_approveToken(asset, address(ITO), amount));
        assert(sam.try_depositSenior(address(ITO), amount, asset));

    }

    // Note: This helper function ends with time warped to exactly 1 second after ITO starts.
    function depositBoth(address asset, uint256 amountJunior, uint256 amountSenior) public {
        
        if (asset == DAI) {
            mint("DAI", address(jim), amountJunior + amountSenior);
        }
        else if (asset == FRAX) {
            mint("FRAX", address(jim), amountJunior + amountSenior);
        }
        else if (asset == USDC) {
            mint("USDC", address(jim), amountJunior + amountSenior);
        }
        else if (asset == USDT) {
            mint("USDT", address(jim), amountJunior + amountSenior);
        }
        else { revert(); }

        hevm.warp(ITO.start() + 1 seconds);

        assert(jim.try_approveToken(asset, address(ITO), amountJunior + amountSenior));
        assert(jim.try_depositJunior(address(ITO), amountJunior, asset));
        assert(jim.try_depositSenior(address(ITO), amountSenior, asset));

    }

    // ---------------
    //    Unit Tets
    // ---------------

    // Ensure ZivoeITO.sol constructor() does not permit _start >= _end (input params).

    function testFail_ZivoeITO_constructor_0() public {
        ITO = new ZivoeITO(
            block.timestamp + 5001 seconds,
            block.timestamp + 5000 seconds,
            address(GBL)
        );
    }

    function testFail_ZivoeITO_constructor_1() public {
        ITO = new ZivoeITO(
            block.timestamp + 5000 seconds,
            block.timestamp + 5000 seconds,
            address(GBL)
        );
    }

    function test_ZivoeITO_constructor_2() public {
        ITO = new ZivoeITO(
            block.timestamp + 4999 seconds,
            block.timestamp + 5000 seconds,
            address(GBL)
        );
    }

    // Validate depositJunior() and depositSenior() restrictions.
    // For both functions, this includes:
    //   - Restricting deposits until the ITO starts.
    //   - Restricting deposits after the ITO ends.
    //   - Restricting deposits of non-whitelisted assets.

    function test_ZivoeITO_depositJunior_restrictions_notStarted() public {

        // Mint 100 DAI and 100 WETH for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        mint("WETH", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(bob.try_approveToken(WETH, address(ITO), 100 ether));

        // Should throw with: "ZivoeITO::depositJunior() block.timestamp < start"
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositJunior() block.timestamp < start");
        ITO.depositJunior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeITO_depositJunior_restrictions_ended() public {

        // Mint 100 DAI and 100 WETH for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        mint("WETH", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(bob.try_approveToken(WETH, address(ITO), 100 ether));

        // Warp in time to "end" (post-ITO time).
        hevm.warp(ITO.end());

        // Should throw with: "ZivoeITO::depositJunior() block.timestamp >= end"
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositJunior() block.timestamp >= end");
        ITO.depositJunior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeITO_depositJunior_restrictions_notWhitelisted() public {

        // Mint 100 DAI and 100 WETH for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        mint("WETH", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(bob.try_approveToken(WETH, address(ITO), 100 ether));

        // Warp in time to middle-point of ITO.
        hevm.warp(ITO.start() + 1 seconds);

        // Should throw with: "ZivoeITO::depositJunior() !stablecoinWhitelist[asset]"
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositJunior() !stablecoinWhitelist[asset]");
        ITO.depositJunior(100 ether, address(WETH));
        hevm.stopPrank();
    }

    function test_ZivoeITO_depositSenior_restrictions_notStarted() public {

        // Mint 100 DAI and 100 WETH for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        mint("WETH", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(bob.try_approveToken(WETH, address(ITO), 100 ether));

        // Should throw with: "ZivoeITO::depositSenior() block.timestamp < start"
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositSenior() block.timestamp < start");
        ITO.depositSenior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeITO_depositSenior_restrictions_ended() public {

        // Mint 100 DAI and 100 WETH for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        mint("WETH", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(bob.try_approveToken(WETH, address(ITO), 100 ether));

        // Warp in time to "end" (post-ITO time).
        hevm.warp(ITO.end());

        // Should throw with: "ZivoeITO::depositSenior() block.timestamp >= end"
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositSenior() block.timestamp >= end");
        ITO.depositSenior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeITO_depositSenior_restrictions_notWhitelisted() public {

        // Mint 100 DAI and 100 WETH for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        mint("WETH", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(bob.try_approveToken(WETH, address(ITO), 100 ether));

        // Warp in time to middle-point of ITO.
        hevm.warp(ITO.start() + 1 seconds);

        // Should throw with: "ZivoeITO::depositSenior() !stablecoinWhitelist[asset]"
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositSenior() !stablecoinWhitelist[asset]");
        ITO.depositSenior(100 ether, address(WETH));
        hevm.stopPrank();
    }

    // Validate depositJunior() state changes.
    // Validate depositSenior() state changes.
    // Note: Test all 4 coins (DAI/FRAX/USDC/USDT) for initial ITO whitelisted assets.

    function test_ZivoeITO_depositJunior_DAI_state(uint160 amountIn) public {
        
        uint256 amount = uint256(amountIn);
        
        // Pre-state DAI deposit.
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _pre_DAI = IERC20(DAI).balanceOf(address(ITO));

        depositJunior(DAI, amountIn);

        // Post-state DAI deposit.
        uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _post_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _post_DAI = IERC20(DAI).balanceOf(address(ITO));

        assertEq(_post_JuniorCredits - _pre_JuniorCredits, GBL.standardize(amount, DAI));
        assertEq(_post_zJTT - _pre_zJTT, GBL.standardize(amount, DAI));
        assertEq(_post_DAI - _pre_DAI, amount);

    }

    function test_ZivoeITO_depositJunior_FRAX_state(uint160 amountIn) public {
        
        uint256 amount = uint256(amountIn);

        // Pre-state FRAX deposit.
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _pre_FRAX = IERC20(FRAX).balanceOf(address(ITO));

        depositJunior(FRAX, amountIn);

        // Post-state FRAX deposit.
        uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _post_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _post_FRAX = IERC20(FRAX).balanceOf(address(ITO));

        assertEq(_post_JuniorCredits - _pre_JuniorCredits, GBL.standardize(amount, FRAX));
        assertEq(_post_zJTT - _pre_zJTT, GBL.standardize(amount, FRAX));
        assertEq(_post_FRAX - _pre_FRAX, amount);
    }

    function test_ZivoeITO_depositJunior_USDC_state(uint160 amountIn) public {
        
        uint256 amount = uint256(amountIn);

        // Pre-state USDC deposit.
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _pre_USDC = IERC20(USDC).balanceOf(address(ITO));

        depositJunior(USDC, amountIn);

        // Post-state USDC deposit.
        uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _post_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _post_USDC = IERC20(USDC).balanceOf(address(ITO));

        assertEq(_post_JuniorCredits - _pre_JuniorCredits, GBL.standardize(amount, USDC));
        assertEq(_post_zJTT - _pre_zJTT, GBL.standardize(amount, USDC));
        assertEq(_post_USDC - _pre_USDC, amount);
    }

    function test_ZivoeITO_depositJunior_USDT_state(uint160 amountIn) public {
        
        uint256 amount = uint256(amountIn);

        // Pre-state USDT deposit.
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _pre_USDT = IERC20(USDT).balanceOf(address(ITO));

        depositJunior(USDT, amount);

        // Post-state USDT deposit.
        uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _post_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _post_USDT = IERC20(USDT).balanceOf(address(ITO));

        assertEq(_post_JuniorCredits - _pre_JuniorCredits, GBL.standardize(amount, USDT));
        assertEq(_post_zJTT - _pre_zJTT, GBL.standardize(amount, USDT));
        assertEq(_post_USDT - _pre_USDT, amount);
    }

    function test_ZivoeITO_depositSenior_DAI_state(uint160 amountIn) public {
        
        uint256 amount = uint256(amountIn);

        // Pre-state DAI deposit.
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _pre_DAI = IERC20(DAI).balanceOf(address(ITO));

        depositSenior(DAI, amount);

        // Post-state DAI deposit.
        uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _post_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _post_DAI = IERC20(DAI).balanceOf(address(ITO));

        assertEq(_post_SeniorCredits - _pre_SeniorCredits, GBL.standardize(amount, DAI) * 3);
        assertEq(_post_zSTT - _pre_zSTT, GBL.standardize(amount, DAI));
        assertEq(_post_DAI - _pre_DAI, amount);

    }

    function test_ZivoeITO_depositSenior_FRAX_state(uint160 amountIn) public {
        
        uint256 amount = uint256(amountIn);

        // Pre-state FRAX deposit.
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _pre_FRAX = IERC20(FRAX).balanceOf(address(ITO));

        depositSenior(FRAX, amount);

        // Post-state FRAX deposit.
        uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _post_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _post_FRAX = IERC20(FRAX).balanceOf(address(ITO));

        assertEq(_post_SeniorCredits - _pre_SeniorCredits, GBL.standardize(amount, FRAX) * 3);
        assertEq(_post_zSTT - _pre_zSTT, GBL.standardize(amount, FRAX));
        assertEq(_post_FRAX - _pre_FRAX, amount);

    }

    function test_ZivoeITO_depositSenior_USDC_state(uint160 amountIn) public {
        
        uint256 amount = uint256(amountIn);

        // Pre-state USDC deposit.
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _pre_USDC = IERC20(USDC).balanceOf(address(ITO));

        depositSenior(USDC, amount);

        // Post-state USDC deposit.
        uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _post_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _post_USDC = IERC20(USDC).balanceOf(address(ITO));

        assertEq(_post_SeniorCredits - _pre_SeniorCredits, GBL.standardize(amount, USDC) * 3);
        assertEq(_post_zSTT - _pre_zSTT, GBL.standardize(amount, USDC));
        assertEq(_post_USDC - _pre_USDC, amount);

    }

    function test_ZivoeITO_depositSenior_USDT_state(uint160 amountIn) public {
        
        uint256 amount = uint256(amountIn);

        // Pre-state USDT deposit.
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _pre_USDT = IERC20(USDT).balanceOf(address(ITO));

        depositSenior(USDT, amount);

        // Post-state USDT deposit.
        uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _post_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _post_USDT = IERC20(USDT).balanceOf(address(ITO));

        assertEq(_post_SeniorCredits - _pre_SeniorCredits, GBL.standardize(amount, USDT) * 3);
        assertEq(_post_zSTT - _pre_zSTT, GBL.standardize(amount, USDT));
        assertEq(_post_USDT - _pre_USDT, amount);

    }


    // Validate claim() restrictions.
    // This includes:
    //   - Restricting claim until after the ITO concludes (block.timestamp > end).
    //   - Restricting claim if person has already claimed (a one-time only action).
    //   - Restricting claim if (seniorCredits || juniorCredits) == 0.
 
    function test_ZivoeITO_claim_restrictions_notEnded() public {

        // Warp to the end unix.
        hevm.warp(ITO.end());

        // Can't call claim() until block.timestamp > end.
        hevm.startPrank(address(sam));
        hevm.expectRevert("ZivoeITO::claim() block.timestamp <= end && !migrated");
        ITO.claim();
        hevm.stopPrank();
    }

    // Note: uint96 works, uint160 throws overflow/underflow error.
    function test_ZivoeITO_claim_restrictions_claimTwice(uint96 amountIn) public {
        
        uint256 amount = uint256(amountIn) + 1;

        // Warp to the end unix.
        hevm.warp(ITO.end());

        // "sam" will depositSenior() ...
        // "jim" will depositJunior() ...
        depositSenior(FRAX, amount);
        depositJunior(USDT, amount);

        // Warp to end.
        hevm.warp(ITO.end() + 1);

        // "sam" will claim once (successful) but cannot claim again.
        assert(sam.try_claim(address(ITO)));
        hevm.startPrank(address(sam));
        hevm.expectRevert("ZivoeITO::claim() airdropClaimeded[caller]");
        ITO.claim();
        hevm.stopPrank();
    }

    function test_ZivoeITO_claim_restrictions_zeroCredits() public {
        // Warp to end.
        hevm.warp(ITO.end() + 1);

        // Can't call claim() if seniorCredits == 0 && juniorCredits == 0.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::claim() seniorCredits[caller] == 0 && juniorCredits[caller] == 0");
        ITO.claim();
        hevm.stopPrank();
    }

    // Validate claim() state changes, single user depositing into ITO (a single tranche), a.k.a. "_single_senior".
    // Validate claim() state changes, single user depositing into ITO (both tranches), a.k.a. "_both".
    // Validate claim() state changes, two users depositing into ITO (both tranches), a.k.a. "_multi".

    function test_ZivoeITO_claim_state_single_senior_DAI(uint96 amountIn_senior) public {

        uint256 amount_senior = uint256(amountIn_senior) + 1;

        depositSenior(DAI, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claim (senior).
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
        
        (uint256 _zSTT_Claimed_SAM,, uint256 _ZVE_Claimed_SAM) = sam.claimAidrop(address(ITO));

        // Post-state claim (senior).
        {
            uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
            // Note: * 3 for the 3x Multiplier on credits for depositing into SeniorTranche
            assertEq(_pre_SeniorCredits - _post_SeniorCredits, amount_senior * 3);  
        }

        {
            uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, amount_senior);
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_SAM);
        }

        {
            uint256 _post_ZVE_ITO = ZVE.balanceOf(address(ITO));
            // Note: Reads something like ... (SeniorCredits * 10% of ZVE) / (SeniorCredits + JuniorCredits)
            assertEq(_pre_ZVE_ITO - _post_ZVE_ITO, (amount_senior * 3 * ZVE.totalSupply() / 10) / (amount_senior * 3)); 
            assertEq(_pre_ZVE_ITO - _post_ZVE_ITO, _ZVE_Claimed_SAM);
        }
    }

    function test_ZivoeITO_claim_state_single_senior_FRAX(uint96 amountIn_senior) public {

        uint256 amount_senior = uint256(amountIn_senior) + 1;

        depositSenior(FRAX, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claim (senior).
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
        
        (uint256 _zSTT_Claimed_SAM,, uint256 _ZVE_Claimed_SAM) = sam.claimAidrop(address(ITO));

        // Post-state claim (senior).
        {
            uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
            // Note: * 3 for the 3x Multiplier on credits for depositing into SeniorTranche
            assertEq(_pre_SeniorCredits - _post_SeniorCredits, amount_senior * 3);  
        }

        {
            uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, amount_senior);
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_SAM);
        }

        {
            uint256 _post_ZVE_ITO = ZVE.balanceOf(address(ITO));
            // Note: Reads something like ... (SeniorCredits * 10% of ZVE) / (SeniorCredits + JuniorCredits)
            assertEq(_pre_ZVE_ITO - _post_ZVE_ITO, (amount_senior * 3 * ZVE.totalSupply() / 10) / (amount_senior * 3)); 
            assertEq(_pre_ZVE_ITO - _post_ZVE_ITO, _ZVE_Claimed_SAM);
        }
    }

    function test_ZivoeITO_claim_state_single_senior_USDC(uint96 amountIn_senior) public {

        uint256 amount_senior = uint256(amountIn_senior) + 1;

        depositSenior(USDC, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claim (senior).
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
        
        (uint256 _zSTT_Claimed_SAM,, uint256 _ZVE_Claimed_SAM) = sam.claimAidrop(address(ITO));

        // Post-state claim (senior).
        {
            uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
            // Note: * 3 for the 3x Multiplier on credits for depositing into SeniorTranche
            assertEq(_pre_SeniorCredits - _post_SeniorCredits, GBL.standardize(amount_senior, USDC) * 3);  
        }

        {
            uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, GBL.standardize(amount_senior, USDC));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_SAM);
        }

        {
            uint256 _post_ZVE_ITO = ZVE.balanceOf(address(ITO));
            // Note: Reads something like ... (SeniorCredits * 10% of ZVE) / (SeniorCredits + JuniorCredits)
            assertEq(
                _pre_ZVE_ITO - _post_ZVE_ITO, 
                (GBL.standardize(amount_senior, USDC) * 3 * ZVE.totalSupply() / 10) / (GBL.standardize(amount_senior, USDC) * 3))
            ; 
            assertEq(_pre_ZVE_ITO - _post_ZVE_ITO, _ZVE_Claimed_SAM);
        }
    }

    function test_ZivoeITO_claim_state_single_senior_USDT(uint96 amountIn_senior) public {

        uint256 amount_senior = uint256(amountIn_senior) + 1;

        depositSenior(USDT, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claim (senior).
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
        
        (uint256 _zSTT_Claimed_SAM,, uint256 _ZVE_Claimed_SAM) = sam.claimAidrop(address(ITO));

        // Post-state claim (senior).
        {
            uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
            // Note: * 3 for the 3x Multiplier on credits for depositing into SeniorTranche
            assertEq(_pre_SeniorCredits - _post_SeniorCredits, GBL.standardize(amount_senior, USDT) * 3);  
        }

        {
            uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, GBL.standardize(amount_senior, USDT));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_SAM);
        }

        {
            uint256 _post_ZVE_ITO = ZVE.balanceOf(address(ITO));
            // Note: Reads something like ... (SeniorCredits * 10% of ZVE) / (SeniorCredits + JuniorCredits)
            assertEq(
                _pre_ZVE_ITO - _post_ZVE_ITO, 
                (GBL.standardize(amount_senior, USDT) * 3 * ZVE.totalSupply() / 10) / (GBL.standardize(amount_senior, USDT) * 3)
            ); 
            assertEq(_pre_ZVE_ITO - _post_ZVE_ITO, _ZVE_Claimed_SAM);
        }
    }

    function test_ZivoeITO_claim_state_single_junior_DAI(uint96 amountIn_junior) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;

        depositJunior(DAI, amount_junior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claim (junior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
        
        (, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Claimed_JIM) = jim.claimAidrop(address(ITO));

        // Post-state claim (junior).
        {
            uint256 _post_JuniorCredits = ITO.juniorCredits(address(sam));
            assertEq(_pre_JuniorCredits - _post_JuniorCredits, amount_junior);  
        }

        {
            uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, amount_junior);
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);
        }

        {
            uint256 _post_ZVE_ITO = ZVE.balanceOf(address(ITO));
            // Note: Reads something like ... (JuniorCredits * 10% of ZVE) / (SeniorCredits + JuniorCredits)
            assertEq(_pre_ZVE_ITO - _post_ZVE_ITO, (amount_junior * ZVE.totalSupply() / 10) / (amount_junior)); 
            assertEq(_pre_ZVE_ITO - _post_ZVE_ITO, _ZVE_Claimed_JIM);
        }
    }

    function test_ZivoeITO_claim_state_single_junior_FRAX(uint96 amountIn_junior) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;

        depositJunior(FRAX, amount_junior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claim (junior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
        
        (, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Claimed_JIM) = jim.claimAidrop(address(ITO));

        // Post-state claim (junior).
        {
            uint256 _post_JuniorCredits = ITO.juniorCredits(address(sam));
            assertEq(_pre_JuniorCredits - _post_JuniorCredits, amount_junior);  
        }

        {
            uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, amount_junior);
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);
        }

        {
            uint256 _post_ZVE_ITO = ZVE.balanceOf(address(ITO));
            // Note: Reads something like ... (JuniorCredits * 10% of ZVE) / (SeniorCredits + JuniorCredits)
            assertEq(_pre_ZVE_ITO - _post_ZVE_ITO, (amount_junior * ZVE.totalSupply() / 10) / (amount_junior)); 
            assertEq(_pre_ZVE_ITO - _post_ZVE_ITO, _ZVE_Claimed_JIM);
        }
    }

    function test_ZivoeITO_claim_state_single_junior_USDC(uint96 amountIn_junior) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;

        depositJunior(USDC, amount_junior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claim (junior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
        
        (, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Claimed_JIM) = jim.claimAidrop(address(ITO));

        // Post-state claim (junior).
        {
            uint256 _post_JuniorCredits = ITO.juniorCredits(address(sam));
            assertEq(_pre_JuniorCredits - _post_JuniorCredits, GBL.standardize(amount_junior, USDC));  
        }

        {
            uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, GBL.standardize(amount_junior, USDC));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);
        }

        {
            uint256 _post_ZVE_ITO = ZVE.balanceOf(address(ITO));
            // Note: Reads something like ... (JuniorCredits * 10% of ZVE) / (SeniorCredits + JuniorCredits)
            assertEq(
                _pre_ZVE_ITO - _post_ZVE_ITO, 
                (GBL.standardize(amount_junior, USDC) * ZVE.totalSupply() / 10) / (GBL.standardize(amount_junior, USDC))
            ); 
            assertEq(_pre_ZVE_ITO - _post_ZVE_ITO, _ZVE_Claimed_JIM);
        }
    }

    function test_ZivoeITO_claim_state_single_junior_USDT(uint96 amountIn_junior) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;

        depositJunior(USDT, amount_junior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claim (junior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
        
        (, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Claimed_JIM) = jim.claimAidrop(address(ITO));

        // Post-state claim (junior).
        {
            uint256 _post_JuniorCredits = ITO.juniorCredits(address(sam));
            assertEq(_pre_JuniorCredits - _post_JuniorCredits, GBL.standardize(amount_junior, USDT));  
        }

        {
            uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, GBL.standardize(amount_junior, USDT));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);
        }

        {
            uint256 _post_ZVE_ITO = ZVE.balanceOf(address(ITO));
            // Note: Reads something like ... (JuniorCredits * 10% of ZVE) / (SeniorCredits + JuniorCredits)
            assertEq(
                _pre_ZVE_ITO - _post_ZVE_ITO, 
                (GBL.standardize(amount_junior, USDT) * ZVE.totalSupply() / 10) / (GBL.standardize(amount_junior, USDT))
            ); 
            assertEq(_pre_ZVE_ITO - _post_ZVE_ITO, _ZVE_Claimed_JIM);
        }
    }

    function test_ZivoeITO_claim_state_both_DAI(uint96 amountIn_junior, uint96 amountIn_senior) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;
        uint256 amount_senior = uint256(amountIn_senior) + 1;

        depositBoth(DAI, amount_junior, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claim (junior + senior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
        
        (uint256 _zSTT_Claimed_JIM, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Claimed_JIM) = jim.claimAidrop(address(ITO));

        // Post-state claim (junior + senior).

        {
            uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
            assertEq(_pre_JuniorCredits - _post_JuniorCredits, amount_junior);  
        }

        {
            uint256 _post_SeniorCredits = ITO.seniorCredits(address(jim));
            assertEq(_pre_SeniorCredits - _post_SeniorCredits, amount_senior * 3);  
        }

        {
            uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, amount_junior);
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);
        }

        {
            uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, amount_senior);
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_JIM);
        }

        {
            // Note: Person is the only depositor, thus claiming all 10% of ZVE in contract.
            assertEq(_pre_ZVE_ITO - ZVE.balanceOf(address(ITO)), ZVE.totalSupply() / 10); 
            assertEq(_pre_ZVE_ITO - ZVE.balanceOf(address(ITO)), _ZVE_Claimed_JIM);
        }
    }

    function test_ZivoeITO_claim_state_both_FRAX(uint96 amountIn_junior, uint96 amountIn_senior) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;
        uint256 amount_senior = uint256(amountIn_senior) + 1;

        depositBoth(FRAX, amount_junior, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claim (junior + senior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
        
        (uint256 _zSTT_Claimed_JIM, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Claimed_JIM) = jim.claimAidrop(address(ITO));

        // Post-state claim (junior + senior).

        {
            uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
            assertEq(_pre_JuniorCredits - _post_JuniorCredits, amount_junior);  
        }

        {
            uint256 _post_SeniorCredits = ITO.seniorCredits(address(jim));
            assertEq(_pre_SeniorCredits - _post_SeniorCredits, amount_senior * 3);  
        }

        {
            uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, amount_junior);
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);
        }

        {
            uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, amount_senior);
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_JIM);
        }

        {
            // Note: Person is the only depositor, thus claiming all 10% of ZVE in contract.
            assertEq(_pre_ZVE_ITO - ZVE.balanceOf(address(ITO)), ZVE.totalSupply() / 10); 
            assertEq(_pre_ZVE_ITO - ZVE.balanceOf(address(ITO)), _ZVE_Claimed_JIM);
        }
    }

    function test_ZivoeITO_claim_state_both_USDC(uint96 amountIn_junior, uint96 amountIn_senior) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;
        uint256 amount_senior = uint256(amountIn_senior) + 1;

        depositBoth(USDC, amount_junior, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claim (junior + senior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
        
        (uint256 _zSTT_Claimed_JIM, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Claimed_JIM) = jim.claimAidrop(address(ITO));

        // Post-state claim (junior + senior).

        {
            uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
            assertEq(_pre_JuniorCredits - _post_JuniorCredits, GBL.standardize(amount_junior, USDC));  
        }

        {
            uint256 _post_SeniorCredits = ITO.seniorCredits(address(jim));
            assertEq(_pre_SeniorCredits - _post_SeniorCredits, GBL.standardize(amount_senior, USDC) * 3);  
        }

        {
            uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, GBL.standardize(amount_junior, USDC));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);
        }

        {
            uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, GBL.standardize(amount_senior, USDC));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_JIM);
        }

        {
            // Note: Person is the only depositor, thus claiming all 10% of ZVE in contract.
            assertEq(_pre_ZVE_ITO - ZVE.balanceOf(address(ITO)), ZVE.totalSupply() / 10); 
            assertEq(_pre_ZVE_ITO - ZVE.balanceOf(address(ITO)), _ZVE_Claimed_JIM);
        }
    }

    function test_ZivoeITO_claim_state_both_USDT(uint96 amountIn_junior, uint96 amountIn_senior) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;
        uint256 amount_senior = uint256(amountIn_senior) + 1;

        depositBoth(USDT, amount_junior, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claim (junior + senior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
        
        (uint256 _zSTT_Claimed_JIM, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Claimed_JIM) = jim.claimAidrop(address(ITO));

        // Post-state claim (junior + senior).

        {
            uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
            assertEq(_pre_JuniorCredits - _post_JuniorCredits, GBL.standardize(amount_junior, USDT));  
        }

        {
            uint256 _post_SeniorCredits = ITO.seniorCredits(address(jim));
            assertEq(_pre_SeniorCredits - _post_SeniorCredits, GBL.standardize(amount_senior, USDT) * 3);  
        }

        {
            uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, GBL.standardize(amount_junior, USDT));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);
        }

        {
            uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, GBL.standardize(amount_senior, USDT));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_JIM);
        }

        {
            // Note: Person is the only depositor, thus claiming all 10% of ZVE in contract.
            assertEq(_pre_ZVE_ITO - ZVE.balanceOf(address(ITO)), ZVE.totalSupply() / 10); 
            assertEq(_pre_ZVE_ITO - ZVE.balanceOf(address(ITO)), _ZVE_Claimed_JIM);
        }
    }

    function test_ZivoeITO_claim_state_multi(
        uint96 amountIn_junior, 
        uint96 amountIn_senior
    ) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;
        uint256 amount_senior = uint256(amountIn_senior) + 1;

        depositJunior(DAI, amount_junior);
        depositJunior(FRAX, amount_junior);
        depositJunior(USDC, amount_junior);
        depositJunior(USDT, amount_junior);

        depositSenior(DAI, amount_senior);
        depositSenior(FRAX, amount_senior);
        depositSenior(USDC, amount_senior);
        depositSenior(USDT, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);
        
        {
            // Pre-state claim (senior).
            uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
            uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
            uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
            
            (uint256 _zSTT_Claimed_SAM,, uint256 _ZVE_Claimed_SAM) = sam.claimAidrop(address(ITO));

            // #1 Senior Deposit Check: SeniorCredits + zSTT
            {    
                // Post-state claim (senior).
                uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
                uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));

                assertEq(
                    _pre_SeniorCredits - _post_SeniorCredits,
                    (amount_senior * 2 + GBL.standardize(amount_senior, USDT) + GBL.standardize(amount_senior, USDC)) * 3
                );  // Note: * 3 for the 3x Multiplier on credits for depositing into SeniorTranche
                assertEq(
                    _pre_zSTT_ITO - _post_zSTT_ITO,
                    (amount_senior * 2 + GBL.standardize(amount_senior, USDT) + GBL.standardize(amount_senior, USDC))
                );
                assertEq(
                    _pre_zSTT_ITO - _post_zSTT_ITO,
                    _zSTT_Claimed_SAM
                );
            }

            // #2 Senior Deposit Check: ZVE
            {    
                // Post-state claim (senior).
                uint256 _post_ZVE_ITO = ZVE.balanceOf(address(ITO));

                // Note: This invariant assumes only two people have deposited into the ITO 
                //       (with each user depositing an equal stanardized amount per stablecoin, but different "equal" amount per user).
                assertEq(
                    _pre_ZVE_ITO - _post_ZVE_ITO,
                    ((amount_senior * 2 + GBL.standardize(amount_senior, USDT) + GBL.standardize(amount_senior, USDC)) * 3 * ZVE.totalSupply() / 10) / 
                    (
                        (amount_senior * 2 + GBL.standardize(amount_senior, USDT) + GBL.standardize(amount_senior, USDC)) * 3 +
                        (amount_junior * 2 + GBL.standardize(amount_junior, USDT) + GBL.standardize(amount_junior, USDC))
                    )
                ); // Note: Reads something like ... (SeniorCredits * 10% of ZVE) / (SeniorCredits + JuniorCredits)
                assertEq(
                    _pre_ZVE_ITO - _post_ZVE_ITO,
                    _ZVE_Claimed_SAM
                );
            }
        }

        {

            // Pre-state claim (junior).
            uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
            uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
            uint256 _pre_ZVE_ITO = ZVE.balanceOf(address(ITO));
            
            (, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Claimed_JIM) = jim.claimAidrop(address(ITO));

            // #1 Junior Deposit Check: JuniorCredits + zJTT
            {    
                // Post-state claim (junior).
                uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
                uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
                assertEq(
                    _pre_JuniorCredits - _post_JuniorCredits,
                    (amount_junior * 2 + GBL.standardize(amount_junior, USDT) + GBL.standardize(amount_junior, USDC))
                );
                assertEq(
                    _pre_zJTT_ITO - _post_zJTT_ITO,
                    (amount_junior * 2 + GBL.standardize(amount_junior, USDT) + GBL.standardize(amount_junior, USDC))
                );
                assertEq(
                    _pre_zJTT_ITO - _post_zJTT_ITO,
                    _zJTT_Claimed_JIM
                );
            }

            // #2 Junior Deposit Check: ZVE
            {    
                // Post-state claim (junior).
                uint256 _post_ZVE_ITO = ZVE.balanceOf(address(ITO));

                // Note: This invariant assumes only two people have deposited into the ITO 
                //       (with each user depositing an equal stanardized amount per stablecoin, but different "equal" amount per user).
                assertEq(
                    _pre_ZVE_ITO - _post_ZVE_ITO,
                    ((amount_junior * 2 + GBL.standardize(amount_junior, USDT) + GBL.standardize(amount_junior, USDC)) * ZVE.totalSupply() / 10) / 
                    (
                        (amount_senior * 2 + GBL.standardize(amount_senior, USDT) + GBL.standardize(amount_senior, USDC)) * 3 +
                        (amount_junior * 2 + GBL.standardize(amount_junior, USDT) + GBL.standardize(amount_junior, USDC))
                    )
                ); // Note: Reads something like ... (JuniorCredits * 10% of ZVE) / (SeniorCredits + JuniorCredits)
                assertEq(
                    _pre_ZVE_ITO - _post_ZVE_ITO,
                    _ZVE_Claimed_JIM
                );
            }

        }
        
    }


    // Validate migrateDeposits() restrictions.
    // This includes:
    //  - Not callable until after ITO ends.
    //  - Not callable more than once.

    function test_ZivoeITO_migrateDeposits_restrictions_notEnded(uint96 amountIn_A, uint96 amountIn_B) public {
        
        uint256 amount_A = uint256(amountIn_A) + 1;
        uint256 amount_B = uint256(amountIn_B) + 1;

        hevm.warp(ITO.start() + 1 seconds);

        depositSenior(FRAX, amount_A);
        depositSenior(DAI, amount_A);
        depositJunior(FRAX, amount_B);
        depositJunior(DAI, amount_B);
        depositBoth(USDC, amount_A, amount_B);
        depositBoth(USDT, amount_A, amount_B);

        hevm.warp(ITO.end());

        // Can't call until after ITO ends (block.timestamp > end).
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::migrateDeposits() block.timestamp <= end");
        ITO.migrateDeposits();
        hevm.stopPrank();
    }

    function test_ZivoeITO_migrateDeposits_restrictions_migrateTwice(uint96 amountIn_A, uint96 amountIn_B) public {
        
        uint256 amount_A = uint256(amountIn_A) + 1;
        uint256 amount_B = uint256(amountIn_B) + 1;

        hevm.warp(ITO.start() + 1 seconds);

        depositSenior(FRAX, amount_A);
        depositSenior(DAI, amount_A);
        depositJunior(FRAX, amount_B);
        depositJunior(DAI, amount_B);
        depositBoth(USDC, amount_A, amount_B);
        depositBoth(USDT, amount_A, amount_B);
        
        hevm.warp(ITO.end() + 1 seconds);

        // Succesfull call now that ITO ends.
        assert(bob.try_migrateDeposits(address(ITO)));

        hevm.warp(ITO.end() + 50 days);

        // Can't call a second time later on.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::migrateDeposits() migrated");
        ITO.migrateDeposits();
        hevm.stopPrank();
    }






    // Validate migrateDeposits() state changes.

    function test_ZivoeITO_migrateDeposits_state(uint96 amountIn_A, uint96 amountIn_B) public {
        
        uint256 amount_A = uint256(amountIn_A) + 1;
        uint256 amount_B = uint256(amountIn_B) + 1;

        hevm.warp(ITO.start() + 1 seconds);

        depositBoth(DAI, amount_A, amount_B);
        depositBoth(FRAX, amount_A, amount_B);
        depositBoth(USDC, amount_A, amount_B);
        depositBoth(USDT, amount_A, amount_B);

        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state.

        uint256 _preBalance_DAI_DAO = IERC20(DAI).balanceOf(address(DAO));
        uint256 _preBalance_FRAX_DAO = IERC20(FRAX).balanceOf(address(DAO));
        uint256 _preBalance_USDC_DAO = IERC20(USDC).balanceOf(address(DAO));
        uint256 _preBalance_USDT_DAO = IERC20(USDT).balanceOf(address(DAO));

        uint256 _preBalance_DAI_ZVL = IERC20(DAI).balanceOf(address(zvl));
        uint256 _preBalance_FRAX_ZVL = IERC20(FRAX).balanceOf(address(zvl));
        uint256 _preBalance_USDC_ZVL = IERC20(USDC).balanceOf(address(zvl));
        uint256 _preBalance_USDT_ZVL = IERC20(USDT).balanceOf(address(zvl));
        
        assert(!ITO.migrated());
        assert(!YDL.unlocked());
        assert(!ZVT.tranchesUnlocked());

        ITO.migrateDeposits();

        // Post-state.
        withinDiff(IERC20(DAI).balanceOf(address(DAO)) - _preBalance_DAI_DAO, (amount_A + amount_B) * 9000 / 10000, 1);
        withinDiff(IERC20(FRAX).balanceOf(address(DAO)) - _preBalance_FRAX_DAO, (amount_A + amount_B) * 9000 / 10000, 1);
        withinDiff(IERC20(USDC).balanceOf(address(DAO)) - _preBalance_USDC_DAO, (amount_A + amount_B) * 9000 / 10000, 1);
        withinDiff(IERC20(USDT).balanceOf(address(DAO)) - _preBalance_USDT_DAO, (amount_A + amount_B) * 9000 / 10000, 1);

        // Post-state.
        withinDiff(IERC20(DAI).balanceOf(address(zvl)) - _preBalance_DAI_ZVL, (amount_A + amount_B) * 1000 / 10000, 1);
        withinDiff(IERC20(FRAX).balanceOf(address(zvl)) - _preBalance_FRAX_ZVL, (amount_A + amount_B) * 1000 / 10000, 1);
        withinDiff(IERC20(USDC).balanceOf(address(zvl)) - _preBalance_USDC_ZVL, (amount_A + amount_B) * 1000 / 10000, 1);
        withinDiff(IERC20(USDT).balanceOf(address(zvl)) - _preBalance_USDT_ZVL, (amount_A + amount_B) * 1000 / 10000, 1);

        assert(ITO.migrated());
        assert(YDL.unlocked());
        assert(ZVT.tranchesUnlocked());

    }
    
}
