// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

import "../ZivoeTranches.sol";

contract ZivoeTranchesTest is Utility {
    
    ZivoeTranches    ZVT;

    function setUp() public {

        setUpTokens();
        createActors();

        // Deploy ZivoeToken.sol

        ZVE = new ZivoeToken(
            10000000 ether,   // 10 million supply
            18,
            'Zivoe',
            'ZVE',
            address(god)
        );

        // Deploy ZivoeDAO.sol

        DAO = new ZivoeDAO(address(god), address(GBL));

        // Deploy "SeniorTrancheToken" through ZivoeTrancheToken.sol
        // Deploy "JuniorTrancheToken" through ZivoeTrancheToken.sol

        zSTT = new ZivoeTrancheToken(
            18,
            'SeniorTrancheToken',
            'zSTT',
            address(god)
        );

        zJTT = new ZivoeTrancheToken(
            18,
            'JuniorTrancheToken',
            'zJTT',
            address(god)
        );

        // Deploy ZivoeTranches.sol

        ZVT = new ZivoeTranches(
            address(GBL),
            address(god)
        );

        assert(god.try_changeMinterRole(address(zJTT), address(ZVT), true));
        assert(god.try_changeMinterRole(address(zSTT), address(ZVT), true));
    }

    // Verify initial state of ZivoeITO.sol.
    function test_ZivoeTranches_constructor() public {

        // Pre-state checks.
        assertEq(ZVT.GBL(), address(GBL));
        assertEq(ZVT.owner(), address(god));

        assert(ZVT.stablecoinWhitelist(0x6B175474E89094C44Da98b954EedeAC495271d0F));
        assert(ZVT.stablecoinWhitelist(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
        assert(ZVT.stablecoinWhitelist(0x853d955aCEf822Db058eb8505911ED77F175b99e));
        assert(ZVT.stablecoinWhitelist(0xdAC17F958D2ee523a2206206994597C13D831ec7));

        assert(ZVT.killSwitch());
    }

    // Verify flipSwitch() restrictions.
    // Verify flipSwitch() state changes.

    function test_ZivoeTranches_flipSwitch_restrictions() public {

        // "bob" cannot call flipSwitch().
        assert(!bob.try_flipSwitch(address(ZVT)));
    }

    function test_ZivoeTranches_flipSwitch_state_changes() public {

        // "god" will call flipSwitch().
        assert(god.try_flipSwitch(address(ZVT)));

        // State of flipSwitch will be false post admin call.
        assert(!ZVT.killSwitch());

        // "god" will call flipSwitch().
        assert(god.try_flipSwitch(address(ZVT)));

        // State of flipSwitch will be true post admin call.
        assert(ZVT.killSwitch());
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

    // Verify depositJunior() restrictions.
    // Verify depositJunior() state changes.

    function test_ZivoeTranches_depositJunior_restrictions() public {

        // -----------------------------
        // Testing non whitelisted asset
        // -----------------------------

        // "god" will call flipSwitch() to enable deposits.
        assert(god.try_flipSwitch(address(ZVT)));

        // Mint "bob" 100 WETH.
        mint("WETH", address(bob), 100 ether);

        // Cannot deposit a stable coin that is not whitelisted.
        assert(bob.try_approveToken(WETH, address(ZVT), 100 ether));
        assert(!bob.try_depositJuniorTranches(address(ZVT), 100 ether, WETH));

        // --------------------------
        // Testing killSwitch deposit
        // --------------------------

        // "god" will activate killSwitch.
        assert(god.try_flipSwitch(address(ZVT)));

        // Mint "bob" 100 WETH.
        mint("DAI", address(bob), 100 ether);

        // Cannot make a deposit when the killSwitch is active.
        assert(bob.try_approveToken(DAI, address(ZVT), 100 ether));
        assert(!bob.try_depositJuniorTranches(address(ZVT), 100 ether, DAI));
    }

    function test_ZivoeTranches_depositJunior_state_changes() public {

        // "god" will call flipSwitch() to enable deposits.
        assert(god.try_flipSwitch(address(ZVT)));

        // -------------------
        // DAI depositJunior()
        // -------------------

        mint("DAI", address(tom), 100 ether);

        // Pre-state check (DAI).
        assertEq(IERC20(DAI).balanceOf(address(DAO)), 0);
        assertEq(IERC20(DAI).balanceOf(address(tom)), 100 ether);
        assertEq(IERC20(address(zJTT)).balanceOf(address(tom)), 0);

        // "tom" performs deposit of DAI.
        assert(tom.try_approveToken(DAI, address(ZVT), 100 ether));
        assert(tom.try_depositJuniorTranches(address(ZVT), 100 ether, DAI));

        // Post-state check (DAI).
        assertEq(IERC20(DAI).balanceOf(address(DAO)), 100 ether);
        assertEq(IERC20(DAI).balanceOf(address(tom)), 0);
        assertEq(IERC20(address(zJTT)).balanceOf(address(tom)), 100 ether);

        // --------------------
        // USDC depositJunior()
        // --------------------

        mint("USDC", address(tom), 100 * USD);

        // Pre-state check (USDC).
        assertEq(IERC20(USDC).balanceOf(address(DAO)), 0);
        assertEq(IERC20(USDC).balanceOf(address(tom)), 100 * USD);
        assertEq(IERC20(address(zJTT)).balanceOf(address(tom)), 100 ether);

        // "tom" performs deposit of USDC.
        assert(tom.try_approveToken(USDC, address(ZVT), 100 * USD));
        assert(tom.try_depositJuniorTranches(address(ZVT), 100 * USD, USDC));

        // Post-state check (USDC).
        assertEq(IERC20(USDC).balanceOf(address(DAO)), 100 * USD);
        assertEq(IERC20(USDC).balanceOf(address(tom)), 0);
        assertEq(IERC20(address(zJTT)).balanceOf(address(tom)), 200 ether);

        // --------------------
        // FRAX depositJunior()
        // --------------------

        mint("FRAX", address(tom), 100 ether);

        // Pre-state check (FRAX).
        assertEq(IERC20(FRAX).balanceOf(address(DAO)), 0);
        assertEq(IERC20(FRAX).balanceOf(address(tom)), 100 ether);
        assertEq(IERC20(address(zJTT)).balanceOf(address(tom)), 200 ether);

        // "tom" performs deposit of FRAX.
        assert(tom.try_approveToken(FRAX, address(ZVT), 100 ether));
        assert(tom.try_depositJuniorTranches(address(ZVT), 100 ether, FRAX));

        // Post-state check (FRAX).
        assertEq(IERC20(FRAX).balanceOf(address(DAO)), 100 ether);
        assertEq(IERC20(FRAX).balanceOf(address(tom)), 0);
        assertEq(IERC20(address(zJTT)).balanceOf(address(tom)), 300 ether);

        // --------------------
        // USDT depositJunior()
        // --------------------

        mint("USDT", address(tom), 100 * USD);

        // Pre-state check (USDT).
        assertEq(IERC20(USDT).balanceOf(address(DAO)), 0);
        assertEq(IERC20(USDT).balanceOf(address(tom)), 100 * USD);
        assertEq(IERC20(address(zJTT)).balanceOf(address(tom)), 300 ether);

        // "tom" performs deposit of USDT.
        assert(tom.try_approveToken(USDT, address(ZVT), 100 * USD));
        assert(tom.try_depositJuniorTranches(address(ZVT), 100 * USD, USDT));

        // Post-state check (USDT).
        assertEq(IERC20(USDT).balanceOf(address(DAO)), 100 * USD);
        assertEq(IERC20(USDT).balanceOf(address(tom)), 0);
        assertEq(IERC20(address(zJTT)).balanceOf(address(tom)), 400 ether);
    }

    // Verify depositSenior() restrictions.
    // Verify depositSenior() state changes.

    function test_ZivoeTranches_depositSenior_restrictions() public {

        // -----------------------------
        // Testing non whitelisted asset
        // -----------------------------

        // "god" will call flipSwitch() to enable deposits.
        assert(god.try_flipSwitch(address(ZVT)));

        // Mint "bob" 100 WETH.
        mint("WETH", address(bob), 100 ether);

        // Cannot deposit a stable coin that is not whitelisted.
        assert(bob.try_approveToken(WETH, address(ZVT), 100 ether));
        assert(!bob.try_depositSeniorTranches(address(ZVT), 100 ether, WETH));

        // --------------------------
        // Testing killSwitch deposit
        // --------------------------

        // "god" will activate killSwitch.
        assert(god.try_flipSwitch(address(ZVT)));

        // Mint "sam" 100 DAI.
        mint("DAI", address(bob), 100 ether);

        // Cannot make a deposit when the killSwitch is active.
        assert(bob.try_approveToken(DAI, address(ZVT), 100 ether));
        assert(!bob.try_depositSeniorTranches(address(ZVT), 1000, DAI));
    }

    function test_ZivoeTranches_depositSenior_state_changes() public {

        // -------------------
        // DAI depositSenior()
        // -------------------

        // "god" will call flipSwitch() to enable deposits.
        assert(god.try_flipSwitch(address(ZVT)));

        mint("DAI", address(sam), 100 ether);

        // Pre-state check (DAI).
        assertEq(IERC20(DAI).balanceOf(address(DAO)), 0);
        assertEq(IERC20(DAI).balanceOf(address(sam)), 100 ether);
        assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), 0);

        // "sam" performs deposit of DAI.
        assert(sam.try_approveToken(DAI, address(ZVT), 100 ether));
        assert(sam.try_depositSeniorTranches(address(ZVT), 100 ether, DAI));

        // Post-state check (DAI).
        assertEq(IERC20(DAI).balanceOf(address(DAO)), 100 ether);
        assertEq(IERC20(DAI).balanceOf(address(sam)), 0);
        assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), 100 ether);

        // --------------------
        // USDC depositSenior()
        // --------------------

        mint("USDC", address(sam), 100 * USD);

        // Pre-state check (USDC).
        assertEq(IERC20(USDC).balanceOf(address(DAO)), 0);
        assertEq(IERC20(USDC).balanceOf(address(sam)), 100 * USD);
        assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), 100 ether);

        // "sam" performs deposit of USDC.
        assert(sam.try_approveToken(USDC, address(ZVT), 100 * USD));
        assert(sam.try_depositSeniorTranches(address(ZVT), 100 * USD, USDC));

        // Post-state check (USDC).
        assertEq(IERC20(USDC).balanceOf(address(DAO)), 100 * USD);
        assertEq(IERC20(USDC).balanceOf(address(sam)), 0);
        assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), 200 ether);

        // --------------------
        // FRAX depositSenior()
        // --------------------
        mint("FRAX", address(sam), 100 ether);

        // Pre-state check (FRAX).
        assertEq(IERC20(FRAX).balanceOf(address(DAO)), 0);
        assertEq(IERC20(FRAX).balanceOf(address(sam)), 100 ether);
        assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), 200 ether);

        // "sam" performs deposit of FRAX.
        assert(sam.try_approveToken(FRAX, address(ZVT), 100 ether));
        assert(sam.try_depositSeniorTranches(address(ZVT), 100 ether, FRAX));

        // Post-state check (FRAX).
        assertEq(IERC20(FRAX).balanceOf(address(DAO)), 100 ether);
        assertEq(IERC20(FRAX).balanceOf(address(sam)), 0);
        assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), 300 ether);

        // --------------------
        // USDT depositSenior()
        // --------------------

        mint("USDT", address(sam), 100 * USD);

        // Pre-state check (USDT).
        assertEq(IERC20(USDT).balanceOf(address(DAO)), 0);
        assertEq(IERC20(USDT).balanceOf(address(sam)), 100 * USD);
        assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), 300 ether);

        // "sam" performs deposit of USDT.
        assert(sam.try_approveToken(USDT, address(ZVT), 100 * USD));
        assert(sam.try_depositSeniorTranches(address(ZVT), 100 * USD, USDT));

        // Post-state check (USDT).
        assertEq(IERC20(USDT).balanceOf(address(DAO)), 100 * USD);
        assertEq(IERC20(USDT).balanceOf(address(sam)), 0);
        assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), 400 ether);
    }

}