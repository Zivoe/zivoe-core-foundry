// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

import { IZivoeGBL, ICRVDeployer, ICRVMetaPool, ICRVPlainPoolFBP } from "../interfaces/InterfacesAggregated.sol";


contract OCL_ZVE_CRV_0 is ZivoeLocker {
    
    // ---------------
    // State Variables
    // ---------------

    address public constant CRV_Deployer = 0xB9fC157394Af804a3578134A6585C0dc9cc990d4;  /// @dev CRV.FI deployer for meta-pools.
    address public constant FBP = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;           /// @dev FRAX BasePool (FRAX/USDC) for CRV Finance.
    address public constant FBP_LP = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;        /// @dev Frax BasePool LP token address.
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;          /// @dev The FRAX stablecoin.
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;          /// @dev The USDC stablecoin.

    address public ZVE_MP;      /// @dev To be determined upon pool deployment via constructor().
    address public GBL;         /// @dev Zivoe globals.


    
    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the OCL_ZVE_CRV_0.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.
    constructor(
        address DAO,
        address _GBL
    ) {
        transferOwnership(DAO);
        GBL = _GBL;
        ZVE_MP = ICRVDeployer(CRV_Deployer).deploy_metapool(
            FBP,                        /// The base-pool (FBP = FraxBasePool).
            "ZVE_MP",             /// Name of meta-pool.
            "ZVE/FBP",                  /// Symbol of meta-pool.
            IZivoeGBL(_GBL).ZVE(),      /// Coin paired with base-pool. ($ZVE).
            250,                        /// Amplifier, TODO: Research optimal value.
            20000000                    /// 0.20% fee.
        );
    }

    // ------
    // Events
    // ------

    event Debug(address);
    event Debug(uint256[]);

    // ---------
    // Functions
    // ---------

    function canPushMulti() external pure override returns(bool) {
        return true;
    }

    function canPullMulti() external pure override returns(bool) {
        return true;
    }

    /// @dev    This pulls capital from the DAO, does any necessary pre-conversions, and adds liquidity into ZVE MetaPool.
    /// @notice Only callable by the DAO.
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) public override onlyOwner {
        require((assets[0] == FRAX || assets[0] == USDC) && assets[1] == IZivoeGBL(GBL).ZVE());
        for (uint i = 0; i < 2; i++) {
            IERC20(assets[i]).transferFrom(owner(), address(this), amounts[i]);
        }
        // BasePool Deposit
        // FBP.coins(0) == FRAX
        // FBP.coins(1) == USDC
        if (assets[0] == FRAX) {
            IERC20(FRAX).approve(FBP, IERC20(FRAX).balanceOf(address(this)));
            uint256[2] memory deposits_bp;
            deposits_bp[0] = IERC20(FRAX).balanceOf(address(this));
            ICRVPlainPoolFBP(FBP).add_liquidity(deposits_bp, 0);
        }
        else {
            IERC20(USDC).approve(FBP, IERC20(USDC).balanceOf(address(this)));
            uint256[2] memory deposits_bp;
            deposits_bp[1] = IERC20(USDC).balanceOf(address(this));
            ICRVPlainPoolFBP(FBP).add_liquidity(deposits_bp, 0);
        }
        // FBP + ZVE, MetaPool Deposit
        // ZVE_MP.coins(0) == ZVE
        // ZVE_MP.coins(1) == FBP
        IERC20(FBP_LP).approve(ZVE_MP, IERC20(FBP_LP).balanceOf(address(this)));
        IERC20(IZivoeGBL(GBL).ZVE()).approve(ZVE_MP, IERC20(IZivoeGBL(GBL).ZVE()).balanceOf(address(this)));
        uint256[2] memory deposits_mp;
        deposits_mp[0] = IERC20(IZivoeGBL(GBL).ZVE()).balanceOf(address(this));
        deposits_mp[1] = IERC20(FBP_LP).balanceOf(address(this));
        ICRVMetaPool(ZVE_MP).add_liquidity(deposits_mp, 0);
    }

    

    /// @dev    This burns LP tokens from the ZVE MetaPool, and returns resulting coins back to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  assets The asset to return (in this case, required to be USDC).
    function pullFromLockerMulti(address[] calldata assets) public override onlyOwner {
        // TODO: Consider need for "key"-like activation/approval of withdrawal below.
        require(assets[0] == USDC && assets[1] == FRAX && assets[2] == IZivoeGBL(GBL).ZVE());
    }

}
