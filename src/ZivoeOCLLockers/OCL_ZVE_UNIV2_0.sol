// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

import { IZivoeGBL, IUniswapV2Router01, IUniswapV2Factory } from "../interfaces/InterfacesAggregated.sol";

contract OCL_ZVE_UNIV2_0 is ZivoeLocker {
    
    
    // ---------------
    // State Variables
    // ---------------

    address constant public UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant public UNIV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant public FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    
    address public GBL;         /// @dev Zivoe globals.

    uint256 baseline;
    uint256 nextYieldDistribution;

    
    // -----------
    // Constructor
    // -----------

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



    // ------
    // Events
    // ------

    event Debug(address);
    event Debug(uint256[]);
    event Debug(uint256);

    // ---------
    // Modifiers
    // ---------

    // ---------
    // Functions
    // ---------

    function canPushMulti() external pure override returns(bool) {
        return true;
    }

    function canPullMulti() external pure override returns(bool) {
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
        // TODO: Increase baseline.
    }

    /// @dev    This burns LP tokens from the UniswapV2 ZVE/FRAX pool and returns them to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  assets The assets to return.
    function pullFromLockerMulti(address[] calldata assets) public override onlyOwner {
        // TODO: Consider need for "key"-like activation/approval of withdrawal below.
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
    }

    /// @dev    This forwards yield to the YDL (according to specific conditions as will be discussed).
    function forwardYield() public {
        require(block.timestamp > nextYieldDistribution);
        nextYieldDistribution = block.timestamp + 30 days;
        _forwardYield();
    }

    function _forwardYield() private {
        
    }

    /// @dev Returns information on how much FRAX is convertible via current LP tokens.
    function _FRAXConvertible() public returns(uint256 amt) {
        amt = 5;
    }

}