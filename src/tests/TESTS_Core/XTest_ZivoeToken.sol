// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeToken is Utility {

    function setUp() public {

        // Run initial setup functions.
        createActors();
        setUpTokens();

        GBL = new ZivoeGlobals();

        ZVE = new ZivoeToken(
            "Zivoe",
            "ZVE",
            address(god),
            address(GBL)
        );

        DAO = new ZivoeDAO(address(GBL));
        DAO.transferOwnership(address(god));

        zSTT = new ZivoeTrancheToken(
            "Zivoe Senior Tranche",
            "zSTT"
        );

        zJTT = new ZivoeTrancheToken(
            "Zivoe Junior Tranche",
            "zJTT"
        );

        zSTT.transferOwnership(address(god));
        zJTT.transferOwnership(address(god));

        ITO = new ZivoeITO(
            block.timestamp + 1000 seconds,
            block.timestamp + 5000 seconds,
            address(GBL)
        );

        stSTT = new ZivoeRewards(
            address(zSTT),
            address(GBL)

        );

        stJTT = new ZivoeRewards(
            address(zJTT),
            address(GBL)

        );

        stZVE = new ZivoeRewards(
            address(ZVE),
            address(GBL)
        );

        YDL = new ZivoeYDL(
            address(GBL),
            FRAX
        );

        YDL.transferOwnership(address(god));

        vestZVE = new ZivoeRewardsVesting(
            address(ZVE),
            address(GBL)
        );

        // Deploy ZivoeTranches.sol

        ZVT = new ZivoeTranches(
            address(GBL)
        );

        ZVT.transferOwnership(address(DAO));

        address[] memory _wallets = new address[](14);

        _wallets[0] = address(DAO);
        _wallets[1] = address(ITO);
        _wallets[2] = address(stJTT);
        _wallets[3] = address(stSTT);
        _wallets[4] = address(stZVE);
        _wallets[5] = address(vestZVE);
        _wallets[6] = address(YDL);
        _wallets[7] = address(zJTT);
        _wallets[8] = address(zSTT);
        _wallets[9] = address(ZVE);
        _wallets[10] = address(god);
        _wallets[11] = address(god);
        _wallets[12] = address(0);
        _wallets[13] = address(ZVT);

        GBL.initializeGlobals(_wallets);

        assert(god.try_changeMinterRole(address(zJTT), address(ZVT), true));
        assert(god.try_changeMinterRole(address(zSTT), address(ZVT), true));

        // Whitelist ZVT locker to DAO.
        assert(god.try_updateIsLocker(address(GBL), address(ZVT), true));

    }

    // Verify initial state of ZivoeToken.sol.

    function xtest_ZivoeToken_constructor() public {

        // Pre-state checks.
        assertEq(ZVE.name(), "Zivoe");
        assertEq(ZVE.symbol(), "ZVE");
        assertEq(ZVE.decimals(), 18);
        assertEq(ZVE.totalSupply(), 25000000 ether);
        assertEq(ZVE.balanceOf(address(god)), 25000000 ether);
    }


    // Verify transfer() restrictions.
    // Verify transfer() state changes.

    function xtest_ZivoeToken_transfer_restrictions() public {

        // Can't transfer to address(0).
        assert(!god.try_transferToken(address(ZVE), address(0), 100));

        // Can't transfer more than balance.
        assert(!god.try_transferToken(address(ZVE), address(1), 100000000 ether));

        // Currently CAN transfer 0 tokens.
        assert(god.try_transferToken(address(ZVE), address(1), 0));
    }

    function xtest_ZivoeToken_transfer_state_changes() public {

        // Pre-state check.
        uint preBal_god = ZVE.balanceOf(address(god));
        uint preBal_tom = ZVE.balanceOf(address(jim));

        // Transfer 100 tokens.
        assert(god.try_transferToken(address(ZVE), address(jim), 100));

        // Post-state check.
        uint postBal_god = ZVE.balanceOf(address(god));
        uint postBal_tom = ZVE.balanceOf(address(jim));
        assertEq(preBal_god - postBal_god, 100);
        assertEq(postBal_tom - preBal_tom, 100);
    }

    // Verify approve() state changes.
    // Verify approve() restrictions.

    function xtest_ZivoeToken_approve_state_changes() public {
        // Pre-state check.
        assertEq(ZVE.allowance(address(god), address(this)), 0);

        // Increase to 100 ether.
        assert(god.try_approveToken(address(ZVE), address(this), 100 ether));
        assertEq(ZVE.allowance(address(god), address(this)), 100 ether);

        // Reduce to 0.
        assert(god.try_approveToken(address(ZVE), address(this), 0));
        assertEq(ZVE.allowance(address(god), address(this)), 0);
    }

    function xtest_ZivoeToken_approve_restrictions() public {
        // Can't approve address(0).
        assert(!bob.try_approveToken(address(ZVE), address(0), 100 ether));
    }

    // Verify transferFrom() state changes.
    // Verify transferFrom() restrictions.

    function xtest_ZivoeToken_transferFrom_state_changes() public {

        // Increase allowance of this contract to 100 ether.
        assert(god.try_approveToken(address(ZVE), address(this), 100 ether));
    
        // Pre-state check.
        assertEq(ZVE.balanceOf(address(this)), 0);
        assertEq(ZVE.allowance(address(god), address(this)), 100 ether);

        // Transfer 50 $ZVE.
        ZVE.transferFrom(address(god), address(this), 50 ether);

        // Post-state check.
        assertEq(ZVE.balanceOf(address(this)), 50 ether);
        assertEq(ZVE.allowance(address(god), address(this)), 50 ether);
        
        // Transfer 50 more $ZVE.
        ZVE.transferFrom(address(god), address(this), 50 ether);

        // Post-state check.
        assertEq(ZVE.balanceOf(address(this)), 100 ether);
        assertEq(ZVE.allowance(address(god), address(this)), 0);
    }

    function xtest_ZivoeToken_transferFrom_restrictions() public {
        
        // Approve "bob" to transfer 100 $ZVE.
        assert(god.try_approveToken(address(ZVE), address(bob), 100 ether));

        // Can't transfer more than allowance (110 $ZVE vs. 100 $ZVE).
        assert(!bob.try_transferFromToken(address(ZVE), address(god), address(bob), 110 ether));
    }

    // Verify increaseAllowance() state changes.
    // NOTE: No restrictions on increaseAllowance().

    function xtest_ZivoeToken_increaseAllowance_state_changes() public {
        
        // Pre-state allowance check, for "jim" controlling "this".
        assertEq(ZVE.allowance(address(this), address(jim)), 0);

        // Increase allowance for "jim" controlling "this" by 10 ether (10 $ZVE).
        ZVE.increaseAllowance(address(jim), 10 ether);

        // Post-state check.
        assertEq(ZVE.allowance(address(this), address(jim)), 10 ether);
    }

    // Verify decreaseAllowance() state changes.
    // Verify decreaseAllowance() restrictions.
    
    function xtest_ZivoeToken_decreaseAllowance_state_changes() public {
        
        // Increase allowance for "god" controlling "this" by 100 ether (100 $ZVE).
        ZVE.increaseAllowance(address(god), 100 ether);

        // Post-state check.
        assertEq(ZVE.allowance(address(this), address(god)), 100 ether);

        // Decrease allowance for "god" controlling "this" by 50 ether (50 $ZVE).
        ZVE.decreaseAllowance(address(god), 50 ether);
        
        // Post-state check.
        assertEq(ZVE.allowance(address(this), address(god)), 50 ether);

        // Decrease allowance for "god" controlling "this" by 50 ether (50 $ZVE).
        ZVE.decreaseAllowance(address(god), 50 ether);

        // Post-state check.
        assertEq(ZVE.allowance(address(this), address(god)), 0);
    }
    
    function xtest_ZivoeToken_decreaseAllowance_restrictions() public {
        
        // Increase allowance for "bob" controlling "jim" by 100 ether (100 $ZVE).
        assert(bob.try_increaseAllowance(address(ZVE), address(jim), 100 ether));

        // Can't decreaseAllowance() more than current allowance (sub-zero / underflow).
        assert(!bob.try_decreaseAllowance(address(ZVE), address(jim), 105 ether));
    }

    // Verify burn() state changes.
    // Verify burn() restrictions.

    function xtest_ZivoeToken_burn_state_changes() public {
        
        // Pre-state check.
        assertEq(ZVE.totalSupply(),           25000000 ether);
        assertEq(ZVE.balanceOf(address(god)), 25000000 ether);

        // User "god" will burn 1000 $ZVE.
        assert(god.try_burn(address(ZVE), 1000 ether));

        // Post-state check.
        assertEq(ZVE.totalSupply(),           25000000 ether - 1000 ether);
        assertEq(ZVE.balanceOf(address(god)), 25000000 ether - 1000 ether);

    }

    function xtest_ZivoeToken_burn_restrictions() public {
        
        // Can't burn more than balance, "god" owns all 25,000,000 $ZVE.
        assert(!god.try_burn(address(ZVE), 25000005 ether));
    }

}