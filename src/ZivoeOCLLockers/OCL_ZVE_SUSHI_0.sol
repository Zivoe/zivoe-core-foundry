// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

import { IZivoeGlobals, ISushiRouter, ISushiFactory } from "../interfaces/InterfacesAggregated.sol";

contract OCL_ZVE_SUSHI_0 is ZivoeLocker {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    address constant public SUSHI_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address constant public SUSHI_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address constant public FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    
    address public immutable GBL;  /// @dev Zivoe globals contract.

    uint256 public baseline;                /// @dev FRAX convertible, used for forwardYield() accounting.
    uint256 public nextYieldDistribution;   /// @dev Determines next available forwardYield() call.
    

    // -----------
    // Constructor
    // -----------

    // TODO: Refactor for GBL pointer/reference.

    /// @notice Initializes the OCL_ZVE_SUSHI_0.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.
    constructor(
        address DAO,
        address _GBL
    ) {
        transferOwnership(DAO);
        GBL = _GBL;
    }


    // TODO: Consider event logs here for specific actions / conversions.

    // ---------
    // Functions
    // ---------

    // TODO: Refactor for partial pull().

    function canPushMulti() public override pure returns (bool) {
        return true;
    }

    function canPullMulti() public override pure returns (bool) {
        return true;
    }

    /// @dev    This pulls capital from the DAO and adds liquidity into a Sushi ZVE/FRAX pool.
    /// @notice Only callable by the DAO.
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) external override onlyOwner {
        require(
            assets[0] == FRAX && assets[1] == IZivoeGlobals(GBL).ZVE(),
            "OCL_ZVE_SUSHI_0::pushToLockerMulti() assets[0] != FRAX || assets[1] != IZivoeGlobals(GBL).ZVE()"
        );

        for (uint i = 0; i < 2; i++) {
            IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
        }
        if (nextYieldDistribution == 0) {
            nextYieldDistribution = block.timestamp + 30 days;
        }
        uint256 preBaseline;
        if (baseline != 0) {
            (preBaseline,) = FRAXConvertible();
        }
        // SushiRouter, addLiquidity()
        IERC20(FRAX).safeApprove(SUSHI_ROUTER, IERC20(FRAX).balanceOf(address(this)));
        IERC20(IZivoeGlobals(GBL).ZVE()).safeApprove(SUSHI_ROUTER, IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        ISushiRouter(SUSHI_ROUTER).addLiquidity(
            FRAX, 
            IZivoeGlobals(GBL).ZVE(), 
            IERC20(FRAX).balanceOf(address(this)),
            IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)),
            IERC20(FRAX).balanceOf(address(this)),
            IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)),
            address(this),
            block.timestamp + 14 days
        );
        // Increase baseline.
        (uint256 postBaseline,) = FRAXConvertible();
        require(postBaseline > preBaseline, "OCL_ZVE_SUSHI_0::pushToLockerMulti() postBaseline < preBaseline");
        baseline = postBaseline - preBaseline;
    }

    /// @dev    This burns LP tokens from the Sushi ZVE/FRAX pool and returns them to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  assets The assets to return.
    function pullFromLockerMulti(address[] calldata assets) external override onlyOwner {
        require(
            assets[0] == FRAX && assets[1] == IZivoeGlobals(GBL).ZVE(),
            "OCL_ZVE_SUSHI_0::pullFromLockerMulti() assets[0] != FRAX || assets[1] != IZivoeGlobals(GBL).ZVE()"
        );

        address pair = ISushiFactory(SUSHI_FACTORY).getPair(FRAX, IZivoeGlobals(GBL).ZVE());
        IERC20(pair).safeApprove(SUSHI_ROUTER, IERC20(pair).balanceOf(address(this)));
        ISushiRouter(SUSHI_ROUTER).removeLiquidity(
            FRAX, 
            IZivoeGlobals(GBL).ZVE(), 
            IERC20(pair).balanceOf(address(this)), 
            0, 
            0,
            address(this),
            block.timestamp + 14 days
        );
        IERC20(FRAX).safeTransfer(owner(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(IZivoeGlobals(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        baseline = 0;
    }

    /// @dev    This forwards yield to the YDL in the form of FRAX.
    function forwardYield() external {
        if (IZivoeGlobals(GBL).isKeeper(_msgSender())) {
            require(
                block.timestamp > nextYieldDistribution - 12 hours, 
                "OCL_ZVE_SUSHI_0::forwardYield() block.timestamp <= nextYieldDistribution - 12 hours"
            );
        }
        else {
            require(block.timestamp > nextYieldDistribution, "OCL_ZVE_SUSHI_0::forwardYield() block.timestamp <= nextYieldDistribution");
        }
        (uint256 amt, uint256 lp) = FRAXConvertible();
        require(amt > baseline, "OCL_ZVE_SUSHI_0::forwardYield() amt <= baseline");
        nextYieldDistribution = block.timestamp + 30 days;
        _forwardYield(amt, lp);
    }

    /// @dev Returns information on how much FRAX is convertible via current LP tokens.
    /// @return amt Current FRAX harvestable.
    /// @return lp Current ZVE/FRAX LP tokens.
    /// @notice The withdrawal mechanism is ZVE/FRAX_LP => Frax.
    function FRAXConvertible() public view returns (uint256 amt, uint256 lp) {
        address pair = ISushiFactory(SUSHI_FACTORY).getPair(FRAX, IZivoeGlobals(GBL).ZVE());
        uint256 balance_FRAX = IERC20(FRAX).balanceOf(pair);
        uint256 totalSupply_PAIR = IERC20(pair).totalSupply();
        lp = IERC20(pair).balanceOf(address(this));
        amt = lp * balance_FRAX / totalSupply_PAIR;
    }

    function _forwardYield(uint256 amt, uint256 lp) private {
        uint256 lpBurnable = (amt - baseline) * lp / amt / 2;
        address pair = ISushiFactory(SUSHI_FACTORY).getPair(FRAX, IZivoeGlobals(GBL).ZVE());
        IERC20(pair).safeApprove(SUSHI_ROUTER, lpBurnable);
        ISushiRouter(SUSHI_ROUTER).removeLiquidity(
            FRAX,
            IZivoeGlobals(GBL).ZVE(),
            lpBurnable,
            0,
            0,
            address(this),
            block.timestamp + 14 days
        );
        IERC20(FRAX).safeTransfer(IZivoeGlobals(GBL).YDL(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(IZivoeGlobals(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        (baseline,) = FRAXConvertible();
    }

}