// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

import { ICRV_PP_128_NP, ICRV_MP_256, ILendingPool, IAToken, IZivoeGlobals } from "../interfaces/InterfacesAggregated.sol";

/// @dev    This contract is responsible for allocating capital to AAVE (v2).
///         TODO: Consider looking into credit delegation.
contract OCY_AAVE is ZivoeLocker {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;  /// @dev Zivoe globals contract.

    /// @dev Stablecoin addresses.
    address public constant DAI  = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    /// @dev CRV.FI pool addresses (plain-pool, and meta-pool).
    address public constant CRV_PP = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address public constant FRAX3CRV_MP = 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B;

    /// @dev AAVE v2 addresses.
    address public constant AAVE_V2_LendingPool = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address public constant AAVE_V2_aUSDC = 0xBcca60bB61934080951369a648Fb03DF4F96263C;

    uint256 baseline;
    uint256 nextYieldDistribution;


    
    // -----------
    // Constructor
    // -----------

    // TODO: Refactor for GBL pointer/reference.

    /// @notice Initializes the OCY_AAVE.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.
    constructor(address DAO, address _GBL) {
        transferOwnership(DAO);
        GBL = _GBL;
    }


    // TODO: Consider event logs here for specific actions / conversions.

    // ---------
    // Functions
    // ---------

    // TODO: Refactor for partial pull().

    function canPush() external override pure returns (bool) {
        return true;
    }

    function canPull() external override pure returns (bool) {
        return true;
    }

    /// @dev    This pulls capital from the DAO, does any necessary pre-conversions, and invests into AAVE v2 (USDC pool).
    /// @notice Only callable by the DAO.
    function pushToLocker(address asset, uint256 amount) external override onlyOwner {

        require(amount > 0, "OCY_AAVE::pushToLocker() amount == 0");

        nextYieldDistribution = block.timestamp + 30 days;

        IERC20(asset).safeTransferFrom(owner(), address(this), amount);

        if (asset == USDC) {
            _invest();
        }
        else {
            if (asset == DAI) {
                // Convert DAI to USDC via 3CRV pool.
                IERC20(asset).safeApprove(CRV_PP, IERC20(asset).balanceOf(address(this)));
                ICRV_PP_128_NP(CRV_PP).exchange(0, 1, IERC20(asset).balanceOf(address(this)), 0);
                _invest();
            }
            else if (asset == USDT) {
                // Convert USDT to USDC via 3CRV pool.
                IERC20(asset).safeApprove(CRV_PP, IERC20(asset).balanceOf(address(this)));
                ICRV_PP_128_NP(CRV_PP).exchange(int128(2), int128(1), IERC20(asset).balanceOf(address(this)), 0);
                _invest();
            }
            else if (asset == FRAX) {
                // Convert FRAX to USDC via FRAX/3CRV meta-pool.
                IERC20(asset).safeApprove(FRAX3CRV_MP, IERC20(asset).balanceOf(address(this)));
                ICRV_MP_256(FRAX3CRV_MP).exchange_underlying(int128(0), int128(2), IERC20(asset).balanceOf(address(this)), 0);
                _invest();
            }
            else {
                /// @dev Revert here, given unknown "asset" received (otherwise, "asset" will be locked and/or lost forever).
                revert("OCY_AAVE.sol::pushToLocker() asset not supported"); 
            }
        }
    }

    /// @dev    This divests allocation from AAVE v2 (USDC pool) and returns capital to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  asset The asset to return (in this case, required to be USDC).
    function pullFromLocker(address asset) external override onlyOwner {
        require(asset == USDC, "OCY_AAVE::pullFromLocker() asset != USDC");
        _divest();
    }

    /// @dev    This forwards yield to the YDL (according to specific conditions as will be discussed).
    function forwardYield() external {
        require(block.timestamp > nextYieldDistribution, "OCY_AAVE::forwardYield() block.timestamp <= nextYieldDistribution");
        nextYieldDistribution = block.timestamp + 30 days;
        _forwardYield();
        baseline = IERC20(AAVE_V2_aUSDC).balanceOf(address(this));
    }

    function _forwardYield() private {
        uint256 currentBalance = IERC20(AAVE_V2_aUSDC).balanceOf(address(this));
        uint256 difference = currentBalance - baseline;
        ILendingPool(AAVE_V2_LendingPool).withdraw(USDC, difference, address(this));
        IERC20(USDC).safeApprove(FRAX3CRV_MP, IERC20(USDC).balanceOf(address(this)));
        ICRV_MP_256(FRAX3CRV_MP).exchange_underlying(int128(2), int128(0), IERC20(USDC).balanceOf(address(this)), 0);
        IERC20(FRAX).safeApprove(IZivoeGlobals(GBL).YDL(), IERC20(FRAX).balanceOf(address(this)));
    }

    /// @dev    This directs USDC into the AAVE v2 lending protocol.
    /// @notice Private function, should only be called through pushToLocker() which can only be called by DAO.
    function _invest() private {
        baseline += IERC20(USDC).balanceOf(address(this));
        IERC20(USDC).safeApprove(AAVE_V2_LendingPool, IERC20(USDC).balanceOf(address(this)));
        ILendingPool(AAVE_V2_LendingPool).deposit(USDC, IERC20(USDC).balanceOf(address(this)), address(this), uint16(0));
    }

    /// @dev    This removes USDC from the AAVE lending protocol.
    /// @notice Private function, should only be called through pullFromLocker() which can only be called by DAO.
    function _divest() private {
        /// TODO: Add event log for removal amount (?) or forwardYield (?), use return var below.
        // uint256 departure = ILendingPool(AAVE_V2_LendingPool).withdraw(USDC, type(uint256).max, IZivoeGlobals(GBL).DAO());
        ILendingPool(AAVE_V2_LendingPool).withdraw(USDC, type(uint256).max, IZivoeGlobals(GBL).DAO());
        baseline = 0;
    }

}
