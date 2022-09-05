// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

import { IZivoeRewards, IZivoeGlobals } from "../interfaces/InterfacesAggregated.sol";


contract OCE_ZVE is ZivoeLocker {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;   /// @dev Zivoe globals contract.

    uint256 public nextDistribution;    /// @dev Determines next available forwardYield() call.
    uint256 public distributionsMade;   /// @dev # of distributions made.
    
    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the OCE_ZVE.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.
    constructor(
        address DAO,
        address _GBL
    ) {
        transferOwnership(DAO);
        GBL = _GBL;
    }

    // ---------
    // Functions
    // ---------

    function canPush() external override view returns (bool) {
        return distributionsMade <= 4;
    }

    function canPull() external override pure returns (bool) {
        return true;
    }

    function canPullPartial() external override pure returns (bool) {
        return true;
    }

    /// @dev    Allocates ZVE from the DAO to this locker for emissions, automatically forwards 50% of ZVE to emissions schedule.
    /// @notice Only callable by the DAO.
    function pushToLocker(address asset, uint256 amount) external override onlyOwner {
        require(asset == IZivoeGlobals(GBL).ZVE(), "asset != IZivoeGlobals(GBL).ZVE()");
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
        if (nextDistribution == 0 && distributionsMade == 0) {
            nextDistribution = block.timestamp + 360 days;
            distributionsMade = 1;
        }
        _forwardEmissions(amount / 2);
    }

    /// @dev    Returns all ZVE within this contract to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  asset To be denoted as ZVE.
    function pullFromLocker(address asset) external override onlyOwner {
        require(asset == IZivoeGlobals(GBL).ZVE(), "asset != IZivoeGlobals(GBL).ZVE()");
        IERC20(asset).safeTransfer(owner(), IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
    }

    /// @dev    This returns a partial amount of ZVE tokens to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  asset To be denoted as ZVE.
    /// @param  amount The amount of ZVE to return.
    function pullFromLockerPartial(address asset, uint256 amount) external override onlyOwner {
        require(asset == IZivoeGlobals(GBL).ZVE(), "asset != IZivoeGlobals(GBL).ZVE()");
        IERC20(asset).safeTransfer(owner(), amount);
    }

    /// @dev    This forwards ZVE to the various lockers via public accessbility.
    function forwardEmissions() external {
        require(block.timestamp > nextDistribution, "block.timestamp <= nextDistribution");
        nextDistribution += 360 days;
        distributionsMade += 1;
        // NOTE: On the 5th distribution, this locker will allocate remaining ZVE for emissions.
        if (distributionsMade == 5) {
            _forwardEmissions(IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        }
        else {
            _forwardEmissions(IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)) / 2);
        }
    }

    /// @dev    This handles the accoounting for forwarding ZVE to lockers privately.
    function _forwardEmissions(uint256 amount) private {
        IERC20(IZivoeGlobals(GBL).ZVE()).safeApprove(IZivoeGlobals(GBL).stZVE(), amount / 3);
        IERC20(IZivoeGlobals(GBL).ZVE()).safeApprove(IZivoeGlobals(GBL).stSTT(), amount / 3);
        IERC20(IZivoeGlobals(GBL).ZVE()).safeApprove(IZivoeGlobals(GBL).stJTT(), amount / 3);
        IZivoeRewards(IZivoeGlobals(GBL).stZVE()).depositReward(IZivoeGlobals(GBL).ZVE(), amount / 3);
        IZivoeRewards(IZivoeGlobals(GBL).stSTT()).depositReward(IZivoeGlobals(GBL).ZVE(), amount / 3);
        IZivoeRewards(IZivoeGlobals(GBL).stJTT()).depositReward(IZivoeGlobals(GBL).ZVE(), amount / 3);
    }

}
