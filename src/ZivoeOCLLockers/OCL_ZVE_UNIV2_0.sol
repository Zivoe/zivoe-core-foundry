// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

import { IZivoeGBL, IUniswapV2Router01, IUniswapV2Factory } from "../interfaces/InterfacesAggregated.sol";

contract OCL_ZVE_UNIV2_0 is ZivoeLocker {
    
    // ---------------------
    //    State Variables
    // ---------------------

    address constant public UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant public UNIV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant public FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    
    address public immutable GBL;  /// @dev Zivoe globals contract.

    uint256 public baseline;                /// @dev FRAX convertible, used for forwardYield() accounting.
    uint256 public nextYieldDistribution;   /// @dev Determines next available forwardYield() call.

    
    // -----------
    // Constructor
    // -----------

    // TODO: Refactor for GBL pointer/reference.

    /// @notice Initializes the OCL_ZVE_UNIV2_0.sol contract.
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

    function canPushMulti() external pure override returns (bool) {
        return true;
    }

    function canPullMulti() external pure override returns (bool) {
        return true;
    }

    /// @dev    This pulls capital from the DAO and adds liquidity into a UniswapV2 ZVE/FRAX pool.
    /// @notice Only callable by the DAO.
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) public override onlyOwner {
        require(assets[0] == FRAX && assets[1] == IZivoeGBL(GBL).ZVE());
        for (uint i = 0; i < 2; i++) {
            IERC20(assets[i]).transferFrom(owner(), address(this), amounts[i]);
        }
        if (nextYieldDistribution == 0) {
            nextYieldDistribution = block.timestamp + 30 days;
        }
        uint256 preBaseline;
        if (baseline != 0) {
            (preBaseline,) = _FRAXConvertible();
        }
        // UniswapRouter, addLiquidity()
        IERC20(FRAX).approve(UNIV2_ROUTER, IERC20(FRAX).balanceOf(address(this)));
        IERC20(IZivoeGBL(GBL).ZVE()).approve(UNIV2_ROUTER, IERC20(IZivoeGBL(GBL).ZVE()).balanceOf(address(this)));
        IUniswapV2Router01(UNIV2_ROUTER).addLiquidity(
            FRAX, 
            IZivoeGBL(GBL).ZVE(), 
            IERC20(FRAX).balanceOf(address(this)),
            IERC20(IZivoeGBL(GBL).ZVE()).balanceOf(address(this)),
            IERC20(FRAX).balanceOf(address(this)),
            IERC20(IZivoeGBL(GBL).ZVE()).balanceOf(address(this)),
            address(this),
            block.timestamp + 14 days
        );
        // Increase baseline.
        (uint256 postBaseline,) = _FRAXConvertible();
        require(postBaseline > preBaseline);
        baseline = postBaseline - preBaseline;
    }

    /// @dev    This burns LP tokens from the UniswapV2 ZVE/FRAX pool and returns them to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  assets The assets to return.
    function pullFromLockerMulti(address[] calldata assets) public override onlyOwner {
        require(assets[0] == FRAX && assets[1] == IZivoeGBL(GBL).ZVE());
        address pair = IUniswapV2Factory(UNIV2_FACTORY).getPair(FRAX, IZivoeGBL(GBL).ZVE());
        IERC20(pair).approve(UNIV2_ROUTER, IERC20(pair).balanceOf(address(this)));
        IUniswapV2Router01(UNIV2_ROUTER).removeLiquidity(
            FRAX, 
            IZivoeGBL(GBL).ZVE(), 
            IERC20(pair).balanceOf(address(this)), 
            0, 
            0,
            address(this),
            block.timestamp + 14 days
        );
        IERC20(FRAX).transfer(owner(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(IZivoeGBL(GBL).ZVE()).transfer(owner(), IERC20(IZivoeGBL(GBL).ZVE()).balanceOf(address(this)));
        baseline = 0;
    }

    /// @dev    This forwards yield to the YDL in the form of FRAX.
    function forwardYield() public {
        if (IZivoeGBL(GBL).isKeeper(_msgSender())) {
            require(block.timestamp > nextYieldDistribution - 12 hours);
        }
        else {
            require(block.timestamp > nextYieldDistribution);
        }
        require(block.timestamp > nextYieldDistribution);
        (uint256 amt, uint256 lp) = _FRAXConvertible();
        require(amt > baseline);
        nextYieldDistribution = block.timestamp + 30 days;
        _forwardYield(amt, lp);
    }

    function _forwardYield(uint256 amt, uint256 lp) private {
        uint256 lpBurnable = (amt - baseline) * lp / amt / 2;
        address pair = IUniswapV2Factory(UNIV2_FACTORY).getPair(FRAX, IZivoeGBL(GBL).ZVE());
        IERC20(pair).approve(UNIV2_ROUTER, lpBurnable);
        IUniswapV2Router01(UNIV2_ROUTER).removeLiquidity(
            FRAX,
            IZivoeGBL(GBL).ZVE(),
            lpBurnable,
            0,
            0,
            address(this),
            block.timestamp + 14 days
        );
        IERC20(FRAX).transfer(IZivoeGBL(GBL).YDL(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(IZivoeGBL(GBL).ZVE()).transfer(owner(), IERC20(IZivoeGBL(GBL).ZVE()).balanceOf(address(this)));
        (baseline,) = _FRAXConvertible();
    }

    /// @dev Returns information on how much FRAX is convertible via current LP tokens.
    /// @return amt Current FRAX harvestable.
    /// @return lp Current ZVE/FRAX LP tokens.
    /// @notice The withdrawal mechanism is ZVE/FRAX_LP => Frax.
    function _FRAXConvertible() public view returns (uint256 amt, uint256 lp) {
        address pair = IUniswapV2Factory(UNIV2_FACTORY).getPair(FRAX, IZivoeGBL(GBL).ZVE());
        uint256 balance_FRAX = IERC20(FRAX).balanceOf(pair);
        uint256 totalSupply_PAIR = IERC20(pair).totalSupply();
        lp = IERC20(pair).balanceOf(address(this));
        amt = lp * balance_FRAX / totalSupply_PAIR;
    }

}