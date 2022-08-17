// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

import { IZivoeGBL, ISushiRouter, ISushiFactory } from "../interfaces/InterfacesAggregated.sol";

contract OCL_ZVE_SUSHI_0 is ZivoeLocker {
    
    
    // ---------------
    // State Variables
    // ---------------

    address constant public SUSHI_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address constant public SUSHI_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address constant public FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    
    address public GBL;         /// @dev Zivoe globals.

    uint256 baseline;
    uint256 nextYieldDistribution;
    

    // -----------
    // Constructor
    // -----------

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

    /// @dev    This pulls capital from the DAO and adds liquidity into a Sushi ZVE/FRAX pool.
    /// @notice Only callable by the DAO.
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) public override onlyOwner {
        require(assets[0] == FRAX && assets[1] == IZivoeGBL(GBL).ZVE());
        for (uint i = 0; i < 2; i++) {
            IERC20(assets[i]).transferFrom(owner(), address(this), amounts[i]);
        }
        if (nextYieldDistribution == 0) {
            nextYieldDistribution = block.timestamp + 30 days;
        }
        // SushiRouter, addLiquidity()
        IERC20(FRAX).approve(SUSHI_ROUTER, IERC20(FRAX).balanceOf(address(this)));
        IERC20(IZivoeGBL(GBL).ZVE()).approve(SUSHI_ROUTER, IERC20(IZivoeGBL(GBL).ZVE()).balanceOf(address(this)));
        ISushiRouter(SUSHI_ROUTER).addLiquidity(
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

    /// @dev    This burns LP tokens from the Sushi ZVE/FRAX pool and returns them to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  assets The assets to return.
    function pullFromLockerMulti(address[] calldata assets) public override onlyOwner {
        // TODO: Consider need for "key"-like activation/approval of withdrawal below.
        require(assets[0] == FRAX && assets[1] == IZivoeGBL(GBL).ZVE());
        address pair = ISushiFactory(SUSHI_FACTORY).getPair(FRAX, IZivoeGBL(GBL).ZVE());
        IERC20(pair).approve(SUSHI_ROUTER, IERC20(pair).balanceOf(address(this)));
        ISushiRouter(SUSHI_ROUTER).removeLiquidity(
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