// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

// TODO: Create two asset-opinionated OCC lockers (OCC_FRAX.sol, OCC_USDC.sol).

import { ICRV_PP_128_NP, ICRV_MP_256, ILendingPool, IZivoeYDL } from "../interfaces/InterfacesAggregated.sol";

/// @dev    OCC stands for "On-Chain Credit Locker".
///         A "balloon" loan is an interest-only loan, with principal repaid in full at the end.
///         An "amortized" loan is a principal and interest loan, with consistent payments until fully "Repaid".
///         This locker is responsible for handling accounting of loans.
///         This locker is responsible for handling payments and distribution of payments.
///         This locker is responsible for handling defaults and liquidations (if needed).
contract OCC_FRAX is ZivoeLocker {
    
    // ---------------
    // State Variables
    // ---------------

    /// @dev Stablecoin addresses.
    address public constant DAI  = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    /// @dev CRV.FI pool addresses (plain-pool, and meta-pool).
    address public constant CRV_PP = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address public constant FRAX3CRV_MP = 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B;

    address public YDL;                                                     /// @dev The yield distribution locker that accepts capital for yield.
    address public ISS;                                                     /// @dev The entity that is allowed to issue loans.

    address public baseToken = 0x853d955aCEf822Db058eb8505911ED77F175b99e;  /// @dev The FRAX stablecoin address.

    uint256 public counterID;                                               /// @dev Tracks the IDs, incrementing overtime for the "loans" mapping.

    mapping (uint256 => Loan) public loans;                                 /// @dev Mapping of loans.

    enum LoanState {Null, Initialized, Active, Repaid, Defaulted, Cancelled, Resolved}      /// @dev Tracks state of the loan, enabling or disabling certain actions (function calls).
    enum LoanSchedule { Bullet, Amortized }                                       /// @dev Tracks payment schedule type of the loan.

    /// @dev Tracks the loan.
    struct Loan {
        address borrower;               /// @dev The address that receives capital when the loan is funded.
        uint256 principalOwed;          /// @dev The amount of principal still owed on the loan.
        uint256 APR;                    /// @dev The annualized percentage rate charged on the outstanding principal.
        uint256 APRLateFee;             /// @dev The annualized percentage rate charged on the outstanding principal.
        uint256 paymentDueBy;           /// @dev The timestamp (in seconds) for when the next payment is due.
        uint256 paymentsRemaining;      /// @dev The number of payments remaining until the loan is "Repaid".
        uint256 term;                   /// @dev The term or "duration" of the loan (this is the number of paymentIntervals that will occur, i.e. 10 monthly, 52 weekly).
        uint256 paymentInterval;        /// @dev The interval of time between payments (in seconds).
        uint256 requestExpiry;          /// @dev The block.timestamp at which the request for this loan expires (hardcoded 2 weeks).
        int8 paymentSchedule;           /// @dev The payment schedule of the loan (0 = "Bullet" or 1 = "Amortized").
        LoanState state;                /// @dev The state of the loan.
    }



    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the OCC_FRAX.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _YDL The yield distribution locker that collects and distributes capital for this OCC locker.
    /// @param _ISS The entity that is allowed to call fundLoan().
    constructor(address DAO, address _YDL, address _ISS) {
        transferOwnership(DAO);
        YDL = _YDL;
        ISS = _ISS;
    }



    // ------
    // Events
    // ------



    // ---------
    // Modifiers
    // ---------

    modifier isIssuer() {
        require(_msgSender() == ISS, "OCC_FRAX.sol::isIssuer() msg.sender != GOV");
        _;
    }



    // ---------
    // Functions
    // ---------

    function canPush() external pure override returns(bool) {
        return true;
    }

    function canPull() external pure override returns(bool) {
        return true;
    }


    /// @dev    This pulls capital from the DAO, does any necessary pre-conversions, and invests into AAVE v2 (USDC pool).
    /// @notice Only callable by the DAO.
    function pushToLocker(address asset, uint256 amount) public override onlyOwner {

        require(amount >= 0, "OCC_FRAX.sol::pushToLocker() amount == 0");

        IERC20(asset).transferFrom(owner(), address(this), amount);

        if (asset != FRAX) {
            if (asset == DAI) {
                // Convert DAI to FRAX via FRAX/3CRV meta-pool.
                IERC20(asset).approve(FRAX3CRV_MP, IERC20(asset).balanceOf(address(this)));
                ICRV_MP_256(FRAX3CRV_MP).exchange_underlying(int128(1), int128(0), IERC20(asset).balanceOf(address(this)), 0);
            }
            else if (asset == USDC) {
                // Convert USDC to FRAX via FRAX/3CRV meta-pool.
                IERC20(asset).approve(FRAX3CRV_MP, IERC20(asset).balanceOf(address(this)));
                ICRV_MP_256(FRAX3CRV_MP).exchange_underlying(int128(2), int128(0), IERC20(asset).balanceOf(address(this)), 0);
            }
            else if (asset == USDT) {
                // Convert USDT to FRAX via FRAX/3CRV meta-pool.
                IERC20(asset).approve(FRAX3CRV_MP, IERC20(asset).balanceOf(address(this)));
                ICRV_MP_256(FRAX3CRV_MP).exchange_underlying(int128(3), int128(0), IERC20(asset).balanceOf(address(this)), 0);
            }
            else {
                /// @dev Revert here, given unknown "asset" received (otherwise, "asset" will be locked and/or lost forever).
                revert("OCC_FRAX.sol::pushToLocker() asset not supported"); 
            }
        }
    }

    /// @dev                    Requests a loan.
    /// @param  borrowAmount    The amount to borrow (in other words, initial principal).
    /// @param  APR             The annualized percentage rate charged on the outstanding principal.
    /// @param  APRLateFee      The annualized percentage rate charged on the outstanding principal (in addition to APR) for late payments.
    /// @param  term            The term or "duration" of the loan (this is the number of paymentIntervals that will occur, i.e. 10 monthly, 52 weekly).
    /// @param  paymentInterval The interval of time between payments (in seconds).
    /// @param  paymentSchedule The payment schedule type ("Bullet" or "Amortization").
    function requestLoan(
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 term,
        uint256 paymentInterval,
        int8 paymentSchedule
    ) public {
        
        require(APR <= 3600, "OCC_FRAX.sol::requestLoan() APR > 3600");
        require(APRLateFee <= 3600, "OCC_FRAX.sol::requestLoan() APRLateFee > 3600");
        require(term > 0, "OCC_FRAX.sol::requestLoan() term == 0");
        // TODO: Add in quarterly, annually, standardize.
        // 90 days
        // 360 days
        require(
            paymentInterval == 86400 * 7.5 || paymentInterval == 86400 * 15 || paymentInterval == 86400 * 30 || paymentInterval == 86400 * 90 || paymentInterval == 86400 * 360, 
            "OCC_FRAX.sol::requestLoan() invalid paymentInterval value"
        );
        require(paymentSchedule == 0 || paymentSchedule == 1);

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
            paymentSchedule,
            LoanState.Initialized
        );

        counterID += 1;
    }

    /// @dev Cancels a loan request.
    function cancelRequest(uint256 id) public {

        require(_msgSender() == loans[id].borrower, "OCC_FRAX.sol::cancelRequest() _msgSender() != loans[id].borrower");
        require(loans[id].state == LoanState.Initialized, "OCC_FRAX.sol::cancelRequest() loans[id].state != LoanState.Initialized");

        loans[id].state = LoanState.Cancelled;
    }

    /// @dev    Funds and initiates a loan.
    /// @param  id The ID of the loan.
    function fundLoan(uint256 id) public isIssuer {

        require(loans[id].state == LoanState.Initialized, "OCC_FRAX.sol::fundLoan() loans[id].state != LoanState.Initialized");
        require(IERC20(baseToken).balanceOf(address(this)) >= loans[id].principalOwed, "OCC_FRAX.sol::fundLoan() FRAX available < loans[id].principalOwed");
        require(block.timestamp < loans[id].requestExpiry, "OCC_FRAX.sol::fundLoan() block.timestamp >= loans[id].requestExpiry");

        loans[id].state = LoanState.Active;
        loans[id].paymentDueBy = block.timestamp + loans[id].paymentInterval;
        IERC20(baseToken).transfer(loans[id].borrower, loans[id].principalOwed);
    }

    event Debug(string, uint256);

    /// @dev    Make a payment on a loan.
    /// @param  id The ID of the loan.
    function makePayment(uint256 id) public {

        require(
            loans[id].state == LoanState.Active || loans[id].state == LoanState.Defaulted, 
            "OCC_FRAX.sol::makePayment() loans[id].state != LoanState.Active && loans[id].state != LoanState.Insolvent"
        );

        (uint256 principalOwed, uint256 interestOwed,) = amountOwed(id);

        // TODO: Determine best location to return principal (currently DAO).
        IERC20(baseToken).transferFrom(_msgSender(), YDL, interestOwed);
        IERC20(baseToken).transferFrom(_msgSender(), owner(), principalOwed);

        if (loans[id].paymentsRemaining == 1) {
            loans[id].state = LoanState.Repaid;
            loans[id].paymentDueBy = 0;
        }
        else {
            loans[id].paymentDueBy += loans[id].paymentInterval;
        }

        // TODO: Discuss this line, if appropriate or required (?)
        if (loans[id].state == LoanState.Defaulted) {
            loans[id].state = LoanState.Active;
        }

        loans[id].principalOwed -= principalOwed;
        loans[id].paymentsRemaining -= 1;
    }

    /// @dev    Mark a loan insolvent if a payment hasn't been made for over 90 days.
    /// @param  id The ID of the loan.
    function markDefault(uint256 id) public {

        require( 
            loans[id].paymentDueBy + 86400 * 90 < block.timestamp, 
            "OCC_FRAX.sol::markDefault() seconds passed since paymentDueBy less than 90 days"
        );

        loans[id].state = LoanState.Defaulted;
    }

    // TODO: Update this function per specifications.

    /// @dev    Make a full (or partial) payment to resolve a insolvent loan.
    /// @param  id The ID of the loan.
    /// @param  amount The amount of principal to pay down.
    function resolveDefault(uint256 id, uint256 amount) public {

        require(loans[id].state == LoanState.Defaulted, "OCC_FRAX.sol::resolveInsolvency() loans[id].state != LoanState.Insolvent");

        uint256 paymentAmount;

        if (amount >= loans[id].principalOwed) {
            paymentAmount = loans[id].principalOwed;
            loans[id].principalOwed == 0;
            loans[id].state = LoanState.Repaid;
            IERC20(baseToken).transferFrom(_msgSender(), owner(), amount - loans[id].principalOwed);
        }
        else {
            paymentAmount = amount;
            loans[id].principalOwed -= paymentAmount;
        }

        IERC20(baseToken).transferFrom(_msgSender(), owner(), paymentAmount);
    }

    // TODO: Update this function per specifications.
    
    /// @dev    Supply interest to a repaid loan (for arbitrary interest repayment).
    /// @param  id The ID of the loan.
    /// @param  amt The amount of  interest to supply.
    function supplyInterest(uint256 id, uint256 amt) public {

        require(loans[id].state == LoanState.Resolved, "OCC_FRAX.sol::supplyInterest() loans[id].state != LoanState.Repaid");

        IERC20(baseToken).transferFrom(_msgSender(), YDL, amt); 
    }

    // TODO: Unit testing verification.

    /// @dev    Issuer specifies a loan has been repaid fully via interest deposits in terms of off-chain debt.
    /// @param  id The ID of the loan.
    function markRepaid(uint256 id) public isIssuer {

        require(loans[id].state == LoanState.Resolved, "OCC_FRAX.sol::markRepaid() loans[id].state != LoanState.Repaid");

        loans[id].state = LoanState.Repaid;
    }

    /// @dev    Returns information for amount owed on next payment of a particular loan.
    /// @param  id The ID of the loan.
    /// @return principalOwed The amount of principal owed.
    /// @return interestOwed The amount of interest owed.
    /// @return totalOwed The total amount owed, combining principal plus interested.
    function amountOwed(uint256 id) public view returns(uint256 principalOwed, uint256 interestOwed, uint256 totalOwed) {

        // 0 == Bullet
        if (loans[id].paymentSchedule == 0) {
            if (loans[id].paymentsRemaining == 1) {
                principalOwed = loans[id].principalOwed;
            }

            interestOwed = loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * 10000);

            if (block.timestamp > loans[id].paymentDueBy) {
                interestOwed += loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * 10000);
            }

            totalOwed = principalOwed + interestOwed;
        }
        // 1 == Amortization (only two options, use else here).
        else {

            interestOwed = loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * 10000);

            if (block.timestamp > loans[id].paymentDueBy) {
                interestOwed += loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * 10000);
            }

            principalOwed = loans[id].principalOwed / loans[id].paymentsRemaining;

            totalOwed = principalOwed + interestOwed;
        }
        
    }

    /// @dev    Returns information for a given loan
    /// @param  id The ID of the loan.
    function loanInformation(uint256 id) public view returns(
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
    ) {
        borrower = loans[id].borrower;
        principalOwed = loans[id].principalOwed;
        APR = loans[id].APR;
        APRLateFee = loans[id].APRLateFee;
        paymentDueBy = loans[id].paymentDueBy;
        paymentsRemaining = loans[id].paymentsRemaining;
        term = loans[id].term;
        paymentInterval = loans[id].paymentInterval;
        requestExpiry = loans[id].requestExpiry;
        paymentSchedule = loans[id].paymentSchedule;
        loanState = uint256(loans[id].state);
    }

}
