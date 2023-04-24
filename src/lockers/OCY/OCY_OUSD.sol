// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

interface OCY_OUSD_IOUSD {
    function rebaseOptIn() external;
}

contract OCY_OUSD is ZivoeLocker {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable OUSD = 0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86;     /// @dev Origin Dollar contract.
    address public immutable GBL;                                                   /// @dev The ZivoeGlobals contract.
    address public immutable OCY_YDL;                                               /// @dev The OCY_YDL contract.

    uint256 public distributionLast;        /// @dev Timestamp of last distribution.
    uint256 public basis;                   /// @dev The basis of OUSD for distribution accounting.

    uint256 public constant INTERVAL = 14 days;    /// @dev Number of seconds between each distribution.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_OUSD contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _OCY_YDL The OCY_YDL contract.
    constructor(address DAO, address _GBL, address _OCY_YDL) {
        transferOwnership(DAO);
        GBL = _GBL;
        OCY_YDL = _OCY_YDL;
        distributionLast = block.timestamp;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during swipeBasis().
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

    /// @notice Ensures this locker has opted-in for the OUSD rebase.
    /// @dev    Only callable once, reverts afterwards once this contract is already opted-in.
    function rebase() public {
        OCY_OUSD_IOUSD(OUSD).rebaseOptIn();
    }

    /// @notice Migrates specific amount of ERC20 from owner() to locker.
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLocker(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(asset == OUSD, "OCY_OUSD::pushToLocker() asset != OUSD");
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
        basis += amount;
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override onlyOwner {
        require(asset == OUSD, "OCY_OUSD::pushToLocker() asset != OUSD");
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
        basis = 0;
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(asset == OUSD, "OCY_OUSD::pushToLocker() asset != OUSD");
        IERC20(asset).safeTransfer(owner(), amount);
        /// NOTE: OUSD balance can potentially decrease (negative yield).
        if (amount >= basis) {
            basis = 0;
        }
        else {
            basis -= amount;
        }
    }

    /// @notice Forwards excess basis to OCT_YDL for conversion.
    /// @dev    Callable every 14 days.
    function swipeBasis() external {
        require(block.timestamp > distributionLast + INTERVAL, "OCY_OUSD::swipeBasis() block.timestamp <= distributionLast + INTERVAL");
        distributionLast = block.timestamp;
        uint256 amountOUSD = IERC20(OUSD).balanceOf(address(this));
        if (amountOUSD > basis) {
            IERC20(OUSD).safeTransfer(owner(), amountOUSD - basis);
            emit YieldForwarded(amountOUSD - basis, IERC20(OUSD).balanceOf(address(this)));
        }
        basis = IERC20(OUSD).balanceOf(address(this));
    }

}