// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

import "../ZivoeTranches.sol";

contract ZivoeTranchesTest is Utility {
    
    ZivoeTranches    ZVT;

    function setUp() public {

        setUpFundedDAO();

        // Deploy ZivoeTranches.sol

        ZVT = new ZivoeTranches(
            address(GBL)
        );

        assert(god.try_changeMinterRole(address(zJTT), address(ZVT), true));
        assert(god.try_changeMinterRole(address(zSTT), address(ZVT), true));

        // Whitelist ZVT locker to DAO.
        assert(god.try_modifyLockerWhitelist(address(DAO), address(ZVT), true));

        // Move 2.5mm ZVE from DAO to ZVT.
        assert(god.try_push(address(DAO), address(ZVT), address(ZVE), 2500000 ether));

    }

    // Verify initial state of ZivoeITO.sol.
    function test_ZivoeTranches_constructor() public {

        // Pre-state checks.
        assertEq(ZVT.owner(), address(god));
        assertEq(ZVT.GBL(), address(GBL));

        assert(ZVT.stablecoinWhitelist(0x6B175474E89094C44Da98b954EedeAC495271d0F));
        assert(ZVT.stablecoinWhitelist(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
        assert(ZVT.stablecoinWhitelist(0x853d955aCEf822Db058eb8505911ED77F175b99e));
        assert(ZVT.stablecoinWhitelist(0xdAC17F958D2ee523a2206206994597C13D831ec7));
    }

    // Verify modifyStablecoinWhitelist() restrictions.
    // Verify modifyStablecoinWhitelist() state changes

    function test_ZivoeTranches_modifyStablecoinWhitelist_restrictions() public {

        // "bob" cannot call modifyStablecoinWhitelist().
        assert(!bob.try_modifyStablecoinWhitelist(address(ZVT), address(DAI), false));
    }

    function test_ZivoeTranches_modifyStablecoinWhitelist_state_changes() public {

        // "god" will call modifyStablecoinWhitelist() and set DAI to false.
        assert(god.try_modifyStablecoinWhitelist(address(ZVT), address(DAI), false));

        // Verify state of DAI in the stableCoinWhitelist is false.
        assert(!ZVT.stablecoinWhitelist(address(DAI)));

        // "god" will call modifyStablecoinWhitelist() and set TrueUSD to true.
        assert(god.try_modifyStablecoinWhitelist(address(ZVT), TUSD, true));

        // Verify state of TrueUSD in the stableCoinWhitelist is true.
        assert(ZVT.stablecoinWhitelist(TUSD));
    }

    // Verify rewardZVEJuniorDeposit() values.
    // Verify rewardZVESeniorDeposit() values.
    
    function test_ZivoeTranches_rewardZVEJuniorDeposit_values() public { 

        // Values when tranches are initially equal, should be minZVEPerJTT * deposit.
        emit Debug('', ZVT.rewardZVEJuniorDeposit(1 ether));
        emit Debug('', ZVT.rewardZVEJuniorDeposit(100_000 ether));
        emit Debug('', ZVT.rewardZVEJuniorDeposit(5_000_000 ether));

        // Increase ratio of tranches from 1:1 => 1:5, Junior:Senior.
        assertEq(zSTT.totalSupply(), 4_000_000 ether);
        assertEq(zJTT.totalSupply(), 4_000_000 ether);

        mint("DAI", address(sam), 16_000_000 ether);
        assert(sam.try_approveToken(DAI, address(ZVT), 16_000_000 ether));
        assert(sam.try_depositSeniorTranches(address(ZVT), 16_000_000 ether, DAI));

        assertEq(zSTT.totalSupply(), 20_000_000 ether);
        assertEq(zJTT.totalSupply(), 4_000_000 ether);

        // Values when tranches are in-between.
        emit Debug('', ZVT.rewardZVEJuniorDeposit(1 ether));
        emit Debug('', ZVT.rewardZVEJuniorDeposit(100_000 ether));
        emit Debug('', ZVT.rewardZVEJuniorDeposit(5_000_000 ether));

        
        // Increase size of tranches equivalently, test larger numbers.
        mint("DAI", address(sam), 216_000_000 ether);
        assert(sam.try_approveToken(DAI, address(ZVT), 216_000_000 ether));
        assert(sam.try_depositSeniorTranches(address(ZVT), 180_000_000 ether, DAI));
        assert(sam.try_depositJuniorTranches(address(ZVT), 36_000_000 ether, DAI));
        assertEq(zSTT.totalSupply(), 200_000_000 ether);
        assertEq(zJTT.totalSupply(), 40_000_000 ether);

        // Values when tranches are in-between.
        emit Debug('', ZVT.rewardZVEJuniorDeposit(1 ether));
        emit Debug('', ZVT.rewardZVEJuniorDeposit(100_000 ether));
        emit Debug('', ZVT.rewardZVEJuniorDeposit(5_000_000 ether));

    }
    
    function test_ZivoeTranches_rewardZVESeniorDeposit_values() public { 

        // Values when tranches are initially equal, should be minZVEPerJTT * deposit.
        emit Debug('', ZVT.rewardZVESeniorDeposit(1 ether));
        emit Debug('', ZVT.rewardZVESeniorDeposit(100_000 ether));
        emit Debug('', ZVT.rewardZVESeniorDeposit(5_000_000 ether));

        // Increase ratio of tranches from 1:1 => 1:5, Junior:Senior.
        assertEq(zSTT.totalSupply(), 4_000_000 ether);
        assertEq(zJTT.totalSupply(), 4_000_000 ether);

        mint("DAI", address(sam), 16_000_000 ether);
        assert(sam.try_approveToken(DAI, address(ZVT), 16_000_000 ether));
        assert(sam.try_depositSeniorTranches(address(ZVT), 16_000_000 ether, DAI));

        assertEq(zSTT.totalSupply(), 20_000_000 ether);
        assertEq(zJTT.totalSupply(), 4_000_000 ether);

        // Values when tranches are in-between.
        emit Debug('', ZVT.rewardZVESeniorDeposit(1 ether));
        emit Debug('', ZVT.rewardZVESeniorDeposit(100_000 ether));
        emit Debug('', ZVT.rewardZVESeniorDeposit(5_000_000 ether));

        // Increase size of tranches equivalently, test larger numbers.
        mint("DAI", address(sam), 216_000_000 ether);
        assert(sam.try_approveToken(DAI, address(ZVT), 216_000_000 ether));
        assert(sam.try_depositSeniorTranches(address(ZVT), 180_000_000 ether, DAI));
        assert(sam.try_depositJuniorTranches(address(ZVT), 36_000_000 ether, DAI));
        assertEq(zSTT.totalSupply(), 200_000_000 ether);
        assertEq(zJTT.totalSupply(), 40_000_000 ether);

        // Values when tranches are in-between.
        emit Debug('', ZVT.rewardZVESeniorDeposit(1 ether));
        emit Debug('', ZVT.rewardZVESeniorDeposit(100_000 ether));
        emit Debug('', ZVT.rewardZVESeniorDeposit(5_000_000 ether));

    }

    // Verify depositJunior() restrictions.
    // Verify depositJunior() state changes.

    function test_ZivoeTranches_depositJunior_restrictions() public {

        // Testing non whitelisted asset.

        // Mint "bob" 100 WETH.
        mint("WETH", address(bob), 100 ether);

        // Cannot deposit a stable coin that is not whitelisted.
        assert(bob.try_approveToken(WETH, address(ZVT), 100 ether));
        assert(!bob.try_depositJuniorTranches(address(ZVT), 100 ether, WETH));

        // -------------------
        // DAI depositJunior()
        // -------------------
        // NOTE: This will fail because there is currently an equal amount of capital in the tranches,
        //       and the default value is 20%, this occurred initially due to ITO.

        emit Debug('a', IERC20(address(zJTT)).totalSupply());
        emit Debug('a', IERC20(address(zSTT)).totalSupply());

        mint("DAI", address(tom), 100 ether);

        uint256 pre_DAO_S = IERC20(DAI).balanceOf(address(DAO));
        uint256 pre_tom_S = IERC20(DAI).balanceOf(address(tom));
        uint256 pre_tom_JTT = IERC20(address(zJTT)).balanceOf(address(tom));

        // "tom" performs deposit of DAI.
        assert(tom.try_approveToken(DAI, address(ZVT), 100 ether));
        assert(!tom.try_depositJuniorTranches(address(ZVT), 100 ether, DAI));

    }

    function test_ZivoeTranches_depositJunior_state_changes() public {

        // NOTE: In order to facilitate deposits into junior,
        //       the pools must come back into acceptable balance.
        //       This includes 10% - 30% range, Junior:Senior.

        // Increase ratio of tranches from 1:1 => 1:5, Junior:Senior.
        assertEq(zSTT.totalSupply(), 4_000_000 ether);
        assertEq(zJTT.totalSupply(), 4_000_000 ether);

        mint("DAI", address(sam), 16_000_000 ether);
        assert(sam.try_approveToken(DAI, address(ZVT), 16_000_000 ether));
        assert(sam.try_depositSeniorTranches(address(ZVT), 16_000_000 ether, DAI));

        // -------------------
        // DAI depositJunior()
        // -------------------

        mint("DAI", address(tom), 10000 ether);

        uint256 pre_DAO_S = IERC20(DAI).balanceOf(address(DAO));
        uint256 pre_tom_S = IERC20(DAI).balanceOf(address(tom));
        uint256 pre_tom_JTT = IERC20(address(zJTT)).balanceOf(address(tom));
        uint256 pre_tom_ZVE = IERC20(ZVE).balanceOf(address(tom));

        uint256 zveRewards = ZVT.rewardZVEJuniorDeposit(10000 ether);

        // "tom" performs deposit of DAI.
        assert(tom.try_approveToken(DAI, address(ZVT), 10000 ether));
        assert(tom.try_depositJuniorTranches(address(ZVT), 10000 ether, DAI));

        uint256 post_DAO_S = IERC20(DAI).balanceOf(address(DAO));
        uint256 post_tom_S = IERC20(DAI).balanceOf(address(tom));
        uint256 post_tom_JTT = IERC20(address(zJTT)).balanceOf(address(tom));
        uint256 post_tom_ZVE = IERC20(ZVE).balanceOf(address(tom));

        // Post-state check (DAI).
        assertEq(post_DAO_S - pre_DAO_S, 10000 ether);
        assertEq(pre_tom_S - post_tom_S, 10000 ether);
        assertEq(post_tom_JTT - pre_tom_JTT, 10000 ether);
        assertEq(post_tom_ZVE - pre_tom_ZVE, zveRewards);

        // --------------------
        // USDC depositJunior()
        // --------------------

        mint("USDC", address(tom), 100 * USD);

        // Pre-state check (USDC).
        pre_DAO_S = IERC20(USDC).balanceOf(address(DAO));
        pre_tom_S = IERC20(USDC).balanceOf(address(tom));
        pre_tom_JTT = IERC20(address(zJTT)).balanceOf(address(tom));

        // "tom" performs deposit of USDC.
        assert(tom.try_approveToken(USDC, address(ZVT), 100 * USD));
        assert(tom.try_depositJuniorTranches(address(ZVT), 100 * USD, USDC));

        post_DAO_S = IERC20(USDC).balanceOf(address(DAO));
        post_tom_S = IERC20(USDC).balanceOf(address(tom));
        post_tom_JTT = IERC20(address(zJTT)).balanceOf(address(tom));

        // Post-state check (USDC).
        assertEq(post_DAO_S - pre_DAO_S, 100 * USD);
        assertEq(pre_tom_S - post_tom_S, 100 * USD);
        assertEq(post_tom_JTT - pre_tom_JTT, 100 ether);

        // --------------------
        // FRAX depositJunior()
        // --------------------

        mint("FRAX", address(tom), 100 ether);

        // Pre-state check (FRAX).
        pre_DAO_S = IERC20(FRAX).balanceOf(address(DAO));
        pre_tom_S = IERC20(FRAX).balanceOf(address(tom));
        pre_tom_JTT = IERC20(address(zJTT)).balanceOf(address(tom));

        // "tom" performs deposit of FRAX.
        assert(tom.try_approveToken(FRAX, address(ZVT), 100 ether));
        assert(tom.try_depositJuniorTranches(address(ZVT), 100 ether, FRAX));

        post_DAO_S = IERC20(FRAX).balanceOf(address(DAO));
        post_tom_S = IERC20(FRAX).balanceOf(address(tom));
        post_tom_JTT = IERC20(address(zJTT)).balanceOf(address(tom));

        // Post-state check (FRAX).
        assertEq(post_DAO_S - pre_DAO_S, 100 ether);
        assertEq(pre_tom_S - post_tom_S, 100 ether);
        assertEq(post_tom_JTT - pre_tom_JTT, 100 ether);

        // --------------------
        // USDT depositJunior()
        // --------------------

        mint("USDT", address(tom), 100 * USD);

        // Pre-state check (USDT).
        pre_DAO_S = IERC20(USDT).balanceOf(address(DAO));
        pre_tom_S = IERC20(USDT).balanceOf(address(tom));
        pre_tom_JTT = IERC20(address(zJTT)).balanceOf(address(tom));

        // "tom" performs deposit of USDT.
        assert(tom.try_approveToken(USDT, address(ZVT), 100 * USD));
        assert(tom.try_depositJuniorTranches(address(ZVT), 100 * USD, USDT));

        post_DAO_S = IERC20(USDT).balanceOf(address(DAO));
        post_tom_S = IERC20(USDT).balanceOf(address(tom));
        post_tom_JTT = IERC20(address(zJTT)).balanceOf(address(tom));

        // Post-state check (USDT).
        assertEq(post_DAO_S - pre_DAO_S, 100 * USD);
        assertEq(pre_tom_S - post_tom_S, 100 * USD);
        assertEq(post_tom_JTT - pre_tom_JTT, 100 ether);
    }

    // Verify depositSenior() restrictions.
    // Verify depositSenior() state changes.

    function test_ZivoeTranches_depositSenior_restrictions() public {

        // Testing non whitelisted asset

        // Mint "bob" 100 WETH.
        mint("WETH", address(bob), 100 ether);

        // Cannot deposit a stable coin that is not whitelisted.
        assert(bob.try_approveToken(WETH, address(ZVT), 100 ether));
        assert(!bob.try_depositSeniorTranches(address(ZVT), 100 ether, WETH));
    }

    function test_ZivoeTranches_depositSenior_state_changes() public {

        // -------------------
        // DAI depositSenior()
        // -------------------

        mint("DAI", address(sam), 10000 ether);

        // Pre-state check (DAI).
        uint256 pre_DAO_S = IERC20(DAI).balanceOf(address(DAO));
        uint256 pre_sam_S = IERC20(DAI).balanceOf(address(sam));
        uint256 pre_sam_JTT = IERC20(address(zSTT)).balanceOf(address(sam));
        uint256 pre_sam_ZVE = IERC20(ZVE).balanceOf(address(sam));
        
        uint256 zveRewards = ZVT.rewardZVESeniorDeposit(10000 ether);
        
        // "sam" performs deposit of DAI.
        assert(sam.try_approveToken(DAI, address(ZVT), 10000 ether));
        assert(sam.try_depositSeniorTranches(address(ZVT), 10000 ether, DAI));

        uint256 post_DAO_S = IERC20(DAI).balanceOf(address(DAO));
        uint256 post_sam_S = IERC20(DAI).balanceOf(address(sam));
        uint256 post_sam_JTT = IERC20(address(zSTT)).balanceOf(address(sam));
        uint256 post_sam_ZVE = IERC20(ZVE).balanceOf(address(sam));

        // Post-state check (DAI).
        assertEq(post_DAO_S - pre_DAO_S, 10000 ether);
        assertEq(pre_sam_S - post_sam_S, 10000 ether);
        assertEq(post_sam_JTT - pre_sam_JTT, 10000 ether);
        assertEq(post_sam_ZVE - pre_sam_ZVE, zveRewards);

        // Check ZVE Rewards (once).

        // --------------------
        // USDC depositSenior()
        // --------------------

        mint("USDC", address(sam), 100 * USD);

        // Pre-state check (USDC).
        pre_DAO_S = IERC20(USDC).balanceOf(address(DAO));
        pre_sam_S = IERC20(USDC).balanceOf(address(sam));
        pre_sam_JTT = IERC20(address(zSTT)).balanceOf(address(sam));

        // "sam" performs deposit of USDC.
        assert(sam.try_approveToken(USDC, address(ZVT), 100 * USD));
        assert(sam.try_depositSeniorTranches(address(ZVT), 100 * USD, USDC));

        post_DAO_S = IERC20(USDC).balanceOf(address(DAO));
        post_sam_S = IERC20(USDC).balanceOf(address(sam));
        post_sam_JTT = IERC20(address(zSTT)).balanceOf(address(sam));
    
        // Post-state check (USDC).
        assertEq(post_DAO_S - pre_DAO_S, 100 * USD);
        assertEq(pre_sam_S - post_sam_S, 100 * USD);
        assertEq(post_sam_JTT - pre_sam_JTT, 100 ether);

        // --------------------
        // FRAX depositSenior()
        // --------------------
        mint("FRAX", address(sam), 100 ether);

        // Pre-state check (FRAX).
        pre_DAO_S = IERC20(FRAX).balanceOf(address(DAO));
        pre_sam_S = IERC20(FRAX).balanceOf(address(sam));
        pre_sam_JTT = IERC20(address(zSTT)).balanceOf(address(sam));

        // "sam" performs deposit of FRAX.
        assert(sam.try_approveToken(FRAX, address(ZVT), 100 ether));
        assert(sam.try_depositSeniorTranches(address(ZVT), 100 ether, FRAX));

        post_DAO_S = IERC20(FRAX).balanceOf(address(DAO));
        post_sam_S = IERC20(FRAX).balanceOf(address(sam));
        post_sam_JTT = IERC20(address(zSTT)).balanceOf(address(sam));

        // Post-state check (FRAX).
        assertEq(post_DAO_S - pre_DAO_S, 100 ether);
        assertEq(pre_sam_S - post_sam_S, 100 ether);
        assertEq(post_sam_JTT - pre_sam_JTT, 100 ether);

        // --------------------
        // USDT depositSenior()
        // --------------------

        mint("USDT", address(sam), 100 * USD);

        // Pre-state check (USDT).
        pre_DAO_S = IERC20(USDT).balanceOf(address(DAO));
        pre_sam_S = IERC20(USDT).balanceOf(address(sam));
        pre_sam_JTT = IERC20(address(zSTT)).balanceOf(address(sam));

        // "sam" performs deposit of USDT.
        assert(sam.try_approveToken(USDT, address(ZVT), 100 * USD));
        assert(sam.try_depositSeniorTranches(address(ZVT), 100 * USD, USDT));

        post_DAO_S = IERC20(USDT).balanceOf(address(DAO));
        post_sam_S = IERC20(USDT).balanceOf(address(sam));
        post_sam_JTT = IERC20(address(zSTT)).balanceOf(address(sam));

        // Post-state check (USDT).
        assertEq(post_DAO_S - pre_DAO_S, 100 * USD);
        assertEq(pre_sam_S - post_sam_S, 100 * USD);
        assertEq(post_sam_JTT - pre_sam_JTT, 100 ether);
    }

}