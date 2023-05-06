// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IZivoeGlobals_OCY_Convex_B {
    /// @notice Returns the address of the Zivoe Laboratory.
    function ZVL() external view returns (address);
}

/// @notice This contract allocates stablecoins to the sUSD base-pool on Convex.
contract OCY_Convex_B is ZivoeLocker, ReentrancyGuard {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;                   /// @dev The ZivoeGlobals contract.

    address public OCT_YDL;                         /// @dev The OCT_YDL contract.

    uint256 public distributionLast;                /// @dev Timestamp of last distribution.
    uint256 public basis;                           /// @dev The basis for distribution accounting.

    uint256 public constant INTERVAL = 14 days;     /// @dev Number of seconds between each distribution.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_OUSD contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _OCT_YDL The OCT_YDL (Treasury and ZivoeSwapper) contract.
    constructor(address DAO, address _GBL, address _OCT_YDL) {
        transferOwnership(DAO);
        GBL = _GBL;
        OCT_YDL = _OCT_YDL;
        distributionLast = block.timestamp;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during forwardYield().
    /// @param  priorBasis The prior value of basis.
    /// @param  newBasis The new value of basis.
    event BasisAdjusted(uint256 priorBasis, uint256 newBasis);

    /// @notice Emitted during setOCTYDL().
    /// @param  newOCT The new OCT_YDL contract.
    /// @param  oldOCT The old OCT_YDL contract.
    event OCTYDLSetZVL(address indexed newOCT, address indexed oldOCT);

    /// @notice Emitted during forwardYield().
    /// @param  amount The amount of OUSD forwarded.
    /// @param  newBasis The new basis value.
    event YieldForwarded(uint256 amount, uint256 newBasis);


    // ---------------
    //    Functions
    // ---------------

    function canPush() public pure override returns (bool) {
        return true;
    }

    function canPull() public pure override returns (bool) {
        return true;
    }

    function canPullPartial() public override pure returns (bool) {
        return true;
    }

    /// @notice Update the OCT_YDL endpoint.
    /// @dev    This function MUST only be called by ZVL().
    /// @param  _OCT_YDL The new address for OCT_YDL.
    function setOCTYDL(address _OCT_YDL) external {
        require(
            _msgSender() == IZivoeGlobals_OCY_Convex_B(GBL).ZVL(), 
            "OCY_Convex_B::setOCTYDL() _msgSender() != IZivoeGlobals_OCY_Convex_B(GBL).ZVL()"
        );
        emit OCTYDLSetZVL(_OCT_YDL, OCT_YDL);
        OCT_YDL = _OCT_YDL;
    }

    /// @notice Forwards excess basis to OCY_Convex_B for conversion.
    /// @dev    Callable every 14 days.
    function forwardYield() external nonReentrant {
        require(
            block.timestamp > distributionLast + INTERVAL, 
            "OCY_Convex_B::forwardYield() block.timestamp <= distributionLast + INTERVAL"
        );
        distributionLast = block.timestamp;
        // basis = ?;
    }

}