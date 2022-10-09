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

        // Initialize and whitelist OCC_Modular locker.
        OCC_Modular_DAI = new OCC_Modular(address(DAO), address(DAI), address(GBL), address(man));
        OCC_Modular_FRAX = new OCC_Modular(address(DAO), address(FRAX), address(GBL), address(man));
        OCC_Modular_USDC = new OCC_Modular(address(DAO), address(USDC), address(GBL), address(man));
        OCC_Modular_USDT = new OCC_Modular(address(DAO), address(USDT), address(GBL), address(man));

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
                paymentSchedule
            ));
        }

        else { revert(); }

    }

    function man_fundLoan(uint256 loanID, address asset) public {

        if (asset == DAI) {
            assert(man.try_fundLoan(address(OCC_Modular_DAI), loanID));
        }

        else if (asset == FRAX) {
            assert(man.try_fundLoan(address(OCC_Modular_FRAX), loanID));
        }

        else if (asset == USDC) {
            assert(man.try_fundLoan(address(OCC_Modular_USDC), loanID));
        }

        else if (asset == USDT) {
            assert(man.try_fundLoan(address(OCC_Modular_USDT), loanID));
        }

        else { revert(); }

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
        
        assertEq(OCC_Modular_DAI.issuer(), address(zvl));
        assertEq(OCC_Modular_FRAX.issuer(), address(zvl));
        assertEq(OCC_Modular_USDC.issuer(), address(zvl));
        assertEq(OCC_Modular_USDT.issuer(), address(zvl));

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
                paymentSchedule
            );

            (
                address _borrower, 
                int8 _paymentSchedule, 
                uint256[9] memory _details
            ) = OCC_Modular_DAI.loanData(loanID);

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
            assertEq(_details[8], 1);

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
                paymentSchedule
            );

            (
                address _borrower, 
                int8 _paymentSchedule, 
                uint256[9] memory _details
            ) = OCC_Modular_FRAX.loanData(loanID);

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
            assertEq(_details[8], 1);

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
                paymentSchedule
            );

            (
                address _borrower, 
                int8 _paymentSchedule, 
                uint256[9] memory _details
            ) = OCC_Modular_USDC.loanData(loanID);

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
            assertEq(_details[8], 1);

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
                paymentSchedule
            );

            (
                address _borrower, 
                int8 _paymentSchedule, 
                uint256[9] memory _details
            ) = OCC_Modular_USDT.loanData(loanID);

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
            assertEq(_details[8], 1);

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
        int8 paymentSchedule = 2;
        
        // Can't requestLoan with APR > 3600.

        APR = 3601;
        
        assert(!bob.try_requestLoan(
            address(OCC_Modular_DAI),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_FRAX),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDC),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDT),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));

        APR = uint256(random) % 3601;

        // Can't requestLoan with APRLateFee > 3600.

        APRLateFee = 3601;
        
        assert(!bob.try_requestLoan(
            address(OCC_Modular_DAI),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_FRAX),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDC),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDT),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));

        APRLateFee = uint256(random) % 3601;

        // Can't requestLoan with term == 0.
        
        assert(!bob.try_requestLoan(
            address(OCC_Modular_DAI),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_FRAX),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDC),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDT),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));

        term = uint256(random) % 100 + 1;

        // Can't requestLoan with invalid paymentInterval (only 5 valid options).
        
        assert(!bob.try_requestLoan(
            address(OCC_Modular_DAI),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_FRAX),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDC),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDT),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));

        paymentInterval = options[uint256(random) % 5];
        
        // Can't requestLoan with invalid paymentSchedule (0 || 1).
        
        assert(!bob.try_requestLoan(
            address(OCC_Modular_DAI),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_FRAX),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDC),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(!bob.try_requestLoan(
            address(OCC_Modular_USDT),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));

        paymentSchedule = choice ? int8(0) : int8(1);
        
        // Finally, show valid settings being accepted in requestLoan.

        assert(bob.try_requestLoan(
            address(OCC_Modular_DAI),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(bob.try_requestLoan(
            address(OCC_Modular_FRAX),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(bob.try_requestLoan(
            address(OCC_Modular_USDC),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
        ));
        assert(bob.try_requestLoan(
            address(OCC_Modular_USDT),
            borrowAmount, APR, APRLateFee, term, paymentInterval, paymentSchedule
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
        (,, uint256[9] memory details_DAI) = OCC_Modular_DAI.loanData(_loanID_DAI);
        (,, uint256[9] memory details_FRAX) = OCC_Modular_DAI.loanData(_loanID_FRAX);
        (,, uint256[9] memory details_USDC) = OCC_Modular_DAI.loanData(_loanID_USDC);
        (,, uint256[9] memory details_USDT) = OCC_Modular_DAI.loanData(_loanID_USDT);

        assertEq(details_DAI[8], 1);
        assertEq(details_FRAX[8], 1);
        assertEq(details_USDC[8], 1);
        assertEq(details_USDT[8], 1);

        assert(tim.try_cancelRequest(address(OCC_Modular_DAI), _loanID_DAI));
        assert(tim.try_cancelRequest(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(tim.try_cancelRequest(address(OCC_Modular_USDC), _loanID_USDC));
        assert(tim.try_cancelRequest(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state.
        assertEq(details_DAI[8], 5);
        assertEq(details_FRAX[8], 5);
        assertEq(details_USDC[8], 5);
        assertEq(details_USDT[8], 5);
    }

    // Validate makePayment() state changes.
    // Validate makePayment() restrictions.
    // This includes:
    //  - loans[id].state must equal LoanState.Active

    // Validate markDefault() state changes.
    // Validate markDefault() restrictions.
    // This includes:
    //  - loans[id].paymentDueBy must be older than 90 days

    // Validate markRepaid() state changes.
    // Validate markRepaid() restrictions.
    // This includes:
    //  - _msgSender() must be issuer
    //  - loans[id].state must equal LoanState.Repaid

    // Validate callLoan() state changes.
    // Validate callLoan() restrictions.
    // This includes:
    //  - _msgSender() must be borrower
    //  - loans[id].state must equal LoanState.Active

    // Validate resolveDefault() state changes.
    // Validate resolveDefault() restrictions.
    // This includes:
    //  - loans[id].state must equal LoanState.Defaulted

    // Validate supplyInterest() state changes.
    // Validate supplyInterest() restrictions.
    // This includes:
    //  - loans[id].state must equal LoanState.Resolved

    // Validate supplyInterest() state changes.
    // Validate supplyInterest() restrictions.
    // This includes:
    //  - loans[id].state must equal LoanState.Resolved

    // Validate pullFromLocker() state changes, restrictions.
    // Validate pullFromLockerMulti() state changes, restrictions.
    // Validate pushToLockerMulti() state changes, restrictions.
    // Validate pullFromLockerMulti() state changes, restrictions.
    // Note: The only restriction to check is if onlyOwner modifier is present.






    // function xtest_OCC_FRAX_fundLoan_firstPaymentInfo_bullet() public {

    //     // Pre-state check.
    //     uint256 id = OCC_0_FRAX.counterID();

    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether,
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(0)
    //     ));

    //     // Add more FRAX into contract.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

    //     // Fund loan (5 days later).
    //     hevm.warp(block.timestamp + 5 days);
    //     assert(god.try_fundLoan(address(OCC_0_FRAX), id));

    //     (uint256 principalOwed, uint256 interestOwed, uint256 totalOwed) = OCC_0_FRAX.amountOwed(id);

    //     assertEq(principalOwed, 0);
    //     assertEq(interestOwed,  123287671232876712328);
    //     assertEq(totalOwed,     123287671232876712328);

    //     (,, uint256 APR, uint256 APRLateFee, uint256 paymentDueBy,,, uint256 paymentInterval,,,) = OCC_0_FRAX.loanInformation(id);

    //     // interestOwed = loans[id].principalOwed * (1 + loans[id].paymentInterval * loans[id].APR) / (86400 * 365 * BIPS);

    //     uint interestOwedDirect = 10000 ether * paymentInterval * APR / (86400 * 365 * BIPS);
    //     assertEq(interestOwed,  interestOwedDirect);
    //     emit Debug('totalOwed', totalOwed);
    //     assertEq(totalOwed,     interestOwedDirect);

    //     // if (block.timestamp > loans[id].paymentDueBy) {
    //     //     interestOwed += loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * loans[id].APRLateFee / (86400 * 365 * BIPS);
    //     // }

    //     hevm.warp(paymentDueBy + 15 days);

    //     (principalOwed, interestOwed, totalOwed) = OCC_0_FRAX.amountOwed(id);

    //     uint interestOwedExtra = 10000 ether * (block.timestamp - paymentDueBy) * (APR + APRLateFee) / (86400 * 365 * BIPS);

    //     assertEq(totalOwed, interestOwedDirect + interestOwedExtra);

    // }

    // function xtest_OCC_FRAX_fundLoan_firstPaymentInfo_amortization() public {

    //     // Pre-state check.
    //     uint256 id = OCC_0_FRAX.counterID();

    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether,
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(1)
    //     ));

    //     // Add more FRAX into contract.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

    //     // Fund loan (5 days later).
    //     hevm.warp(block.timestamp + 5 days);
    //     assert(god.try_fundLoan(address(OCC_0_FRAX), id));

    //     (uint256 principalOwed, uint256 interestOwed, uint256 totalOwed) = OCC_0_FRAX.amountOwed(id);

    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  123287671232876712328);
    //     assertEq(totalOwed,     956621004566210045661);

    //     (
    //         ,
    //         ,
    //         uint256 APR,
    //         uint256 APRLateFee,
    //         uint256 paymentDueBy,
    //         uint256 paymentsRemaining,
    //         ,
    //         uint256 paymentInterval,
    //         ,
    //         ,
    //     ) = OCC_0_FRAX.loanInformation(id);

    //     uint interestOwedDirect = 10000 ether * paymentInterval * APR / (86400 * 365 * BIPS);
    //     uint principalOwedDirect = 10000 ether / paymentsRemaining;
    //     assertEq(interestOwed,   interestOwedDirect);
    //     assertEq(principalOwed,  principalOwedDirect);
    //     assertEq(totalOwed,      principalOwedDirect + interestOwedDirect);

    //     hevm.warp(paymentDueBy + 14 days);

    //     (principalOwed, interestOwed, totalOwed) = OCC_0_FRAX.amountOwed(id);

    //     uint interestOwedExtra = 10000 ether * (block.timestamp - paymentDueBy) * (APR + APRLateFee) / (86400 * 365 * BIPS);

    //     assertEq(totalOwed, principalOwedDirect + interestOwedDirect + interestOwedExtra);

    // }

    // // markDefault() restrictions
    // // markDefault() state changes

    // function xtest_OCC_FRAX_markDefault_restrictions() public {

    //     // Create loan.
    //     uint256 id = OCC_0_FRAX.counterID();

    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether,
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(0)
    //     ));

    //     // Add more FRAX into contract.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

    //     // Fund loan (5 days later).
    //     hevm.warp(block.timestamp + 5 days);
    //     assert(god.try_fundLoan(address(OCC_0_FRAX), id));

    //     // Can't markDefault() if not past paymentDueBy timestamp.
    //     // Logically: loans[id].paymentDueBy + 86400 * 90 >= block.timestamp
    //     (,,,,uint256 paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(0);
    //     hevm.warp(paymentDueBy + 1);
    //     assert(!bob.try_markDefault(address(OCC_0_FRAX), id));

    //     hevm.warp(paymentDueBy + 90 days);
    //     assert(!bob.try_markDefault(address(OCC_0_FRAX), id));

    //     hevm.warp(paymentDueBy + 90 days + 1);
    //     assert(bob.try_markDefault(address(OCC_0_FRAX), id));

    // }

    // function xtest_OCC_FRAX_markDefault_state_changes() public {

    //     // Create loan.
    //     uint256 id = OCC_0_FRAX.counterID();

    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether,
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(0)
    //     ));

    //     // Add more FRAX into contract.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

    //     // Fund loan (5 days later).
    //     hevm.warp(block.timestamp + 5 days);
    //     assert(god.try_fundLoan(address(OCC_0_FRAX), id));

    //     // Pre-state check.
    //     (,,,,uint256 paymentDueBy,,,,,,uint256 loanState) = OCC_0_FRAX.loanInformation(0);
    //     assertEq(loanState, 2);

    //     // Mark loan defaulted.
    //     hevm.warp(paymentDueBy + 90 days + 1);
    //     assert(bob.try_markDefault(address(OCC_0_FRAX), id));

    //     // Post-state check.
    //     (,,,,,,,,,,loanState) = OCC_0_FRAX.loanInformation(0);
    //     assertEq(loanState, 4);

    // }

    // // makePayment() restrictions
    // // makePayment() state changes

    // function xtest_OCC_FRAX_makePayment_restrictions() public {

    //     // Can't make payment on a Null loan (some id beyond what's been initialized, e.g. id + 1).
    //     (,,,,,,,,,,uint256 loanState) = OCC_0_FRAX.loanInformation(0);
    //     assertEq(loanState, 0);
    //     assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 10000 ether));
    //     assert(!bob.try_makePayment(address(OCC_0_FRAX), 0));

    //     // Create loan.
    //     uint256 id = OCC_0_FRAX.counterID();

    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether,
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(0)
    //     ));

    //     // Can't make payment on an Initialized (non-funded) loan.
    //     (,,,,,,,,,,loanState) = OCC_0_FRAX.loanInformation(id);
    //     assertEq(loanState, 1);
    //     assert(!bob.try_makePayment(address(OCC_0_FRAX), id));

    //     // Can't make payment on a Cancelled loan.
    //     assert(bob.try_cancelRequest(address(OCC_0_FRAX), id));
    //     (,,,,,,,,,,loanState) = OCC_0_FRAX.loanInformation(id);
    //     assertEq(loanState, 5);
    //     assert(!bob.try_makePayment(address(OCC_0_FRAX), id));

    //     // Create new loan request and fund it.
    //     id = OCC_0_FRAX.counterID();

    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether,
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(0)
    //     ));


    //     // Add more FRAX into contract.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

    //     // Fund loan (5 days later).
    //     hevm.warp(block.timestamp + 5 days);
    //     assert(god.try_fundLoan(address(OCC_0_FRAX), id));

    //     // Can't make payment on a Repaid loan (simulate many payments to end to reach Repaid state first).
    //     assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 20000 ether));

    //     mint("FRAX", address(bob), 20000 ether);

    //     // 12 payments.
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     // After final payment (12th), loan is in Repaid state, and makePayment() will not work.
    //     (,,,,,,,,,,loanState) = OCC_0_FRAX.loanInformation(id);
    //     assertEq(loanState, 3);
    //     assert(!bob.try_makePayment(address(OCC_0_FRAX), id));

    // }

    // function xtest_OCC_FRAX_makePayment_state_changes_bullet() public {

    //     // Create new loan request and fund it.
    //     uint256 id = OCC_0_FRAX.counterID();

    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether,
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(0)
    //     ));


    //     // Add more FRAX into contract.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

    //     // Fund loan (5 days later).
    //     hevm.warp(block.timestamp + 5 days);
    //     assert(god.try_fundLoan(address(OCC_0_FRAX), id));

    //     // Give Bob money to make payments and approve FRAX.
    //     assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 20000 ether));
    //     mint("FRAX", address(bob), 20000 ether);

    //     // Pre-state first payment check.
    //     (,,,,uint256 paymentDueBy,,,,,,)      = OCC_0_FRAX.loanInformation(id);
    //     (,,,,,uint256 paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);
    //     (uint256 principalOwed, uint256 interestOwed,) = OCC_0_FRAX.amountOwed(id);

    //     assertEq(paymentDueBy, block.timestamp + 15 days);
    //     assertEq(paymentsRemaining, 12);
    //     assertEq(principalOwed, 0);
    //     assertEq(interestOwed,  123287671232876712328);

    //     uint256 pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));

    //     // Make first payment.
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     // Post-state first payment check.
    //     uint256 post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
    //     (,,,,, paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);

    //     assertEq(pre_FRAX_bob - post_FRAX_bob, interestOwed);
    //     assertEq(paymentsRemaining, 11);

    //     // Iterate through remaining interest payments.
    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 2
    //     hevm.warp(paymentDueBy);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 3
    //     hevm.warp(paymentDueBy);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 4
    //     hevm.warp(paymentDueBy);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 5
    //     hevm.warp(paymentDueBy);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 6
    //     hevm.warp(paymentDueBy);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 7
    //     hevm.warp(paymentDueBy);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 8
    //     hevm.warp(paymentDueBy);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 9
    //     hevm.warp(paymentDueBy);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 10
    //     hevm.warp(paymentDueBy);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 11
    //     hevm.warp(paymentDueBy);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     // Pre-state final payment (12th) check.
    //     (principalOwed, interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     (,,,,, paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);

    //     assertEq(paymentsRemaining, 1);
    //     assertEq(principalOwed, 10000 ether);
    //     assertEq(interestOwed,  123287671232876712328);

    //     pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
    //     uint256 pre_FRAX_DAO = IERC20(FRAX).balanceOf(OCC_0_FRAX.owner());

    //     // Make final payment (with principal).
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     // Post-state final payment check.
    //     post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
    //     uint256 post_FRAX_DAO = IERC20(FRAX).balanceOf(OCC_0_FRAX.owner());

    //     assertEq(post_FRAX_DAO - pre_FRAX_DAO, 10000 ether);
    //     assertEq(pre_FRAX_bob - post_FRAX_bob, 10000 ether + interestOwed);

        
    //     (,principalOwed,,,,,,,,,)        = OCC_0_FRAX.loanInformation(id);
    //     (,,,,paymentDueBy,,,,,,)         = OCC_0_FRAX.loanInformation(id);
    //     (,,,,,paymentsRemaining,,,,,)    = OCC_0_FRAX.loanInformation(id);
    //     (,,,,,,,,,,uint256 loanState)    = OCC_0_FRAX.loanInformation(id);

    //     assertEq(principalOwed, 0);
    //     assertEq(paymentDueBy, 0);
    //     assertEq(paymentsRemaining, 0);
    //     assertEq(loanState, 3);

    // }

    // function xtest_OCC_FRAX_makePayment_state_changes_amortization() public {

    //     // Create new loan request and fund it.
    //     uint256 id = OCC_0_FRAX.counterID();

    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether,
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(1)
    //     ));


    //     // Add more FRAX into contract.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

    //     // Fund loan (5 days later).
    //     hevm.warp(block.timestamp + 5 days);
    //     assert(god.try_fundLoan(address(OCC_0_FRAX), id));

    //     // Give Bob money to make payments and approve FRAX.
    //     assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 20000 ether));
    //     mint("FRAX", address(bob), 20000 ether);

    //     // Pre-state first payment check.
    //     (,,,,uint256 paymentDueBy,,,,,,)      = OCC_0_FRAX.loanInformation(id);
    //     (,,,,,uint256 paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);
    //     (uint256 principalOwed, uint256 interestOwed,) = OCC_0_FRAX.amountOwed(id);

    //     assertEq(paymentDueBy, block.timestamp + 15 days);
    //     assertEq(paymentsRemaining, 12);
    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  123287671232876712328);

    //     uint256 pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));

    //     // Make first payment.
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     // Post-state first payment check.
    //     uint256 post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
    //     (,,,,, paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);

    //     assertEq(pre_FRAX_bob - post_FRAX_bob, interestOwed + principalOwed);
    //     assertEq(paymentsRemaining, 11);

    //     // Iterate through remaining interest payments.
    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 2
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  113013698630136986301);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 3
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  102739726027397260273);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 4
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  92465753424657534246);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 5
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  82191780821917808219);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 6
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  71917808219178082191);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 7
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  61643835616438356164);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 8
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  51369863013698630137);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 9
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333334);
    //     assertEq(interestOwed,  41095890410958904109);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 10
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333334);
    //     assertEq(interestOwed,  30821917808219178082);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 11
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333334);
    //     assertEq(interestOwed,  20547945205479452054);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     // Pre-state final payment (12th) check.
    //     (principalOwed, interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     (,,,,, paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);

    //     assertEq(paymentsRemaining, 1);
    //     assertEq(principalOwed, 833333333333333333334);
    //     assertEq(interestOwed,  10273972602739726027);

    //     pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
    //     uint256 pre_FRAX_DAO = IERC20(FRAX).balanceOf(OCC_0_FRAX.owner());

    //     // Make final payment (with principal).
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     // Post-state final payment check.
    //     post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
    //     uint256 post_FRAX_DAO = IERC20(FRAX).balanceOf(OCC_0_FRAX.owner());

    //     assertEq(post_FRAX_DAO - pre_FRAX_DAO, 833333333333333333334);
    //     assertEq(pre_FRAX_bob - post_FRAX_bob, 843607305936073059361);

        
    //     (,principalOwed,,,,,,,,,)        = OCC_0_FRAX.loanInformation(id);
    //     (,,,,paymentDueBy,,,,,,)         = OCC_0_FRAX.loanInformation(id);
    //     (,,,,,paymentsRemaining,,,,,)    = OCC_0_FRAX.loanInformation(id);
    //     (,,,,,,,,,,uint256 loanState)    = OCC_0_FRAX.loanInformation(id);

    //     assertEq(principalOwed, 0);
    //     assertEq(paymentDueBy, 0);
    //     assertEq(paymentsRemaining, 0);
    //     assertEq(loanState, 3);

    // }

    // function xtest_OCC_FRAX_callLoan_state_changes_amortization() public {

    //     // Create new loan request and fund it.
    //     uint256 id = OCC_0_FRAX.counterID();

    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether,
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(1)
    //     ));


    //     // Add more FRAX into contract.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

    //     // Fund loan (5 days later).
    //     hevm.warp(block.timestamp + 5 days);
    //     assert(god.try_fundLoan(address(OCC_0_FRAX), id));

    //     // Give Bob money to make payments and approve FRAX.
    //     assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 20000 ether));
    //     mint("FRAX", address(bob), 20000 ether);

    //     // Pre-state first payment check.
    //     (,,,,uint256 paymentDueBy,,,,,,)      = OCC_0_FRAX.loanInformation(id);
    //     (,,,,,uint256 paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);
    //     (uint256 principalOwed, uint256 interestOwed,) = OCC_0_FRAX.amountOwed(id);

    //     assertEq(paymentDueBy, block.timestamp + 15 days);
    //     assertEq(paymentsRemaining, 12);
    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  123287671232876712328);

    //     uint256 pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));

    //     // Make first payment.
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     // Post-state first payment check.
    //     uint256 post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
    //     (,,,,, paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);

    //     assertEq(pre_FRAX_bob - post_FRAX_bob, interestOwed + principalOwed);
    //     assertEq(paymentsRemaining, 11);

    //     // Iterate through a few principal and interest payments.
    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 2
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  113013698630136986301);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 3
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  102739726027397260273);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 4
    //     hevm.warp(paymentDueBy);
    //     (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
    //     assertEq(principalOwed, 833333333333333333333);
    //     assertEq(interestOwed,  92465753424657534246);
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     // Pre-state check.
    //     hevm.warp(paymentDueBy - 1 days);
    //     (,principalOwed,,,,,,,,,)       = OCC_0_FRAX.loanInformation(id);
    //     (,,,,,paymentsRemaining,,,,,)   = OCC_0_FRAX.loanInformation(id);
    //     (,,,,,,,,,,uint256 loanState)   = OCC_0_FRAX.loanInformation(id);

    //     assertEq(principalOwed, 6666666666666666666668);
    //     assertEq(paymentsRemaining,  8);
    //     assertEq(loanState,  2);

    //     // Call the loan (paying it off in full).
    //     assert(bob.try_callLoan(address(OCC_0_FRAX), id));

    //     // Post-state check.
    //     (,principalOwed,,,,,,,,,)       = OCC_0_FRAX.loanInformation(id);
    //     (,,,,,paymentsRemaining,,,,,)   = OCC_0_FRAX.loanInformation(id);
    //     (,,,,,,,,,,loanState)           = OCC_0_FRAX.loanInformation(id);

    //     assertEq(principalOwed, 0);
    //     assertEq(paymentsRemaining,  0);
    //     assertEq(loanState,  3);
        
    // }

  
    // function xtest_OCC_FRAX_supplyInterest_state_changes() public {
        
    //     // Create new loan request and fund it.
    //     uint256 id = OCC_0_FRAX.counterID();

    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether,
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(0)
    //     ));


    //     // Add more FRAX into contract.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

    //     // Fund loan (5 days later).
    //     hevm.warp(block.timestamp + 5 days);
    //     assert(god.try_fundLoan(address(OCC_0_FRAX), id));

    //     // Can't make payment on a Repaid loan (simulate many payments to end to reach Repaid state first).
    //     assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 20000 ether));

    //     mint("FRAX", address(bob), 20000 ether);

    //     // 12 payments.
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));
    //     assert(bob.try_makePayment(address(OCC_0_FRAX), id));

    //     // After final payment (12th), loan is in Repaid state.
    //     (,,,,,,,,,,uint256 loanState) = OCC_0_FRAX.loanInformation(id);
    //     assertEq(loanState, 3);

    // }
    
}
