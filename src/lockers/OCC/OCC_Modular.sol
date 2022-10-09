// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

import "../Utility/ZivoeSwapper.sol";

import { ICRV_PP_128_NP, ICRV_MP_256, ILendingPool, IZivoeGlobals, IZivoeYDL } from "../../misc/InterfacesAggregated.sol";

/// @dev    OCC stands for "On-Chain Credit Locker".
///         A "balloon" loan is an interest-only loan, with principal repaid in full at the end.
///         An "amortized" loan is a principal and interest loan, with consistent payments until fully "Repaid".
///         This locker is responsible for handling accounting of loans.
///         This locker is responsible for handling payments and distribution of payments.
///         This locker is responsible for handling defaults and liquidations (if needed).
contract OCC_Modular is ZivoeLocker, ZivoeSwapper {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    /// @dev Tracks state of the loan, enabling or disabling certain actions (function calls).
    /// @param Initialized Loan request has been created, not funded (or passed expiry date).
    /// @param Active Loan has been funded, is currently receiving payments.
    /// @param Repaid Loan was funded, and has been fully repaid.
    /// @param Defaulted Default state, loan isn't initialized yet.
    /// @param Cancelled Loan request was created, then cancelled prior to funding.
    /// @param Resolved Loan was funded, then there was a default, then the full amount of principal was repaid.
    enum LoanState { 
        Null,
        Initialized, 
        Active, 
        Repaid, 
        Defaulted, 
        Cancelled, 
        Resolved 
    }

    /// @dev Tracks payment schedule type of the loan.
    enum LoanSchedule { Balloon, Amortized }

    /// @dev Tracks the loan.
    struct Loan {
        address borrower;               /// @dev The address that receives capital when the loan is funded.
        uint256 principalOwed;          /// @dev The amount of principal still owed on the loan.
        uint256 APR;                    /// @dev The annualized percentage rate charged on the outstanding principal.
        uint256 APRLateFee;             /// @dev The annualized percentage rate charged on the outstanding principal.
        uint256 paymentDueBy;           /// @dev The timestamp (in seconds) for when the next payment is due.
        uint256 paymentsRemaining;      /// @dev The number of payments remaining until the loan is "Repaid".
        uint256 term;                   /// @dev The number of paymentIntervals that will occur, i.e. 10 monthly, 52 weekly, a.k.a. "duration".
        uint256 paymentInterval;        /// @dev The interval of time between payments (in seconds).
        uint256 requestExpiry;          /// @dev The block.timestamp at which the request for this loan expires (hardcoded 2 weeks).
        uint256 gracePeriod;            /// @dev The amount of time (in seconds) a borrower has to makePayment() before loan could default.
        int8 paymentSchedule;           /// @dev The payment schedule of the loan (0 = "Balloon" or 1 = "Amortized").
        LoanState state;                /// @dev The state of the loan.
    }

    address public immutable stablecoin;        /// @dev The stablecoin for this OCC contract.
    address public immutable GBL;               /// @dev The ZivoeGlobals contract.
    address public issuer;                      /// @dev The entity that is allowed to issue loans.
    
    uint256 public counterID;                   /// @dev Tracks the IDs, incrementing overtime for the "loans" mapping.

    uint256 public amountForConversion;         /// @dev The amount of stablecoin in this contract convertible and forwardable to YDL.

    mapping (uint256 => Loan) public loans;     /// @dev Mapping of loans.

    uint256 private constant BIPS = 10000;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCC_Modular.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The yield distribution locker that collects and distributes capital for this OCC locker.
    /// @param _issuer The entity that is allowed to call fundLoan() and markRepaid().
    constructor(address DAO, address _stablecoin, address _GBL, address _issuer) {
        transferOwnership(DAO);
        stablecoin = _stablecoin;
        GBL = _GBL;
        issuer = _issuer;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted when cancelRequest() is called.
    /// @param  id Identifier for the loan request cancelled.
    event RequestCancelled(uint256 id);

    /// @notice Emitted when requestLoan() is called.
    /// @param  id              Identifier for the loan request created.
    /// @param  borrowAmount    The amount to borrow (in other words, initial principal).
    /// @param  APR             The annualized percentage rate charged on the outstanding principal.
    /// @param  APRLateFee      The annualized percentage rate charged on the outstanding principal (in addition to APR) for late payments.
    /// @param  term            The term or "duration" of the loan (this is the number of paymentIntervals that will occur, i.e. 10 monthly, 52 weekly).
    /// @param  paymentInterval The interval of time between payments (in seconds).
    /// @param  requestExpiry   The block.timestamp at which the request for this loan expires (hardcoded 2 weeks).
    /// @param  gracePeriod     The amount of time (in seconds) a borrower has to makePayment() before loan could default.
    /// @param  paymentSchedule The payment schedule type ("Balloon" or "Amortization").
    event RequestCreated(
        uint256 id,
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 term,
        uint256 paymentInterval,
        uint256 requestExpiry,
        uint256 gracePeriod,
        int8 paymentSchedule
    );

    /// @notice Emitted when fundLoan() is called.
    /// @param id Identifier for the loan funded.
    /// @param principal The amount of stablecoin funded.
    /// @param paymentDueBy Timestamp (unix seconds) by which next payment is due.
    event RequestFunded(
        uint256 id,
        uint256 principal,
        address borrower,
        uint256 paymentDueBy
    );

    /// @notice Emitted when makePayment() is called.
    /// @param id Identifier for the loan on which payment is made.
    /// @param payee The address which made payment on the loan.
    /// @param amt The total amount of the payment.
    /// @param interest The interest portion of "amt" paid.
    /// @param principal The principal portion of "amt" paid.
    /// @param nextPaymentDue The timestamp by which next payment is due.
    event PaymentMade(
        uint256 id,
        address payee,
        uint256 amt,
        uint256 interest,
        uint256 principal,
        uint256 nextPaymentDue
    );

    /// @notice Emitted when markDefault() is called.
    /// @param id Identifier for the loan which defaulted.
    event DefaultMarked(
        uint256 id,
        uint256 principalDefaulted,
        uint256 priorNetDefaults,
        uint256 currentNetDefaults
    );

    /// @notice Emitted when markRepaid() is called.
    /// TODO: Delay until this function is discussed further.

    /// @notice Emitted when callLoan() is called.
    /// @param id Identifier for the loan which is called.
    /// @param amt The total amount of the payment.
    /// @param interest The interest portion of "amt" paid.
    /// @param principal The principal portion of "amt" paid.
    event LoanCalled(
        uint256 id,
        uint256 amt,
        uint256 interest,
        uint256 principal
    );

    /// @notice Emitted when resolveDefault() is called.
    /// @param id The identifier for the loan in default that is resolved (or partially).
    /// @param amt The amount of principal paid back.
    /// @param payee The address responsible for resolving the default.
    /// @param resolved Denotes if the loan is fully resolved (false if partial).
    event DefaultResolved(
        uint256 id,
        uint256 amt,
        address payee,
        bool resolved
    );

    /// @notice Emitted when supplyInterest() is called.
    /// TODO: Delay until this function is discussed further.

    // ---------------
    //    Modifiers
    // ---------------

    modifier isIssuer() {
        require(_msgSender() == issuer, "OCC_Modular::isIssuer() msg.sender != issuer");
        _;
    }



    // ---------------
    //    Functions
    // ---------------

    function canPush() public override pure returns (bool) {
        return true;
    }

    function canPull() public override pure returns (bool) {
        return true;
    }

    function canPushMulti() public override pure returns (bool) {
        return true;
    }

    function canPullMulti() public override pure returns (bool) {
        return true;
    }

    function canPullPartial() public override pure returns (bool) {
        return true;
    }

    function canPullMultiPartial() public override pure returns (bool) {
        return true;
    }

    /// @notice Migrates full amount of ERC20s from locker to owner().
    /// @param  assets The assets to migrate.
    function pullFromLockerMulti(address[] calldata assets) external override onlyOwner {
        for (uint i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransfer(owner(), IERC20(assets[i]).balanceOf(address(this)));
            if (assets[i] == stablecoin) {
                amountForConversion = 0;
            }
        }
    }

    /// @notice Migrates specific amounts of ERC20s from locker to owner().
    /// @param  assets The assets to migrate.
    /// @param  amounts The amounts of "assets" to migrate, corresponds to "assets" by position in array.
    function pullFromLockerMultiPartial(address[] calldata assets, uint256[] calldata amounts) external override onlyOwner {
        for (uint i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransfer(owner(), amounts[i]);
            if (assets[i] == stablecoin && IERC20(stablecoin).balanceOf(address(this)) < amountForConversion) {
                amountForConversion = IERC20(stablecoin).balanceOf(address(this));
            }
        }
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    function pullFromLocker(address asset) external override onlyOwner {
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
        if (asset == stablecoin) {
            amountForConversion = 0;
        }
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    function pullFromLockerPartial(address asset, uint256 amount) external override onlyOwner {
        require(canPullPartial(), "ZivoeLocker::pullFromLockerPartial() !canPullPartial()");
        IERC20(asset).safeTransfer(owner(), amount);
        if (IERC20(stablecoin).balanceOf(address(this)) < amountForConversion) {
            amountForConversion = IERC20(stablecoin).balanceOf(address(this));
        }
    }

    /// @dev    Returns information for amount owed on next payment of a particular loan.
    /// @param  id The ID of the loan.
    /// @return principal The amount of principal owed.
    /// @return interest The amount of interest owed.
    /// @return total The total amount owed, combining principal plus interested.
    function amountOwed(uint256 id) public view returns (uint256 principal, uint256 interest, uint256 total) {

        // 0 == Balloon
        if (loans[id].paymentSchedule == 0) {
            if (loans[id].paymentsRemaining == 1) {
                principal = loans[id].principalOwed;
            }

            interest = loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS);

            if (block.timestamp > loans[id].paymentDueBy) {
                interest += loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            }

            total = principal + interest;
        }
        // 1 == Amortization (only two options, use else here).
        else {

            interest = loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS);

            if (block.timestamp > loans[id].paymentDueBy) {
                interest += loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            }

            principal = loans[id].principalOwed / loans[id].paymentsRemaining;

            total = principal + interest;
        }
        
    }

    /// @notice Returns information for a given loan
    /// @dev    Refer to documentation on Loan struct for return param information.
    /// @param  id The ID of the loan.
    /// @return borrower The borrower of the loan.
    /// @return paymentSchedule The structure of the payment schedule.
    /// @return details The remaining details of the loan:
    ///                  details[0] = principalOwed
    ///                  details[1] = APR
    ///                  details[2] = APRLateFee
    ///                  details[3] = paymentDueBy
    ///                  details[4] = paymentsRemaining
    ///                  details[5] = term
    ///                  details[6] = paymentInterval
    ///                  details[7] = requestExpiry
    ///                  details[8] = gracePeriod
    ///                  details[9] = loanState
    function loanInfo(uint256 id) public view returns (
        address borrower, 
        int8 paymentSchedule,
        uint256[10] memory details
    ) {
        borrower = loans[id].borrower;
        paymentSchedule = loans[id].paymentSchedule;
        details[0] = loans[id].principalOwed;
        details[1] = loans[id].APR;
        details[2] = loans[id].APRLateFee;
        details[3] = loans[id].paymentDueBy;
        details[4] = loans[id].paymentsRemaining;
        details[5] = loans[id].term;
        details[6] = loans[id].paymentInterval;
        details[7] = loans[id].requestExpiry;
        details[8] = loans[id].gracePeriod;
        details[9] = uint256(loans[id].state);
    }

    /// @dev Cancels a loan request.
    function cancelRequest(uint256 id) external {

        require(_msgSender() == loans[id].borrower, "OCC_Modular::cancelRequest() _msgSender() != loans[id].borrower");
        require(loans[id].state == LoanState.Initialized, "OCC_Modular::cancelRequest() loans[id].state != LoanState.Initialized");

        emit RequestCancelled(id);

        loans[id].state = LoanState.Cancelled;
    }

    /// @dev                    Requests a loan.
    /// @param  borrowAmount    The amount to borrow (in other words, initial principal).
    /// @param  APR             The annualized percentage rate charged on the outstanding principal.
    /// @param  APRLateFee      The annualized percentage rate charged on the outstanding principal (in addition to APR) for late payments.
    /// @param  term            The term or "duration" of the loan (this is the number of paymentIntervals that will occur, i.e. 10 monthly, 52 weekly).
    /// @param  paymentInterval The interval of time between payments (in seconds).
    /// @param  gracePeriod     The amount of time (in seconds) the borrower has to makePayment() before loan could default.
    /// @param  paymentSchedule The payment schedule type ("Balloon" or "Amortization").
    function requestLoan(
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 term,
        uint256 paymentInterval,
        uint256 gracePeriod,
        int8 paymentSchedule
    ) external {
        
        require(APR <= 3600, "OCC_Modular::requestLoan() APR > 3600");
        require(APRLateFee <= 3600, "OCC_Modular::requestLoan() APRLateFee > 3600");
        require(term > 0, "OCC_Modular::requestLoan() term == 0");
        require(
            paymentInterval == 86400 * 7.5 || paymentInterval == 86400 * 15 || paymentInterval == 86400 * 30 || paymentInterval == 86400 * 90 || paymentInterval == 86400 * 360, 
            "OCC_Modular::requestLoan() invalid paymentInterval value, try: 86400 * (7.5 || 15 || 30 || 90 || 360)"
        );
        require(paymentSchedule == 0 || paymentSchedule == 1, "OCC_Modular::requestLoan() paymentSchedule != 0 && paymentSchedule != 1");

        emit RequestCreated(
            counterID,
            borrowAmount,
            APR,
            APRLateFee,
            term,
            paymentInterval,
            block.timestamp + 14 days,
            gracePeriod,
            paymentSchedule
        );

        loans[counterID] = Loan(
            _msgSender(),
            borrowAmount,
            APR,
            APRLateFee,
            0,
            term,
            term,
            paymentInterval,
            block.timestamp + 14 days,
            gracePeriod,
            paymentSchedule,
            LoanState.Initialized
        );

        counterID += 1;
    }

    /// @dev    Funds and initiates a loan.
    /// @param  id The ID of the loan.
    function fundLoan(uint256 id) external isIssuer {

        require(loans[id].state == LoanState.Initialized, "OCC_Modular::fundLoan() loans[id].state != LoanState.Initialized");
        require(block.timestamp < loans[id].requestExpiry, "OCC_Modular::fundLoan() block.timestamp >= loans[id].requestExpiry");

        emit RequestFunded(id, loans[id].principalOwed, loans[id].borrower, block.timestamp + loans[id].paymentInterval);

        loans[id].state = LoanState.Active;
        loans[id].paymentDueBy = block.timestamp + loans[id].paymentInterval;
        IERC20(stablecoin).safeTransfer(loans[id].borrower, loans[id].principalOwed);
        
        if (IERC20(stablecoin).balanceOf(address(this)) < amountForConversion) {
            amountForConversion = IERC20(stablecoin).balanceOf(address(this));
        }
    }

    /// @dev    Make a payment on a loan.
    /// @dev    Anyone is allowed to make a payment on someone's loan ("borrower" may lose initial wallet).
    /// @param  id The ID of the loan.
    function makePayment(uint256 id) external {

        require(
            loans[id].state == LoanState.Active, 
            "OCC_Modular::makePayment() loans[id].state != LoanState.Active && loans[id].state != LoanState.Defaulted"
        );

        (uint256 principalOwed, uint256 interestOwed,) = amountOwed(id);

        emit PaymentMade(
            id,
            _msgSender(),
            principalOwed + interestOwed,
            interestOwed,
            principalOwed,
            loans[id].paymentDueBy + loans[id].paymentInterval
        );

        // Transfer interest to YDL if in same format, otherwise keep here for 1INCH forwarding.
        if (stablecoin == IZivoeYDL(IZivoeGlobals(GBL).YDL()).distributedAsset()) {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), IZivoeGlobals(GBL).YDL(), interestOwed);
        }
        else {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), address(this), interestOwed);
            amountForConversion += interestOwed;
        }
        
        IERC20(stablecoin).safeTransferFrom(_msgSender(), owner(), principalOwed);

        if (loans[id].paymentsRemaining == 1) {
            loans[id].state = LoanState.Repaid;
            loans[id].paymentDueBy = 0;
        }
        else {
            loans[id].paymentDueBy += loans[id].paymentInterval;
        }

        loans[id].principalOwed -= principalOwed;
        loans[id].paymentsRemaining -= 1;
    }

    /// @dev    Mark a loan insolvent if a payment hasn't been made for over 90 days.
    /// @param  id The ID of the loan.
    function markDefault(uint256 id) external {
        require( 
            loans[id].paymentDueBy + 86400 * 90 < block.timestamp, 
            "OCC_Modular::markDefault() loans[id].paymentDueBy + 86400 * 90 >= block.timestamp"
        );
        emit DefaultMarked(
            id,
            loans[id].principalOwed,
            IZivoeGlobals(GBL).defaults(),
            IZivoeGlobals(GBL).defaults() + loans[id].principalOwed
        );
        loans[id].state = LoanState.Defaulted;
        // TODO: Standardize thie value to WEI.
        IZivoeGlobals(GBL).increaseDefaults(loans[id].principalOwed);
    }

    /// @dev    Issuer specifies a loan has been repaid fully via interest deposits in terms of off-chain debt.
    /// @param  id The ID of the loan.
    function markRepaid(uint256 id) external isIssuer {
        require(loans[id].state == LoanState.Resolved, "OCC_Modular::markRepaid() loans[id].state != LoanState.Resolved");
        loans[id].state = LoanState.Repaid;
    }

    /// @dev    Pays off the loan in full, plus additional interest for paymentInterval.
    /// @dev    Only the "borrower" of the loan may elect this option.
    /// @param  id The loan to pay off early.
    function callLoan(uint256 id) external {
        require(_msgSender() == loans[id].borrower);

        require(
            loans[id].state == LoanState.Active,
            "OCC_Modular::makePayment() loans[id].state != LoanState.Active"
        );

        uint256 principalOwed = loans[id].principalOwed;
        (, uint256 interestOwed,) = amountOwed(id);

        emit LoanCalled(id, interestOwed + principalOwed, interestOwed, principalOwed);

        IERC20(stablecoin).safeTransferFrom(_msgSender(), IZivoeGlobals(GBL).YDL(), interestOwed);
        IERC20(stablecoin).safeTransferFrom(_msgSender(), owner(), principalOwed);

        loans[id].state = LoanState.Repaid;
        loans[id].paymentDueBy = 0;
        loans[id].principalOwed = 0;
        loans[id].paymentsRemaining = 0;
    }

    /// @dev    Make a full (or partial) payment to resolve a insolvent loan.
    /// @param  id The ID of the loan.
    /// @param  amount The amount of principal to pay down.
    function resolveDefault(uint256 id, uint256 amount) external {

        require(loans[id].state == LoanState.Defaulted, "OCC_Modular::resolveInsolvency() loans[id].state != LoanState.Defaulted");

        uint256 paymentAmount;

        if (amount >= loans[id].principalOwed) {
            paymentAmount = loans[id].principalOwed;
            loans[id].principalOwed == 0;
            loans[id].state = LoanState.Resolved;
        }
        else {
            paymentAmount = amount;
            loans[id].principalOwed -= paymentAmount;
        }

        emit DefaultResolved(id, amount, _msgSender(), loans[id].state == LoanState.Resolved);

        IERC20(stablecoin).safeTransferFrom(_msgSender(), owner(), paymentAmount);
        IZivoeGlobals(GBL).decreaseDefaults(paymentAmount);
    }

    // TODO: Discuss this function, ensure specifications are proper, or if this function is truly needed.
    
    /// @dev    Supply interest to a repaid loan (for arbitrary interest repayment).
    /// @param  id The ID of the loan.
    /// @param  amt The amount of  interest to supply.
    function supplyInterest(uint256 id, uint256 amt) external {
        require(loans[id].state == LoanState.Resolved, "OCC_Modular::supplyInterest() loans[id].state != LoanState.Resolved");
        IERC20(stablecoin).safeTransferFrom(_msgSender(), IZivoeGlobals(GBL).YDL(), amt); 
    }

    /// @dev This function converts and forwards available "amountForConversion" to YDL.distributeAsset().
    function forwardInterestKeeper(bytes calldata data) external {
        require(IZivoeGlobals(GBL).isKeeper(_msgSender()), "OCC_Modular::forwardInterestKeeper() !IZivoeGlobals(GBL).isKeeper(_msgSender())");
        address _toAsset = IZivoeYDL(IZivoeGlobals(GBL).YDL()).distributedAsset();
        require(_toAsset != stablecoin, "OCC_Modular::forwardInterestKeeper() _toAsset == stablecoin");

        // Swap available "amountForConversion" from stablecoin to YDL.distributedAsset().
        convertAsset(stablecoin, _toAsset, amountForConversion, data);

        // Transfer all _toAsset received to the YDL, then reduce amountForConversion to 0.
        IERC20(_toAsset).safeTransfer(IZivoeGlobals(GBL).YDL(), IERC20(_toAsset).balanceOf(address(this)));
        amountForConversion = 0;
    }

}
