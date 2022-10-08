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
        OCC_Modular_DAI = new OCC_Modular(address(DAO), address(DAI), address(GBL), address(zvl));
        OCC_Modular_FRAX = new OCC_Modular(address(DAO), address(FRAX), address(GBL), address(zvl));
        OCC_Modular_USDC = new OCC_Modular(address(DAO), address(USDC), address(GBL), address(zvl));
        OCC_Modular_USDT = new OCC_Modular(address(DAO), address(USDT), address(GBL), address(zvl));

        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_DAI), true);
        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_FRAX), true);
        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_USDC), true);
        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_USDT), true);

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function requestRandomLoan(uint96 random, bool choice, address asset) internal returns (uint256 loanID) {
        
        uint32[5] memory paymentInterval = [86400 * 7.5, 86400 * 15, 86400 * 30, 86400 * 90, 86400 * 360];

        uint256 borrowAmount = uint256(random);
        uint256 APR = uint256(random) % 3601;
        uint256 APRLateFee = uint256(random) % 3601;
        uint256 term = uint256(random) % 25 + 1;
        uint256 option = uint256(random) % 5;
        int8 paymentSchedule = choice ? int8(0) : int8(1);

        if (asset == DAI) {
            loanID = OCC_Modular_DAI.counterID();
            OCC_Modular_DAI.requestLoan(
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(paymentInterval[option]),
                paymentSchedule
            );
        }

        else if (asset == FRAX) {
            loanID = OCC_Modular_FRAX.counterID();
            OCC_Modular_FRAX.requestLoan(
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(paymentInterval[option]),
                paymentSchedule
            );
        }

        else if (asset == USDC) {
            loanID = OCC_Modular_USDC.counterID();
            OCC_Modular_USDC.requestLoan(
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(paymentInterval[option]),
                paymentSchedule
            );
        }

        else if (asset == USDT) {
            loanID = OCC_Modular_USDT.counterID();
            OCC_Modular_USDT.requestLoan(
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(paymentInterval[option]),
                paymentSchedule
            );
        }

        else { revert(); }

    }

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
        bool choice, 
        uint8 modularity
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

    function test_OCC_Modular_cancelLoan_restrictions(
        uint96 random, 
        bool choice
    ) {

        uint256 _loanID_DAI = requestRandomLoan(random, choice, DAI);
        uint256 _loanID_FRAX = requestRandomLoan(random, choice, FRAX);
        uint256 _loanID_USDC = requestRandomLoan(random, choice, USDC);
        uint256 _loanID_USDT = requestRandomLoan(random, choice, USDT);

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



    // // Simulate depositing various stablecoins into OCC_FRAX.sol from ZivoeDAO.sol via ZivoeDAO::pushToLocker().

    // function xtest_OCC_FRAX_push() public {

    //     // Push 1mm USDC + USDT + DAI + FRAX to locker.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 1000000 * 10**6));
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDT), 1000000 * 10**6));
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(DAI),  1000000 * 10**18));
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(FRAX), 1000000 * 10**18));

    //     // Post-state checks.
    //     // Ensuring aUSDC received is within 5000 (out of 4mm, so .125% slippage/fees allowed here, increase if needed depending on main-net state).
    //     withinDiff(IERC20(FRAX).balanceOf(address(OCC_0_FRAX)), 4000000 * 10**18, 5000 * 10**18);

    // }

    // // Simulate depositing then withdrawing partial amounts of FRAX via ZivoeDAO::pullPartial().

    // function xtest_OCC_FRAX_pullPartial() public {

    //     // Push 1mm USDC + USDT + DAI + FRAX to locker.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 1000000 * 10**6));
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDT), 1000000 * 10**6));
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(DAI),  1000000 * 10**18));
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(FRAX), 1000000 * 10**18));

    //     // Pre-state checks.
    //     // Ensuring aUSDC received is within 5000 (out of 4mm, so .125% slippage/fees allowed here, increase if needed depending on main-net state).
    //     withinDiff(IERC20(FRAX).balanceOf(address(OCC_0_FRAX)), 4000000 * 10**18, 5000 * 10**18);

    //     // Pull out partial amount (3mm FRAX).
    //     assert(god.try_pullPartial(address(DAO), address(OCC_0_FRAX), address(FRAX), 3000000 * 10**18));

    //     // Check within diff (1mm FRAX remaining).
    //     withinDiff(IERC20(FRAX).balanceOf(address(OCC_0_FRAX)), 1000000 * 10**18, 5000 * 10**18);

    // }

    // // Simulate pulling FRAX after depositing various stablecoins.

    // function xtest_OCC_FRAX_pull() public {

    //     // Push 1mm USDC + USDT + DAI + FRAX to locker.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 1000000 * 10**6));
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDT), 1000000 * 10**6));
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(DAI),  1000000 * 10**18));
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(FRAX), 1000000 * 10**18));

    //     emit Debug("USDC", IERC20(address(USDC)).balanceOf(address(OCC_0_FRAX)));
    //     emit Debug("USDT", IERC20(address(USDT)).balanceOf(address(OCC_0_FRAX)));
    //     emit Debug("DAI", IERC20(address(DAI)).balanceOf(address(OCC_0_FRAX)));
    //     emit Debug("FRAX", IERC20(address(FRAX)).balanceOf(address(OCC_0_FRAX)));

    //     assert(god.try_pull(address(DAO), address(OCC_0_FRAX), address(FRAX)));

    // }

    // // requestLoan() restrictions
    // // requestLoan() state changes

    // function xtest_OCC_FRAX_requestLoan_restrictions() public {
        
    //     // APR > 3600 not allowed.
    //     assert(!bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether, 
    //         3601,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(0)
    //     ));

    //     // APRLateFee > 3600 not allowed.
    //     assert(!bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether, 
    //         3000,
    //         3601,
    //         12,
    //         86400 * 15,
    //         int8(0)
    //     ));

    //     // term == 0 not allowed.
    //     assert(!bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether, 
    //         3000,
    //         1500,
    //         0,
    //         86400 * 15,
    //         int8(0)
    //     ));

    //     // paymentInterval == 86400 * 3.5 || 86400 * 7 || 86400 * 15 || 86400 * 30 enforced.
    //     assert(!bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether, 
    //         3000,
    //         1500,
    //         12,
    //         86400 * 13,
    //         int8(0)
    //     ));
    // }

    // function xtest_OCC_FRAX_requestLoan_state_changes() public {

    //     // Pre-state check.
    //     assertEq(OCC_0_FRAX.counterID(), 0);
    //     (
    //         address borrower, 
    //         uint256 principalOwed, 
    //         uint256 APR, 
    //         uint256 APRLateFee, 
    //         uint256 paymentDueBy,
    //         uint256 paymentsRemaining,
    //         uint256 term,
    //         uint256 paymentInterval,
    //         uint256 requestExpiry,
    //         int8    paymentSchedule,
    //         uint256 loanState
    //     ) = OCC_0_FRAX.loanInformation(0);

    //     assertEq(borrower,              address(0));
    //     assertEq(principalOwed,         0);
    //     assertEq(APR,                   0);
    //     assertEq(APRLateFee,            0);
    //     assertEq(paymentDueBy,          0);
    //     assertEq(paymentsRemaining,     0);
    //     assertEq(term,                  0);
    //     assertEq(paymentInterval,       0);
    //     assertEq(paymentSchedule,       0);
    //     assertEq(loanState,             0);
        
    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether, 
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(0)
    //     ));

    //     // Post-state check.
    //     (borrower,,,,,,,,,,)          = OCC_0_FRAX.loanInformation(0);
    //     (,principalOwed,,,,,,,,,)     = OCC_0_FRAX.loanInformation(0);
    //     (,,APR,,,,,,,,)               = OCC_0_FRAX.loanInformation(0);
    //     (,,,APRLateFee,,,,,,,)        = OCC_0_FRAX.loanInformation(0);
    //     (,,,,paymentDueBy,,,,,,)      = OCC_0_FRAX.loanInformation(0);
    //     (,,,,,paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(0);
    //     (,,,,,,term,,,,)              = OCC_0_FRAX.loanInformation(0);
    //     (,,,,,,,paymentInterval,,,)   = OCC_0_FRAX.loanInformation(0);
    //     (,,,,,,,,requestExpiry,,)     = OCC_0_FRAX.loanInformation(0);
    //     (,,,,,,,,,paymentSchedule,)   = OCC_0_FRAX.loanInformation(0);
    //     (,,,,,,,,,,loanState)         = OCC_0_FRAX.loanInformation(0);
            
    //     assertEq(borrower,              address(bob));
    //     assertEq(principalOwed,         10000 ether);
    //     assertEq(APR,                   3000);
    //     assertEq(APRLateFee,            1500);
    //     assertEq(paymentDueBy,          0);
    //     assertEq(paymentsRemaining,     12);
    //     assertEq(term,                  12);
    //     assertEq(paymentInterval,       86400 * 15);
    //     assertEq(requestExpiry,         block.timestamp + 14 days);
    //     assertEq(paymentSchedule,       0);
    //     assertEq(loanState,             1);

    //     assertEq(OCC_0_FRAX.counterID(), 1);

    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         50000 ether, 
    //         3500,
    //         1800,
    //         24,
    //         86400 * 30,
    //         int8(1)
    //     ));

    //     // Post-state check.
    //     (borrower,,,,,,,,,,)          = OCC_0_FRAX.loanInformation(1);
    //     (,principalOwed,,,,,,,,,)     = OCC_0_FRAX.loanInformation(1);
    //     (,,APR,,,,,,,,)               = OCC_0_FRAX.loanInformation(1);
    //     (,,,APRLateFee,,,,,,,)        = OCC_0_FRAX.loanInformation(1);
    //     (,,,,paymentDueBy,,,,,,)      = OCC_0_FRAX.loanInformation(1);
    //     (,,,,,paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(1);
    //     (,,,,,,term,,,,)              = OCC_0_FRAX.loanInformation(1);
    //     (,,,,,,,paymentInterval,,,)   = OCC_0_FRAX.loanInformation(1);
    //     (,,,,,,,,requestExpiry,,)     = OCC_0_FRAX.loanInformation(1);
    //     (,,,,,,,,,paymentSchedule,)   = OCC_0_FRAX.loanInformation(1);
    //     (,,,,,,,,,,loanState)         = OCC_0_FRAX.loanInformation(1);
        
    //     assertEq(borrower,              address(bob));
    //     assertEq(principalOwed,         50000 ether);
    //     assertEq(APR,                   3500);
    //     assertEq(APRLateFee,            1800);
    //     assertEq(paymentDueBy,          0);
    //     assertEq(paymentsRemaining,     24);
    //     assertEq(term,                  24);
    //     assertEq(paymentInterval,       86400 * 30);
    //     assertEq(requestExpiry,         block.timestamp + 14 days);
    //     assertEq(paymentSchedule,       1);
    //     assertEq(loanState,             1);

    //     assertEq(OCC_0_FRAX.counterID(), 2);

    // }

    // // cancelRequest() restrictions
    // // cancelRequest() state changes

    // function xtest_OCC_FRAX_cancelRequest_restrictions() public {

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
        
    //     // Can't cancel loan if msg.sender != borrower (loan requester).
    //     assert(!god.try_cancelRequest(address(OCC_0_FRAX), id));

    //     // Can't cancel loan if state != initialized (in this case, already cancelled).
    //     assert(bob.try_cancelRequest(address(OCC_0_FRAX), id));
    //     assert(!bob.try_cancelRequest(address(OCC_0_FRAX), id));
    // }

    // function xtest_OCC_FRAX_cancelRequest_state_changes() public {

    //     uint256  id = OCC_0_FRAX.counterID();
    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether,
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(0)
    //     ));

    //     // Pre-state check.
    //     (,,,,,,,,,,uint256 loanState) = OCC_0_FRAX.loanInformation(id);
    //     assertEq(loanState, 1);

    //     assert(bob.try_cancelRequest(address(OCC_0_FRAX), id));

    //     // Post-state check.
    //     (,,,,,,,,,,loanState) = OCC_0_FRAX.loanInformation(id);
    //     assertEq(loanState, 5);
    // }

    // // fundLoan() restrictions
    // // fundLoan() state changes

    // function xtest_OCC_FRAX_fundLoan_restrictions() public {
        
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

    //     // Can't fundLoan() if FRAX balance is below requested amount.
    //     // In this case it will revert due to 0 balance of FRAX available
    //     assert(!god.try_fundLoan(address(OCC_0_FRAX), id));

    //     // Can't fundLoan() if LoanState != Initialized
    //     // Demonstrate this by cancelling above request.
    //     assert(bob.try_cancelRequest(address(OCC_0_FRAX), id));
    //     assert(!god.try_fundLoan(address(OCC_0_FRAX), id));

    //     // Add more FRAX into contract.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

    //     // Ensure greater than 10k FRAX (loan request) is available.
    //     assert(IERC20(FRAX).balanceOf(address(OCC_0_FRAX)) > 10000 ether);
        
    //     (, uint256 principalOwed,,,,,,,,,) = OCC_0_FRAX.loanInformation(0);
    //     assertEq(principalOwed, 10000 ether);

    //     // Prove loan is not fundable now that it's cancelled (still).
    //     assert(!god.try_fundLoan(address(OCC_0_FRAX), id));

    //     // Create new loan and warp past the requestExpiry timestamp.
    //     uint256 id2 = OCC_0_FRAX.counterID();
    //     assert(bob.try_requestLoan(
    //         address(OCC_0_FRAX),
    //         10000 ether,
    //         3000,
    //         1500,
    //         12,
    //         86400 * 15,
    //         int8(0)
    //     ));
    //     hevm.warp(block.timestamp + 14 days);

    //     // Can't fundLoan if block.timestamp > requestExpiry.
    //     assert(!god.try_fundLoan(address(OCC_0_FRAX), id2));

    //     // Prove warping back 1 second (edge-case) loan is then fundable.
    //     hevm.warp(block.timestamp - 1);
    //     assert(god.try_fundLoan(address(OCC_0_FRAX), id2));

    // }

    // function xtest_OCC_FRAX_fundLoan_state_changes() public {

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

    //     {
    //         (
    //             address borrower, 
    //             uint256 principalOwed, 
    //             uint256 APR, 
    //             uint256 APRLateFee, 
    //             uint256 paymentDueBy,
    //             uint256 paymentsRemaining,
    //             uint256 term,
    //             uint256 paymentInterval,
    //             uint256 requestExpiry,
    //             int8    paymentSchedule,
    //             uint256 loanState
    //         ) = OCC_0_FRAX.loanInformation(id);
            
    //         assertEq(borrower,              address(bob));
    //         assertEq(principalOwed,         10000 ether);
    //         assertEq(APR,                   3000);
    //         assertEq(APRLateFee,            1500);
    //         assertEq(paymentDueBy,          0);
    //         assertEq(paymentsRemaining,     12);
    //         assertEq(term,                  12);
    //         assertEq(paymentInterval,       86400 * 15);
    //         assertEq(requestExpiry,         block.timestamp + 14 days);
    //         assertEq(paymentSchedule,       0);
    //         assertEq(loanState,             1);
    //     }
    

    //     // Add more FRAX into contract.
    //     assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

    //     uint256 occ_FRAX_pre = IERC20(FRAX).balanceOf(address(OCC_0_FRAX));
    //     uint256 bob_FRAX_pre = IERC20(FRAX).balanceOf(address(bob));

    //     // Fund loan (5 days later).
    //     hevm.warp(block.timestamp + 5 days);
    //     assert(god.try_fundLoan(address(OCC_0_FRAX), id));

    //     // Post-state check.
    //     {
    //         (
    //             address borrower, 
    //             uint256 principalOwed, 
    //             uint256 APR, 
    //             uint256 APRLateFee, 
    //             uint256 paymentDueBy,
    //             uint256 paymentsRemaining,
    //             uint256 term,
    //             uint256 paymentInterval,
    //             uint256 requestExpiry,
    //             int8    paymentSchedule,
    //             uint256 loanState
    //         ) = OCC_0_FRAX.loanInformation(id);
                
    //         assertEq(borrower,              address(bob));
    //         assertEq(principalOwed,         10000 ether);
    //         assertEq(APR,                   3000);
    //         assertEq(APRLateFee,            1500);
    //         assertEq(paymentDueBy,          block.timestamp + 86400 * 15);
    //         assertEq(paymentsRemaining,     12);
    //         assertEq(term,                  12);
    //         assertEq(paymentInterval,       86400 * 15);
    //         assertEq(requestExpiry,         block.timestamp + 9 days);
    //         assertEq(paymentSchedule,       0);
    //         assertEq(loanState,             2);
    //     }

    //     uint256 occ_FRAX_post = IERC20(FRAX).balanceOf(address(OCC_0_FRAX));
    //     uint256 bob_FRAX_post = IERC20(FRAX).balanceOf(address(bob));

    //     assertEq(bob_FRAX_post - bob_FRAX_pre, 10000 ether);
    //     assertEq(occ_FRAX_pre - occ_FRAX_post, 10000 ether);

    // }

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

    // // resolveInsolvency() restrictions
    // // resolveInsolvency() state changes

    // function xtest_OCC_FRAX_resolveInsolvency_restrictions() public {
        
    // }

    // function xtest_OCC_FRAX_resolveInsolvency_state_changes() public {
        
    // }

    // // supplyInterest() restrictions
    // // supplyInterest() state changes

    // function xtest_OCC_FRAX_supplyInterest_restrictions() public {

        
    //     // Create new loan request.
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

    //     // Can't suupplyInterest on a non-Redeemed loan.
    //     assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 20000 ether));
    //     mint("FRAX", address(bob), 20000 ether);

    //     assert(!bob.try_supplyInterest(address(OCC_0_FRAX), id, 20000 ether));

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
