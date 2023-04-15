// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IZivoeGlobals_OCC {
    /// @notice Returns the address of the ZivoeYDL contract.
    function YDL() external view returns (address);

    /// @notice Returns the net defaults in the system.
    /// @return amount The amount of net defaults in the system.
    function defaults() external view returns (uint256 amount);

    /// @notice Returns true if an address is whitelisted as a keeper.
    /// @return keeper Equals "true" if address is a keeper, "false" if not.
    function isKeeper(address) external view returns (bool keeper);

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param amount The amount of a given "asset".
    /// @param asset The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount The above amount standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);

    /// @notice Call when a default is resolved, decreases net defaults system-wide.
    /// @dev    The value "amount" should be standardized to WEI.
    /// @param  amount The default amount that has been resolved.
    function decreaseDefaults(uint256 amount) external;

    /// @notice Call when a default occurs, increases net defaults system-wide.
    /// @dev    The value "amount" should be standardized to WEI.
    /// @param  amount The default amount.
    function increaseDefaults(uint256 amount) external;
}

interface IZivoeYDL_OCC {
    /// @notice Returns the "stablecoin" that will be distributed via YDL.
    /// @return asset The address of the "stablecoin" that will be distributed via YDL.
    function distributedAsset() external view returns (address asset);
}

