// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../TESTS_Basic/Utility.sol";

import "../ZivoeOCCLockers/OCC_FRAX.sol";

contract OCC_FRAXTest is Utility {

    OCC_FRAX OCC_0_FRAX;

    function setUp() public {

        setUpFundedDAO();

        // Initialize and whitelist MyAAVELocker
        OCC_0_FRAX = new OCC_FRAX(address(DAO), address(YDL), address(gov));
        god.try_modifyLockerWhitelist(address(DAO), address(OCC_0_FRAX), true);

    }

    function test_OCC_FRAX_init() public {
        assertEq(OCC_0_FRAX.owner(),                address(DAO));
        assertEq(OCC_0_FRAX.YDL(),                  address(YDL));
        assertEq(OCC_0_FRAX.DAI(),                  DAI);
        assertEq(OCC_0_FRAX.FRAX(),                 FRAX);
        assertEq(OCC_0_FRAX.USDC(),                 USDC);
        assertEq(OCC_0_FRAX.USDT(),                 USDT);
        assertEq(OCC_0_FRAX.CRV_PP(),               0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);    // 3pool
        assertEq(OCC_0_FRAX.FRAX3CRV_MP(),          0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B);    // meta-pool (FRAX/3CRV)
    }

    // Simulate depositing various stablecoins into OCC_FRAX.sol from ZivoeDAO.sol via ZivoeDAO::pushToLocker().

    function test_OCC_FRAX_push() public {

        // Push 1mm USDC + USDT + DAI + FRAX to locker.
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDT), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(DAI),  1000000 * 10**18));
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(FRAX), 1000000 * 10**18));

        // Post-state checks.
        // Ensuring aUSDC received is within 5000 (out of 4mm, so .125% slippage/fees allowed here, increase if needed depending on main-net state).
        withinDiff(IERC20(FRAX).balanceOf(address(OCC_0_FRAX)), 4000000 * 10**18, 5000 * 10**18);

    }

    // Simulate pulling FRAX after depositing various stablecoins.

    function test_OCC_FRAX_pull() public {

        // Push 1mm USDC + USDT + DAI + FRAX to locker.
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDT), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(DAI),  1000000 * 10**18));
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(FRAX), 1000000 * 10**18));

        emit Debug('USDC', IERC20(address(USDC)).balanceOf(address(OCC_0_FRAX)));
        emit Debug('USDT', IERC20(address(USDT)).balanceOf(address(OCC_0_FRAX)));
        emit Debug('DAI', IERC20(address(DAI)).balanceOf(address(OCC_0_FRAX)));
        emit Debug('FRAX', IERC20(address(FRAX)).balanceOf(address(OCC_0_FRAX)));

        assert(god.try_pull(address(DAO), address(OCC_0_FRAX), address(FRAX)));

    }

    // requestLoan() restrictions
    // requestLoan() state changes

    function test_OCC_FRAX_requestLoan_restrictions() public {
        
        // APR > 3600 not allowed.
        assert(!bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether, 
            3601,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));

        // APRLateFee > 3600 not allowed.
        assert(!bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether, 
            3000,
            3601,
            12,
            86400 * 14,
            int8(0)
        ));

        // term == 0 not allowed.
        assert(!bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether, 
            3000,
            1500,
            0,
            86400 * 14,
            int8(0)
        ));

        // paymentInterval == 86400 * 3.5 || 86400 * 7 || 86400 * 14 || 86400 * 30 enforced.
        assert(!bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether, 
            3000,
            1500,
            12,
            86400 * 13,
            int8(0)
        ));
    }

    function test_OCC_FRAX_requestLoan_state_changes() public {

        // Pre-state check.
        assertEq(OCC_0_FRAX.counterID(), 0);
        (
            address borrower, 
            uint256 principalOwed, 
            uint256 APR, 
            uint256 APRLateFee, 
            uint256 paymentDueBy,
            uint256 paymentsRemaining,
            uint256 term,
            uint256 paymentInterval,
            uint256 requestExpiry,
            int8    paymentSchedule,
            uint256 loanState
        ) = OCC_0_FRAX.loanInformation(0);

        assertEq(borrower,              address(0));
        assertEq(principalOwed,         0);
        assertEq(APR,                   0);
        assertEq(APRLateFee,            0);
        assertEq(paymentDueBy,          0);
        assertEq(paymentsRemaining,     0);
        assertEq(term,                  0);
        assertEq(paymentInterval,       0);
        assertEq(paymentSchedule,       0);
        assertEq(loanState,             0);
        
        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether, 
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));

        // Post-state check.
        (borrower,,,,,,,,,,)          = OCC_0_FRAX.loanInformation(0);
        (,principalOwed,,,,,,,,,)     = OCC_0_FRAX.loanInformation(0);
        (,,APR,,,,,,,,)               = OCC_0_FRAX.loanInformation(0);
        (,,,APRLateFee,,,,,,,)        = OCC_0_FRAX.loanInformation(0);
        (,,,,paymentDueBy,,,,,,)      = OCC_0_FRAX.loanInformation(0);
        (,,,,,paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(0);
        (,,,,,,term,,,,)              = OCC_0_FRAX.loanInformation(0);
        (,,,,,,,paymentInterval,,,)   = OCC_0_FRAX.loanInformation(0);
        (,,,,,,,,requestExpiry,,)     = OCC_0_FRAX.loanInformation(0);
        (,,,,,,,,,paymentSchedule,)   = OCC_0_FRAX.loanInformation(0);
        (,,,,,,,,,,loanState)         = OCC_0_FRAX.loanInformation(0);
            
        assertEq(borrower,              address(bob));
        assertEq(principalOwed,         10000 ether);
        assertEq(APR,                   3000);
        assertEq(APRLateFee,            1500);
        assertEq(paymentDueBy,          0);
        assertEq(paymentsRemaining,     12);
        assertEq(term,                  12);
        assertEq(paymentInterval,       86400 * 14);
        assertEq(requestExpiry,         block.timestamp + 14 days);
        assertEq(paymentSchedule,       0);
        assertEq(loanState,             1);

        assertEq(OCC_0_FRAX.counterID(), 1);

        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            50000 ether, 
            3500,
            1800,
            24,
            86400 * 30,
            int8(1)
        ));

        // Post-state check.
        (borrower,,,,,,,,,,)          = OCC_0_FRAX.loanInformation(1);
        (,principalOwed,,,,,,,,,)     = OCC_0_FRAX.loanInformation(1);
        (,,APR,,,,,,,,)               = OCC_0_FRAX.loanInformation(1);
        (,,,APRLateFee,,,,,,,)        = OCC_0_FRAX.loanInformation(1);
        (,,,,paymentDueBy,,,,,,)      = OCC_0_FRAX.loanInformation(1);
        (,,,,,paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(1);
        (,,,,,,term,,,,)              = OCC_0_FRAX.loanInformation(1);
        (,,,,,,,paymentInterval,,,)   = OCC_0_FRAX.loanInformation(1);
        (,,,,,,,,requestExpiry,,)     = OCC_0_FRAX.loanInformation(1);
        (,,,,,,,,,paymentSchedule,)   = OCC_0_FRAX.loanInformation(1);
        (,,,,,,,,,,loanState)         = OCC_0_FRAX.loanInformation(1);
        
        assertEq(borrower,              address(bob));
        assertEq(principalOwed,         50000 ether);
        assertEq(APR,                   3500);
        assertEq(APRLateFee,            1800);
        assertEq(paymentDueBy,          0);
        assertEq(paymentsRemaining,     24);
        assertEq(term,                  24);
        assertEq(paymentInterval,       86400 * 30);
        assertEq(requestExpiry,         block.timestamp + 14 days);
        assertEq(paymentSchedule,       1);
        assertEq(loanState,             1);

        assertEq(OCC_0_FRAX.counterID(), 2);

    }

    // cancelRequest() restrictions
    // cancelRequest() state changes

    function test_OCC_FRAX_cancelRequest_restrictions() public {

        uint256 id = OCC_0_FRAX.counterID();
        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));
        
        // Can't cancel loan if msg.sender != borrower (loan requester).
        assert(!god.try_cancelRequest(address(OCC_0_FRAX), id));

        // Can't cancel loan if state != initialized (in this case, already cancelled).
        assert(bob.try_cancelRequest(address(OCC_0_FRAX), id));
        assert(!bob.try_cancelRequest(address(OCC_0_FRAX), id));
    }

    function test_OCC_FRAX_cancelRequest_state_changes() public {

        uint256  id = OCC_0_FRAX.counterID();
        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));

        // Pre-state check.
        (,,,,,,,,,,uint256 loanState) = OCC_0_FRAX.loanInformation(id);
        assertEq(loanState, 1);

        assert(bob.try_cancelRequest(address(OCC_0_FRAX), id));

        // Post-state check.
        (,,,,,,,,,,loanState) = OCC_0_FRAX.loanInformation(id);
        assertEq(loanState, 5);
    }

    // fundLoan() restrictions
    // fundLoan() state changes

    function test_OCC_FRAX_fundLoan_restrictions() public {
        
        uint256 id = OCC_0_FRAX.counterID();
        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));

        // Can't fundLoan() if FRAX balance is below requested amount.
        // In this case it will revert due to 0 balance of FRAX available
        assert(!gov.try_fundLoan(address(OCC_0_FRAX), id));

        // Can't fundLoan() if LoanState != Initialized
        // Demonstrate this by cancelling above request.
        assert(bob.try_cancelRequest(address(OCC_0_FRAX), id));
        assert(!gov.try_fundLoan(address(OCC_0_FRAX), id));

        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

        // Ensure greater than 10k FRAX (loan request) is available.
        assert(IERC20(FRAX).balanceOf(address(OCC_0_FRAX)) > 10000 ether);
        
        (, uint256 principalOwed,,,,,,,,,) = OCC_0_FRAX.loanInformation(0);
        assertEq(principalOwed, 10000 ether);

        // Prove loan is not fundable now that it's cancelled (still).
        assert(!gov.try_fundLoan(address(OCC_0_FRAX), id));

        // Create new loan and warp past the requestExpiry timestamp.
        uint256 id2 = OCC_0_FRAX.counterID();
        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));
        hevm.warp(block.timestamp + 14 days);

        // Can't fundLoan if block.timestamp > requestExpiry.
        assert(!gov.try_fundLoan(address(OCC_0_FRAX), id2));

        // Prove warping back 1 second (edge-case) loan is then fundable.
        hevm.warp(block.timestamp - 1);
        assert(gov.try_fundLoan(address(OCC_0_FRAX), id2));

    }

    function test_OCC_FRAX_fundLoan_state_changes() public {

        // Pre-state check.
        uint256 id = OCC_0_FRAX.counterID();

        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));

        {
            (
                address borrower, 
                uint256 principalOwed, 
                uint256 APR, 
                uint256 APRLateFee, 
                uint256 paymentDueBy,
                uint256 paymentsRemaining,
                uint256 term,
                uint256 paymentInterval,
                uint256 requestExpiry,
                int8    paymentSchedule,
                uint256 loanState
            ) = OCC_0_FRAX.loanInformation(id);
            
            assertEq(borrower,              address(bob));
            assertEq(principalOwed,         10000 ether);
            assertEq(APR,                   3000);
            assertEq(APRLateFee,            1500);
            assertEq(paymentDueBy,          0);
            assertEq(paymentsRemaining,     12);
            assertEq(term,                  12);
            assertEq(paymentInterval,       86400 * 14);
            assertEq(requestExpiry,         block.timestamp + 14 days);
            assertEq(paymentSchedule,       0);
            assertEq(loanState,             1);
        }
    

        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

        uint256 occ_FRAX_pre = IERC20(FRAX).balanceOf(address(OCC_0_FRAX));
        uint256 bob_FRAX_pre = IERC20(FRAX).balanceOf(address(bob));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_0_FRAX), id));

        // Post-state check.
        {
            (
                address borrower, 
                uint256 principalOwed, 
                uint256 APR, 
                uint256 APRLateFee, 
                uint256 paymentDueBy,
                uint256 paymentsRemaining,
                uint256 term,
                uint256 paymentInterval,
                uint256 requestExpiry,
                int8    paymentSchedule,
                uint256 loanState
            ) = OCC_0_FRAX.loanInformation(id);
                
            assertEq(borrower,              address(bob));
            assertEq(principalOwed,         10000 ether);
            assertEq(APR,                   3000);
            assertEq(APRLateFee,            1500);
            assertEq(paymentDueBy,          block.timestamp + 86400 * 14);
            assertEq(paymentsRemaining,     12);
            assertEq(term,                  12);
            assertEq(paymentInterval,       86400 * 14);
            assertEq(requestExpiry,         block.timestamp + 9 days);
            assertEq(paymentSchedule,       0);
            assertEq(loanState,             2);
        }

        uint256 occ_FRAX_post = IERC20(FRAX).balanceOf(address(OCC_0_FRAX));
        uint256 bob_FRAX_post = IERC20(FRAX).balanceOf(address(bob));

        assertEq(bob_FRAX_post - bob_FRAX_pre, 10000 ether);
        assertEq(occ_FRAX_pre - occ_FRAX_post, 10000 ether);

    }

    function test_OCC_FRAX_fundLoan_firstPaymentInfo_bullet() public {

        // Pre-state check.
        uint256 id = OCC_0_FRAX.counterID();

        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));

        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_0_FRAX), id));

        (uint256 principalOwed, uint256 interestOwed, uint256 totalOwed) = OCC_0_FRAX.amountOwed(id);

        assertEq(principalOwed, 0);
        assertEq(interestOwed,  115068493150684931506);
        assertEq(totalOwed,     115068493150684931506);

        (,, uint256 APR, uint256 APRLateFee, uint256 paymentDueBy,,, uint256 paymentInterval,,,) = OCC_0_FRAX.loanInformation(id);

        // interestOwed = loans[id].principalOwed * (1 + loans[id].paymentInterval * loans[id].APR) / (86400 * 365 * 10000);

        uint interestOwedDirect = 10000 ether * paymentInterval * APR / (86400 * 365 * 10000);
        assertEq(interestOwed,  interestOwedDirect);
        emit Debug('totalOwed', totalOwed);
        assertEq(totalOwed,     interestOwedDirect);

        // if (block.timestamp > loans[id].paymentDueBy) {
        //     interestOwed += loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * loans[id].APRLateFee / (86400 * 365 * 10000);
        // }

        hevm.warp(paymentDueBy + 14 days);

        (principalOwed, interestOwed, totalOwed) = OCC_0_FRAX.amountOwed(id);

        uint interestOwedExtra = 10000 ether * (block.timestamp - paymentDueBy) * (APR + APRLateFee) / (86400 * 365 * 10000);

        assertEq(totalOwed, interestOwedDirect + interestOwedExtra);

    }

    function test_OCC_FRAX_fundLoan_firstPaymentInfo_amortization() public {

        // TODO: Refactor for amortization purposes.

        // Pre-state check.
        uint256 id = OCC_0_FRAX.counterID();

        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(1)
        ));

        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_0_FRAX), id));

        (uint256 principalOwed, uint256 interestOwed, uint256 totalOwed) = OCC_0_FRAX.amountOwed(id);

        assertEq(principalOwed, 833333333333333333333);
        assertEq(interestOwed,  115068493150684931506);
        assertEq(totalOwed,     948401826484018264839);

        (
            ,
            ,
            uint256 APR,
            uint256 APRLateFee,
            uint256 paymentDueBy,
            uint256 paymentsRemaining,
            ,
            uint256 paymentInterval,
            ,
            ,
        ) = OCC_0_FRAX.loanInformation(id);

        uint interestOwedDirect = 10000 ether * paymentInterval * APR / (86400 * 365 * 10000);
        uint principalOwedDirect = 10000 ether / paymentsRemaining;
        assertEq(interestOwed,   interestOwedDirect);
        assertEq(principalOwed,  principalOwedDirect);
        assertEq(totalOwed,      principalOwedDirect + interestOwedDirect);

        hevm.warp(paymentDueBy + 14 days);

        (principalOwed, interestOwed, totalOwed) = OCC_0_FRAX.amountOwed(id);

        uint interestOwedExtra = 10000 ether * (block.timestamp - paymentDueBy) * (APR + APRLateFee) / (86400 * 365 * 10000);

        assertEq(totalOwed, principalOwedDirect + interestOwedDirect + interestOwedExtra);

    }

    // markInsolvent() restrictions
    // markInsolvent() state changes

    function test_OCC_FRAX_markInsolvent_restrictions() public {

        // Create loan.
        uint256 id = OCC_0_FRAX.counterID();

        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));

        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_0_FRAX), id));

        // Can't markInsolvent() if not past paymentDueBy timestamp.
        // Logically: loans[id].paymentDueBy + 86400 * 60 >= block.timestamp
        (,,,,uint256 paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(0);
        hevm.warp(paymentDueBy + 1);
        assert(!bob.try_markInsolvent(address(OCC_0_FRAX), id));

        hevm.warp(paymentDueBy + 60 days);
        assert(!bob.try_markInsolvent(address(OCC_0_FRAX), id));

        hevm.warp(paymentDueBy + 60 days + 1);
        assert(bob.try_markInsolvent(address(OCC_0_FRAX), id));

    }

    function test_OCC_FRAX_markInsolvent_state_changes() public {

        // Create loan.
        uint256 id = OCC_0_FRAX.counterID();

        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));

        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_0_FRAX), id));

        // Pre-state check.
        (,,,,uint256 paymentDueBy,,,,,,uint256 loanState) = OCC_0_FRAX.loanInformation(0);
        assertEq(loanState, 2);

        // Mark loan insolvent.
        hevm.warp(paymentDueBy + 60 days + 1);
        assert(bob.try_markInsolvent(address(OCC_0_FRAX), id));

        // Post-state check.
        (,,,,,,,,,,loanState) = OCC_0_FRAX.loanInformation(0);
        assertEq(loanState, 4);

    }

    // makePayment() restrictions
    // makePayment() state changes

    function test_OCC_FRAX_makePayment_restrictions() public {

        // Can't make payment on a Null loan (some id beyond what's been initialized, e.g. id + 1).
        (,,,,,,,,,,uint256 loanState) = OCC_0_FRAX.loanInformation(0);
        assertEq(loanState, 0);
        assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 10000 ether));
        assert(!bob.try_makePayment(address(OCC_0_FRAX), 0));

        // Create loan.
        uint256 id = OCC_0_FRAX.counterID();

        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));

        // Can't make payment on an Initialized (non-funded) loan.
        (,,,,,,,,,,loanState) = OCC_0_FRAX.loanInformation(id);
        assertEq(loanState, 1);
        assert(!bob.try_makePayment(address(OCC_0_FRAX), id));

        // Can't make payment on a Cancelled loan.
        assert(bob.try_cancelRequest(address(OCC_0_FRAX), id));
        (,,,,,,,,,,loanState) = OCC_0_FRAX.loanInformation(id);
        assertEq(loanState, 5);
        assert(!bob.try_makePayment(address(OCC_0_FRAX), id));

        // Create new loan request and fund it.
        id = OCC_0_FRAX.counterID();

        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));


        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_0_FRAX), id));

        // Can't make payment on a Repaid loan (simulate many payments to end to reach Repaid state first).
        assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 20000 ether));

        mint("FRAX", address(bob), 20000 ether);

        // 12 payments.
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        // After final payment (12th), loan is in Repaid state, and makePayment() will not work.
        (,,,,,,,,,,loanState) = OCC_0_FRAX.loanInformation(id);
        assertEq(loanState, 3);
        assert(!bob.try_makePayment(address(OCC_0_FRAX), id));

    }

    function test_OCC_FRAX_makePayment_state_changes_bullet() public {

        // Create new loan request and fund it.
        uint256 id = OCC_0_FRAX.counterID();

        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));


        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_0_FRAX), id));

        // Give Bob money to make payments and approve FRAX.
        assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 20000 ether));
        mint("FRAX", address(bob), 20000 ether);

        // Pre-state first payment check.
        (,,,,uint256 paymentDueBy,,,,,,)      = OCC_0_FRAX.loanInformation(id);
        (,,,,,uint256 paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);
        (uint256 principalOwed, uint256 interestOwed,) = OCC_0_FRAX.amountOwed(id);

        assertEq(paymentDueBy, block.timestamp + 14 days);
        assertEq(paymentsRemaining, 12);
        assertEq(principalOwed, 0);
        assertEq(interestOwed,  115068493150684931506);

        uint256 pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));

        // Make first payment.
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        // Post-state first payment check.
        uint256 post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
        (,,,,, paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);

        assertEq(pre_FRAX_bob - post_FRAX_bob, interestOwed);
        assertEq(paymentsRemaining, 11);

        // Iterate through remaining interest payments.
        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 2
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 3
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 4
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 5
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 6
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 7
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 8
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 9
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 10
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 11
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        // Pre-state final payment (12th) check.
        (principalOwed, interestOwed,) = OCC_0_FRAX.amountOwed(id);
        (,,,,, paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);

        assertEq(paymentsRemaining, 1);
        assertEq(principalOwed, 10000 ether);
        assertEq(interestOwed,  115068493150684931506);

        pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
        uint256 pre_FRAX_DAO = IERC20(FRAX).balanceOf(OCC_0_FRAX.owner());

        // Make final payment (with principal).
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        // Post-state final payment check.
        post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
        uint256 post_FRAX_DAO = IERC20(FRAX).balanceOf(OCC_0_FRAX.owner());

        assertEq(post_FRAX_DAO - pre_FRAX_DAO, 10000 ether);
        assertEq(pre_FRAX_bob - post_FRAX_bob, 10000 ether + interestOwed);

        
        (,principalOwed,,,,,,,,,)        = OCC_0_FRAX.loanInformation(id);
        (,,,,paymentDueBy,,,,,,)         = OCC_0_FRAX.loanInformation(id);
        (,,,,,paymentsRemaining,,,,,)    = OCC_0_FRAX.loanInformation(id);
        (,,,,,,,,,,uint256 loanState)    = OCC_0_FRAX.loanInformation(id);

        assertEq(principalOwed, 0);
        assertEq(paymentDueBy, 0);
        assertEq(paymentsRemaining, 0);
        assertEq(loanState, 3);

    }

    function test_OCC_FRAX_makePayment_state_changes_amortization() public {

        // TODO: Refactor this for amortization purposes.

        // Create new loan request and fund it.
        uint256 id = OCC_0_FRAX.counterID();

        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(1)
        ));


        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_0_FRAX), id));

        // Give Bob money to make payments and approve FRAX.
        assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 20000 ether));
        mint("FRAX", address(bob), 20000 ether);

        // Pre-state first payment check.
        (,,,,uint256 paymentDueBy,,,,,,)      = OCC_0_FRAX.loanInformation(id);
        (,,,,,uint256 paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);
        (uint256 principalOwed, uint256 interestOwed,) = OCC_0_FRAX.amountOwed(id);

        assertEq(paymentDueBy, block.timestamp + 14 days);
        assertEq(paymentsRemaining, 12);
        assertEq(principalOwed, 833333333333333333333);
        assertEq(interestOwed,  115068493150684931506);

        uint256 pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));

        // Make first payment.
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        // Post-state first payment check.
        uint256 post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
        (,,,,, paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);

        assertEq(pre_FRAX_bob - post_FRAX_bob, interestOwed + principalOwed);
        assertEq(paymentsRemaining, 11);

        // Iterate through remaining interest payments.
        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 2
        hevm.warp(paymentDueBy);
        (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
        assertEq(principalOwed, 833333333333333333333);
        assertEq(interestOwed,  105479452054794520547);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 3
        hevm.warp(paymentDueBy);
        (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
        assertEq(principalOwed, 833333333333333333333);
        assertEq(interestOwed,  95890410958904109589);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 4
        hevm.warp(paymentDueBy);
        (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
        assertEq(principalOwed, 833333333333333333333);
        assertEq(interestOwed,  86301369863013698630);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 5
        hevm.warp(paymentDueBy);
        (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
        assertEq(principalOwed, 833333333333333333333);
        assertEq(interestOwed,  76712328767123287671);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 6
        hevm.warp(paymentDueBy);
        (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
        assertEq(principalOwed, 833333333333333333333);
        assertEq(interestOwed,  67123287671232876712);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 7
        hevm.warp(paymentDueBy);
        (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
        assertEq(principalOwed, 833333333333333333333);
        assertEq(interestOwed,  57534246575342465753);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 8
        hevm.warp(paymentDueBy);
        (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
        assertEq(principalOwed, 833333333333333333333);
        assertEq(interestOwed,  47945205479452054794);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 9
        hevm.warp(paymentDueBy);
        (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
        assertEq(principalOwed, 833333333333333333334);
        assertEq(interestOwed,  38356164383561643835);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 10
        hevm.warp(paymentDueBy);
        (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
        assertEq(principalOwed, 833333333333333333334);
        assertEq(interestOwed,  28767123287671232876);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        (,,,,paymentDueBy,,,,,,) = OCC_0_FRAX.loanInformation(id); // 11
        hevm.warp(paymentDueBy);
        (principalOwed,interestOwed,) = OCC_0_FRAX.amountOwed(id);
        assertEq(principalOwed, 833333333333333333334);
        assertEq(interestOwed,  19178082191780821917);
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        // Pre-state final payment (12th) check.
        (principalOwed, interestOwed,) = OCC_0_FRAX.amountOwed(id);
        (,,,,, paymentsRemaining,,,,,) = OCC_0_FRAX.loanInformation(id);

        assertEq(paymentsRemaining, 1);
        assertEq(principalOwed, 833333333333333333334);
        assertEq(interestOwed,  9589041095890410958);

        pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
        uint256 pre_FRAX_DAO = IERC20(FRAX).balanceOf(OCC_0_FRAX.owner());

        // Make final payment (with principal).
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        // Post-state final payment check.
        post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
        uint256 post_FRAX_DAO = IERC20(FRAX).balanceOf(OCC_0_FRAX.owner());

        assertEq(post_FRAX_DAO - pre_FRAX_DAO, 833333333333333333334);
        assertEq(pre_FRAX_bob - post_FRAX_bob, 842922374429223744292);

        
        (,principalOwed,,,,,,,,,)        = OCC_0_FRAX.loanInformation(id);
        (,,,,paymentDueBy,,,,,,)         = OCC_0_FRAX.loanInformation(id);
        (,,,,,paymentsRemaining,,,,,)    = OCC_0_FRAX.loanInformation(id);
        (,,,,,,,,,,uint256 loanState)    = OCC_0_FRAX.loanInformation(id);

        assertEq(principalOwed, 0);
        assertEq(paymentDueBy, 0);
        assertEq(paymentsRemaining, 0);
        assertEq(loanState, 3);

    }

    // resolveInsolvency() restrictions
    // resolveInsolvency() state changes

    function test_OCC_FRAX_resolveInsolvency_restrictions() public {
        // TODO: Discuss this function. Delay till later.
    }

    function test_OCC_FRAX_resolveInsolvency_state_changes() public {
        // TODO: Discuss this function. Delay till later.
    }

    // supplyExcessInterest() restrictions
    // supplyExcessInterest() state changes

    function test_OCC_FRAX_supplyExcessInterest_restrictions() public {

        
        // Create new loan request.
        uint256 id = OCC_0_FRAX.counterID();

        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));

        // Can't suupplyExcessInterest on a non-Repaid loan.
        assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 20000 ether));
        mint("FRAX", address(bob), 20000 ether);

        assert(!bob.try_supplyExcessInterest(address(OCC_0_FRAX), id, 20000 ether));

    }

    function test_OCC_FRAX_supplyExcessInterest_state_changes() public {

        
        // Create new loan request and fund it.
        uint256 id = OCC_0_FRAX.counterID();

        assert(bob.try_requestLoan(
            address(OCC_0_FRAX),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14,
            int8(0)
        ));


        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_0_FRAX), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_0_FRAX), id));

        // Can't make payment on a Repaid loan (simulate many payments to end to reach Repaid state first).
        assert(bob.try_approveToken(address(FRAX), address(OCC_0_FRAX), 20000 ether));

        mint("FRAX", address(bob), 20000 ether);

        // 12 payments.
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));
        assert(bob.try_makePayment(address(OCC_0_FRAX), id));

        // After final payment (12th), loan is in Repaid state.
        (,,,,,,,,,,uint256 loanState) = OCC_0_FRAX.loanInformation(id);
        assertEq(loanState, 3);

        // Pre-state check.
        uint256 pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));

        // Supply excess interest ($500 in FRAX).
        assert(bob.try_supplyExcessInterest(address(OCC_0_FRAX), id, 500 ether));

        // Post-state check.
        uint256 post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));

        assertEq(pre_FRAX_bob - post_FRAX_bob, 500 ether);

    }
    
}
