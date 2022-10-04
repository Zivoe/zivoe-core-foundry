// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeITO is Utility {

    function setUp() public {
        // Note: Initial state of ZivoeITO.sol is validated in Test_DeployCore.sol.
        deployCore(false);
    }


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
    // Includes:
    //   - Restricting deposits until the ITO commences.
    //   - Restricting deposits after the ITO concludes.
    //   - Restricting deposits of non-whitelisted assets.

    function xtest_ZivoeITO_depositJunior_restrictions() public {
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

    function xtest_ZivoeITO_depositJunior_state_changes() public {
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

    function xtest_ZivoeITO_depositSenior_restrictions() public {

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

    function xtest_ZivoeITO_depositSenior_state_changes() public {
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

    function simulateDeposits(
        uint256 seniorDeposit, 
        TrancheLiquidityProvider seniorDepositor, 
        uint256 juniorDeposit,
        TrancheLiquidityProvider juniorDepositor
    ) public {

        // Warp to ITO start unix.
        hevm.warp(ITO.start());

        // ----------------------------------
        // seniorDepositor => depositSenior()
        // ----------------------------------

        mint("DAI",  address(seniorDepositor), seniorDeposit * 1 ether);
        mint("FRAX", address(seniorDepositor), seniorDeposit * 1 ether);
        mint("USDC", address(seniorDepositor), seniorDeposit * USD);
        mint("USDT", address(seniorDepositor), seniorDeposit * USD);

        assert(seniorDepositor.try_approveToken(DAI,  address(ITO), seniorDeposit * 1 ether));
        assert(seniorDepositor.try_approveToken(FRAX, address(ITO), seniorDeposit * 1 ether));
        assert(seniorDepositor.try_approveToken(USDC, address(ITO), seniorDeposit * USD));
        assert(seniorDepositor.try_approveToken(USDT, address(ITO), seniorDeposit * USD));

        assert(seniorDepositor.try_depositSenior(address(ITO), seniorDeposit * 1 ether, address(DAI)));
        assert(seniorDepositor.try_depositSenior(address(ITO), seniorDeposit * 1 ether, address(FRAX)));
        assert(seniorDepositor.try_depositSenior(address(ITO), seniorDeposit * USD, address(USDC)));
        assert(seniorDepositor.try_depositSenior(address(ITO), seniorDeposit * USD, address(USDT)));

        // ------------------------
        // juniorDepositor => depositJunior()
        // ------------------------

        mint("DAI",  address(juniorDepositor), juniorDeposit * 1 ether);
        mint("FRAX", address(juniorDepositor), juniorDeposit * 1 ether);
        mint("USDC", address(juniorDepositor), juniorDeposit * USD);
        mint("USDT", address(juniorDepositor), juniorDeposit * USD);

        assert(juniorDepositor.try_approveToken(DAI,  address(ITO), juniorDeposit * 1 ether));
        assert(juniorDepositor.try_approveToken(FRAX, address(ITO), juniorDeposit * 1 ether));
        assert(juniorDepositor.try_approveToken(USDC, address(ITO), juniorDeposit * USD));
        assert(juniorDepositor.try_approveToken(USDT, address(ITO), juniorDeposit * USD));

        assert(juniorDepositor.try_depositJunior(address(ITO), juniorDeposit * 1 ether, address(DAI)));
        assert(juniorDepositor.try_depositJunior(address(ITO), juniorDeposit * 1 ether, address(FRAX)));
        assert(juniorDepositor.try_depositJunior(address(ITO), juniorDeposit * USD, address(USDC)));
        assert(juniorDepositor.try_depositJunior(address(ITO), juniorDeposit * USD, address(USDT)));
    }


    // Verify claim() restrictions.
    // Verify claim() state changes.
 
    function xtest_ZivoeITO_claim_restrictions() public {

        // Simulate deposits, 4mm Senior / 2mm Junior (4x input amount).
        simulateDeposits(1000000, tom, 500000, sam);
        
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

    function xtest_ZivoeITO_claim_state_changes() public {

        // Simulate deposits, 5mm Senior / 4mm Junior (4x input amount).
        simulateDeposits(1250000, sam, 1000000, tom);

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

        (uint256 _zSTT_SAM,, uint256 _ZVE_SAM) = sam.claimAidrop(address(ITO));

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

        (,uint256 _zJTT_TOM, uint256 _ZVE_TOM) = tom.claimAidrop(address(ITO));

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

    function xtest_ZivoeITO_claim_state_changes_multiTrancheInvestor() public {

        // Simulate deposits.
        simulateDeposits(1_000_000, sam, 100_000, tom);
        simulateDeposits(2_000_000, tom, 50_000, sam);

        // Warp to the end unix + 1 second (can only call claim() after end unix).
        hevm.warp(ITO.end() + 1);


        // ----------------
        // "sam" => claim()
        // ----------------
        // Pre-state check.
        assertEq(ITO.seniorCredits(address(sam)), 1_000_000 * 4 * 3 ether);
        assertEq(ITO.juniorCredits(address(sam)),    50_000 * 4 * 1 ether);
        assertEq(zSTT.balanceOf(address(sam)),                          0);
        assertEq(zJTT.balanceOf(address(sam)),                          0);
        assertEq(ZVE.balanceOf(address(sam)),                           0);

        assertEq(zSTT.balanceOf(address(ITO)),        3_000_000 * 4 ether);
        assertEq(zJTT.balanceOf(address(ITO)),          150_000 * 4 ether);
        assertEq(ZVE.balanceOf(address(ITO)),             2_500_000 ether);

        (uint256 _zSTT_SAM, uint256 _zJTT_SAM, uint256 _ZVE_SAM) = sam.claimAidrop(address(ITO));

        // Post-state check.
        assertEq(ITO.seniorCredits(address(sam)),                       0);
        assertEq(ITO.juniorCredits(address(sam)),                       0);
        assertEq(zSTT.balanceOf(address(sam)),                  _zSTT_SAM);
        assertEq(zJTT.balanceOf(address(sam)),                  _zJTT_SAM);
        assertEq(ZVE.balanceOf(address(sam)),                    _ZVE_SAM);

        assertEq(zSTT.balanceOf(address(ITO)),        2_000_000 * 4 ether);
        assertEq(zJTT.balanceOf(address(ITO)),          100_000 * 4 ether);
        assertEq(ZVE.balanceOf(address(ITO)),    2500000 ether - _ZVE_SAM);

        // ----------------
        // "tom" => claim()
        // ----------------

        assertEq(ITO.seniorCredits(address(tom)), 2_000_000 * 4 * 3 ether);
        assertEq(ITO.juniorCredits(address(tom)),   100_000 * 4 * 1 ether);
        assertEq(zSTT.balanceOf(address(tom)),                          0);
        assertEq(zJTT.balanceOf(address(tom)),                          0);
        assertEq(ZVE.balanceOf(address(tom)),                           0);

        assertEq(zSTT.balanceOf(address(ITO)),        2_000_000 * 4 ether);
        assertEq(zJTT.balanceOf(address(ITO)),          100_000 * 4 ether);
        assertEq(ZVE.balanceOf(address(ITO)),    2500000 ether - _ZVE_SAM);

        (uint256 _zSTT_TOM, uint256 _zJTT_TOM, uint256 _ZVE_TOM) = tom.claimAidrop(address(ITO));

        // Post-state check.
        assertEq(ITO.seniorCredits(address(tom)),                       0);
        assertEq(ITO.juniorCredits(address(tom)),                       0);
        assertEq(zSTT.balanceOf(address(tom)),                  _zSTT_TOM);
        assertEq(zJTT.balanceOf(address(tom)),                  _zJTT_TOM);
        assertEq(ZVE.balanceOf(address(tom)),                    _ZVE_TOM);

        assertEq(zSTT.balanceOf(address(ITO)),                                     0);
        assertEq(zJTT.balanceOf(address(ITO)),                                     0);
        assertEq(ZVE.balanceOf(address(ITO)),    2500000 ether - _ZVE_SAM - _ZVE_TOM);

        // Should verify migrateDeposits() can work within this context as well.
        ITO.migrateDeposits();
        
    }

    // Verify migrateDeposits() restrictions.
    // Verify migrateDeposits() state changes.

    function xtest_ZivoeITO_migrateDeposits_restrictions() public {

        // Simulate deposits, 5mm Senior / 4mm Junior (4x input amount).
        simulateDeposits(1250000, tom, 1000000, sam);

        // Warp to the end unix (second before migrateDeposits() window opens).
        hevm.warp(ITO.end());

        // Can't call migrateDeposits() until block.timestamp > end.
        assert(!bob.try_migrateDeposits(address(ITO)));
    }

    function xtest_ZivoeITO_migrateDeposits_state_changes() public {
        
        // Simulate deposits, 5mm Senior / 4mm Junior (4x input amount).
        simulateDeposits(1250000, tom, 1000000, sam);

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
