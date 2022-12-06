// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

interface IZivoeGlobals_P_3 {
    function stZVE() external view returns (address);
    function stSTT() external view returns (address);
    function stJTT() external view returns (address);
    function TLC() external view returns (address);
    function YDL() external view returns (address);
    function ZVE() external view returns (address);
    function defaults() external view returns (uint256);
    function isKeeper(address) external view returns (bool);
    function standardize(uint256, address) external view returns (uint256);
    function decreaseDefaults(uint256) external;
    function increaseDefaults(uint256) external;
}

interface IZivoeRewards_P_0 {
    function depositReward(address, uint256) external;
}

/// @notice This contract facilitates an exponential decay emissions schedule for $ZVE.
///         This contract has the following responsibilities:
///           - Handles accounting (with governable variables) to support emissions schedule.
///           - Forwards $ZVE to all ZivoeRewards contracts at will (stZVE, stSTT, stJTT).
contract OCE_ZVE is ZivoeLocker {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;           /// @dev The ZivoeGlobals contract.

    uint256 public lastDistribution;        /// @dev The block.timestamp value of last distribution.

    uint256 public exponentialDecayPerSecond = RAY * 99999998 / 100000000;    /// @dev The rate of decay per second.

    /// @dev Determines distribution between rewards contract, in BIPS.
    /// @dev The sum of distributionRatioBIPS[0], distributionRatioBIPS[1], and distributionRatioBIPS[2] must equal BIPS.
    ///      distributionRatioBIPS[0] => stZVE
    ///      distributionRatioBIPS[1] => stSTT
    ///      distributionRatioBIPS[2] => stJTT
    uint256[3] public distributionRatioBIPS;

    ///NOTE: add description for two below variables
    uint256 private constant BIPS = 10000;
    uint256 private constant RAY = 10 ** 27;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCE_ZVE.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The ZivoeGlobals contract.
    constructor(
        address DAO,
        address _GBL
    ) {
        transferOwnership(DAO);
        GBL = _GBL;
        lastDistribution = block.timestamp;
    }

    // ------------
    //    Events
    // ------------

    /// @notice Emitted during updateDistributionRatioBIPS().
    /// @param  oldRatios The old distribution ratios.
    /// @param  newRatios The new distribution ratios.
    event UpdatedDistributionRatioBIPS(uint256[3] oldRatios, uint256[3] newRatios);

    /// @notice Emitted during forwardEmissions().
    /// @param  stZVE The amount of $ZVE emitted to the $ZVE rewards contract.
    /// @param  stJTT The amount of $ZVE emitted to the $zJTT rewards contract.
    /// @param  stSTT The amount of $ZVE emitted to the $zSTT rewards contract.
    event EmissionsForwarded(uint256 stZVE, uint256 stJTT, uint256 stSTT);

    /// @notice Emitted during setExponentialDecayPerSecond().
    /// @param  oldValue The old value of exponentialDecayPerSecond.
    /// @param  newValue The new value of exponentialDecayPerSecond.
    event UpdatedExponentialDecayPerSecond(uint256 oldValue, uint256 newValue);



    // ---------------
    //    Functions
    // ---------------

    function canPush() public override pure returns (bool) {
        return true;
    }

    /// @notice    Allocates ZVE from the DAO to this locker for emissions, automatically forwards 50% of ZVE to emissions schedule.
    /// @dev       Only callable by the DAO.
    /// @param     asset The asset to push to this locker (in this case $ZVE).
    /// @param     amount The amount of $ZVE to push to this locker.
    function pushToLocker(address asset, uint256 amount) external override onlyOwner {
        require(asset == IZivoeGlobals_P_3(GBL).ZVE(), "OCE_ZVE::pushToLocker() asset != IZivoeGlobals_P_3(GBL).ZVE()");
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }
    
    /// @notice Updates the distribution between rewards contract, in BIPS.
    /// @dev    The sum of distributionRatioBIPS[0], distributionRatioBIPS[1], and distributionRatioBIPS[2] must equal BIPS.
    /// @param  _distributionRatioBIPS The updated values for the state variable distributionRatioBIPS.
    function updateDistributionRatioBIPS(uint256[3] calldata _distributionRatioBIPS) external {
        require(_msgSender() == IZivoeGlobals_P_3(GBL).TLC(), "OCE_ZVE::setExponentialDecayPerSecond() _msgSender() != IZivoeGlobals_P_3(GBL).TLC()");
        require(
            _distributionRatioBIPS[0] + _distributionRatioBIPS[1] + _distributionRatioBIPS[2] == BIPS,
            "OCE_ZVE::updateDistributionRatioBIPS() _distributionRatioBIPS[0] + _distributionRatioBIPS[1] + _distributionRatioBIPS[2] != BIPS"
        );
        emit UpdatedDistributionRatioBIPS(distributionRatioBIPS, _distributionRatioBIPS);
        distributionRatioBIPS[0] = _distributionRatioBIPS[0];
        distributionRatioBIPS[1] = _distributionRatioBIPS[1];
        distributionRatioBIPS[2] = _distributionRatioBIPS[2];
    }

    /// @notice Forwards $ZVE available for distribution.
    function forwardEmissions() external {
        _forwardEmissions(
            IERC20(IZivoeGlobals_P_3(GBL).ZVE()).balanceOf(address(this)) - 
            decay(IERC20(IZivoeGlobals_P_3(GBL).ZVE()).balanceOf(address(this)), block.timestamp - lastDistribution)
        );
        lastDistribution = block.timestamp;
    }

    /// @notice This handles the accounting for forwarding ZVE to lockers privately.
    /// @param amount The amount of $ZVE to distribute.
    function _forwardEmissions(uint256 amount) private {
        emit EmissionsForwarded(
            amount * distributionRatioBIPS[0] / BIPS,
            amount * distributionRatioBIPS[1] / BIPS,
            amount * distributionRatioBIPS[2] / BIPS
        );
        IERC20(IZivoeGlobals_P_3(GBL).ZVE()).safeApprove(IZivoeGlobals_P_3(GBL).stZVE(), amount * distributionRatioBIPS[0] / BIPS);
        IERC20(IZivoeGlobals_P_3(GBL).ZVE()).safeApprove(IZivoeGlobals_P_3(GBL).stSTT(), amount * distributionRatioBIPS[1] / BIPS);
        IERC20(IZivoeGlobals_P_3(GBL).ZVE()).safeApprove(IZivoeGlobals_P_3(GBL).stJTT(), amount * distributionRatioBIPS[2] / BIPS);
        IZivoeRewards_P_0(IZivoeGlobals_P_3(GBL).stZVE()).depositReward(IZivoeGlobals_P_3(GBL).ZVE(), amount * distributionRatioBIPS[0] / BIPS);
        IZivoeRewards_P_0(IZivoeGlobals_P_3(GBL).stSTT()).depositReward(IZivoeGlobals_P_3(GBL).ZVE(), amount * distributionRatioBIPS[1] / BIPS);
        IZivoeRewards_P_0(IZivoeGlobals_P_3(GBL).stJTT()).depositReward(IZivoeGlobals_P_3(GBL).ZVE(), amount * distributionRatioBIPS[2] / BIPS);
    }

    /// @notice Updates the exponentialDecayPerSecond variable with provided input.
    /// @dev    For 1.0000% decrease per second, _exponentialDecayPerSecond would be (1 - 0.01) * RAY
    /// @dev    For 0.0001% decrease per second, _exponentialDecayPerSecond would be (1 - 0.000001) * RAY
    /// @param _exponentialDecayPerSecond The updated value for exponentialDecayPerSecond state variable.
    function setExponentialDecayPerSecond(uint256 _exponentialDecayPerSecond) public {
        require(_msgSender() == IZivoeGlobals_P_3(GBL).TLC(), "OCE_ZVE::setExponentialDecayPerSecond() _msgSender() != IZivoeGlobals_P_3(GBL).TLC()");
        emit UpdatedExponentialDecayPerSecond(exponentialDecayPerSecond, _exponentialDecayPerSecond);
        exponentialDecayPerSecond = _exponentialDecayPerSecond; 
    }



    // ----------
    //    Math
    // ----------

    // Functions were ported from:
    // https://github.com/makerdao/dss/blob/master/src/abaci.so

    /// @dev Returns the amount remaining after a decay.
    /// @param top The amount decaying.
    /// @param dur The seconds of decay.
    function decay(uint256 top, uint256 dur) public view returns (uint256) {
        return rmul(top, rpow(exponentialDecayPerSecond, dur, RAY));
    }

    /// NOTE: description and params to add ?
    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x * y;
        require(y == 0 || z / y == x, "OCE_ZVE::rmul() y != 0 && z / y != x");
        z = z / RAY;
    }
    
    /// NOTE: description and params to add ?
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