/// @notice  OCC stands for "On-Chain Credit".
///          A "balloon" loan is an interest-only loan, with principal repaid in full at the end.
///          An "amortized" loan is a principal and interest loan, with consistent payments until fully "Repaid".
///          This locker is responsible for handling accounting of loans.
///          This locker is responsible for handling payments and distribution of payments.
///          This locker is responsible for handling defaults and liquidations (if needed).
contract OCC_Modular is ZivoeLocker, ReentrancyGuard {
    
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
        uint256 APRLateFee;             /// @dev The additional annualized percentage rate charged on the outstanding principal if payment is late.
        uint256 paymentDueBy;           /// @dev The timestamp (in seconds) for when the next payment is due.
        uint256 paymentsRemaining;      /// @dev The number of payments remaining until the loan is "Repaid".
        uint256 term;                   /// @dev The number of paymentIntervals that will occur, i.e. 10, 52, 200 in relation to "paymentInterval".
        uint256 paymentInterval;        /// @dev The interval of time between payments (in seconds).
        uint256 requestExpiry;          /// @dev The block.timestamp at which the request for this loan expires (hardcoded 2 weeks).
        uint256 gracePeriod;            /// @dev The amount of time (in seconds) a borrower has to makePayment() before loan could default.
        int8 paymentSchedule;           /// @dev The payment schedule of the loan (0 = "Balloon" or 1 = "Amortized").
        LoanState state;                /// @dev The state of the loan.
    }

    address public immutable stablecoin;        /// @dev The stablecoin for this OCC contract.
    address public immutable GBL;               /// @dev The ZivoeGlobals contract.
    address public underwriter;                 /// @dev The entity that is allowed to underwrite (a.k.a. issue) loans.
    
    uint256 public counterID;                   /// @dev Tracks the IDs, incrementing overtime for the "loans" mapping.

    mapping (uint256 => Loan) public loans;     /// @dev Mapping of loans.

    uint256 private constant BIPS = 10000;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCC_Modular contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _stablecoin The stablecoin for this OCC contract.
    /// @param _GBL The yield distribution locker that collects and distributes capital for this OCC locker.
    /// @param _underwriter The entity that is allowed to call createOffer() and markRepaid().
    constructor(address DAO, address _stablecoin, address _GBL, address _underwriter) {
        transferOwnershipAndLock(DAO);
        stablecoin = _stablecoin;
        GBL = _GBL;
        underwriter = _underwriter;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during cancelOffer().
    /// @param  id Identifier for the loan request cancelled.
    event OfferCancelled(uint256 indexed id);

    /// @notice Emitted during acceptOffer().
    /// @param id Identifier for the offer accepted.
    /// @param principal The amount of stablecoin lent out.
    /// @param paymentDueBy Timestamp (unix seconds) by which next payment is due.
    event OfferAccepted(uint256 indexed id, uint256 principal, address indexed borrower, uint256 paymentDueBy);

    /// @notice Emitted during createOffer().
    /// @param  borrower        The address borrowing (that will receive the loan).
    /// @param  requestedBy     The address that created the loan request (usually same as borrower).
    /// @param  id              Identifier for the loan request created.
    /// @param  borrowAmount    The amount to borrow (in other words, initial principal).
    /// @param  APR             The annualized percentage rate charged on the outstanding principal.
    /// @param  APRLateFee      The annualized percentage rate charged on the outstanding principal (in addition to APR) for late payments.
    /// @param  term            The term or "duration" of the loan (this is the number of paymentIntervals that will occur, i.e. 10 monthly, 52 weekly).
    /// @param  paymentInterval The interval of time between payments (in seconds).
    /// @param  requestExpiry   The block.timestamp at which the request for this loan expires (hardcoded 2 weeks).
    /// @param  gracePeriod     The amount of time (in seconds) a borrower has to makePayment() before loan could default.
    /// @param  paymentSchedule The payment schedule type ("Balloon" or "Amortization").
    event OfferCreated(
        address indexed borrower,
        address requestedBy,
        uint256 indexed id,
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 term,
        uint256 paymentInterval,
        uint256 requestExpiry,
        uint256 gracePeriod,
        int8 indexed paymentSchedule
    );

    /// @notice Emitted during makePayment() and processPayment().
    /// @param id Identifier for the loan on which payment is made.
    /// @param payee The address which made payment on the loan.
    /// @param amount The total amount of the payment.
    /// @param principal The principal portion of "amount" paid.
    /// @param interest The interest portion of "amount" paid.
    /// @param lateFee The lateFee portion of "amount" paid.
    /// @param nextPaymentDue The timestamp by which next payment is due.
    event PaymentMade(uint256 indexed id, address indexed payee, uint256 amount, uint256 principal, uint256 interest, uint256 lateFee, uint256 nextPaymentDue);

    /// @notice Emitted during markDefault().
    /// @param id Identifier for the loan which is now "defaulted".
    /// @param principalDefaulted The amount defaulted on.
    /// @param priorNetDefaults The prior amount of net (global) defaults.
    /// @param currentNetDefaults The new amount of net (global) defaults.
    event DefaultMarked(uint256 indexed id, uint256 principalDefaulted, uint256 priorNetDefaults, uint256 currentNetDefaults);

    /// @notice Emitted during markRepaid().
    /// @param id Identifier for loan which is now "repaid".
    event RepaidMarked(uint256 indexed id);

    /// @notice Emitted during callLoan().
    /// @param id Identifier for the loan which is called.
    /// @param amount The total amount of the payment.
    /// @param interest The interest portion of "amount" paid.
    /// @param principal The principal portion of "amount" paid.
    /// @param lateFee The lateFee portion of "amount" paid.
    event LoanCalled(uint256 indexed id, uint256 amount, uint256 principal, uint256 interest, uint256 lateFee);

    /// @notice Emitted during resolveDefault().
    /// @param id The identifier for the loan in default that is resolved (or partially).
    /// @param amount The amount of principal paid back.
    /// @param payee The address responsible for resolving the default.
    /// @param resolved Denotes if the loan is fully resolved (false if partial).
    event DefaultResolved(uint256 indexed id, uint256 amount, address indexed payee, bool resolved);

    /// @notice Emitted during supplyInterest().
    /// @param id The identifier for the loan that is supplied additional interest.
    /// @param amount The amount of interest supplied.
    /// @param payee The address responsible for supplying additional interest.
    event InterestSupplied(uint256 indexed id, uint256 amount, address indexed payee);


    /// @notice Emitted during forwardInterestKeeper().
    /// @param toAsset The asset converted to (dependent upon YDL.distributedAsset()).
    /// @param amountConverted The amount of "stablecoin" available for conversion. 
    /// @param amountReceived The amount of "toAsset" received while converting interest.
    event InterestConverted(address indexed toAsset, uint256 amountConverted, uint256 amountReceived);


    // ---------------
    //    Modifiers
    // ---------------

    /// @notice This modifier ensures that the caller is the entity that is allowed to issue loans.
    modifier isUnderwriter() {
        require(_msgSender() == underwriter, "OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        _;
    }



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pushToLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override onlyOwner nonReentrant {
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(address asset, uint256 amount, bytes calldata data) external override onlyOwner nonReentrant {
        IERC20(asset).safeTransfer(owner(), amount);
    }

    /// @notice Returns information for amount owed on next payment of a particular loan.
    /// @param  id The ID of the loan.
    /// @return principal The amount of principal owed.
    /// @return interest The amount of interest owed.
    /// @return lateFee The amount of late fees owed.
    /// @return total Full amount owed, combining principal plus interest.
    function amountOwed(uint256 id) public view returns (uint256 principal, uint256 interest, uint256 lateFee, uint256 total) {
        // 0 == Balloon.
        if (loans[id].paymentSchedule == 0) {
            if (loans[id].paymentsRemaining == 1) { principal = loans[id].principalOwed; }
        }
        // 1 == Amortization (only two options, use else here).
        else { principal = loans[id].principalOwed / loans[id].paymentsRemaining; }
        // Add late fee if past paymentDueBy timestamp.
        if (block.timestamp > loans[id].paymentDueBy && loans[id].state == LoanState.Active) {
            lateFee = loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
        }
        interest = loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS);
        total = principal + interest + lateFee;
    }

    /// @notice Returns information for a given loan.
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
    function loanInfo(uint256 id) external view returns (
        address borrower, int8 paymentSchedule, uint256[10] memory details
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

    /// @notice Cancels a loan request.
    /// @param id The ID of the loan.
    function cancelOffer(uint256 id) isUnderwriter external {
        require(loans[id].state == LoanState.Initialized, "OCC_Modular::cancelOffer() loans[id].state != LoanState.Initialized");
        emit OfferCancelled(id);
        loans[id].state = LoanState.Cancelled;
    }

    /// @notice                 Create a loan offer.
    /// @param  borrower        The address to borrow (that receives the loan).
    /// @param  borrowAmount    The amount to borrow (in other words, initial principal).
    /// @param  APR             The annualized percentage rate charged on the outstanding principal.
    /// @param  APRLateFee      The annualized percentage rate charged on the outstanding principal (in addition to APR) for late payments.
    /// @param  term            The term or "duration" of the loan (this is the number of paymentIntervals that will occur, i.e. 10, 52, 200).
    /// @param  paymentInterval The interval of time between payments (in seconds).
    /// @param  gracePeriod     The amount of time (in seconds) the borrower has to makePayment() before loan could default.
    /// @param  paymentSchedule The payment schedule type ("Balloon" or "Amortization").
    function createOffer(
        address borrower,
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 term,
        uint256 paymentInterval,
        uint256 gracePeriod,
        int8 paymentSchedule
    ) isUnderwriter external {
        require(term > 0, "OCC_Modular::createOffer() term == 0");
        require(
            paymentInterval == 86400 * 7 || paymentInterval == 86400 * 14 || paymentInterval == 86400 * 28 || 
            paymentInterval == 86400 * 91 || paymentInterval == 86400 * 364, 
            "OCC_Modular::createOffer() invalid paymentInterval value, try: 86400 * (7 || 14 || 28 || 91 || 364)"
        );
        require(paymentSchedule <= 1, "OCC_Modular::createOffer() paymentSchedule > 1");

        emit OfferCreated(
            borrower, _msgSender(), counterID, borrowAmount, APR, APRLateFee, term,
            paymentInterval, block.timestamp + 14 days, gracePeriod, paymentSchedule
        );

        loans[counterID] = Loan(
            borrower, borrowAmount, APR, APRLateFee, 0, term, term, paymentInterval, block.timestamp + 14 days,
            gracePeriod, paymentSchedule, LoanState.Initialized
        );

        counterID += 1;
    }

    /// @notice Funds and initiates a loan.
    /// @param  id The ID of the loan.
    function acceptOffer(uint256 id) external nonReentrant {
        require(loans[id].state == LoanState.Initialized, "OCC_Modular::acceptOffer() loans[id].state != LoanState.Initialized");
        require(block.timestamp < loans[id].requestExpiry, "OCC_Modular::acceptOffer() block.timestamp >= loans[id].requestExpiry");
        require(_msgSender() == loans[id].borrower, "OCC_Modular::acceptOffer() _msgSender() != loans[id].borrower");

        emit OfferAccepted(id, loans[id].principalOwed, loans[id].borrower, block.timestamp + loans[id].paymentInterval);

        loans[id].state = LoanState.Active;
        loans[id].paymentDueBy = block.timestamp + loans[id].paymentInterval;
        IERC20(stablecoin).safeTransfer(loans[id].borrower, loans[id].principalOwed);
    }

    /// @notice Make a payment on a loan.
    /// @dev    Anyone is allowed to make a payment on someone's loan.
    /// @param  id The ID of the loan.
    function makePayment(uint256 id) external nonReentrant {
        require(loans[id].state == LoanState.Active, "OCC_Modular::makePayment() loans[id].state != LoanState.Active");

        (uint256 principalOwed, uint256 interestOwed, uint256 lateFee,) = amountOwed(id);

        emit PaymentMade(
            id, _msgSender(), principalOwed + interestOwed + lateFee, principalOwed,
            interestOwed, lateFee, loans[id].paymentDueBy + loans[id].paymentInterval
        );

        // Transfer interest + lateFee to YDL if in same format, otherwise keep here for 1INCH forwarding.
        if (stablecoin == IZivoeYDL_OCC(IZivoeGlobals_OCC(GBL).YDL()).distributedAsset()) {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), IZivoeGlobals_OCC(GBL).YDL(), interestOwed + lateFee);
        }
        else {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), address(this), interestOwed + lateFee);
        }
        
        IERC20(stablecoin).safeTransferFrom(_msgSender(), owner(), principalOwed);

        if (loans[id].paymentsRemaining == 1) {
            loans[id].state = LoanState.Repaid;
            loans[id].paymentDueBy = 0;
        }
        else { loans[id].paymentDueBy += loans[id].paymentInterval; }

        loans[id].principalOwed -= principalOwed;
        loans[id].paymentsRemaining -= 1;
    }

    /// @notice Process a payment for a loan, on behalf of another borrower.
    /// @dev    Anyone is allowed to process a payment, it will take from "borrower".
    /// @dev    Only allowed to call this if block.timestamp > paymentDueBy.
    /// @param  id The ID of the loan.
    function processPayment(uint256 id) external nonReentrant {
        require(loans[id].state == LoanState.Active, "OCC_Modular::processPayment() loans[id].state != LoanState.Active");
        require(block.timestamp > loans[id].paymentDueBy - 3 days, "OCC_Modular::processPayment() block.timestamp <= loans[id].paymentDueBy - 3 days");

        (uint256 principalOwed, uint256 interestOwed, uint256 lateFee,) = amountOwed(id);

        emit PaymentMade(
            id, loans[id].borrower, principalOwed + interestOwed + lateFee, principalOwed,
            interestOwed, lateFee, loans[id].paymentDueBy + loans[id].paymentInterval
        );

        // Transfer interest to YDL if in same format, otherwise keep here for 1INCH forwarding.
        if (stablecoin == IZivoeYDL_OCC(IZivoeGlobals_OCC(GBL).YDL()).distributedAsset()) {
            IERC20(stablecoin).safeTransferFrom(loans[id].borrower, IZivoeGlobals_OCC(GBL).YDL(), interestOwed + lateFee);
        }
        else {
            IERC20(stablecoin).safeTransferFrom(loans[id].borrower, address(this), interestOwed + lateFee);
        }
        
        IERC20(stablecoin).safeTransferFrom(loans[id].borrower, owner(), principalOwed);

        if (loans[id].paymentsRemaining == 1) {
            loans[id].state = LoanState.Repaid;
            loans[id].paymentDueBy = 0;
        }
        else { loans[id].paymentDueBy += loans[id].paymentInterval; }

        loans[id].principalOwed -= principalOwed;
        loans[id].paymentsRemaining -= 1;
    }

    /// @notice Pays off the loan in full, plus additional interest for paymentInterval.
    /// @dev    Only the "borrower" of the loan may elect this option.
    /// @param  id The loan to pay off early.
    function callLoan(uint256 id) external nonReentrant {
        require(_msgSender() == loans[id].borrower, "OCC_Modular::callLoan() _msgSender() != loans[id].borrower");
        require(loans[id].state == LoanState.Active, "OCC_Modular::callLoan() loans[id].state != LoanState.Active");

        uint256 principalOwed = loans[id].principalOwed;
        (, uint256 interestOwed, uint256 lateFee,) = amountOwed(id);

        emit LoanCalled(id, principalOwed + interestOwed + lateFee, principalOwed, interestOwed, lateFee);

        // Transfer interest to YDL if in same format, otherwise keep here for 1INCH forwarding.
        if (stablecoin == IZivoeYDL_OCC(IZivoeGlobals_OCC(GBL).YDL()).distributedAsset()) {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), IZivoeGlobals_OCC(GBL).YDL(), interestOwed + lateFee);
        }
        else {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), address(this), interestOwed + lateFee);
        }

        IERC20(stablecoin).safeTransferFrom(_msgSender(), owner(), principalOwed);

        loans[id].principalOwed = 0;
        loans[id].paymentDueBy = 0;
        loans[id].paymentsRemaining = 0;
        loans[id].state = LoanState.Repaid;
    }

    /// @notice Mark a loan insolvent if a payment hasn't been made beyond the corresponding grace period.
    /// @param  id The ID of the loan.
    function markDefault(uint256 id) external {
        require(loans[id].state == LoanState.Active, "OCC_Modular::markDefault() loans[id].state != LoanState.Active");
        require( 
            loans[id].paymentDueBy + loans[id].gracePeriod < block.timestamp, 
            "OCC_Modular::markDefault() loans[id].paymentDueBy + loans[id].gracePeriod >= block.timestamp"
        );
        
        emit DefaultMarked(
            id,
            loans[id].principalOwed,
            IZivoeGlobals_OCC(GBL).defaults(),
            IZivoeGlobals_OCC(GBL).defaults() + IZivoeGlobals_OCC(GBL).standardize(loans[id].principalOwed, stablecoin)
        );
        loans[id].state = LoanState.Defaulted;
        IZivoeGlobals_OCC(GBL).increaseDefaults(IZivoeGlobals_OCC(GBL).standardize(loans[id].principalOwed, stablecoin));
    }

    /// @notice Underwriter specifies a loan has been repaid fully via interest deposits in terms of off-chain debt.
    /// @param  id The ID of the loan.
    function markRepaid(uint256 id) external isUnderwriter {
        require(loans[id].state == LoanState.Resolved, "OCC_Modular::markRepaid() loans[id].state != LoanState.Resolved");

        emit RepaidMarked(id);
        loans[id].state = LoanState.Repaid;
    }

    /// @notice Make a full (or partial) payment to resolve a insolvent loan.
    /// @param  id The ID of the loan.
    /// @param  amount The amount of principal to pay down.
    function resolveDefault(uint256 id, uint256 amount) external {
        require(
            loans[id].state == LoanState.Defaulted, 
            "OCC_Modular::resolveDefaut() loans[id].state != LoanState.Defaulted"
        );

        uint256 paymentAmount;

        if (amount >= loans[id].principalOwed) {
            paymentAmount = loans[id].principalOwed;
            loans[id].principalOwed = 0;
            loans[id].state = LoanState.Resolved;
        }
        else {
            paymentAmount = amount;
            loans[id].principalOwed -= paymentAmount;
        }

        emit DefaultResolved(id, paymentAmount, _msgSender(), loans[id].state == LoanState.Resolved);

        IERC20(stablecoin).safeTransferFrom(_msgSender(), owner(), paymentAmount);
        IZivoeGlobals_OCC(GBL).decreaseDefaults(IZivoeGlobals_OCC(GBL).standardize(paymentAmount, stablecoin));
    }
    
    /// @notice Supply interest to a repaid loan (for arbitrary interest repayment).
    /// @param  id The ID of the loan.
    /// @param  amount The amount of interest to supply.
    function supplyInterest(uint256 id, uint256 amount) external nonReentrant {
        require(loans[id].state == LoanState.Resolved, "OCC_Modular::supplyInterest() loans[id].state != LoanState.Resolved");
        
        emit InterestSupplied(id, amount, _msgSender());
        // Transfer interest to YDL if in same format, otherwise keep here for 1INCH forwarding.
        if (stablecoin == IZivoeYDL_OCC(IZivoeGlobals_OCC(GBL).YDL()).distributedAsset()) {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), IZivoeGlobals_OCC(GBL).YDL(), amount);
        } else {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), address(this), amount);
        }
    }

}
