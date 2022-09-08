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
    
    uint256 public exponentialDecayRate;    /// @dev The constant that determines the slope of decay.
    uint256 public decayFinality;    /// @dev The constant that determines the slope of decay.

    /// @dev Determines distribution between rewards contract, in BIPS.
    /// @dev The sum of distributionRatioBPS[0], distributionRatioBPS[1], and distributionRatioBPS[2] must equal 10000.
    uint256[3] public distributionRatioBPS;



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

    function canPush() external override pure returns (bool) {
        return true;
    }

    /// @dev    Allocates ZVE from the DAO to this locker for emissions, automatically forwards 50% of ZVE to emissions schedule.
    /// @notice Only callable by the DAO.
    function pushToLocker(address asset, uint256 amount) external override onlyOwner {
        require(asset == IZivoeGlobals(GBL).ZVE(), "asset != IZivoeGlobals(GBL).ZVE()");
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }

    /// @dev Returns amount of $ZVE available for distribution, which decays exponentially.
    function amountDistributable() public pure returns(uint256) {
        return 0;
    }

    /// @notice Updates the distribution between rewards contract, in BIPS.
    /// @dev    The sum of distributionRatioBPS[0], distributionRatioBPS[1], and distributionRatioBPS[2] must equal 10000.
    function updateDistributionRatioBPS(uint256[3] calldata _distributionRatioBPS) external {
        require(
            _distributionRatioBPS[0] + _distributionRatioBPS[1] + _distributionRatioBPS[2] == 10000,
            "OCE_ZVE::updateDistributionRatioBPS() _distributionRatioBPS[0] + _distributionRatioBPS[1] + _distributionRatioBPS[2] != 10000"
        );
        distributionRatioBPS[0] = _distributionRatioBPS[0];
        distributionRatioBPS[1] = _distributionRatioBPS[1];
        distributionRatioBPS[2] = _distributionRatioBPS[2];
    }

    /// @dev Forwards $ZVE available for distribution.
    function forwardEmissions() external {
        _forwardEmissions(amountDistributable());
    }

    /// @dev    This handles the accoounting for forwarding ZVE to lockers privately.
    function _forwardEmissions(uint256 amount) private {
        IERC20(IZivoeGlobals(GBL).ZVE()).safeApprove(IZivoeGlobals(GBL).stZVE(), amount * distributionRatioBPS[0] / 10000);
        IERC20(IZivoeGlobals(GBL).ZVE()).safeApprove(IZivoeGlobals(GBL).stSTT(), amount * distributionRatioBPS[1] / 10000);
        IERC20(IZivoeGlobals(GBL).ZVE()).safeApprove(IZivoeGlobals(GBL).stJTT(), amount * distributionRatioBPS[2] / 10000);
        IZivoeRewards(IZivoeGlobals(GBL).stZVE()).depositReward(IZivoeGlobals(GBL).ZVE(), amount * distributionRatioBPS[0] / 10000);
        IZivoeRewards(IZivoeGlobals(GBL).stSTT()).depositReward(IZivoeGlobals(GBL).ZVE(), amount * distributionRatioBPS[1] / 10000);
        IZivoeRewards(IZivoeGlobals(GBL).stJTT()).depositReward(IZivoeGlobals(GBL).ZVE(), amount * distributionRatioBPS[2] / 10000);
    }

}
