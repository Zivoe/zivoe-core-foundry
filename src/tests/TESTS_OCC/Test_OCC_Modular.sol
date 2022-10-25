// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCC/OCC_Modular.sol";

contract Test_OCC_Modular is Utility {

    OCC_Modular OCC_Modular_DAI;
    OCC_Modular OCC_Modular_FRAX;
    OCC_Modular OCC_Modular_USDC;
    OCC_Modular OCC_Modular_USDT;

    function setUp() public {

        deployCore(false);

        // Initialize and whitelist OCC_Modular lockers.
        OCC_Modular_DAI = new OCC_Modular(address(DAO), address(DAI), address(GBL), address(roy));
        OCC_Modular_FRAX = new OCC_Modular(address(DAO), address(FRAX), address(GBL), address(roy));
        OCC_Modular_USDC = new OCC_Modular(address(DAO), address(USDC), address(GBL), address(roy));
        OCC_Modular_USDT = new OCC_Modular(address(DAO), address(USDT), address(GBL), address(roy));

        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_DAI), true);
        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_FRAX), true);
        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_USDC), true);
        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_USDT), true);

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function tim_requestRandomLoan(uint96 random, bool choice, address asset) internal returns (uint256 loanID) {
        
        uint32[5] memory paymentInterval = [86400 * 7.5, 86400 * 15, 86400 * 30, 86400 * 90, 86400 * 360];

        uint256 borrowAmount = uint256(random);
        uint256 APR = uint256(random) % 3601;
        uint256 APRLateFee = uint256(random) % 3601;
        uint256 term = uint256(random) % 25 + 1;
        uint256 gracePeriod = uint256(random) % 90 days;
        uint256 option = uint256(random) % 5;
        int8 paymentSchedule = choice ? int8(0) : int8(1);

        if (asset == DAI) {
            loanID = OCC_Modular_DAI.counterID();
            assert(tim.try_requestLoan(
                address(OCC_Modular_DAI),
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(paymentInterval[option]),
                gracePeriod,
                paymentSchedule
            ));
        }

        else if (asset == FRAX) {
            loanID = OCC_Modular_FRAX.counterID();
            assert(tim.try_requestLoan(
                address(OCC_Modular_FRAX),
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(paymentInterval[option]),
                gracePeriod,
                paymentSchedule
            ));
        }

        else if (asset == USDC) {
            loanID = OCC_Modular_USDC.counterID();
            assert(tim.try_requestLoan(
                address(OCC_Modular_USDC),
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(paymentInterval[option]),
                gracePeriod,
                paymentSchedule
            ));
        }

        else if (asset == USDT) {
            loanID = OCC_Modular_USDT.counterID();
            assert(tim.try_requestLoan(
                address(OCC_Modular_USDT),
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(paymentInterval[option]),
                gracePeriod,
                paymentSchedule
            ));
        }

        else { revert(); }

    }

    function man_fundLoan(uint256 loanID, address asset) public {

        if (asset == DAI) {
            assert(roy.try_fundLoan(address(OCC_Modular_DAI), loanID));
        }

        else if (asset == FRAX) {
            assert(roy.try_fundLoan(address(OCC_Modular_FRAX), loanID));
        }

        else if (asset == USDC) {
            assert(roy.try_fundLoan(address(OCC_Modular_USDC), loanID));
        }

        else if (asset == USDT) {
            assert(roy.try_fundLoan(address(OCC_Modular_USDT), loanID));
        }

        else { revert(); }

    }

    function simulateITO_and_requestLoans(
        uint96 random, bool choice
    ) public returns (
        uint256 _loanID_DAI, 
        uint256 _loanID_FRAX, 
        uint256 _loanID_USDC, 
        uint256 _loanID_USDT 
    ) {

        uint256 amt = uint256(random);

        simulateITO(amt * WAD, amt * WAD, amt * USD, amt * USD);

        assert(god.try_push(address(DAO), address(OCC_Modular_DAI), DAI, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_FRAX), FRAX, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDC), USDC, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDT), USDT, amt));

        _loanID_DAI = tim_requestRandomLoan(random, choice, DAI);
        _loanID_FRAX = tim_requestRandomLoan(random, choice, FRAX);
        _loanID_USDC = tim_requestRandomLoan(random, choice, USDC);
        _loanID_USDT = tim_requestRandomLoan(random, choice, USDT);

    }

    function simulateITO_and_requestLoans_and_fundLoans(
        uint96 random, bool choice
    ) public returns (
        uint256 _loanID_DAI, 
        uint256 _loanID_FRAX, 
        uint256 _loanID_USDC, 
        uint256 _loanID_USDT 
    ) {

        uint256 amt = uint256(random);

        simulateITO(amt * WAD, amt * WAD, amt * USD, amt * USD);

        assert(god.try_push(address(DAO), address(OCC_Modular_DAI), DAI, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_FRAX), FRAX, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDC), USDC, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDT), USDT, amt));

        _loanID_DAI = tim_requestRandomLoan(random, choice, DAI);
        _loanID_FRAX = tim_requestRandomLoan(random, choice, FRAX);
        _loanID_USDC = tim_requestRandomLoan(random, choice, USDC);
        _loanID_USDT = tim_requestRandomLoan(random, choice, USDT);

        assert(roy.try_fundLoan(address(OCC_Modular_DAI), _loanID_DAI));
        assert(roy.try_fundLoan(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(roy.try_fundLoan(address(OCC_Modular_USDC), _loanID_USDC));
        assert(roy.try_fundLoan(address(OCC_Modular_USDT), _loanID_USDT));

        // Mint borrower tokens for paying interest, or other purposes.
        mint("DAI", address(tim), MAX_UINT / 2);
        mint("FRAX", address(tim), MAX_UINT / 2);
        mint("USDC", address(tim), MAX_UINT / 2);
        mint("USDT", address(tim), MAX_UINT / 2);

        // Handle pre-approvals here for future convenience.
        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), MAX_UINT / 2));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), MAX_UINT / 2));

    }

    function requestLoans_and_fundLoans(
        uint96 random, bool choice
    ) public returns (
        uint256 _loanID_DAI, 
        uint256 _loanID_FRAX, 
        uint256 _loanID_USDC, 
        uint256 _loanID_USDT 
    ) {

        _loanID_DAI = tim_requestRandomLoan(random, choice, DAI);
        _loanID_FRAX = tim_requestRandomLoan(random, choice, FRAX);
        _loanID_USDC = tim_requestRandomLoan(random, choice, USDC);
        _loanID_USDT = tim_requestRandomLoan(random, choice, USDT);

        assert(roy.try_fundLoan(address(OCC_Modular_DAI), _loanID_DAI));
        assert(roy.try_fundLoan(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(roy.try_fundLoan(address(OCC_Modular_USDC), _loanID_USDC));
        assert(roy.try_fundLoan(address(OCC_Modular_USDT), _loanID_USDT));

        // Mint borrower tokens for paying interest, or other purposes.
        mint("DAI", address(tim), MAX_UINT / 2);
        mint("FRAX", address(tim), MAX_UINT / 2);
        mint("USDC", address(tim), MAX_UINT / 2);
        mint("USDT", address(tim), MAX_UINT / 2);

        // Handle pre-approvals here for future convenience.
        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), MAX_UINT / 2));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), MAX_UINT / 2));

    }

    function simulateITO_and_requestLoans_and_fundLoans_and_defaultLoans(
        uint96 random, bool choice
    ) public returns (
        uint256 _loanID_DAI, 
        uint256 _loanID_FRAX, 
        uint256 _loanID_USDC, 
        uint256 _loanID_USDT 
    ) {

        uint256 amt = uint256(random);

        simulateITO(amt * WAD, amt * WAD, amt * USD, amt * USD);

        assert(god.try_push(address(DAO), address(OCC_Modular_DAI), DAI, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_FRAX), FRAX, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDC), USDC, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDT), USDT, amt));

        _loanID_DAI = tim_requestRandomLoan(random, choice, DAI);
        _loanID_FRAX = tim_requestRandomLoan(random, choice, FRAX);
        _loanID_USDC = tim_requestRandomLoan(random, choice, USDC);
        _loanID_USDT = tim_requestRandomLoan(random, choice, USDT);

        assert(roy.try_fundLoan(address(OCC_Modular_DAI), _loanID_DAI));
        assert(roy.try_fundLoan(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(roy.try_fundLoan(address(OCC_Modular_USDC), _loanID_USDC));
        assert(roy.try_fundLoan(address(OCC_Modular_USDT), _loanID_USDT));

        // Mint borrower tokens for paying interest, or other purposes.
        mint("DAI", address(tim), MAX_UINT / 2);
        mint("FRAX", address(tim), MAX_UINT / 2);
        mint("USDC", address(tim), MAX_UINT / 2);
        mint("USDT", address(tim), MAX_UINT / 2);

        // Handle pre-approvals here for future convenience.
        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), MAX_UINT / 2));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), MAX_UINT / 2));

        (,, uint256[10] memory loanInfo_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory loanInfo_FRAX) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory loanInfo_USDC) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory loanInfo_USDT) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        hevm.warp(loanInfo_DAI[3] + loanInfo_DAI[8] + 1 seconds);
        OCC_Modular_DAI.markDefault(_loanID_DAI);

        hevm.warp(loanInfo_FRAX[3] + loanInfo_FRAX[8] + 1 seconds);
        OCC_Modular_FRAX.markDefault(_loanID_FRAX);
        
        hevm.warp(loanInfo_USDC[3] + loanInfo_USDC[8] + 1 seconds);
        OCC_Modular_USDC.markDefault(_loanID_USDC);
        
        hevm.warp(loanInfo_USDT[3] + loanInfo_USDT[8] + 1 seconds);
        OCC_Modular_USDT.markDefault(_loanID_USDT);

    }

    function simulateITO_and_requestLoans_and_fundLoans_and_defaultLoans_and_resolveLoans(
        uint96 random, bool choice
    ) public returns (
        uint256 _loanID_DAI, 
        uint256 _loanID_FRAX, 
        uint256 _loanID_USDC, 
        uint256 _loanID_USDT 
    ) {

        uint256 amt = uint256(random);

        simulateITO(amt * WAD, amt * WAD, amt * USD, amt * USD);

        assert(god.try_push(address(DAO), address(OCC_Modular_DAI), DAI, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_FRAX), FRAX, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDC), USDC, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDT), USDT, amt));

        _loanID_DAI = tim_requestRandomLoan(random, choice, DAI);
        _loanID_FRAX = tim_requestRandomLoan(random, choice, FRAX);
        _loanID_USDC = tim_requestRandomLoan(random, choice, USDC);
        _loanID_USDT = tim_requestRandomLoan(random, choice, USDT);

        assert(roy.try_fundLoan(address(OCC_Modular_DAI), _loanID_DAI));
        assert(roy.try_fundLoan(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(roy.try_fundLoan(address(OCC_Modular_USDC), _loanID_USDC));
        assert(roy.try_fundLoan(address(OCC_Modular_USDT), _loanID_USDT));

        // Mint borrower tokens for paying interest, or other purposes.
        mint("DAI", address(tim), MAX_UINT / 2);
        mint("FRAX", address(tim), MAX_UINT / 2);
        mint("USDC", address(tim), MAX_UINT / 2);
        mint("USDT", address(tim), MAX_UINT / 2);

        // Handle pre-approvals here for future convenience.
        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), MAX_UINT / 2));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), MAX_UINT / 2));

        (,, uint256[10] memory loanInfo_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory loanInfo_FRAX) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory loanInfo_USDC) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory loanInfo_USDT) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        hevm.warp(loanInfo_DAI[3] + loanInfo_DAI[8] + 1 seconds);
        OCC_Modular_DAI.markDefault(_loanID_DAI);

        hevm.warp(loanInfo_FRAX[3] + loanInfo_FRAX[8] + 1 seconds);
        OCC_Modular_FRAX.markDefault(_loanID_FRAX);
        
        hevm.warp(loanInfo_USDC[3] + loanInfo_USDC[8] + 1 seconds);
        OCC_Modular_USDC.markDefault(_loanID_USDC);
        
        hevm.warp(loanInfo_USDT[3] + loanInfo_USDT[8] + 1 seconds);
        OCC_Modular_USDT.markDefault(_loanID_USDT);
        
        assert(tim.try_resolveDefault(address(OCC_Modular_DAI), _loanID_DAI, loanInfo_DAI[0]));
        assert(tim.try_resolveDefault(address(OCC_Modular_FRAX), _loanID_FRAX, loanInfo_DAI[0]));
        assert(tim.try_resolveDefault(address(OCC_Modular_USDC), _loanID_USDC, loanInfo_DAI[0]));
        assert(tim.try_resolveDefault(address(OCC_Modular_USDT), _loanID_USDT, loanInfo_DAI[0]));

    }

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate initial state.

    function test_OCC_Modular_init() public {
        
        // Ownership.
        assertEq(OCC_Modular_DAI.owner(), address(DAO));
        assertEq(OCC_Modular_FRAX.owner(), address(DAO));
        assertEq(OCC_Modular_USDC.owner(), address(DAO));
        assertEq(OCC_Modular_USDT.owner(), address(DAO));
        
        // State variables.
        assertEq(OCC_Modular_DAI.stablecoin(), address(DAI));
        assertEq(OCC_Modular_FRAX.stablecoin(), address(FRAX));
        assertEq(OCC_Modular_USDC.stablecoin(), address(USDC));
        assertEq(OCC_Modular_USDT.stablecoin(), address(USDT));
        
        assertEq(OCC_Modular_DAI.GBL(), address(GBL));
        assertEq(OCC_Modular_FRAX.GBL(), address(GBL));
        assertEq(OCC_Modular_USDC.GBL(), address(GBL));
        assertEq(OCC_Modular_USDT.GBL(), address(GBL));
        
        assertEq(OCC_Modular_DAI.issuer(), address(roy));
        assertEq(OCC_Modular_FRAX.issuer(), address(roy));
        assertEq(OCC_Modular_USDC.issuer(), address(roy));
        assertEq(OCC_Modular_USDT.issuer(), address(roy));

        assert(OCC_Modular_DAI.canPush());
        assert(OCC_Modular_FRAX.canPush());
        assert(OCC_Modular_USDC.canPush());
        assert(OCC_Modular_USDT.canPush());

        assert(OCC_Modular_DAI.canPull());
        assert(OCC_Modular_FRAX.canPull());
        assert(OCC_Modular_USDC.canPull());
        assert(OCC_Modular_USDT.canPull());
        
        assert(OCC_Modular_DAI.canPushMulti());
        assert(OCC_Modular_FRAX.canPushMulti());
        assert(OCC_Modular_USDC.canPushMulti());
        assert(OCC_Modular_USDT.canPushMulti());
        
        assert(OCC_Modular_DAI.canPullMulti());
        assert(OCC_Modular_FRAX.canPullMulti());
        assert(OCC_Modular_USDC.canPullMulti());
        assert(OCC_Modular_USDT.canPullMulti());
        
        assert(OCC_Modular_DAI.canPullPartial());
        assert(OCC_Modular_FRAX.canPullPartial());
        assert(OCC_Modular_USDC.canPullPartial());
        assert(OCC_Modular_USDT.canPullPartial());

    }

    // Validate state changes of requestLoan() function.
    // Validate restrictions of requestLoan() function.
    // Restrictions include:
    //  - APR > 3600
    //  - APRLateFee > 3600
    //  - Invalid paymentInterval (only 5 valid options)
    //  - paymentSchedule != (0 || 1)
    
    function test_OCC_Modular_requestLoan_state(
        uint96 random, 
        bool choice, 
        uint8 modularity
    ) public {

        uint32[5] memory paymentInterval = [
            86400 * 7.5, 86400 * 15, 86400 * 30, 86400 * 90, 86400 * 360
        ];

        uint256 borrowAmount = uint256(random);
        uint256 APR = uint256(random) % 3601;
        uint256 APRLateFee = uint256(random) % 3601;
        uint256 term = uint256(random) % 25 + 1;
        uint256 gracePeriod = uint256(random) % 90 days;
        uint256 option = uint256(random) % 5;
        int8 paymentSchedule = choice ? int8(0) : int8(1);
        
        uint256 loanID;

        if (modularity % 4 == 0) {

            loanID = OCC_Modular_DAI.counterID();

            OCC_Modular_DAI.requestLoan(
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(paymentInterval[option]),
                gracePeriod,
                paymentSchedule
            );

            (
                address _borrower, 
                int8 _paymentSchedule, 
                uint256[10] memory _details
            ) = OCC_Modular_DAI.loanInfo(loanID);

            assertEq(_borrower, address(this));
            assertEq(paymentSchedule, _paymentSchedule);
            assertEq(_details[0], borrowAmount);
            assertEq(_details[1], APR);
            assertEq(_details[2], APRLateFee);
            assertEq(_details[3], 0);
            assertEq(_details[4], term);
            assertEq(_details[5], term);
            assertEq(_details[6], uint256(paymentInterval[option]));
            assertEq(_details[7], block.timestamp + 14 days);
            assertEq(_details[8], gracePeriod);
            assertEq(_details[9], 1);

            assertEq(OCC_Modular_DAI.counterID(), loanID + 1);

        }

        if (modularity % 4 == 1) {

            loanID = OCC_Modular_FRAX.counterID();

            OCC_Modular_FRAX.requestLoan(
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(paymentInterval[option]),
                gracePeriod,
                paymentSchedule
            );

            (
                address _borrower, 
                int8 _paymentSchedule, 
                uint256[10] memory _details
            ) = OCC_Modular_FRAX.loanInfo(loanID);

            assertEq(_borrower, address(this));
            assertEq(paymentSchedule, _paymentSchedule);
            assertEq(_details[0], borrowAmount);
            assertEq(_details[1], APR);
            assertEq(_details[2], APRLateFee);
            assertEq(_details[3], 0);
            assertEq(_details[4], term);
            assertEq(_details[5], term);
            assertEq(_details[6], uint256(paymentInterval[option]));
            assertEq(_details[7], block.timestamp + 14 days);
            assertEq(_details[8], gracePeriod);
            assertEq(_details[9], 1);

            assertEq(OCC_Modular_FRAX.counterID(), loanID + 1);

        }

        if (modularity % 4 == 2) {

            loanID = OCC_Modular_USDC.counterID();

            OCC_Modular_USDC.requestLoan(
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(paymentInterval[option]),
                gracePeriod,
                paymentSchedule
            );

            (
                address _borrower, 
                int8 _paymentSchedule, 
                uint256[10] memory _details
            ) = OCC_Modular_USDC.loanInfo(loanID);

            assertEq(_borrower, address(this));
            assertEq(paymentSchedule, _paymentSchedule);
            assertEq(_details[0], borrowAmount);
            assertEq(_details[1], APR);
            assertEq(_details[2], APRLateFee);
            assertEq(_details[3], 0);
            assertEq(_details[4], term);
            assertEq(_details[5], term);
            assertEq(_details[6], uint256(paymentInterval[option]));
            assertEq(_details[7], block.timestamp + 14 days);
            assertEq(_details[8], gracePeriod);
            assertEq(_details[9], 1);

            assertEq(OCC_Modular_USDC.counterID(), loanID + 1);

        }

        if (modularity % 4 == 3) {

            loanID = OCC_Modular_USDT.counterID();

            OCC_Modular_USDT.requestLoan(
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(paymentInterval[option]),
                gracePeriod,
                paymentSchedule
            );

            (
                address _borrower, 
                int8 _paymentSchedule, 
                uint256[10] memory _details
            ) = OCC_Modular_USDT.loanInfo(loanID);

            assertEq(_borrower, address(this));
            assertEq(paymentSchedule, _paymentSchedule);
            assertEq(_details[0], borrowAmount);
            assertEq(_details[1], APR);
            assertEq(_details[2], APRLateFee);
            assertEq(_details[3], 0);
            assertEq(_details[4], term);
            assertEq(_details[5], term);
            assertEq(_details[6], uint256(paymentInterval[option]));
            assertEq(_details[7], block.timestamp + 14 days);
            assertEq(_details[8], gracePeriod);
            assertEq(_details[9], 1);

            assertEq(OCC_Modular_USDT.counterID(), loanID + 1);

        }
        
    }

    function test_OCC_Modular_requestLoan_restrictions(
        uint96 random, 
        bool choice
    ) public {

        uint32[5] memory options = [
            86400 * 7.5, 86400 * 15, 86400 * 30, 86400 * 90, 86400 * 360
        ];

        uint256 borrowAmount = uint256(random);
        uint256 APR;
        uint256 APRLateFee;
        uint256 term;
        uint256 paymentInterval;
        uint256 gracePeriod;
        int8 paymentSchedule = 2;
        
        // Can't requestLoan with APR > 3600.

        APR = 3601;
        
        assert(!bob.try_requestLoan(
            address(OCC_Modular_DAI),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_FRAX),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDC),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDT),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));

        APR = uint256(random) % 3601;

        // Can't requestLoan with APRLateFee > 3600.

        APRLateFee = 3601;
        
        assert(!bob.try_requestLoan(
            address(OCC_Modular_DAI),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_FRAX),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDC),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDT),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));

        APRLateFee = uint256(random) % 3601;

        // Can't requestLoan with term == 0.
        
        assert(!bob.try_requestLoan(
            address(OCC_Modular_DAI),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_FRAX),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDC),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDT),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));

        term = uint256(random) % 100 + 1;

        // Can't requestLoan with invalid paymentInterval (only 5 valid options).
        
        assert(!bob.try_requestLoan(
            address(OCC_Modular_DAI),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_FRAX),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDC),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDT),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));

        paymentInterval = options[uint256(random) % 5];
        
        // Can't requestLoan with invalid paymentSchedule (0 || 1).
        
        assert(!bob.try_requestLoan(
            address(OCC_Modular_DAI),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_FRAX),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDC),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDT),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));

        paymentSchedule = choice ? int8(0) : int8(1);
        
        // Finally, show valid settings being accepted in requestLoan.

        assert(bob.try_requestLoan(
            address(OCC_Modular_DAI),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(bob.try_requestLoan(
            address(OCC_Modular_FRAX),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(bob.try_requestLoan(
            address(OCC_Modular_USDC),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));
        assert(bob.try_requestLoan(
            address(OCC_Modular_USDT),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        ));

    }

    // Validate cancelRequest() state changes.
    // Validate cancelRequest() restrictions.
    // This includes:
    //  - _msgSender() must equal borrower
    //  - loans[id].state must equal LoanState.Initialized

    function test_OCC_Modular_cancelLoan_restrictions(uint96 random, bool choice) public {

        uint256 amt = uint256(random);

        simulateITO(amt * WAD, amt * WAD, amt * USD, amt * USD);

        assert(god.try_push(address(DAO), address(OCC_Modular_DAI), DAI, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_FRAX), FRAX, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDC), USDC, amt));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDT), USDT, amt));

        uint256 _loanID_DAI = tim_requestRandomLoan(random, choice, DAI);
        uint256 _loanID_FRAX = tim_requestRandomLoan(random, choice, FRAX);
        uint256 _loanID_USDC = tim_requestRandomLoan(random, choice, USDC);
        uint256 _loanID_USDT = tim_requestRandomLoan(random, choice, USDT);

        // Can't cancelRequest() unless _msgSender() == borrower.
        assert(!bob.try_cancelRequest(address(OCC_Modular_DAI), _loanID_DAI));
        assert(!bob.try_cancelRequest(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_cancelRequest(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_cancelRequest(address(OCC_Modular_USDT), _loanID_USDT));

        // Fund two of these loans.
        man_fundLoan(_loanID_DAI, DAI);
        man_fundLoan(_loanID_FRAX, FRAX);

        // Cancel two of these loans (in advance) of restrictions check.
        assert(tim.try_cancelRequest(address(OCC_Modular_USDC), _loanID_USDC));
        assert(tim.try_cancelRequest(address(OCC_Modular_USDT), _loanID_USDT));

        // Can't cancelRequest() if state != LoanState.Initialized.
        assert(!tim.try_cancelRequest(address(OCC_Modular_DAI), _loanID_DAI));
        assert(!tim.try_cancelRequest(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!tim.try_cancelRequest(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!tim.try_cancelRequest(address(OCC_Modular_USDT), _loanID_USDT));

    }

    function test_OCC_Modular_cancelLoan_state(uint96 random, bool choice) public {
        
        uint256 _loanID_DAI = tim_requestRandomLoan(random, choice, DAI);
        uint256 _loanID_FRAX = tim_requestRandomLoan(random, choice, FRAX);
        uint256 _loanID_USDC = tim_requestRandomLoan(random, choice, USDC);
        uint256 _loanID_USDT = tim_requestRandomLoan(random, choice, USDT);

        // Pre-state.
        (,, uint256[10] memory details_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory details_FRAX) = OCC_Modular_DAI.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory details_USDC) = OCC_Modular_DAI.loanInfo(_loanID_USDC);
        (,, uint256[10] memory details_USDT) = OCC_Modular_DAI.loanInfo(_loanID_USDT);

        assertEq(details_DAI[9], 1);
        assertEq(details_FRAX[9], 1);
        assertEq(details_USDC[9], 1);
        assertEq(details_USDT[9], 1);

        assert(tim.try_cancelRequest(address(OCC_Modular_DAI), _loanID_DAI));
        assert(tim.try_cancelRequest(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(tim.try_cancelRequest(address(OCC_Modular_USDC), _loanID_USDC));
        assert(tim.try_cancelRequest(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state.
        (,, details_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, details_FRAX) = OCC_Modular_DAI.loanInfo(_loanID_FRAX);
        (,, details_USDC) = OCC_Modular_DAI.loanInfo(_loanID_USDC);
        (,, details_USDT) = OCC_Modular_DAI.loanInfo(_loanID_USDT);

        // Post-state.
        assertEq(details_DAI[9], 5);
        assertEq(details_FRAX[9], 5);
        assertEq(details_USDC[9], 5);
        assertEq(details_USDT[9], 5);
    }

    // Validate fundLoan() state changes.
    // Validate fundLoan() restrictions.
    // This includes:
    //  - loans[id].state must equal LoanState.Initialized

    function test_OCC_Modular_fundLoan_restrictions(uint96 random, bool choice) public {

        (
            uint256 _loanID_DAI, 
            uint256 _loanID_FRAX, 
            uint256 _loanID_USDC, 
            uint256 _loanID_USDT 
        ) = simulateITO_and_requestLoans(random, choice);

        // Cancel two loan requests.
        assert(tim.try_cancelRequest(address(OCC_Modular_DAI), _loanID_DAI));
        assert(tim.try_cancelRequest(address(OCC_Modular_USDC), _loanID_USDC));

        // Can't fund loan if state != LoanState.Initialized.
        assert(!roy.try_fundLoan(address(OCC_Modular_DAI), _loanID_DAI));
        assert(!roy.try_fundLoan(address(OCC_Modular_USDC), _loanID_USDC));

        // Warp past expiry time (14 days past loan creation).
        hevm.warp(block.timestamp + 14 days + 1 seconds);

        // Can't fund loan if block.timestamp > loans[id].requestExpiry.
        assert(!roy.try_fundLoan(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!roy.try_fundLoan(address(OCC_Modular_USDT), _loanID_USDT));

    }

    function test_OCC_Modular_fundLoan_state(uint96 random, bool choice) public {

        (
            uint256 _loanID_DAI, 
            uint256 _loanID_FRAX, 
            uint256 _loanID_USDC, 
            uint256 _loanID_USDT 
        ) = simulateITO_and_requestLoans(random, choice);


        // Pre-state DAI.
        uint256 _preStable_borrower = IERC20(DAI).balanceOf(address(tim));
        uint256 _preStable_occ = IERC20(DAI).balanceOf(address(OCC_Modular_DAI));

        assert(roy.try_fundLoan(address(OCC_Modular_DAI), _loanID_DAI));

        // Post-state DAI.
        (,, uint256[10] memory _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        uint256 _postStable_borrower = IERC20(DAI).balanceOf(address(tim));
        uint256 _postStable_occ = IERC20(DAI).balanceOf(address(OCC_Modular_DAI));
        
        assertEq(_postDetails[3], block.timestamp + _postDetails[6]);
        assertEq(_postDetails[9], 2);
        assertEq(_postStable_borrower - _preStable_borrower, _postDetails[0]);
        assertEq(_preStable_occ - _postStable_occ, _postDetails[0]);


        // Pre-state FRAX.
        _preStable_borrower = IERC20(FRAX).balanceOf(address(tim));
        _preStable_occ = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));

        assert(roy.try_fundLoan(address(OCC_Modular_FRAX), _loanID_FRAX));

        // Post-state FRAX
        (,, _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        _postStable_borrower = IERC20(FRAX).balanceOf(address(tim));
        _postStable_occ = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));
        
        assertEq(_postDetails[3], block.timestamp + _postDetails[6]);
        assertEq(_postDetails[9], 2);
        assertEq(_postStable_borrower - _preStable_borrower, _postDetails[0]);
        assertEq(_preStable_occ - _postStable_occ, _postDetails[0]);


        // Pre-state USDC.
        _preStable_borrower = IERC20(USDC).balanceOf(address(tim));
        _preStable_occ = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));

        assert(roy.try_fundLoan(address(OCC_Modular_USDC), _loanID_USDC));

        // Post-state USDC
        (,, _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        _postStable_borrower = IERC20(USDC).balanceOf(address(tim));
        _postStable_occ = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));
        
        assertEq(_postDetails[3], block.timestamp + _postDetails[6]);
        assertEq(_postDetails[9], 2);
        assertEq(_postStable_borrower - _preStable_borrower, _postDetails[0]);
        assertEq(_preStable_occ - _postStable_occ, _postDetails[0]);


        // Pre-state USDT.
        _preStable_borrower = IERC20(USDT).balanceOf(address(tim));
        _preStable_occ = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));

        assert(roy.try_fundLoan(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state USDT
        (,, _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        _postStable_borrower = IERC20(USDT).balanceOf(address(tim));
        _postStable_occ = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));
        
        assertEq(_postDetails[3], block.timestamp + _postDetails[6]);
        assertEq(_postDetails[9], 2);
        assertEq(_postStable_borrower - _preStable_borrower, _postDetails[0]);
        assertEq(_preStable_occ - _postStable_occ, _postDetails[0]);

    }

    // Validate makePayment() state changes.
    // Validate makePayment() restrictions.
    // This includes:
    //  - loans[id].state must equal LoanState.Active

    function test_OCC_Modular_makePayment_restrictions(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI, 
            uint256 _loanID_FRAX, 
            uint256 _loanID_USDC, 
            uint256 _loanID_USDT 
        ) = simulateITO_and_requestLoans(random, choice);

        uint256 amt = uint256(random);

        mint("DAI", address(tim), amt * 2);
        mint("FRAX", address(tim), amt * 2);
        mint("USDC", address(tim), amt * 2);
        mint("USDT", address(tim), amt * 2);

        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), amt * 2));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), amt * 2));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), amt * 2));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), amt * 2));

        // Can't make payment on loan if state != LoanState.Active (these loans aren't funded).
        assert(!tim.try_makePayment(address(OCC_Modular_DAI), _loanID_DAI));
        assert(!tim.try_makePayment(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!tim.try_makePayment(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!tim.try_makePayment(address(OCC_Modular_USDT), _loanID_USDT));

    }

    function test_OCC_Modular_makePayment_state_DAI(uint96 random, bool choice) public {

        (uint256 _loanID_DAI,,,) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (, int8 schedule,) = OCC_Modular_DAI.loanInfo(_loanID_DAI);

        uint256[6] memory balanceData = [
            IERC20(DAI).balanceOf(address(DAO)), // _preDAO_stable
            IERC20(DAI).balanceOf(address(DAO)), // _postDAO_stable
            IERC20(DAI).balanceOf(address(YDL)), // _preYDL_stable
            IERC20(DAI).balanceOf(address(YDL)), // _postYDL_stable
            IERC20(DAI).balanceOf(address(tim)), // _preTim_stable
            IERC20(DAI).balanceOf(address(tim))  // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 totalOwed
        ) = OCC_Modular_DAI.amountOwed(_loanID_DAI);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, totalOwed) = OCC_Modular_DAI.amountOwed(_loanID_DAI);
            (,, _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            balanceData[0] = IERC20(DAI).balanceOf(address(DAO));
            balanceData[2] = IERC20(DAI).balanceOf(address(YDL));
            balanceData[4] = IERC20(DAI).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[1] + _preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            assert(tim.try_makePayment(address(OCC_Modular_DAI), _loanID_DAI));

            // Post-state.
            (,, _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            balanceData[1] = IERC20(DAI).balanceOf(address(DAO));
            balanceData[3] = IERC20(DAI).balanceOf(address(YDL));
            balanceData[5] = IERC20(DAI).balanceOf(address(tim));

            // Note: YDL.distributedAsset() == DAI, don't check amountForConversion increase.
            
            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check state changes.
            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3]);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_makePayment_state_FRAX(uint96 random, bool choice) public {

        (, uint256 _loanID_FRAX,,) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (, int8 schedule,) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);

        uint256 _preAmountForConversion = OCC_Modular_FRAX.amountForConversion();
        uint256 _postAmountForConversion = OCC_Modular_FRAX.amountForConversion();

        uint256[6] memory balanceData = [
            IERC20(FRAX).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(FRAX).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX)),  // _prcOCC_stable
            IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX)),  // _postOCC_stable
            IERC20(FRAX).balanceOf(address(tim)),               // _preTim_stable
            IERC20(FRAX).balanceOf(address(tim))                // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 totalOwed
        ) = OCC_Modular_FRAX.amountOwed(_loanID_FRAX);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, totalOwed) = OCC_Modular_FRAX.amountOwed(_loanID_FRAX);
            (,, _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            balanceData[0] = IERC20(FRAX).balanceOf(address(DAO));
            balanceData[2] = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));
            balanceData[4] = IERC20(FRAX).balanceOf(address(tim));
            _preAmountForConversion = OCC_Modular_FRAX.amountForConversion();

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[1] + _preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            assert(tim.try_makePayment(address(OCC_Modular_FRAX), _loanID_FRAX));

            // Post-state.
            (,, _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            balanceData[1] = IERC20(FRAX).balanceOf(address(DAO));
            balanceData[3] = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));
            balanceData[5] = IERC20(FRAX).balanceOf(address(tim));
            _postAmountForConversion = OCC_Modular_FRAX.amountForConversion();

            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            // Note: YDL.distributedAsset() == DAI, check amountForConversion increase.
            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            assertEq(_postAmountForConversion - _preAmountForConversion, interestOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3]);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_makePayment_state_USDC(uint96 random, bool choice) public {

        (,, uint256 _loanID_USDC,) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (, int8 schedule,) = OCC_Modular_USDC.loanInfo(_loanID_USDC);

        uint256 _preAmountForConversion = OCC_Modular_USDC.amountForConversion();
        uint256 _postAmountForConversion = OCC_Modular_USDC.amountForConversion();

        uint256[6] memory balanceData = [
            IERC20(USDC).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(USDC).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(USDC).balanceOf(address(OCC_Modular_USDC)),  // _prcOCC_stable
            IERC20(USDC).balanceOf(address(OCC_Modular_USDC)),  // _postOCC_stable
            IERC20(USDC).balanceOf(address(tim)),               // _preTim_stable
            IERC20(USDC).balanceOf(address(tim))                // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 totalOwed
        ) = OCC_Modular_USDC.amountOwed(_loanID_USDC);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, totalOwed) = OCC_Modular_USDC.amountOwed(_loanID_USDC);
            (,, _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            balanceData[0] = IERC20(USDC).balanceOf(address(DAO));
            balanceData[2] = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));
            balanceData[4] = IERC20(USDC).balanceOf(address(tim));
            _preAmountForConversion = OCC_Modular_USDC.amountForConversion();

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[1] + _preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            assert(tim.try_makePayment(address(OCC_Modular_USDC), _loanID_USDC));

            // Post-state.
            (,, _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            balanceData[1] = IERC20(USDC).balanceOf(address(DAO));
            balanceData[3] = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));
            balanceData[5] = IERC20(USDC).balanceOf(address(tim));
            _postAmountForConversion = OCC_Modular_USDC.amountForConversion();

            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            // Note: YDL.distributedAsset() == DAI, check amountForConversion increase.
            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            assertEq(_postAmountForConversion - _preAmountForConversion, interestOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3]);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_makePayment_state_USDT(uint96 random, bool choice) public {

        (,,, uint256 _loanID_USDT) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        (,, uint256[10] memory _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        (, int8 schedule,) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        uint256 _preAmountForConversion = OCC_Modular_USDT.amountForConversion();
        uint256 _postAmountForConversion = OCC_Modular_USDT.amountForConversion();

        uint256[6] memory balanceData = [
            IERC20(USDT).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(USDT).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(USDT).balanceOf(address(OCC_Modular_USDT)),  // _prcOCC_stable
            IERC20(USDT).balanceOf(address(OCC_Modular_USDT)),  // _postOCC_stable
            IERC20(USDT).balanceOf(address(tim)),               // _preTim_stable
            IERC20(USDT).balanceOf(address(tim))                // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 totalOwed
        ) = OCC_Modular_USDT.amountOwed(_loanID_USDT);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, totalOwed) = OCC_Modular_USDT.amountOwed(_loanID_USDT);
            (,, _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            balanceData[0] = IERC20(USDT).balanceOf(address(DAO));
            balanceData[2] = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));
            balanceData[4] = IERC20(USDT).balanceOf(address(tim));
            _preAmountForConversion = OCC_Modular_USDT.amountForConversion();

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[1] + _preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            assert(tim.try_makePayment(address(OCC_Modular_USDT), _loanID_USDT));

            // Post-state.
            (,, _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            balanceData[1] = IERC20(USDT).balanceOf(address(DAO));
            balanceData[3] = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));
            balanceData[5] = IERC20(USDT).balanceOf(address(tim));
            _postAmountForConversion = OCC_Modular_USDT.amountForConversion();
            
            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            // Note: YDL.distributedAsset() == DAI, check amountForConversion increase.
            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            assertEq(_postAmountForConversion - _preAmountForConversion, interestOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3]);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    // Validate processPayment() state changes.
    // Validate processPayment() restrictions.
    // This includes:
    //  - Can't call processPayment() unless state == LoanState.Active
    //  - Can't call processPayment() unless block.timestamp > nextPaymentDue

    function test_OCC_Modular_processPayment_restrictions(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_requestLoans(random, choice);

        // Can't call processPayment() unless state == LoanState.Active.
        assert(!bob.try_processPayment(address(OCC_Modular_DAI), _loanID_DAI));
        assert(!bob.try_processPayment(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_processPayment(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_processPayment(address(OCC_Modular_USDT), _loanID_USDT));

        (
            _loanID_DAI,
            _loanID_FRAX,
            _loanID_USDC,
            _loanID_USDT
        ) = requestLoans_and_fundLoans(random, choice);

        // Can't call processPayment() unless block.timestamp > nextPaymentDue.
        assert(!bob.try_processPayment(address(OCC_Modular_DAI), _loanID_DAI));
        assert(!bob.try_processPayment(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_processPayment(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_processPayment(address(OCC_Modular_USDT), _loanID_USDT));

    }

    function test_OCC_Modular_processPayment_state_DAI(uint96 random, bool choice) public {

        (uint256 _loanID_DAI,,,) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (, int8 schedule,) = OCC_Modular_DAI.loanInfo(_loanID_DAI);

        uint256[6] memory balanceData = [
            IERC20(DAI).balanceOf(address(DAO)), // _preDAO_stable
            IERC20(DAI).balanceOf(address(DAO)), // _postDAO_stable
            IERC20(DAI).balanceOf(address(YDL)), // _preYDL_stable
            IERC20(DAI).balanceOf(address(YDL)), // _postYDL_stable
            IERC20(DAI).balanceOf(address(tim)), // _preTim_stable
            IERC20(DAI).balanceOf(address(tim))  // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 totalOwed
        ) = OCC_Modular_DAI.amountOwed(_loanID_DAI);

        hevm.warp(_preDetails[3] + 1 seconds);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, totalOwed) = OCC_Modular_DAI.amountOwed(_loanID_DAI);
            (,, _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            balanceData[0] = IERC20(DAI).balanceOf(address(DAO));
            balanceData[2] = IERC20(DAI).balanceOf(address(YDL));
            balanceData[4] = IERC20(DAI).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[1] + _preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            OCC_Modular_DAI.processPayment(_loanID_DAI);

            // Post-state.
            (,, _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            balanceData[1] = IERC20(DAI).balanceOf(address(DAO));
            balanceData[3] = IERC20(DAI).balanceOf(address(YDL));
            balanceData[5] = IERC20(DAI).balanceOf(address(tim));

            // Note: YDL.distributedAsset() == DAI, don't check amountForConversion increase.
            
            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check state changes.
            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3] + 1 seconds);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_processPayment_state_FRAX(uint96 random, bool choice) public {

        (, uint256 _loanID_FRAX,,) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (, int8 schedule,) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);

        uint256 _preAmountForConversion = OCC_Modular_FRAX.amountForConversion();
        uint256 _postAmountForConversion = OCC_Modular_FRAX.amountForConversion();

        uint256[6] memory balanceData = [
            IERC20(FRAX).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(FRAX).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX)),  // _prcOCC_stable
            IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX)),  // _postOCC_stable
            IERC20(FRAX).balanceOf(address(tim)),               // _preTim_stable
            IERC20(FRAX).balanceOf(address(tim))                // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 totalOwed
        ) = OCC_Modular_FRAX.amountOwed(_loanID_FRAX);

        hevm.warp(_preDetails[3] + 1 seconds);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, totalOwed) = OCC_Modular_FRAX.amountOwed(_loanID_FRAX);
            (,, _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            balanceData[0] = IERC20(FRAX).balanceOf(address(DAO));
            balanceData[2] = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));
            balanceData[4] = IERC20(FRAX).balanceOf(address(tim));
            _preAmountForConversion = OCC_Modular_FRAX.amountForConversion();

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[1] + _preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            OCC_Modular_FRAX.processPayment(_loanID_FRAX);

            // Post-state.
            (,, _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            balanceData[1] = IERC20(FRAX).balanceOf(address(DAO));
            balanceData[3] = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));
            balanceData[5] = IERC20(FRAX).balanceOf(address(tim));
            _postAmountForConversion = OCC_Modular_FRAX.amountForConversion();

            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            // Note: YDL.distributedAsset() == DAI, check amountForConversion increase.
            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            assertEq(_postAmountForConversion - _preAmountForConversion, interestOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3] + 1 seconds);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_processPayment_state_USDC(uint96 random, bool choice) public {

        (,, uint256 _loanID_USDC,) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (, int8 schedule,) = OCC_Modular_USDC.loanInfo(_loanID_USDC);

        uint256 _preAmountForConversion = OCC_Modular_USDC.amountForConversion();
        uint256 _postAmountForConversion = OCC_Modular_USDC.amountForConversion();

        uint256[6] memory balanceData = [
            IERC20(USDC).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(USDC).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(USDC).balanceOf(address(OCC_Modular_USDC)),  // _prcOCC_stable
            IERC20(USDC).balanceOf(address(OCC_Modular_USDC)),  // _postOCC_stable
            IERC20(USDC).balanceOf(address(tim)),               // _preTim_stable
            IERC20(USDC).balanceOf(address(tim))                // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 totalOwed
        ) = OCC_Modular_USDC.amountOwed(_loanID_USDC);

        hevm.warp(_preDetails[3] + 1 seconds);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, totalOwed) = OCC_Modular_USDC.amountOwed(_loanID_USDC);
            (,, _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            balanceData[0] = IERC20(USDC).balanceOf(address(DAO));
            balanceData[2] = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));
            balanceData[4] = IERC20(USDC).balanceOf(address(tim));
            _preAmountForConversion = OCC_Modular_USDC.amountForConversion();

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[1] + _preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            OCC_Modular_USDC.processPayment(_loanID_USDC);

            // Post-state.
            (,, _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            balanceData[1] = IERC20(USDC).balanceOf(address(DAO));
            balanceData[3] = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));
            balanceData[5] = IERC20(USDC).balanceOf(address(tim));
            _postAmountForConversion = OCC_Modular_USDC.amountForConversion();

            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            // Note: YDL.distributedAsset() == DAI, check amountForConversion increase.
            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            assertEq(_postAmountForConversion - _preAmountForConversion, interestOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3] + 1 seconds);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_processPayment_state_USDT(uint96 random, bool choice) public {

        (,,, uint256 _loanID_USDT) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        (,, uint256[10] memory _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        (, int8 schedule,) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        uint256 _preAmountForConversion = OCC_Modular_USDT.amountForConversion();
        uint256 _postAmountForConversion = OCC_Modular_USDT.amountForConversion();

        uint256[6] memory balanceData = [
            IERC20(USDT).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(USDT).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(USDT).balanceOf(address(OCC_Modular_USDT)),  // _prcOCC_stable
            IERC20(USDT).balanceOf(address(OCC_Modular_USDT)),  // _postOCC_stable
            IERC20(USDT).balanceOf(address(tim)),               // _preTim_stable
            IERC20(USDT).balanceOf(address(tim))                // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 totalOwed
        ) = OCC_Modular_USDT.amountOwed(_loanID_USDT);

        hevm.warp(_preDetails[3] + 1 seconds);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, totalOwed) = OCC_Modular_USDT.amountOwed(_loanID_USDT);
            (,, _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            balanceData[0] = IERC20(USDT).balanceOf(address(DAO));
            balanceData[2] = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));
            balanceData[4] = IERC20(USDT).balanceOf(address(tim));
            _preAmountForConversion = OCC_Modular_USDT.amountForConversion();

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[1] + _preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            OCC_Modular_USDT.processPayment(_loanID_USDT);

            // Post-state.
            (,, _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            balanceData[1] = IERC20(USDT).balanceOf(address(DAO));
            balanceData[3] = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));
            balanceData[5] = IERC20(USDT).balanceOf(address(tim));
            _postAmountForConversion = OCC_Modular_USDT.amountForConversion();
            
            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            // Note: YDL.distributedAsset() == DAI, check amountForConversion increase.
            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            assertEq(_postAmountForConversion - _preAmountForConversion, interestOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3] + 1 seconds);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    // Validate markDefault() state changes.
    // Validate markDefault() restrictions.
    // This includes:
    //  - loans[id].paymentDueBy + gracePeriod must be > block.timestamp

    function test_OCC_Modular_markDefault_restrictions(uint96 random, bool choice) public {

        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_requestLoans(random, choice);

        // Can't call markDefault() if state != LoanState.Active.
        assert(!bob.try_markDefault(address(OCC_Modular_DAI), _loanID_DAI));
        assert(!bob.try_markDefault(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_markDefault(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_markDefault(address(OCC_Modular_USDT), _loanID_USDT));

        (
            _loanID_DAI,
            _loanID_FRAX,
            _loanID_USDC,
            _loanID_USDT
        ) = requestLoans_and_fundLoans(random, choice);

        // Can't call markDefault() if not pass paymentDueBy + gracePeriod.
        assert(!bob.try_markDefault(address(OCC_Modular_DAI), _loanID_DAI));
        assert(!bob.try_markDefault(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_markDefault(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_markDefault(address(OCC_Modular_USDT), _loanID_USDT));

        (,, uint256[10] memory loanInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);

        // Warp to actual time callable (same data for all loans).
        hevm.warp(loanInfo[3] + loanInfo[8] + 1 seconds);

        assert(bob.try_markDefault(address(OCC_Modular_DAI), _loanID_DAI));
        assert(bob.try_markDefault(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(bob.try_markDefault(address(OCC_Modular_USDC), _loanID_USDC));
        assert(bob.try_markDefault(address(OCC_Modular_USDT), _loanID_USDT));

    }

    function test_OCC_Modular_markDefault_state(uint96 random, bool choice) public {

        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        (,, uint256[10] memory loanInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);

        // Warp to actual time callable (same data for all loans).
        hevm.warp(loanInfo[3] + loanInfo[8] + 1 seconds);

        // Pre-state, DAI.
        (,, loanInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        assertEq(GBL.defaults(), 0);
        assertEq(loanInfo[9], 2);

        assert(bob.try_markDefault(address(OCC_Modular_DAI), _loanID_DAI));

        // Post-state, DAI.
        (,, loanInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        assertEq(GBL.defaults(), GBL.standardize(random, DAI));
        assertEq(loanInfo[9], 4);

        // Pre-state, FRAX.
        (,, loanInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        assertEq(loanInfo[9], 2);

        assert(bob.try_markDefault(address(OCC_Modular_FRAX), _loanID_FRAX));

        // Post-state, FRAX.
        (,, loanInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        assertEq(GBL.defaults(), GBL.standardize(random, DAI) + GBL.standardize(random, FRAX));
        assertEq(loanInfo[9], 4);

        // Pre-state, USDC.
        (,, loanInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        assertEq(loanInfo[9], 2);

        assert(bob.try_markDefault(address(OCC_Modular_USDC), _loanID_USDC));

        // Post-state, USDC.
        (,, loanInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        assertEq(
            GBL.defaults(), 
            GBL.standardize(random, DAI) + GBL.standardize(random, FRAX) + 
            GBL.standardize(random, USDC)
        );
        assertEq(loanInfo[9], 4);

        // Pre-state, USDT.
        (,, loanInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        assertEq(loanInfo[9], 2);
        
        assert(bob.try_markDefault(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state, USDT.
        (,, loanInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        assertEq(
            GBL.defaults(), 
            GBL.standardize(random, DAI) + GBL.standardize(random, FRAX) + 
            GBL.standardize(random, USDC) + GBL.standardize(random, USDT)
        );
        assertEq(loanInfo[9], 4);

    }

    // Validate callLoan() state changes.
    // Validate callLoan() restrictions.
    // This includes:
    //  - _msgSender() must be borrower
    //  - loans[id].state must equal LoanState.Active

    function test_OCC_Modular_callLoan_restrictions(uint96 random, bool choice) public {

        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        mint("DAI", address(bob), uint256(random));
        mint("FRAX", address(bob), uint256(random));
        mint("USDC", address(bob), uint256(random));
        mint("USDT", address(bob), uint256(random));

        assert(bob.try_approveToken(DAI, address(OCC_Modular_DAI), uint256(random)));
        assert(bob.try_approveToken(FRAX, address(OCC_Modular_FRAX), uint256(random)));
        assert(bob.try_approveToken(USDC, address(OCC_Modular_USDC), uint256(random)));
        assert(bob.try_approveToken(USDT, address(OCC_Modular_USDT), uint256(random)));

        // Can't callLoan() unless _msgSender() == borrower.
        assert(!bob.try_callLoan(address(OCC_Modular_DAI), _loanID_DAI));
        assert(!bob.try_callLoan(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_callLoan(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_callLoan(address(OCC_Modular_USDT), _loanID_USDT));

        _loanID_DAI = tim_requestRandomLoan(random, choice, DAI);
        _loanID_FRAX = tim_requestRandomLoan(random, choice, FRAX);
        _loanID_USDC = tim_requestRandomLoan(random, choice, USDC);
        _loanID_USDT = tim_requestRandomLoan(random, choice, USDT);

        // Can't callLoan() unless state = LoanState.active.
        assert(!tim.try_callLoan(address(OCC_Modular_DAI), _loanID_DAI));
        assert(!tim.try_callLoan(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!tim.try_callLoan(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!tim.try_callLoan(address(OCC_Modular_USDT), _loanID_USDT));

    }

    function test_OCC_Modular_callLoan_state_DAI(uint96 random, bool choice) public {

        (uint256 _loanID_DAI,,,) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        // Pre-state DAI.
        (,, uint256[10] memory _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        
        uint256 principalOwed = _preDetails[0];

        // 20% chance to make late callLoan() (warp ahead of time).
        if (principalOwed % 5 == 0) {
            hevm.warp(_preDetails[3] + random % 7776000); // Potentially up to 90 days late callLoan().
        }

        (, uint256 interestOwed,) = OCC_Modular_DAI.amountOwed(_loanID_DAI);

        uint256[6] memory balanceData = [
            IERC20(DAI).balanceOf(address(DAO)),    // _preDAO_stable
            IERC20(DAI).balanceOf(address(DAO)),    // _postDAO_stable
            IERC20(DAI).balanceOf(address(YDL)),    // _preYDL_stable
            IERC20(DAI).balanceOf(address(YDL)),    // _postYDL_stable
            IERC20(DAI).balanceOf(address(tim)),    // _preTim_stable
            IERC20(DAI).balanceOf(address(tim))     // _postTim_stable
        ];

        assertEq(_preDetails[9], 2);

        // Check amountOwed() interest ...
        if (block.timestamp > _preDetails[3]) {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
            // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            assertEq(
                interestOwed, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[1] + _preDetails[2]) / (86400 * 365 * BIPS)

            );
        }
        else {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
            assertEq(
                interestOwed, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
            );
        }

        assert(tim.try_callLoan(address(OCC_Modular_DAI), _loanID_DAI));

        // Post-state.
        (,, uint256[10] memory _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        balanceData[1] = IERC20(DAI).balanceOf(address(DAO));
        balanceData[3] = IERC20(DAI).balanceOf(address(YDL));
        balanceData[5] = IERC20(DAI).balanceOf(address(tim));

        // Note: Don't check for amountForConversion state change on OCC_Modular_DAI,
        //       given YDL.distributedAsset() == DAI.

        assertEq(balanceData[1] - balanceData[0], principalOwed);
        assertEq(balanceData[3] - balanceData[2], interestOwed);
        assertEq(balanceData[4] - balanceData[5], principalOwed + interestOwed);

        // details[0] = principalOwed
        // details[3] = paymentDueBy
        // details[4] = paymentsRemaining
        // details[6] = paymentInterval
        // details[9] = loanState

        assertEq(_postDetails[0], 0);
        assertEq(_postDetails[3], 0);
        assertEq(_postDetails[4], 0);
        assertEq(_postDetails[9], 3);
        
    }

    function test_OCC_Modular_callLoan_state_FRAX(uint96 random, bool choice) public {

        (, uint256 _loanID_FRAX,,) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        // Pre-state FRAX.
        (,, uint256[10] memory _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        
        uint256 principalOwed = _preDetails[0];

        // 20% chance to make late callLoan() (warp ahead of time).
        if (principalOwed % 5 == 0) {
            hevm.warp(_preDetails[3] + random % 7776000); // Potentially up to 90 days late callLoan().
        }

        (, uint256 interestOwed,) = OCC_Modular_FRAX.amountOwed(_loanID_FRAX);
        
        uint256 _preAmountForConversion = OCC_Modular_FRAX.amountForConversion();

        uint256[6] memory balanceData = [
            IERC20(FRAX).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(FRAX).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX)),  // _prcOCC_stable
            IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX)),  // _postOCC_stable
            IERC20(FRAX).balanceOf(address(tim)),               // _preTim_stable
            IERC20(FRAX).balanceOf(address(tim))                // _postTim_stable
        ];

        assertEq(_preDetails[9], 2);

        // Check amountOwed() interest ...
        if (block.timestamp > _preDetails[3]) {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
            // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            assertEq(
                interestOwed, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[1] + _preDetails[2]) / (86400 * 365 * BIPS)

            );
        }
        else {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
            assertEq(
                interestOwed, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
            );
        }

        assert(tim.try_callLoan(address(OCC_Modular_FRAX), _loanID_FRAX));

        // Post-state.
        (,, uint256[10] memory _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        balanceData[1] = IERC20(FRAX).balanceOf(address(DAO));
        balanceData[3] = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));
        balanceData[5] = IERC20(FRAX).balanceOf(address(tim));
        uint256 _postAmountForConversion = OCC_Modular_FRAX.amountForConversion();

        assertEq(balanceData[1] - balanceData[0], principalOwed);
        assertEq(balanceData[3] - balanceData[2], interestOwed);
        assertEq(balanceData[4] - balanceData[5], principalOwed + interestOwed);
        assertEq(_postAmountForConversion - _preAmountForConversion, interestOwed);

        // details[0] = principalOwed
        // details[3] = paymentDueBy
        // details[4] = paymentsRemaining
        // details[6] = paymentInterval
        // details[9] = loanState

        assertEq(_postDetails[0], 0);
        assertEq(_postDetails[3], 0);
        assertEq(_postDetails[4], 0);
        assertEq(_postDetails[9], 3);
        
    }

    function test_OCC_Modular_callLoan_state_USDC(uint96 random, bool choice) public {

        (,, uint256 _loanID_USDC,) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        // Pre-state USDC.
        (,, uint256[10] memory _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        
        uint256 principalOwed = _preDetails[0];

        // 20% chance to make late callLoan() (warp ahead of time).
        if (principalOwed % 5 == 0) {
            hevm.warp(_preDetails[3] + random % 7776000); // Potentially up to 90 days late callLoan().
        }

        (, uint256 interestOwed,) = OCC_Modular_USDC.amountOwed(_loanID_USDC);
        
        uint256 _preAmountForConversion = OCC_Modular_USDC.amountForConversion();

        uint256[6] memory balanceData = [
            IERC20(USDC).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(USDC).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(USDC).balanceOf(address(OCC_Modular_USDC)),  // _prcOCC_stable
            IERC20(USDC).balanceOf(address(OCC_Modular_USDC)),  // _postOCC_stable
            IERC20(USDC).balanceOf(address(tim)),               // _preTim_stable
            IERC20(USDC).balanceOf(address(tim))                // _postTim_stable
        ];

        assertEq(_preDetails[9], 2);

        // Check amountOwed() interest ...
        if (block.timestamp > _preDetails[3]) {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
            // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            assertEq(
                interestOwed, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[1] + _preDetails[2]) / (86400 * 365 * BIPS)

            );
        }
        else {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
            assertEq(
                interestOwed, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
            );
        }

        assert(tim.try_callLoan(address(OCC_Modular_USDC), _loanID_USDC));

        // Post-state.
        (,, uint256[10] memory _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        balanceData[1] = IERC20(USDC).balanceOf(address(DAO));
        balanceData[3] = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));
        balanceData[5] = IERC20(USDC).balanceOf(address(tim));
        uint256 _postAmountForConversion = OCC_Modular_USDC.amountForConversion();

        assertEq(balanceData[1] - balanceData[0], principalOwed);
        assertEq(balanceData[3] - balanceData[2], interestOwed);
        assertEq(balanceData[4] - balanceData[5], principalOwed + interestOwed);
        assertEq(_postAmountForConversion - _preAmountForConversion, interestOwed);

        // details[0] = principalOwed
        // details[3] = paymentDueBy
        // details[4] = paymentsRemaining
        // details[6] = paymentInterval
        // details[9] = loanState

        assertEq(_postDetails[0], 0);
        assertEq(_postDetails[3], 0);
        assertEq(_postDetails[4], 0);
        assertEq(_postDetails[9], 3);
        
    }

    function test_OCC_Modular_callLoan_state_USDT(uint96 random, bool choice) public {

        (,,, uint256 _loanID_USDT) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        // Pre-state USDT.
        (,, uint256[10] memory _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        
        uint256 principalOwed = _preDetails[0];

        // 20% chance to make late callLoan() (warp ahead of time).
        if (principalOwed % 5 == 0) {
            hevm.warp(_preDetails[3] + random % 7776000); // Potentially up to 90 days late callLoan().
        }

        (, uint256 interestOwed,) = OCC_Modular_USDT.amountOwed(_loanID_USDT);
        
        uint256 _preAmountForConversion = OCC_Modular_USDT.amountForConversion();

        uint256[6] memory balanceData = [
            IERC20(USDT).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(USDT).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(USDT).balanceOf(address(OCC_Modular_USDT)),  // _prcOCC_stable
            IERC20(USDT).balanceOf(address(OCC_Modular_USDT)),  // _postOCC_stable
            IERC20(USDT).balanceOf(address(tim)),               // _preTim_stable
            IERC20(USDT).balanceOf(address(tim))                // _postTim_stable
        ];

        assertEq(_preDetails[9], 2);

        // Check amountOwed() interest ...
        if (block.timestamp > _preDetails[3]) {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
            // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            assertEq(
                interestOwed, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[1] + _preDetails[2]) / (86400 * 365 * BIPS)

            );
        }
        else {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
            assertEq(
                interestOwed, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
            );
        }

        assert(tim.try_callLoan(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state.
        (,, uint256[10] memory _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        balanceData[1] = IERC20(USDT).balanceOf(address(DAO));
        balanceData[3] = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));
        balanceData[5] = IERC20(USDT).balanceOf(address(tim));
        uint256 _postAmountForConversion = OCC_Modular_USDT.amountForConversion();

        assertEq(balanceData[1] - balanceData[0], principalOwed);
        assertEq(balanceData[3] - balanceData[2], interestOwed);
        assertEq(balanceData[4] - balanceData[5], principalOwed + interestOwed);
        assertEq(_postAmountForConversion - _preAmountForConversion, interestOwed);

        // details[0] = principalOwed
        // details[3] = paymentDueBy
        // details[4] = paymentsRemaining
        // details[6] = paymentInterval
        // details[9] = loanState

        assertEq(_postDetails[0], 0);
        assertEq(_postDetails[3], 0);
        assertEq(_postDetails[4], 0);
        assertEq(_postDetails[9], 3);
        
    }

    // Validate resolveDefault() state changes.
    // Validate resolveDefault() restrictions.
    // This includes:
    //  - loans[id].state must equal LoanState.Defaulted

    function test_OCC_Modular_resolveDefault_restrictions(uint96 random, bool choice) public {

        uint256 amt = uint256(random);
        
        (
            uint256 _loanID_DAI, 
            uint256 _loanID_FRAX, 
            uint256 _loanID_USDC, 
            uint256 _loanID_USDT 
        ) = simulateITO_and_requestLoans(random, choice);

        mint("DAI", address(bob), amt);
        mint("FRAX", address(bob), amt);
        mint("USDC", address(bob), amt);
        mint("USDT", address(bob), amt);

        assert(!bob.try_resolveDefault(address(OCC_Modular_DAI), _loanID_DAI, amt));
        assert(!bob.try_resolveDefault(address(OCC_Modular_FRAX), _loanID_FRAX, amt));
        assert(!bob.try_resolveDefault(address(OCC_Modular_USDC), _loanID_USDC, amt));
        assert(!bob.try_resolveDefault(address(OCC_Modular_USDT), _loanID_USDT, amt));

    }

    function test_OCC_Modular_resolveDefault_state(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI, 
            uint256 _loanID_FRAX, 
            uint256 _loanID_USDC, 
            uint256 _loanID_USDT
        ) = simulateITO_and_requestLoans_and_fundLoans_and_defaultLoans(random, choice);

        // Pre-state DAI, partial resolve.
        uint256 _preGlobalDefaults = GBL.defaults();
        (,, uint256[10] memory _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        uint256 _preStable_DAO = IERC20(DAI).balanceOf(address(DAO));
        uint256 _preStable_tim = IERC20(DAI).balanceOf(address(tim));

        // Pay off 1/3rd of the default amount.
        assert(tim.try_resolveDefault(address(OCC_Modular_DAI), _loanID_DAI, _preDetails[0] / 3));

        // Post-state DAI, partial resolve.
        uint256 _postGlobalDefaults = GBL.defaults();
        (,, uint256[10] memory _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        uint256 _postStable_DAO = IERC20(DAI).balanceOf(address(DAO));
        uint256 _postStable_tim = IERC20(DAI).balanceOf(address(tim));

        assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0] / 3, DAI));
        assertEq(_preDetails[0] - _postDetails[0], _preDetails[0] / 3);
        assertEq(_preStable_tim - _postStable_tim, _preDetails[0] / 3);
        assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0] / 3);

        // Note: In some cases, a low-amount loan (of 0 / 1) will transition state => Resolved 
        //       on 0 x-fer resolveDefault(), therefore we perform quick check here.
        if (_postDetails[9] != 6) {
            // Post-state DAI, full resolve.
            _preGlobalDefaults = GBL.defaults();
            (,, _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            _preStable_DAO = IERC20(DAI).balanceOf(address(DAO));
            _preStable_tim = IERC20(DAI).balanceOf(address(tim));

            // Pay off remaining amount.
            assert(tim.try_resolveDefault(address(OCC_Modular_DAI), _loanID_DAI, _preDetails[0]));

            // Post-state DAI, full resolve.
            _postGlobalDefaults = GBL.defaults();
            (,, _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            _postStable_DAO = IERC20(DAI).balanceOf(address(DAO));
            _postStable_tim = IERC20(DAI).balanceOf(address(tim));

            assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0], DAI));
            assertEq(_preDetails[0] - _postDetails[0], _preDetails[0]);
            assertEq(_preStable_tim - _postStable_tim, _preDetails[0]);
            assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0]);
            assertEq(_postDetails[9], 6);
        }

        // Pre-state FRAX, partial resolve.
        _preGlobalDefaults = GBL.defaults();
        (,, _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        _preStable_DAO = IERC20(FRAX).balanceOf(address(DAO));
        _preStable_tim = IERC20(FRAX).balanceOf(address(tim));

        // Pay off 1/3rd of the default amount.
        assert(tim.try_resolveDefault(address(OCC_Modular_FRAX), _loanID_FRAX, _preDetails[0] / 3));

        // Post-state FRAX, partial resolve.
        _postGlobalDefaults = GBL.defaults();
        (,, _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        _postStable_DAO = IERC20(FRAX).balanceOf(address(DAO));
        _postStable_tim = IERC20(FRAX).balanceOf(address(tim));

        assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0] / 3, FRAX));
        assertEq(_preDetails[0] - _postDetails[0], _preDetails[0] / 3);
        assertEq(_preStable_tim - _postStable_tim, _preDetails[0] / 3);
        assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0] / 3);

        // Note: In some cases, a low-amount loan (of 0 / 1) will transition state => Resolved 
        //       on 0 x-fer resolveDefault(), therefore we perform quick check here.
        if (_postDetails[9] != 6) {
            // Post-state FRAX, full resolve.
            _preGlobalDefaults = GBL.defaults();
            (,, _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            _preStable_DAO = IERC20(FRAX).balanceOf(address(DAO));
            _preStable_tim = IERC20(FRAX).balanceOf(address(tim));

            // Pay off remaining amount.
            assert(tim.try_resolveDefault(address(OCC_Modular_FRAX), _loanID_FRAX, _preDetails[0]));

            // Post-state FRAX, full resolve.
            _postGlobalDefaults = GBL.defaults();
            (,, _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            _postStable_DAO = IERC20(FRAX).balanceOf(address(DAO));
            _postStable_tim = IERC20(FRAX).balanceOf(address(tim));

            assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0], FRAX));
            assertEq(_preDetails[0] - _postDetails[0], _preDetails[0]);
            assertEq(_preStable_tim - _postStable_tim, _preDetails[0]);
            assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0]);
            assertEq(_postDetails[9], 6);
        }

        // Pre-state USDC, partial resolve.
        _preGlobalDefaults = GBL.defaults();
        (,, _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        _preStable_DAO = IERC20(USDC).balanceOf(address(DAO));
        _preStable_tim = IERC20(USDC).balanceOf(address(tim));

        // Pay off 1/3rd of the default amount.
        assert(tim.try_resolveDefault(address(OCC_Modular_USDC), _loanID_USDC, _preDetails[0] / 3));

        // Post-state USDC, partial resolve.
        _postGlobalDefaults = GBL.defaults();
        (,, _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        _postStable_DAO = IERC20(USDC).balanceOf(address(DAO));
        _postStable_tim = IERC20(USDC).balanceOf(address(tim));

        assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0] / 3, USDC));
        assertEq(_preDetails[0] - _postDetails[0], _preDetails[0] / 3);
        assertEq(_preStable_tim - _postStable_tim, _preDetails[0] / 3);
        assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0] / 3);

        // Note: In some cases, a low-amount loan (of 0 / 1) will transition state => Resolved 
        //       on 0 x-fer resolveDefault(), therefore we perform quick check here.
        if (_postDetails[9] != 6) {
            // Post-state USDC, full resolve.
            _preGlobalDefaults = GBL.defaults();
            (,, _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            _preStable_DAO = IERC20(USDC).balanceOf(address(DAO));
            _preStable_tim = IERC20(USDC).balanceOf(address(tim));

            // Pay off remaining amount.
            assert(tim.try_resolveDefault(address(OCC_Modular_USDC), _loanID_USDC, _preDetails[0]));

            // Post-state USDC, full resolve.
            _postGlobalDefaults = GBL.defaults();
            (,, _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            _postStable_DAO = IERC20(USDC).balanceOf(address(DAO));
            _postStable_tim = IERC20(USDC).balanceOf(address(tim));

            assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0], USDC));
            assertEq(_preDetails[0] - _postDetails[0], _preDetails[0]);
            assertEq(_preStable_tim - _postStable_tim, _preDetails[0]);
            assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0]);
            assertEq(_postDetails[9], 6);
        }

        // Pre-state USDT, partial resolve.
        _preGlobalDefaults = GBL.defaults();
        (,, _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        _preStable_DAO = IERC20(USDT).balanceOf(address(DAO));
        _preStable_tim = IERC20(USDT).balanceOf(address(tim));

        // Pay off 1/3rd of the default amount.
        assert(tim.try_resolveDefault(address(OCC_Modular_USDT), _loanID_USDT, _preDetails[0] / 3));

        // Post-state USDT, partial resolve.
        _postGlobalDefaults = GBL.defaults();
        (,, _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        _postStable_DAO = IERC20(USDT).balanceOf(address(DAO));
        _postStable_tim = IERC20(USDT).balanceOf(address(tim));

        assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0] / 3, USDT));
        assertEq(_preDetails[0] - _postDetails[0], _preDetails[0] / 3);
        assertEq(_preStable_tim - _postStable_tim, _preDetails[0] / 3);
        assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0] / 3);

        // Note: In some cases, a low-amount loan (of 0 / 1) will transition state => Resolved 
        //       on 0 x-fer resolveDefault(), therefore we perform quick check here.
        if (_postDetails[9] != 6) {
            // Post-state USDT, full resolve.
            _preGlobalDefaults = GBL.defaults();
            (,, _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            _preStable_DAO = IERC20(USDT).balanceOf(address(DAO));
            _preStable_tim = IERC20(USDT).balanceOf(address(tim));

            // Pay off remaining amount.
            assert(tim.try_resolveDefault(address(OCC_Modular_USDT), _loanID_USDT, _preDetails[0]));

            // Post-state USDT, full resolve.
            _postGlobalDefaults = GBL.defaults();
            (,, _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            _postStable_DAO = IERC20(USDT).balanceOf(address(DAO));
            _postStable_tim = IERC20(USDT).balanceOf(address(tim));

            assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0], USDT));
            assertEq(_preDetails[0] - _postDetails[0], _preDetails[0]);
            assertEq(_preStable_tim - _postStable_tim, _preDetails[0]);
            assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0]);
            assertEq(_postDetails[9], 6);
        }

    }

    // Validate supplyInterest() state changes.
    // Validate supplyInterest() restrictions.
    // This includes:
    //  - loans[id].state must equal LoanState.Resolved

    function test_OCC_Modular_supplyInterest_restrictions(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_requestLoans_and_fundLoans(random, choice);

        mint("DAI", address(bob), uint256(random));
        mint("FRAX", address(bob), uint256(random));
        mint("USDC", address(bob), uint256(random));
        mint("USDT", address(bob), uint256(random));

        // Can't call supplyInterest() unless state == LoanState.Resolved.
        assert(!bob.try_supplyInterest(address(OCC_Modular_DAI), _loanID_DAI, uint256(random)));
        assert(!bob.try_supplyInterest(address(OCC_Modular_FRAX), _loanID_FRAX, uint256(random)));
        assert(!bob.try_supplyInterest(address(OCC_Modular_USDC), _loanID_USDC, uint256(random)));
        assert(!bob.try_supplyInterest(address(OCC_Modular_USDT), _loanID_USDT, uint256(random)));

    }

    function test_OCC_Modular_supplyInterest_state(uint96 random, bool choice) public {

        uint256 amt = uint256(random);

        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_requestLoans_and_fundLoans_and_defaultLoans_and_resolveLoans(random, choice);

        // Note: Don't need to check amountForConversion state change for DAI, 
        //       given YDL.distributedAsset() == DAI.
        {
            // Pre-state DAI.
            uint256 _preStable_YDL = IERC20(DAI).balanceOf(address(YDL));
            uint256 _preStable_tim = IERC20(DAI).balanceOf(address(tim));

            assert(tim.try_supplyInterest(address(OCC_Modular_DAI), _loanID_DAI, amt));

            // Post-state DAI.
            uint256 _postStable_YDL = IERC20(DAI).balanceOf(address(YDL));
            uint256 _postStable_tim = IERC20(DAI).balanceOf(address(tim));

            assertEq(_postStable_YDL - _preStable_YDL, amt);
            assertEq(_preStable_tim - _postStable_tim, amt);
        }
        
        {
            // Pre-state FRAX.
            uint256 _preAmountForConversion = OCC_Modular_FRAX.amountForConversion();
            uint256 _preStable_OCC = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));
            uint256 _preStable_tim = IERC20(FRAX).balanceOf(address(tim));

            assert(tim.try_supplyInterest(address(OCC_Modular_FRAX), _loanID_FRAX, amt));

            // Post-state FRAX.
            uint256 _postAmountForConversion = OCC_Modular_FRAX.amountForConversion();
            uint256 _postStable_OCC = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));
            uint256 _postStable_tim = IERC20(FRAX).balanceOf(address(tim));

            assertEq(_postStable_OCC - _preStable_OCC, amt);
            assertEq(_preStable_tim - _postStable_tim, amt);
            assertEq(_postAmountForConversion - _preAmountForConversion, amt);
        }

        {
            // Pre-state USDC.
            uint256 _preAmountForConversion = OCC_Modular_USDC.amountForConversion();
            uint256 _preStable_OCC = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));
            uint256 _preStable_tim = IERC20(USDC).balanceOf(address(tim));

            assert(tim.try_supplyInterest(address(OCC_Modular_USDC), _loanID_USDC, amt));

            // Post-state USDC.
            uint256 _postAmountForConversion = OCC_Modular_USDC.amountForConversion();
            uint256 _postStable_OCC = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));
            uint256 _postStable_tim = IERC20(USDC).balanceOf(address(tim));

            assertEq(_postStable_OCC - _preStable_OCC, amt);
            assertEq(_preStable_tim - _postStable_tim, amt);
            assertEq(_postAmountForConversion - _preAmountForConversion, amt);
        }
        
        {
            // Pre-state USDT.
            uint256 _preAmountForConversion = OCC_Modular_USDT.amountForConversion();
            uint256 _preStable_OCC = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));
            uint256 _preStable_tim = IERC20(USDT).balanceOf(address(tim));

            assert(tim.try_supplyInterest(address(OCC_Modular_USDT), _loanID_USDT, amt));

            // Post-state USDT.
            uint256 _postAmountForConversion = OCC_Modular_USDT.amountForConversion();
            uint256 _postStable_OCC = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));
            uint256 _postStable_tim = IERC20(USDT).balanceOf(address(tim));

            assertEq(_postStable_OCC - _preStable_OCC, amt);
            assertEq(_preStable_tim - _postStable_tim, amt);
            assertEq(_postAmountForConversion - _preAmountForConversion, amt);
        }

    }

    // Validate markRepaid() state changes.
    // Validate markRepaid() restrictions.
    // This includes:
    //  - _msgSender() must be issuer
    //  - loans[id].state must equal LoanState.Resolved

    function test_OCC_Modular_markRepaid_restrictions(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_requestLoans_and_fundLoans_and_defaultLoans_and_resolveLoans(random, choice);

        // Can't call markRepaid() if _msgSender != issuer.
        assert(!bob.try_markRepaid(address(OCC_Modular_DAI), _loanID_DAI));
        assert(!bob.try_markRepaid(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_markRepaid(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_markRepaid(address(OCC_Modular_USDT), _loanID_USDT));

        _loanID_DAI = tim_requestRandomLoan(random, choice, DAI);
        _loanID_FRAX = tim_requestRandomLoan(random, choice, FRAX);
        _loanID_USDC = tim_requestRandomLoan(random, choice, USDC);
        _loanID_USDT = tim_requestRandomLoan(random, choice, USDT);

        // Can't call markRepaid() if state != LoanState.Resolved.
        assert(!roy.try_markRepaid(address(OCC_Modular_DAI), _loanID_DAI));
        assert(!roy.try_markRepaid(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!roy.try_markRepaid(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!roy.try_markRepaid(address(OCC_Modular_USDT), _loanID_USDT));

    }

    function test_OCC_Modular_markRepaid_state(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_requestLoans_and_fundLoans_and_defaultLoans_and_resolveLoans(random, choice);

        // Pre-state.
        (,, uint256[10] memory _details_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory _details_FRAX) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory _details_USDC) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory _details_USDT) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        assertEq(_details_DAI[9], 6);
        assertEq(_details_FRAX[9], 6);
        assertEq(_details_USDC[9], 6);
        assertEq(_details_USDT[9], 6);
        
        assert(roy.try_markRepaid(address(OCC_Modular_DAI), _loanID_DAI));
        assert(roy.try_markRepaid(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(roy.try_markRepaid(address(OCC_Modular_USDC), _loanID_USDC));
        assert(roy.try_markRepaid(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state.
        (,, _details_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, _details_FRAX) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, _details_USDC) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, _details_USDT) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        assertEq(_details_DAI[9], 3);
        assertEq(_details_FRAX[9], 3);
        assertEq(_details_USDC[9], 3);
        assertEq(_details_USDT[9], 3);

    }

    // Validate pullFromLocker() state changes, restrictions.
    // Validate pullFromLockerMulti() state changes, restrictions.
    // Validate pullFromLockerMultiPartial() state changes, restrictions.
    // Note: The only restriction to check is if onlyOwner modifier is present.
    // Note: Skips testing on OCC_Modular_DAI given YDL.distributeAsset() == DAI.

    function test_OCC_Modular_pullFromLocker_x_restrictions() public {

        // Restriction tests for pullFromLocker().
        assert(!bob.try_pullFromLocker_DIRECT(address(OCC_Modular_DAI), DAI));
        assert(!bob.try_pullFromLocker_DIRECT(address(OCC_Modular_FRAX), FRAX));
        assert(!bob.try_pullFromLocker_DIRECT(address(OCC_Modular_USDC), USDC));
        assert(!bob.try_pullFromLocker_DIRECT(address(OCC_Modular_USDT), USDT));

        address[] memory data_DAI = new address[](1);
        address[] memory data_FRAX = new address[](1);
        address[] memory data_USDC = new address[](1);
        address[] memory data_USDT = new address[](1);
        data_DAI[0] = DAI;
        data_FRAX[0] = FRAX;
        data_USDC[0] = USDC;
        data_USDT[0] = USDT;

        // Restriction tests for pullFromLockerMulti().
        assert(!bob.try_pullFromLockerMulti_DIRECT(address(OCC_Modular_DAI), data_DAI));
        assert(!bob.try_pullFromLockerMulti_DIRECT(address(OCC_Modular_FRAX), data_FRAX));
        assert(!bob.try_pullFromLockerMulti_DIRECT(address(OCC_Modular_USDC), data_USDC));
        assert(!bob.try_pullFromLockerMulti_DIRECT(address(OCC_Modular_USDT), data_USDT));

        uint256[] memory amts = new uint256[](1);
        amts[0] = 5;

        // Restriction tests for pullFromLockerMultiPartial().
        assert(!bob.try_pullFromLockerMultiPartial_DIRECT(address(OCC_Modular_DAI), data_DAI, amts));
        assert(!bob.try_pullFromLockerMultiPartial_DIRECT(address(OCC_Modular_FRAX), data_FRAX, amts));
        assert(!bob.try_pullFromLockerMultiPartial_DIRECT(address(OCC_Modular_USDC), data_USDC, amts));
        assert(!bob.try_pullFromLockerMultiPartial_DIRECT(address(OCC_Modular_USDT), data_USDT, amts));

    }

    function test_OCC_Modular_pullFromLocker_state(uint96 random, bool choice) public {

        // Increase amountForConversion via supplyInterest() to perform test.

        uint256 amt = uint256(random);

        (
            ,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_requestLoans_and_fundLoans_and_defaultLoans_and_resolveLoans(random, choice);

        assert(tim.try_supplyInterest(address(OCC_Modular_FRAX), _loanID_FRAX, amt + 1));
        assert(tim.try_supplyInterest(address(OCC_Modular_USDC), _loanID_USDC, amt + 1));
        assert(tim.try_supplyInterest(address(OCC_Modular_USDT), _loanID_USDT, amt + 1));

        // Pre-state.
        assertGt(OCC_Modular_FRAX.amountForConversion(), 0);
        assertGt(OCC_Modular_USDC.amountForConversion(), 0);
        assertGt(OCC_Modular_USDT.amountForConversion(), 0);

        assert(god.try_pull(address(DAO), address(OCC_Modular_FRAX), FRAX));
        assert(god.try_pull(address(DAO), address(OCC_Modular_USDC), USDC));
        assert(god.try_pull(address(DAO), address(OCC_Modular_USDT), USDT));

        // Post-state.
        assertEq(OCC_Modular_FRAX.amountForConversion(), 0);
        assertEq(OCC_Modular_USDC.amountForConversion(), 0);
        assertEq(OCC_Modular_USDT.amountForConversion(), 0);

    }

    function test_OCC_Modular_pullFromLockerMulti_state(uint96 random, bool choice) public {
        
        // Increase amountForConversion via supplyInterest() to perform test.

        uint256 amt = uint256(random);

        (
            ,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_requestLoans_and_fundLoans_and_defaultLoans_and_resolveLoans(random, choice);

        assert(tim.try_supplyInterest(address(OCC_Modular_FRAX), _loanID_FRAX, amt + 1));
        assert(tim.try_supplyInterest(address(OCC_Modular_USDC), _loanID_USDC, amt + 1));
        assert(tim.try_supplyInterest(address(OCC_Modular_USDT), _loanID_USDT, amt + 1));

        address[] memory data_FRAX = new address[](1);
        address[] memory data_USDC = new address[](1);
        address[] memory data_USDT = new address[](1);
        data_FRAX[0] = FRAX;
        data_USDC[0] = USDC;
        data_USDT[0] = USDT;

        // Pre-state.
        assertGt(OCC_Modular_FRAX.amountForConversion(), 0);
        assertGt(OCC_Modular_USDC.amountForConversion(), 0);
        assertGt(OCC_Modular_USDT.amountForConversion(), 0);

        assert(god.try_pullMulti(address(DAO), address(OCC_Modular_FRAX), data_FRAX));
        assert(god.try_pullMulti(address(DAO), address(OCC_Modular_USDC), data_USDC));
        assert(god.try_pullMulti(address(DAO), address(OCC_Modular_USDT), data_USDT));

        // Post-state.
        // amountForConversion should equal 0 after all pullFromLockerMulti() calls (that involve base stablecoin).
        assertEq(OCC_Modular_FRAX.amountForConversion(), 0);
        assertEq(OCC_Modular_FRAX.amountForConversion(), 0);
        assertEq(OCC_Modular_FRAX.amountForConversion(), 0);
        
    }

    function test_OCC_Modular_pullFromLockerMultiPartial_state(uint96 random, bool choice) public {

        // Increase amountForConversion via supplyInterest() to perform test.

        uint256 amt = uint256(random);

        (
            ,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_requestLoans_and_fundLoans_and_defaultLoans_and_resolveLoans(random, choice);

        assert(tim.try_supplyInterest(address(OCC_Modular_FRAX), _loanID_FRAX, amt + 1));
        assert(tim.try_supplyInterest(address(OCC_Modular_USDC), _loanID_USDC, amt + 1));
        assert(tim.try_supplyInterest(address(OCC_Modular_USDT), _loanID_USDT, amt + 1));

        address[] memory data_FRAX = new address[](1);
        address[] memory data_USDC = new address[](1);
        address[] memory data_USDT = new address[](1);
        data_FRAX[0] = FRAX;
        data_USDC[0] = USDC;
        data_USDT[0] = USDT;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amt;

        // Pre-state.
        assertGt(OCC_Modular_FRAX.amountForConversion(), 0);
        assertGt(OCC_Modular_USDC.amountForConversion(), 0);
        assertGt(OCC_Modular_USDT.amountForConversion(), 0);

        uint256 _preAmountForConversion_FRAX = OCC_Modular_FRAX.amountForConversion();
        uint256 _preAmountForConversion_USDC = OCC_Modular_USDC.amountForConversion();
        uint256 _preAmountForConversion_USDT = OCC_Modular_USDT.amountForConversion();

        assert(god.try_pullMultiPartial(address(DAO), address(OCC_Modular_FRAX), data_FRAX, amounts));
        assert(god.try_pullMultiPartial(address(DAO), address(OCC_Modular_USDC), data_USDC, amounts));
        assert(god.try_pullMultiPartial(address(DAO), address(OCC_Modular_USDT), data_USDT, amounts));

        // amountForConversion should equal remaining stablecoin balance IFF amountForConversion < remaining stablecoin balance.
        if (IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX)) > _preAmountForConversion_FRAX) {
            assertEq(OCC_Modular_FRAX.amountForConversion(), _preAmountForConversion_FRAX);
        }
        else {
            assertEq(OCC_Modular_FRAX.amountForConversion(), IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX)));
        }
        if (IERC20(USDC).balanceOf(address(OCC_Modular_USDC)) > _preAmountForConversion_USDC) {
            assertEq(OCC_Modular_USDC.amountForConversion(), _preAmountForConversion_USDC);
        }
        else {
            assertEq(OCC_Modular_USDC.amountForConversion(), IERC20(USDC).balanceOf(address(OCC_Modular_USDC)));
        }
        if (IERC20(USDT).balanceOf(address(OCC_Modular_USDT)) > _preAmountForConversion_USDT) {
            assertEq(OCC_Modular_USDT.amountForConversion(), _preAmountForConversion_USDT);
        }
        else {
            assertEq(OCC_Modular_USDT.amountForConversion(), IERC20(USDT).balanceOf(address(OCC_Modular_USDT)));
        }
        
    }

    // TODO: Validate forwardInterestKeeper() later!
    
    event Log(uint256[]);
    event Log(uint256[24]);

    function test_OCC_Modular_amortization_schedule_peek() public {
        
        uint256 amt = 10_000_000;

        simulateITO(amt * WAD, amt * WAD, amt * USD, amt * USD);

        uint256 borrow_amt = 10_000_000 * USD;

        assert(tim.try_requestLoan(
            address(OCC_Modular_USDC),
            borrow_amt,
            1800,
            600,
            24,
            uint256(86400 * 30),
            86400 * 90,
            int8(1)
        ));
        
        assert(god.try_push(address(DAO), address(OCC_Modular_USDC), USDC, borrow_amt));
        assert(roy.try_fundLoan(address(OCC_Modular_USDC), 0));

        mint("USDC", address(tim), MAX_UINT / 2);
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 2));
        
        (,, uint256[10] memory _details_USDC) = OCC_Modular_USDC.loanInfo(0);

        uint256[24] memory _interest;
        uint256[24] memory _principal;
        uint256[24] memory _total;

        uint256 i;

        emit Debug('a', _details_USDC[0]);
        emit Debug('a', _details_USDC[1]);
        emit Debug('a', _details_USDC[2]);
        emit Debug('a', _details_USDC[3]);
        emit Debug('a', _details_USDC[4]);
        emit Debug('a', _details_USDC[5]);
        emit Debug('a', _details_USDC[6]);
        emit Debug('a', _details_USDC[7]);
        emit Debug('a', _details_USDC[8]);
        emit Debug('a', _details_USDC[9]);

        while (_details_USDC[4] > 0) {
            (_principal[i], _interest[i], _total[i]) = OCC_Modular_USDC.amountOwed(0);
            assert(tim.try_makePayment(address(OCC_Modular_USDC), 0));
            (,, _details_USDC) = OCC_Modular_USDC.loanInfo(0);
            i++;
        }

        emit Log(_interest);
        emit Log(_principal);
        emit Log(_total);

    }

}
