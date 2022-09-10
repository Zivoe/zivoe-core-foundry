// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

import { IZivoeRewards, IZivoeGlobals } from "../interfaces/InterfacesAggregated.sol";


contract OCE_ZVE is ZivoeLocker {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;           /// @dev Zivoe globals contract.

    uint256 public annualEmissionsRateBPS;  /// @dev The percentage (in BPS) that decays (a.k.a. "emits") annually.
    uint256 public lastDistribution;        /// @dev The block.timestamp value of last distribution.

    uint256 public exponentialDecayPerSecond = RAY * 99999998 / 100000000;    /// @dev The rate of decay per second.

    uint256 constant RAY = 10 ** 27;

    /// @dev Determines distribution between rewards contract, in BPS.
    /// @dev The sum of distributionRatioBPS[0], distributionRatioBPS[1], and distributionRatioBPS[2] must equal 10000.
    ///      distributionRatioBPS[0] =< stZVE
    ///      distributionRatioBPS[1] => stJTT
    ///      distributionRatioBPS[2] => stSTT
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
        distributionRatioBPS[0] = 8000;
        distributionRatioBPS[1] = 500;
        distributionRatioBPS[2] = 1500;
        lastDistribution = block.timestamp;
    }

    // ---------
    // Functions
    // ---------

    function canPush() public override view returns (bool) {
        return true;
    }

    /// @dev    Allocates ZVE from the DAO to this locker for emissions, automatically forwards 50% of ZVE to emissions schedule.
    /// @notice Only callable by the DAO.
    function pushToLocker(address asset, uint256 amount) external override onlyOwner {
        require(asset == IZivoeGlobals(GBL).ZVE(), "asset != IZivoeGlobals(GBL).ZVE()");
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }
    
    /// @notice Updates the distribution between rewards contract, in BIPS.
    /// @dev    The sum of distributionRatioBPS[0], distributionRatioBPS[1], and distributionRatioBPS[2] must equal 10000.
    function updateDistributionRatioBPS(uint256[3] calldata _distributionRatioBPS) external {
        require(_msgSender() == IZivoeGlobals(GBL).TLC(), "OCE_ZVE::setExponentialDecayPerSecond() _msgSender() != IZivoeGlobals(GBL).TLC()");
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
        _forwardEmissions(
            IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)) - 
            decayAmount(IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)), block.timestamp - lastDistribution)
        );
        lastDistribution = block.timestamp;
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

    /// @notice Updates the exponentialDecayPerSecond variable with provided input.
    /// @dev    For 1.0000% decrease per second, _exponentialDecayPerSecond would be (1 - 0.01) * RAY
    /// @dev    For 0.0001% decrease per second, _exponentialDecayPerSecond would be (1 - 0.000001) * RAY
    function setExponentialDecayPerSecond(uint256 _exponentialDecayPerSecond) public {
        require(_msgSender() == IZivoeGlobals(GBL).TLC(), "OCE_ZVE::setExponentialDecayPerSecond() _msgSender() != IZivoeGlobals(GBL).TLC()");
        exponentialDecayPerSecond = _exponentialDecayPerSecond; 
    }



    // ----------
    //    Math
    // ----------

    // Functions were ported from:
    // https://github.com/makerdao/dss/blob/master/src/abaci.so

    function decayAmount(uint256 top, uint256 dur) public view returns (uint256) {
        return rmul(top, rpow(exponentialDecayPerSecond, dur, RAY));
    }

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x * y;
        require(y == 0 || z / y == x);
        z = z / RAY;
    }
    
    function rpow(uint256 x, uint256 n, uint256 b) internal pure returns (uint256 z) {
        assembly {
            switch n case 0 { z := b }
            default {
                switch x case 0 { z := 0 }
                default {
                    switch mod(n, 2) case 0 { z := b } default { z := x }
                    let half := div(b, 2)  // for rounding.
                    for { n := div(n, 2) } n { n := div(n,2) } {
                        let xx := mul(x, x)
                        if shr(128, x) { revert(0,0) }
                        let xxRound := add(xx, half)
                        if lt(xxRound, xx) { revert(0,0) }
                        x := div(xxRound, b)
                        if mod(n,2) {
                            let zx := mul(z, x)
                            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                            let zxRound := add(zx, half)
                            if lt(zxRound, zx) { revert(0,0) }
                            z := div(zxRound, b)
                        }
                    }
                }
            }
        }
    }

}
