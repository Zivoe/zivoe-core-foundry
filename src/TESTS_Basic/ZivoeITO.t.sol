// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract ZivoeITOTest is Utility {

    function setUp() public {

        // Run initial setup functions.
        createActors();
        setUpTokens();

        // (0) Deploy ZivoeGBL.sol

        GBL = new ZivoeGBL();

        // (1) Deploy ZivoeToken.sol

        ZVE = new ZivoeToken(
            'Zivoe',
            'ZVE',
            address(god),
            address(GBL)
        );

        // (2) Deploy ZivoeDAO.sol

        DAO = new ZivoeDAO(address(god), address(GBL));

        // (3) Deploy "SeniorTrancheToken" through ZivoeTrancheToken.sol
        // (4) Deploy "JuniorTrancheToken" through ZivoeTrancheToken.sol

        zSTT = new ZivoeTrancheToken(
            'SeniorTrancheToken',
            'zSTT',
            address(god)
        );

        zJTT = new ZivoeTrancheToken(
            'JuniorTrancheToken',
            'zJTT',
            address(god)
        );

        // (5) Deploy ZivoeITO.sol

        ITO = new ZivoeITO(
            block.timestamp + 1000 seconds,
            block.timestamp + 5000 seconds,
            address(GBL)
        );

        // (5.5) Deploy ZivoeRET

        RET = new ZivoeRET(
            address(god),
            address(GBL)
        );

        // (6)  Transfer $ZVE from initial distributor to contract

        god.transferToken(address(ZVE), address(DAO), ZVE.totalSupply() / 2);       // 50% of $ZVE allocated to DAO
        god.transferToken(address(ZVE), address(ITO), ZVE.totalSupply() / 10);      // 10% of $ZVE allocated to ITO

        // (7) Give ZivoeITO.sol minterRole() status over zJTT and zSTT.

        god.try_changeMinterRole(address(zJTT), address(ITO), true);
        god.try_changeMinterRole(address(zSTT), address(ITO), true);

        // (9-11) Deploy staking contracts. 

        stSTT = new MultiRewards(
            address(zSTT),
            address(god),
            address(GBL)
        );

        stJTT = new MultiRewards(
            address(zJTT),
            address(god),
            address(GBL)
        );

        stZVE = new MultiRewards(
            address(ZVE),
            address(god),
            address(GBL)
        );

        // (12) Deploy ZivoeYDL

        YDL = new ZivoeYDL(
            address(gov),
            address(GBL)
        );

        // (13) Initialize vestZVE.

        vestZVE = new MultiRewardsVesting(
            address(ZVE),
            address(GBL)
        );

        // (14) Add rewards to MultiRewards.sol

        god.try_addReward(address(stSTT), FRAX, address(YDL), 1 days);
        god.try_addReward(address(stJTT), FRAX, address(YDL), 1 days);
        god.try_addReward(address(stZVE), FRAX, address(YDL), 1 days);

        god.try_addReward(address(stZVE), address(ZVE), address(YDL), 1 days);
        
        // god.try_addReward(address(stSTT), address(ZVE), address(YDL), 1 days);
        // god.try_addReward(address(stJTT), address(ZVE), address(YDL), 1 days);  // TODO: Double-check YDL distributor role, i.e. passThrough()
        
        // (15) Update the ZivoeGBL contract

        address[] memory _wallets = new address[](13);

        _wallets[0] = address(DAO);
        _wallets[1] = address(ITO);
        _wallets[2] = address(RET);
        _wallets[3] = address(stJTT);
        _wallets[4] = address(stSTT);
        _wallets[5] = address(stZVE);
        _wallets[6] = address(vestZVE);
        _wallets[7] = address(YDL);
        _wallets[8] = address(zJTT);
        _wallets[9] = address(zSTT);
        _wallets[10] = address(ZVE);
        _wallets[11] = address(god);    // ZVL
        _wallets[12] = address(gov);

        GBL.initializeGlobals(_wallets);

        // (16) Initialize the YDL.

        YDL.initialize();
        
        god.transferToken(address(ZVE), address(vestZVE), ZVE.totalSupply() * 4 / 10);  // 40% of $ZVE allocated to Vesting

        god.try_addReward(address(vestZVE), FRAX, address(YDL), 1 days);
        god.try_addReward(address(vestZVE), address(ZVE), address(YDL), 1 days);  // TODO: Double-check YDL distributor role, i.e. passThrough()

    }

    // Verify initial state of ZivoeITO.sol.

    function test_ZivoeITO_constructor() public {

        // Pre-state checks.
        assertEq(ITO.start(), block.timestamp + 1000 seconds);
        assertEq(ITO.end(), block.timestamp + 5000 seconds);
        assertEq(ITO.GBL(), address(GBL));

        assert(ITO.stablecoinWhitelist(0x6B175474E89094C44Da98b954EedeAC495271d0F));
        assert(ITO.stablecoinWhitelist(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
        assert(ITO.stablecoinWhitelist(0x853d955aCEf822Db058eb8505911ED77F175b99e));
        assert(ITO.stablecoinWhitelist(0xdAC17F958D2ee523a2206206994597C13D831ec7));
    }

    // Verify constructor restrictions ZivoeITO.sol.
    // Revert constructor() if _start >= _end.
    function testFail_ZivoeITO_constructor_0() public {
        ITO = new ZivoeITO(
            block.timestamp + 6000 seconds,
            block.timestamp + 5000 seconds,
            address(GBL)
        );
    }

    // ----------------
    // Junior Functions
    // ----------------

    // Verify depositJunior() restrictions.
    // Verify depositJunior() state changes.

    function test_ZivoeITO_depositJunior_restrictions() public {
        // Mint DAI for "bob".
        mint("DAI", address(bob), 100 ether);

        // Warp 1 second before the ITO starts
        hevm.warp(ITO.start() - 1 seconds);

        // Can't call depositJunior() when block.timestamp < start.
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(!bob.try_depositJunior(address(ITO), 100 ether, address(DAI)));

        // Warp to the end unix.
        hevm.warp(ITO.end());

        // Can't call depositJunior() when block.timestamp >= end.
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(!bob.try_depositJunior(address(ITO), 100 ether, address(DAI)));

        // Warp to the start unix, mint() WETH.
        hevm.warp(ITO.start());
        mint("WETH", address(bob), 1 ether);

        // Can't call depositJunior() when asset is not whitelisted.
        assert(bob.try_approveToken(WETH, address(ITO), 1 ether));
        assert(!bob.try_depositJunior(address(ITO), 1 ether, address(WETH)));
    }

    function test_ZivoeITO_depositJunior_state_changes() public {
        // Warp to the start unix.
        hevm.warp(ITO.start());

        // -------------------
        // DAI depositJunior()
        // -------------------
        mint("DAI", address(tom), 100 ether);

        // Pre-state checks.
        assertEq(ITO.juniorCredits(address(tom)), 0);
        assertEq(IERC20(address(DAI)).balanceOf(address(tom)), 100 ether);
        assertEq(IERC20(address(DAI)).balanceOf(address(ITO)), 0);
        assertEq(IERC20(address(zJTT)).balanceOf(address(ITO)), 0);

        // User "tom" deposits DAI into the junior tranche.
        assert(tom.try_approveToken(DAI, address(ITO), 100 ether));
        assert(tom.try_depositJunior(address(ITO), 100 ether, address(DAI)));

        // Post-state checks.
        assertEq(ITO.juniorCredits(address(tom)), 100 ether);
        assertEq(IERC20(address(DAI)).balanceOf(address(tom)), 0);
        assertEq(IERC20(address(DAI)).balanceOf(address(ITO)), 100 ether);
        assertEq(IERC20(address(zJTT)).balanceOf(address(ITO)), 100 ether);


        // --------------------
        // FRAX depositJunior()
        // --------------------
        mint("FRAX", address(tom), 100 ether);

        // Pre-state checks.
        assertEq(ITO.juniorCredits(address(tom)), 100 ether);
        assertEq(IERC20(address(FRAX)).balanceOf(address(tom)), 100 ether);
        assertEq(IERC20(address(FRAX)).balanceOf(address(ITO)), 0);
        assertEq(IERC20(address(zJTT)).balanceOf(address(ITO)), 100 ether);

        // User "tom" deposits FRAX into the junior tranche.
        assert(tom.try_approveToken(FRAX, address(ITO), 100 ether));
        assert(tom.try_depositJunior(address(ITO), 100 ether, address(FRAX)));

        // Post-state checks.
        assertEq(ITO.juniorCredits(address(tom)), 200 ether);
        assertEq(IERC20(address(FRAX)).balanceOf(address(tom)), 0);
        assertEq(IERC20(address(FRAX)).balanceOf(address(ITO)), 100 ether);
        assertEq(IERC20(address(zJTT)).balanceOf(address(ITO)), 200 ether);

        // --------------------
        // USDC depositJunior()
        // --------------------
        mint("USDC", address(tom), 100 * USD);

        // Pre-state checks.
        assertEq(ITO.juniorCredits(address(tom)), 200 ether);
        assertEq(IERC20(address(USDC)).balanceOf(address(tom)), 100 * USD);
        assertEq(IERC20(address(USDC)).balanceOf(address(ITO)), 0);
        assertEq(IERC20(address(zJTT)).balanceOf(address(ITO)), 200 ether);

        // User "tom" deposits USDC into the junior tranche.
        assert(tom.try_approveToken(USDC, address(ITO), 100 * USD));
        assert(tom.try_depositJunior(address(ITO), 100 * USD, address(USDC)));

        // Post-state checks.
        assertEq(ITO.juniorCredits(address(tom)), 300 ether);
        assertEq(IERC20(address(USDC)).balanceOf(address(tom)), 0);
        assertEq(IERC20(address(USDC)).balanceOf(address(ITO)), 100 * USD);
        assertEq(IERC20(address(zJTT)).balanceOf(address(ITO)), 300 ether);

        // --------------------
        // USDT depositJunior()
        // --------------------
        mint("USDT", address(tom), 100 * USD);

        // Pre-state checks.
        assertEq(ITO.juniorCredits(address(tom)), 300 ether);
        assertEq(IERC20(address(USDT)).balanceOf(address(tom)), 100 * USD);
        assertEq(IERC20(address(USDT)).balanceOf(address(ITO)), 0);
        assertEq(IERC20(address(zJTT)).balanceOf(address(ITO)), 300 ether);

        // User "tom" deposits USDT into the junior tranche.
        assert(tom.try_approveToken(USDT, address(ITO), 100 * USD));
        assert(tom.try_depositJunior(address(ITO), 100 * USD, address(USDT)));

        // Post-state checks.
        assertEq(ITO.juniorCredits(address(tom)), 400 ether);
        assertEq(IERC20(address(USDT)).balanceOf(address(tom)), 0);
        assertEq(IERC20(address(USDT)).balanceOf(address(ITO)), 100 * USD);
        assertEq(IERC20(address(zJTT)).balanceOf(address(ITO)), 400 ether);

    }

    // ----------------
    // Senior Functions
    // ----------------

    // Verify depositSenior() restrictions.
    // Verify depositSenior() state changes.

    function test_ZivoeITO_depositSenior_restrictions() public {

        // Mint DAI for "bob".
        mint("DAI", address(bob), 100 ether);

        // Warp 1 second before the ITO starts.
        hevm.warp(ITO.start() - 1 seconds);

        // Can't call depositSenior() when block.timestamp < start.
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(!bob.try_depositSenior(address(ITO), 100 ether, address(DAI)));

        // Warp to the end unix.
        hevm.warp(ITO.end());

        // Can't call depositSenior() when block.timestamp >= end.
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(!bob.try_depositSenior(address(ITO), 100 ether, address(DAI)));

        // Warp to the start unix, mint() WETH.
        hevm.warp(ITO.start());
        mint("WETH", address(bob), 1 ether);

        // Can't call depositSenior() when asset is not whitelisted.
        assert(bob.try_approveToken(WETH, address(ITO), 1 ether));
        assert(!bob.try_depositSenior(address(ITO), 1 ether, address(WETH)));
    }

    function test_ZivoeITO_depositSenior_state_changes() public {
        // Warp to the start unix.
        hevm.warp(ITO.start());

        // -------------------
        // DAI depositSenior()
        // -------------------
        mint("DAI", address(sam), 100 ether);

        // Pre-state checks.
        assertEq(ITO.seniorCredits(address(sam)), 0);
        assertEq(IERC20(address(DAI)).balanceOf(address(sam)), 100 ether);
        assertEq(IERC20(address(DAI)).balanceOf(address(ITO)), 0);
        assertEq(IERC20(address(zSTT)).balanceOf(address(ITO)), 0);

        // User "sam" deposits DAI into the senior tranche.
        assert(sam.try_approveToken(DAI, address(ITO), 100 ether));
        assert(sam.try_depositSenior(address(ITO), 100 ether, address(DAI)));

        // Post-state checks.
        assertEq(ITO.seniorCredits(address(sam)), 300 ether);
        assertEq(IERC20(address(DAI)).balanceOf(address(sam)), 0);
        assertEq(IERC20(address(DAI)).balanceOf(address(ITO)), 100 ether);
        assertEq(IERC20(address(zSTT)).balanceOf(address(ITO)), 100 ether);


        // --------------------
        // FRAX depositSenior()
        // --------------------
        mint("FRAX", address(sam), 100 ether);

        // Pre-state checks.
        assertEq(ITO.seniorCredits(address(sam)), 300 ether);
        assertEq(IERC20(address(FRAX)).balanceOf(address(sam)), 100 ether);
        assertEq(IERC20(address(FRAX)).balanceOf(address(ITO)), 0);
        assertEq(IERC20(address(zSTT)).balanceOf(address(ITO)), 100 ether);

        // User "sam" deposits FRAX into the senior tranche.
        assert(sam.try_approveToken(FRAX, address(ITO), 100 ether));
        assert(sam.try_depositSenior(address(ITO), 100 ether, address(FRAX)));

        // Post-state checks.
        assertEq(ITO.seniorCredits(address(sam)), 600 ether);
        assertEq(IERC20(address(FRAX)).balanceOf(address(sam)), 0);
        assertEq(IERC20(address(FRAX)).balanceOf(address(ITO)), 100 ether);
        assertEq(IERC20(address(zSTT)).balanceOf(address(ITO)), 200 ether);

        // --------------------
        // USDC depositSenior()
        // --------------------
        mint("USDC", address(sam), 100 * USD);

        // Pre-state checks.
        assertEq(ITO.seniorCredits(address(sam)), 600 ether);
        assertEq(IERC20(address(USDC)).balanceOf(address(sam)), 100 * USD);
        assertEq(IERC20(address(USDC)).balanceOf(address(ITO)), 0);
        assertEq(IERC20(address(zSTT)).balanceOf(address(ITO)), 200 ether);

        // User "sam" deposits USDC into the senior tranche.
        assert(sam.try_approveToken(USDC, address(ITO), 100 * USD));
        assert(sam.try_depositSenior(address(ITO), 100 * USD, address(USDC)));

        // Post-state checks.
        assertEq(ITO.seniorCredits(address(sam)), 900 ether);
        assertEq(IERC20(address(USDC)).balanceOf(address(sam)), 0);
        assertEq(IERC20(address(USDC)).balanceOf(address(ITO)), 100 * USD);
        assertEq(IERC20(address(zSTT)).balanceOf(address(ITO)), 300 ether);

        // --------------------
        // USDT depositSenior()
        // --------------------
        mint("USDT", address(sam), 100 * USD);

        // Pre-state checks.
        assertEq(ITO.seniorCredits(address(sam)), 900 ether);
        assertEq(IERC20(address(USDT)).balanceOf(address(sam)), 100 * USD);
        assertEq(IERC20(address(USDT)).balanceOf(address(ITO)), 0);
        assertEq(IERC20(address(zSTT)).balanceOf(address(ITO)), 300 ether);

        // User "sam" deposits USDT into the senior tranche.
        assert(sam.try_approveToken(USDT, address(ITO), 100 * USD));
        assert(sam.try_depositSenior(address(ITO), 100 * USD, address(USDT)));

        // Post-state checks.
        assertEq(ITO.seniorCredits(address(sam)), 1200 ether);
        assertEq(IERC20(address(USDT)).balanceOf(address(sam)), 0);
        assertEq(IERC20(address(USDT)).balanceOf(address(ITO)), 100 * USD);
        assertEq(IERC20(address(zSTT)).balanceOf(address(ITO)), 400 ether);

    }

    // Simulates deposits for a junior and a senior tranche depositor.

    function simulateDeposits(uint256 seniorDeposit, uint256 juniorDeposit) public {

        // Warp to ITO start unix.
        hevm.warp(ITO.start());

        // ------------------------
        // "sam" => depositSenior()
        // ------------------------

        mint("DAI",  address(sam), seniorDeposit * 1 ether);
        mint("FRAX", address(sam), seniorDeposit * 1 ether);
        mint("USDC", address(sam), seniorDeposit * USD);
        mint("USDT", address(sam), seniorDeposit * USD);

        assert(sam.try_approveToken(DAI,  address(ITO), seniorDeposit * 1 ether));
        assert(sam.try_approveToken(FRAX, address(ITO), seniorDeposit * 1 ether));
        assert(sam.try_approveToken(USDC, address(ITO), seniorDeposit * USD));
        assert(sam.try_approveToken(USDT, address(ITO), seniorDeposit * USD));

        assert(sam.try_depositSenior(address(ITO), seniorDeposit * 1 ether, address(DAI)));
        assert(sam.try_depositSenior(address(ITO), seniorDeposit * 1 ether, address(FRAX)));
        assert(sam.try_depositSenior(address(ITO), seniorDeposit * USD, address(USDC)));
        assert(sam.try_depositSenior(address(ITO), seniorDeposit * USD, address(USDT)));

        // ------------------------
        // "tom" => depositJunior()
        // ------------------------

        mint("DAI",  address(tom), juniorDeposit * 1 ether);
        mint("FRAX", address(tom), juniorDeposit * 1 ether);
        mint("USDC", address(tom), juniorDeposit * USD);
        mint("USDT", address(tom), juniorDeposit * USD);

        assert(tom.try_approveToken(DAI,  address(ITO), juniorDeposit * 1 ether));
        assert(tom.try_approveToken(FRAX, address(ITO), juniorDeposit * 1 ether));
        assert(tom.try_approveToken(USDC, address(ITO), juniorDeposit * USD));
        assert(tom.try_approveToken(USDT, address(ITO), juniorDeposit * USD));

        assert(tom.try_depositJunior(address(ITO), juniorDeposit * 1 ether, address(DAI)));
        assert(tom.try_depositJunior(address(ITO), juniorDeposit * 1 ether, address(FRAX)));
        assert(tom.try_depositJunior(address(ITO), juniorDeposit * USD, address(USDC)));
        assert(tom.try_depositJunior(address(ITO), juniorDeposit * USD, address(USDT)));
    }


    // Verify claim() restrictions.
    // Verify claim() state changes.
 
    function test_ZivoeITO_claim_restrictions() public {

        // Simulate deposits, 4mm Senior / 2mm Junior (4x input amount).
        simulateDeposits(1000000, 500000);
        
        // Warp to the end unix.
        hevm.warp(ITO.end());

        // Can't call claim() until block.timestamp > end.
        assert(!sam.try_claim(address(ITO)));
        assert(!tom.try_claim(address(ITO)));
 
        // Warp to end.
        hevm.warp(ITO.end() + 1);

        // Can't call claim() if seniorCredits == 0 && juniorCredits == 0.
        assert(!bob.try_claim(address(ITO)));
    }

    function test_ZivoeITO_claim_state_changes() public {

        // Simulate deposits, 5mm Senior / 4mm Junior (4x input amount).
        simulateDeposits(1250000, 1000000);

        // Warp to the end unix + 1 second (can only call claim() after end unix).
        hevm.warp(ITO.end() + 1);


        // ----------------
        // "sam" => claim()
        // ----------------

        // Pre-state check.
        assertEq(ITO.seniorCredits(address(sam)), 1250000 * 4 * 3 ether);
        assertEq(ITO.juniorCredits(address(sam)), 0);
        assertEq(zSTT.balanceOf(address(ITO)), 5000000 ether);
        assertEq(zSTT.balanceOf(address(sam)), 0);
        assertEq(ZVE.balanceOf(address(ITO)), 2500000 ether);
        assertEq(ZVE.balanceOf(address(sam)), 0);

        (uint256 _zSTT_SAM,, uint256 _ZVE_SAM) = sam.write_claim(address(ITO));

        // Post-state check.
        assertEq(ITO.seniorCredits(address(sam)), 0);
        assertEq(ITO.juniorCredits(address(sam)), 0);
        assertEq(zSTT.balanceOf(address(ITO)), 0);
        assertEq(zSTT.balanceOf(address(sam)), _zSTT_SAM);
        assertEq(ZVE.balanceOf(address(ITO)), 2500000 ether - _ZVE_SAM);
        assertEq(ZVE.balanceOf(address(sam)), _ZVE_SAM);

        // ----------------
        // "tom" => claim()
        // ----------------

        // Pre-state check.
        assertEq(ITO.seniorCredits(address(tom)), 0);
        assertEq(ITO.juniorCredits(address(tom)), 1000000 * 4 ether);
        assertEq(zJTT.balanceOf(address(ITO)), 4000000 ether);
        assertEq(zJTT.balanceOf(address(tom)), 0);
        assertEq(ZVE.balanceOf(address(ITO)), 2500000 ether - _ZVE_SAM);
        assertEq(ZVE.balanceOf(address(tom)), 0);

        (,uint256 _zJTT_TOM, uint256 _ZVE_TOM) = tom.write_claim(address(ITO));

        // Post-state check.
        assertEq(ITO.seniorCredits(address(tom)), 0);
        assertEq(ITO.juniorCredits(address(tom)), 0);
        assertEq(zJTT.balanceOf(address(ITO)), 0);
        assertEq(zJTT.balanceOf(address(tom)), _zJTT_TOM);
        assertEq(ZVE.balanceOf(address(ITO)), 2500000 ether - _ZVE_SAM - _ZVE_TOM);
        assertEq(ZVE.balanceOf(address(tom)), _ZVE_TOM);

        // Should verify migrateDeposits() can work within this context as well.
        ITO.migrateDeposits();
        
    }

    // TODO: Simulate a multi-tranche investor and call claim().

    // Verify migrateDeposits() restrictions.
    // Verify migrateDeposits() state changes.

    function test_ZivoeITO_migrateDeposits_restrictions() public {

        // Simulate deposits, 5mm Senior / 4mm Junior (4x input amount).
        simulateDeposits(1250000, 1000000);

        // Warp to the end unix (second before migrateDeposits() window opens).
        hevm.warp(ITO.end());

        // Can't call migrateDeposits() until block.timestamp > end.
        assert(!bob.try_migrateDeposits(address(ITO)));
    }

    function test_ZivoeITO_migrateDeposits_state_changes() public {
        
        // Simulate deposits, 5mm Senior / 4mm Junior (4x input amount).
        simulateDeposits(1250000, 1000000);

        // Warp to the end unix + 1 second.
        hevm.warp(ITO.end() + 1);

        // Pre-state check.
        assertEq(IERC20(address(DAI)).balanceOf(address(ITO)),  2250000 ether);
        assertEq(IERC20(address(FRAX)).balanceOf(address(ITO)), 2250000 ether);
        assertEq(IERC20(address(USDC)).balanceOf(address(ITO)), 2250000 * USD);
        assertEq(IERC20(address(USDT)).balanceOf(address(ITO)), 2250000 * USD);
        assertEq(IERC20(address(DAI)).balanceOf(address(DAO)),  0);
        assertEq(IERC20(address(FRAX)).balanceOf(address(DAO)), 0);
        assertEq(IERC20(address(USDC)).balanceOf(address(DAO)), 0);
        assertEq(IERC20(address(USDT)).balanceOf(address(DAO)), 0);

        // Migrate deposits.
        assert(bob.try_migrateDeposits(address(ITO)));

        // Post-state check.
        assertEq(IERC20(address(DAI)).balanceOf(address(ITO)),  0);
        assertEq(IERC20(address(FRAX)).balanceOf(address(ITO)), 0);
        assertEq(IERC20(address(USDC)).balanceOf(address(ITO)), 0);
        assertEq(IERC20(address(USDT)).balanceOf(address(ITO)), 0);
        assertEq(IERC20(address(DAI)).balanceOf(address(DAO)),  2250000 ether);
        assertEq(IERC20(address(FRAX)).balanceOf(address(DAO)), 2250000 ether);
        assertEq(IERC20(address(USDC)).balanceOf(address(DAO)), 2250000 * USD);
        assertEq(IERC20(address(USDT)).balanceOf(address(DAO)), 2250000 * USD);
    }
}
