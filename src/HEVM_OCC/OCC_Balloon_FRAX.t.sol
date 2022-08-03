// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../HEVM_Basic/Utility.sol";

import "../ZivoeOCCLockers/OCC_Balloon_FRAX.sol";

contract OCC_Balloon_FRAXTest is Utility {

    OCC_Balloon_FRAX OCC_BALLOON_FRAX_0;

    function setUp() public {

        setUpFundedDAO();

        // Initialize and whitelist MyAAVELocker
        OCC_BALLOON_FRAX_0 = new OCC_Balloon_FRAX(address(DAO), address(YDL), address(gov));
        god.try_modifyLockerWhitelist(address(DAO), address(OCC_BALLOON_FRAX_0), true);

    }

    function test_OCC_Balloon_FRAX_init() public {
        assertEq(OCC_BALLOON_FRAX_0.owner(),                address(DAO));
        assertEq(OCC_BALLOON_FRAX_0.YDL(),                  address(YDL));
        assertEq(OCC_BALLOON_FRAX_0.DAI(),                  DAI);
        assertEq(OCC_BALLOON_FRAX_0.FRAX(),                 FRAX);
        assertEq(OCC_BALLOON_FRAX_0.USDC(),                 USDC);
        assertEq(OCC_BALLOON_FRAX_0.USDT(),                 USDT);
        assertEq(OCC_BALLOON_FRAX_0.CRV_PP(),               0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);    // 3pool
        assertEq(OCC_BALLOON_FRAX_0.FRAX3CRV_MP(),          0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B);    // meta-pool (FRAX/3CRV)
    }

    // Simulate depositing various stablecoins into OCC_Balloon_FRAX.sol from ZivoeDAO.sol via ZivoeDAO::pushToLocker().

    function test_OCC_Balloon_FRAX_push() public {

        // Push 1mm USDC + USDT + DAI + FRAX to locker.
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDC), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDT), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(DAI),  1000000 * 10**18));
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(FRAX), 1000000 * 10**18));

        // Post-state checks.
        // Ensuring aUSDC received is within 5000 (out of 4mm, so .125% slippage/fees allowed here, increase if needed depending on main-net state).
        withinDiff(IERC20(FRAX).balanceOf(address(OCC_BALLOON_FRAX_0)), 4000000 * 10**18, 5000 * 10**18);

    }

    // Simulate pulling FRAX after depositing various stablecoins.
    // TODO: Create basic ZivoeLocker.t.sol contract (below function is inherited, not custom built).

    function test_OCC_Balloon_FRAX_pull() public {

        // Push 1mm USDC + USDT + DAI + FRAX to locker.
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDC), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDT), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(DAI),  1000000 * 10**18));
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(FRAX), 1000000 * 10**18));

        assert(god.try_pull(address(DAO), address(OCC_BALLOON_FRAX_0), address(FRAX)));

    }

    function getFRAX() public {
        // Push 2mm of USDC + USDT + DAI + FRAX to locker.
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDC), 2000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDT), 2000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(DAI),  2000000 * 10**18));
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(FRAX), 2000000 * 10**18));
    }

    // requestLoan() restrictions
    // requestLoan() state changes

    function test_OCC_Balloon_FRAX_requestLoan_restrictions() public {
        
        // APR > 3600 not allowed.
        assert(!bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether, 
            3601,
            1500,
            12,
            86400 * 14
        ));

        // APRLateFee > 3600 not allowed.
        assert(!bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether, 
            3000,
            3601,
            12,
            86400 * 14
        ));

        // term == 0 not allowed.
        assert(!bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether, 
            3000,
            1500,
            0,
            86400 * 14
        ));

        // paymentInterval == 86400 * 3.5 || 86400 * 7 || 86400 * 14 || 86400 * 30 enforced.
        assert(!bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether, 
            3000,
            1500,
            12,
            86400 * 13
        ));
    }

    function test_OCC_Balloon_FRAX_requestLoan_state_changes() public {

        // Pre-state check.
        assertEq(OCC_BALLOON_FRAX_0.counterID(), 0);
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
            uint256 loanState
        ) = OCC_BALLOON_FRAX_0.loanInformation(0);

        assertEq(borrower,              address(0));
        assertEq(principalOwed,         0);
        assertEq(APR,                   0);
        assertEq(APRLateFee,            0);
        assertEq(paymentDueBy,          0);
        assertEq(paymentsRemaining,     0);
        assertEq(term,                  0);
        assertEq(paymentInterval,       0);
        assertEq(loanState,             0);
        
        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether, 
            3000,
            1500,
            12,
            86400 * 14
        ));

        // Post-state check.
        (borrower,,,,,,,,,)          = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,principalOwed,,,,,,,,)     = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,APR,,,,,,,)               = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,APRLateFee,,,,,,)        = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,,paymentDueBy,,,,,)      = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,,,paymentsRemaining,,,,) = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,,,,term,,,)              = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,,,,,paymentInterval,,)   = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,,,,,,requestExpiry,)     = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,,,,,,,loanState)         = OCC_BALLOON_FRAX_0.loanInformation(0);
            
        assertEq(borrower,              address(bob));
        assertEq(principalOwed,         10000 ether);
        assertEq(APR,                   3000);
        assertEq(APRLateFee,            1500);
        assertEq(paymentDueBy,          0);
        assertEq(paymentsRemaining,     12);
        assertEq(term,                  12);
        assertEq(paymentInterval,       86400 * 14);
        assertEq(requestExpiry,         block.timestamp + 14 days);
        assertEq(loanState,             1);

        assertEq(OCC_BALLOON_FRAX_0.counterID(), 1);

    }

    // cancelRequest() restrictions
    // cancelRequest() state changes

    function test_OCC_Balloon_FRAX_cancelRequest_restrictions() public {

        uint256 id = OCC_BALLOON_FRAX_0.counterID();
        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));
        
        // Can't cancel loan if msg.sender != borrower (loan requester).
        assert(!god.try_cancelRequest(address(OCC_BALLOON_FRAX_0), id));

        // Can't cancel loan if state != initialized (in this case, already cancelled).
        assert(bob.try_cancelRequest(address(OCC_BALLOON_FRAX_0), id));
        assert(!bob.try_cancelRequest(address(OCC_BALLOON_FRAX_0), id));
    }

    function test_OCC_Balloon_FRAX_cancelRequest_state_changes() public {

        uint256  id = OCC_BALLOON_FRAX_0.counterID();
        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));

        // Pre-state check.
        (,,,,,,,,, uint256 loanState) = OCC_BALLOON_FRAX_0.loanInformation(id);
        assertEq(loanState, 1);

        assert(bob.try_cancelRequest(address(OCC_BALLOON_FRAX_0), id));

        // Post-state check.
        (,,,,,,,,,loanState) = OCC_BALLOON_FRAX_0.loanInformation(id);
        assertEq(loanState, 5);
    }

    // fundLoan() restrictions
    // fundLoan() state changes

    function test_OCC_Balloon_FRAX_fundLoan_restrictions() public {
        
        uint256 id = OCC_BALLOON_FRAX_0.counterID();
        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));

        // Can't fundLoan() if FRAX balance is below requested amount.
        // In this case it will revert due to 0 balance of FRAX available
        assert(!gov.try_fundLoan(address(OCC_BALLOON_FRAX_0), id));

        // Can't fundLoan() if LoanState != Initialized
        // Demonstrate this by cancelling above request.
        assert(bob.try_cancelRequest(address(OCC_BALLOON_FRAX_0), id));
        assert(!gov.try_fundLoan(address(OCC_BALLOON_FRAX_0), id));

        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDC), 500000 * 10**6));

        // Ensure greater than 10k FRAX (loan request) is available.
        assert(IERC20(FRAX).balanceOf(address(OCC_BALLOON_FRAX_0)) > 10000 ether);
        
        (, uint256 principalOwed,,,,,,,,) = OCC_BALLOON_FRAX_0.loanInformation(0);
        assertEq(principalOwed, 10000 ether);

        // Prove loan is not fundable now that it's cancelled (still).
        assert(!gov.try_fundLoan(address(OCC_BALLOON_FRAX_0), id));

        // Create new loan and warp past the requestExpiry timestamp.
        uint256 id2 = OCC_BALLOON_FRAX_0.counterID();
        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));
        hevm.warp(block.timestamp + 14 days);

        // Can't fundLoan if block.timestamp > requestExpiry.
        assert(!gov.try_fundLoan(address(OCC_BALLOON_FRAX_0), id2));

        // Prove warping back 1 second (edge-case) loan is then fundable.
        hevm.warp(block.timestamp - 1);
        assert(gov.try_fundLoan(address(OCC_BALLOON_FRAX_0), id2));

    }

    function test_OCC_Balloon_FRAX_fundLoan_state_changes() public {

        // Pre-state check.
        uint256 id = OCC_BALLOON_FRAX_0.counterID();

        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));

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
            uint256 loanState
        ) = OCC_BALLOON_FRAX_0.loanInformation(id);
            
        assertEq(borrower,              address(bob));
        assertEq(principalOwed,         10000 ether);
        assertEq(APR,                   3000);
        assertEq(APRLateFee,            1500);
        assertEq(paymentDueBy,          0);
        assertEq(paymentsRemaining,     12);
        assertEq(term,                  12);
        assertEq(paymentInterval,       86400 * 14);
        assertEq(requestExpiry,         block.timestamp + 14 days);
        assertEq(loanState,             1);

        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDC), 500000 * 10**6));

        uint256 occ_FRAX_pre = IERC20(FRAX).balanceOf(address(OCC_BALLOON_FRAX_0));
        uint256 bob_FRAX_pre = IERC20(FRAX).balanceOf(address(bob));

        // Fund loan ( 5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_BALLOON_FRAX_0), id));

        // Post-state check.
        (borrower,,,,,,,,,)          = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,principalOwed,,,,,,,,)     = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,APR,,,,,,,)               = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,APRLateFee,,,,,,)        = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,,paymentDueBy,,,,,)      = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,,,paymentsRemaining,,,,) = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,,,,term,,,)              = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,,,,,paymentInterval,,)   = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,,,,,,requestExpiry,)     = OCC_BALLOON_FRAX_0.loanInformation(0);
        (,,,,,,,,,loanState)         = OCC_BALLOON_FRAX_0.loanInformation(0);

        uint256 occ_FRAX_post = IERC20(FRAX).balanceOf(address(OCC_BALLOON_FRAX_0));
        uint256 bob_FRAX_post = IERC20(FRAX).balanceOf(address(bob));
            
        assertEq(borrower,              address(bob));
        assertEq(principalOwed,         10000 ether);
        assertEq(APR,                   3000);
        assertEq(APRLateFee,            1500);
        assertEq(paymentDueBy,          block.timestamp + 86400 * 14);
        assertEq(paymentsRemaining,     12);
        assertEq(term,                  12);
        assertEq(paymentInterval,       86400 * 14);
        assertEq(requestExpiry,         block.timestamp + 9 days);
        assertEq(loanState,             2);

        assertEq(bob_FRAX_post - bob_FRAX_pre, 10000 ether);
        assertEq(occ_FRAX_pre - occ_FRAX_post, 10000 ether);

    }

    function test_OCC_Balloon_FRAX_fundLoan_firstPaymentInfo() public {

        // Pre-state check.
        uint256 id = OCC_BALLOON_FRAX_0.counterID();

        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));

        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_BALLOON_FRAX_0), id));

        (uint256 principalOwed, uint256 interestOwed, uint256 totalOwed) = OCC_BALLOON_FRAX_0.amountOwed(id);

        assertEq(principalOwed, 0);
        assertEq(interestOwed,  115068493150684931506);
        assertEq(totalOwed,     115068493150684931506);

        (,, uint256 APR, uint256 APRLateFee, uint256 paymentDueBy,,, uint256 paymentInterval,,) = OCC_BALLOON_FRAX_0.loanInformation(id);

        // interestOwed = loans[id].principalOwed * (1 + loans[id].paymentInterval * loans[id].APR) / (86400 * 365 * 10000);

        uint interestOwedDirect = 10000 ether * paymentInterval * APR / (86400 * 365 * 10000);
        assertEq(interestOwed,  interestOwedDirect);
        emit Debug('totalOwed', totalOwed);
        assertEq(totalOwed,     interestOwedDirect);

        // if (block.timestamp > loans[id].paymentDueBy) {
        //     interestOwed += loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * loans[id].APRLateFee / (86400 * 365 * 10000);
        // }

        hevm.warp(paymentDueBy + 14 days);

        (principalOwed, interestOwed, totalOwed) = OCC_BALLOON_FRAX_0.amountOwed(id);

        uint interestOwedExtra = 10000 ether * (block.timestamp - paymentDueBy) * (APR + APRLateFee) / (86400 * 365 * 10000);

        assertEq(totalOwed, interestOwedDirect + interestOwedExtra);

    }

    // markInsolvent() restrictions
    // markInsolvent() state changes

    function test_OCC_Balloon_FRAX_markInsolvent_restrictions() public {

        // Create loan.
        uint256 id = OCC_BALLOON_FRAX_0.counterID();

        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));

        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_BALLOON_FRAX_0), id));

        // Can't markInsolvent() if not past paymentDueBy timestamp.
        // Logically: loans[id].paymentDueBy + 86400 * 60 >= block.timestamp
        (,,,,uint256 paymentDueBy,,,,,) = OCC_BALLOON_FRAX_0.loanInformation(0);
        hevm.warp(paymentDueBy + 1);
        assert(!bob.try_markInsolvent(address(OCC_BALLOON_FRAX_0), id));

        hevm.warp(paymentDueBy + 60 days);
        assert(!bob.try_markInsolvent(address(OCC_BALLOON_FRAX_0), id));

        hevm.warp(paymentDueBy + 60 days + 1);
        assert(bob.try_markInsolvent(address(OCC_BALLOON_FRAX_0), id));

    }

    function test_OCC_Balloon_FRAX_markInsolvent_state_changes() public {

        // Create loan.
        uint256 id = OCC_BALLOON_FRAX_0.counterID();

        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));

        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_BALLOON_FRAX_0), id));

        // Pre-state check.
        (,,,,uint256 paymentDueBy,,,,, uint256 loanState) = OCC_BALLOON_FRAX_0.loanInformation(0);
        assertEq(loanState, 2);

        // Mark loan insolvent.
        hevm.warp(paymentDueBy + 60 days + 1);
        assert(bob.try_markInsolvent(address(OCC_BALLOON_FRAX_0), id));

        // Post-state check.
        (,,,,,,,,,loanState) = OCC_BALLOON_FRAX_0.loanInformation(0);
        assertEq(loanState, 4);

    }

    // makePayment() restrictions
    // makePayment() state changes

    function test_OCC_Balloon_FRAX_makePayment_restrictions() public {

        // Can't make payment on a Null loan (some id beyond what's been initialized, e.g. id + 1).
        (,,,,,,,,,uint256 loanState) = OCC_BALLOON_FRAX_0.loanInformation(0);
        assertEq(loanState, 0);
        assert(bob.try_approveToken(address(FRAX), address(OCC_BALLOON_FRAX_0), 10000 ether));
        assert(!bob.try_makePayment(address(OCC_BALLOON_FRAX_0), 0));

        // Create loan.
        uint256 id = OCC_BALLOON_FRAX_0.counterID();

        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));

        // Can't make payment on an Initialized (non-funded) loan.
        (,,,,,,,,,loanState) = OCC_BALLOON_FRAX_0.loanInformation(id);
        assertEq(loanState, 1);
        assert(!bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        // Can't make payment on a Cancelled loan.
        assert(bob.try_cancelRequest(address(OCC_BALLOON_FRAX_0), id));
        (,,,,,,,,,loanState) = OCC_BALLOON_FRAX_0.loanInformation(id);
        assertEq(loanState, 5);
        assert(!bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        // Create new loan request and fund it.
        id = OCC_BALLOON_FRAX_0.counterID();

        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));


        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_BALLOON_FRAX_0), id));

        // Can't make payment on a Repaid loan (simulate many payments to end to reach Repaid state first).
        assert(bob.try_approveToken(address(FRAX), address(OCC_BALLOON_FRAX_0), 20000 ether));

        mint("FRAX", address(bob), 20000 ether);

        // 12 payments.
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        // After final payment (12th), loan is in Repaid state, and makePayment() will not work.
        (,,,,,,,,,loanState) = OCC_BALLOON_FRAX_0.loanInformation(id);
        assertEq(loanState, 3);
        assert(!bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

    }

    function test_OCC_Balloon_FRAX_makePayment_state_changes() public {

        // Create new loan request and fund it.
        uint256 id = OCC_BALLOON_FRAX_0.counterID();

        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));


        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_BALLOON_FRAX_0), id));

        // Give Bob money to make payments and approve FRAX.
        assert(bob.try_approveToken(address(FRAX), address(OCC_BALLOON_FRAX_0), 20000 ether));
        mint("FRAX", address(bob), 20000 ether);

        // Pre-state first payment check.
        (,,,,uint256 paymentDueBy,,,,,)      = OCC_BALLOON_FRAX_0.loanInformation(id);
        (,,,,,uint256 paymentsRemaining,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id);
        (uint256 principalOwed, uint256 interestOwed,) = OCC_BALLOON_FRAX_0.amountOwed(id);

        assertEq(paymentDueBy, block.timestamp + 14 days);
        assertEq(paymentsRemaining, 12);
        assertEq(principalOwed, 0);
        assertEq(interestOwed,  115068493150684931506);

        uint256 pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));

        // Make first payment.
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        // Post-state first payment check.
        uint256 post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
        (,,,,, paymentsRemaining,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id);

        assertEq(pre_FRAX_bob - post_FRAX_bob, interestOwed);
        assertEq(paymentsRemaining, 11);

        // Iterate through remaining interest payments.
        (,,,,paymentDueBy,,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id); // 2
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        (,,,,paymentDueBy,,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id); // 3
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        (,,,,paymentDueBy,,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id); // 4
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        (,,,,paymentDueBy,,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id); // 5
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        (,,,,paymentDueBy,,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id); // 6
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        (,,,,paymentDueBy,,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id); // 7
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        (,,,,paymentDueBy,,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id); // 8
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        (,,,,paymentDueBy,,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id); // 9
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        (,,,,paymentDueBy,,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id); // 10
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        (,,,,paymentDueBy,,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id); // 11
        hevm.warp(paymentDueBy);
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        // Pre-state final payment (12th) check.
        (principalOwed, interestOwed,) = OCC_BALLOON_FRAX_0.amountOwed(id);
        (,,,,, paymentsRemaining,,,,) = OCC_BALLOON_FRAX_0.loanInformation(id);

        assertEq(paymentsRemaining, 1);
        assertEq(principalOwed, 10000 ether);
        assertEq(interestOwed,  115068493150684931506);

        pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
        uint256 pre_FRAX_DAO = IERC20(FRAX).balanceOf(OCC_BALLOON_FRAX_0.owner());

        // Make final payment (with principal).
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        // Post-state final payment check.
        post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));
        uint256 post_FRAX_DAO = IERC20(FRAX).balanceOf(OCC_BALLOON_FRAX_0.owner());

        assertEq(post_FRAX_DAO - pre_FRAX_DAO, 10000 ether);
        assertEq(pre_FRAX_bob - post_FRAX_bob, 10000 ether + interestOwed);

        
        (,principalOwed,,,,,,,,)        = OCC_BALLOON_FRAX_0.loanInformation(id);
        (,,,,paymentDueBy,,,,,)         = OCC_BALLOON_FRAX_0.loanInformation(id);
        (,,,,,paymentsRemaining,,,,)    = OCC_BALLOON_FRAX_0.loanInformation(id);
        (,,,,,,,,,uint256 loanState)    = OCC_BALLOON_FRAX_0.loanInformation(id);

        assertEq(principalOwed, 0);
        assertEq(paymentDueBy, 0);
        assertEq(paymentsRemaining, 0);
        assertEq(loanState, 3);

    }

    // resolveInsolvency() restrictions
    // resolveInsolvency() state changes

    function test_OCC_Balloon_FRAX_resolveInsolvency_restrictions() public {
        // TODO: Discuss this function. Delay till later.
    }

    function test_OCC_Balloon_FRAX_resolveInsolvency_state_changes() public {
        // TODO: Discuss this function. Delay till later.
    }

    // supplyExcessInterest() restrictions
    // supplyExcessInterest() state changes

    function test_OCC_Balloon_FRAX_supplyExcessInterest_restrictions() public {

        
        // Create new loan request.
        uint256 id = OCC_BALLOON_FRAX_0.counterID();

        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));

        // Can't suupplyExcessInterest on a non-Repaid loan.
        assert(bob.try_approveToken(address(FRAX), address(OCC_BALLOON_FRAX_0), 20000 ether));
        mint("FRAX", address(bob), 20000 ether);

        assert(!bob.try_supplyExcessInterest(address(OCC_BALLOON_FRAX_0), id, 20000 ether));

    }

    function test_OCC_Balloon_FRAX_supplyExcessInterest_state_changes() public {

        
        // Create new loan request and fund it.
        uint256 id = OCC_BALLOON_FRAX_0.counterID();

        assert(bob.try_requestLoan(
            address(OCC_BALLOON_FRAX_0),
            10000 ether,
            3000,
            1500,
            12,
            86400 * 14
        ));


        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_BALLOON_FRAX_0), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(gov.try_fundLoan(address(OCC_BALLOON_FRAX_0), id));

        // Can't make payment on a Repaid loan (simulate many payments to end to reach Repaid state first).
        assert(bob.try_approveToken(address(FRAX), address(OCC_BALLOON_FRAX_0), 20000 ether));

        mint("FRAX", address(bob), 20000 ether);

        // 12 payments.
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));
        assert(bob.try_makePayment(address(OCC_BALLOON_FRAX_0), id));

        // After final payment (12th), loan is in Repaid state.
        (,,,,,,,,,uint256 loanState) = OCC_BALLOON_FRAX_0.loanInformation(id);
        assertEq(loanState, 3);

        // Pre-state check.
        uint256 pre_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));

        // Supply excess interest ($500 in FRAX).
        assert(bob.try_supplyExcessInterest(address(OCC_BALLOON_FRAX_0), id, 500 ether));

        // Post-state check.
        uint256 post_FRAX_bob = IERC20(FRAX).balanceOf(address(bob));

        assertEq(pre_FRAX_bob - post_FRAX_bob, 500 ether);

    }
    
}
