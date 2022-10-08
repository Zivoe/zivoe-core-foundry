// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeTranches is Utility {
    
    function setUp() public {

        deployCore(false);

        // Move 2.5mm ZVE from DAO to ZVT.
        assert(god.try_push(address(DAO), address(ZVT), address(ZVE), 2500000 ether));

    }

    // Verify initial state of ZivoeITO.sol.
    function xtest_ZivoeTranches_constructor() public {

        // Pre-state checks.
        assertEq(ZVT.owner(), address(DAO));
        assertEq(ZVT.GBL(), address(GBL));
    }
    
    // Verify rewardZVEJuniorDeposit() values.
    // Verify rewardZVESeniorDeposit() values.
    
    function xtest_ZivoeTranches_rewardZVEJuniorDeposit_values() public { 

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
    
    function xtest_ZivoeTranches_rewardZVESeniorDeposit_values() public { 

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

    function xtest_ZivoeTranches_depositJunior_restrictions() public {

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

        mint("DAI", address(jim), 100 ether);

        // "jim" performs deposit of DAI.
        assert(jim.try_approveToken(DAI, address(ZVT), 100 ether));
        assert(!jim.try_depositJuniorTranches(address(ZVT), 100 ether, DAI));

    }

    function xtest_ZivoeTranches_depositJunior_state_changes() public {

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

        mint("DAI", address(jim), 10000 ether);

        uint256 pre_DAO_S = IERC20(DAI).balanceOf(address(DAO));
        uint256 pre_tom_S = IERC20(DAI).balanceOf(address(jim));
        uint256 pre_tom_JTT = IERC20(address(zJTT)).balanceOf(address(jim));
        uint256 pre_tom_ZVE = IERC20(ZVE).balanceOf(address(jim));

        uint256 zveRewards = ZVT.rewardZVEJuniorDeposit(10000 ether);

        // "jim" performs deposit of DAI.
        assert(jim.try_approveToken(DAI, address(ZVT), 10000 ether));
        assert(jim.try_depositJuniorTranches(address(ZVT), 10000 ether, DAI));

        uint256 post_DAO_S = IERC20(DAI).balanceOf(address(DAO));
        uint256 post_tom_S = IERC20(DAI).balanceOf(address(jim));
        uint256 post_tom_JTT = IERC20(address(zJTT)).balanceOf(address(jim));
        uint256 post_tom_ZVE = IERC20(ZVE).balanceOf(address(jim));

        // Post-state check (DAI).
        assertEq(post_DAO_S - pre_DAO_S, 10000 ether);
        assertEq(pre_tom_S - post_tom_S, 10000 ether);
        assertEq(post_tom_JTT - pre_tom_JTT, 10000 ether);
        assertEq(post_tom_ZVE - pre_tom_ZVE, zveRewards);

        // --------------------
        // USDC depositJunior()
        // --------------------

        mint("USDC", address(jim), 100 * USD);

        // Pre-state check (USDC).
        pre_DAO_S = IERC20(USDC).balanceOf(address(DAO));
        pre_tom_S = IERC20(USDC).balanceOf(address(jim));
        pre_tom_JTT = IERC20(address(zJTT)).balanceOf(address(jim));

        // "jim" performs deposit of USDC.
        assert(jim.try_approveToken(USDC, address(ZVT), 100 * USD));
        assert(jim.try_depositJuniorTranches(address(ZVT), 100 * USD, USDC));

        post_DAO_S = IERC20(USDC).balanceOf(address(DAO));
        post_tom_S = IERC20(USDC).balanceOf(address(jim));
        post_tom_JTT = IERC20(address(zJTT)).balanceOf(address(jim));

        // Post-state check (USDC).
        assertEq(post_DAO_S - pre_DAO_S, 100 * USD);
        assertEq(pre_tom_S - post_tom_S, 100 * USD);
        assertEq(post_tom_JTT - pre_tom_JTT, 100 ether);

        // --------------------
        // FRAX depositJunior()
        // --------------------

        mint("FRAX", address(jim), 100 ether);

        // Pre-state check (FRAX).
        pre_DAO_S = IERC20(FRAX).balanceOf(address(DAO));
        pre_tom_S = IERC20(FRAX).balanceOf(address(jim));
        pre_tom_JTT = IERC20(address(zJTT)).balanceOf(address(jim));

        // "jim" performs deposit of FRAX.
        assert(jim.try_approveToken(FRAX, address(ZVT), 100 ether));
        assert(jim.try_depositJuniorTranches(address(ZVT), 100 ether, FRAX));

        post_DAO_S = IERC20(FRAX).balanceOf(address(DAO));
        post_tom_S = IERC20(FRAX).balanceOf(address(jim));
        post_tom_JTT = IERC20(address(zJTT)).balanceOf(address(jim));

        // Post-state check (FRAX).
        assertEq(post_DAO_S - pre_DAO_S, 100 ether);
        assertEq(pre_tom_S - post_tom_S, 100 ether);
        assertEq(post_tom_JTT - pre_tom_JTT, 100 ether);

        // --------------------
        // USDT depositJunior()
        // --------------------

        mint("USDT", address(jim), 100 * USD);

        // Pre-state check (USDT).
        pre_DAO_S = IERC20(USDT).balanceOf(address(DAO));
        pre_tom_S = IERC20(USDT).balanceOf(address(jim));
        pre_tom_JTT = IERC20(address(zJTT)).balanceOf(address(jim));

        // "jim" performs deposit of USDT.
        assert(jim.try_approveToken(USDT, address(ZVT), 100 * USD));
        assert(jim.try_depositJuniorTranches(address(ZVT), 100 * USD, USDT));

        post_DAO_S = IERC20(USDT).balanceOf(address(DAO));
        post_tom_S = IERC20(USDT).balanceOf(address(jim));
        post_tom_JTT = IERC20(address(zJTT)).balanceOf(address(jim));

        // Post-state check (USDT).
        assertEq(post_DAO_S - pre_DAO_S, 100 * USD);
        assertEq(pre_tom_S - post_tom_S, 100 * USD);
        assertEq(post_tom_JTT - pre_tom_JTT, 100 ether);
    }

    // Verify depositSenior() restrictions.
    // Verify depositSenior() state changes.

    function xtest_ZivoeTranches_depositSenior_restrictions() public {

        // Testing non whitelisted asset

        // Mint "bob" 100 WETH.
        mint("WETH", address(bob), 100 ether);

        // Cannot deposit a stable coin that is not whitelisted.
        assert(bob.try_approveToken(WETH, address(ZVT), 100 ether));
        assert(!bob.try_depositSeniorTranches(address(ZVT), 100 ether, WETH));
    }

    function xtest_ZivoeTranches_depositSenior_state_changes() public {

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