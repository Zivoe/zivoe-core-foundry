// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../../ZivoeLocker.sol";
import "../../Utility/ZivoeSwapper.sol";

import {
    ICRVPlainPoolFBP, 
    IZivoeGlobals, 
    ICRVMetaPool, 
    ICVX_Booster, 
    IConvexRewards, 
    IZivoeYDL, 
    AggregatorV3Interface
} from "../../../misc/InterfacesAggregated.sol";

interface IZivoeGlobals_P_4 {
    function YDL() external view returns (address);
    function isKeeper(address) external view returns (bool);
    function standardize(uint256, address) external view returns (uint256);
}

interface IZivoeYDL_P_3 {
    function distributedAsset() external view returns (address);
}

/// @dev    This contract aims at deploying lockers that will invest in Convex pools. 
///         Plain pools should contain only stablecoins denominated in same currency (all tokens in USD or all tokens in EUR for example, otherwise USD_Convertible won't be correct as it's determined based on the token that has the minimum value)

contract OCY_CVX_Modular is ZivoeLocker, ZivoeSwapper {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;             /// @dev Zivoe globals.
    uint256 public nextYieldDistribution;     /// @dev Determines next available forwardYield() call. 
    uint256 public investTimeLock;            /// @dev defines a period for keepers to invest before public accessible function.
    bool public metaOrPlainPool;              /// @dev If true = metapool, if false = plain pool
    bool public extraRewards;                 /// @dev If true, extra rewards are distributed on top of CRV and CVX. If false, no extra rewards.
    uint256 public baseline;                  /// @dev USD convertible, used for forwardYield() accounting.
    uint256 public yieldOwedToYDL;            /// @dev Part of LP token increase over baseline that is owed to the YDL (needed for  accounting when pulling or investing capital)
    uint256 public toForwardCRV;              /// @dev CRV tokens harvested that need to be transfered by ZVL to the YDL.
    uint256 public toForwardCVX;              /// @dev CVX tokens harvested that need to be transfered by ZVL to the YDL.
    uint256[] public toForwardExtraRewards;   /// @dev Extra rewards harvested that need to be transfered by ZVL to the YDL.
    uint256[] public toForwardTokensBaseline; /// @dev LP tokens harvested that need to be transfered by ZVL to the YDL.


    /// @dev Convex addresses.
    address public CVX_Deposit_Address;
    address public CVX_Reward_Address;

    /// @dev Convex staking pool ID.
    uint256 public convexPoolID;

    /// @dev Reward addresses.
    address public constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address[] public extraRewardsAddresses;

    /// @dev Curve addresses:
    address public pool;
    address public POOL_LP_TOKEN;

    /// @dev Metapool parameters:
    address public BASE_TOKEN;
    address public MP_UNDERLYING_LP_TOKEN;
    address public MP_UNDERLYING_LP_POOL;
    uint8 public numberOfTokensUnderlyingLPPool;
    int128 public indexBASE_TOKEN;

    /// @dev Plain Pool parameters:
    address[] public PP_TOKENS; 

    /// @dev chainlink price feeds:
    address[] public chainlinkPriceFeeds;

    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the e_OCY_CVX_Modular.sol contract.
    /// @param _zivoeAddresses _ZivoeAddresses[0] = The administrator of this contract (intended to be ZivoeDAO) and _ZivoeAddresses[1] = GBL (the Zivoe globals contract).
    /// @param _metaOrPlainPool If true: metapool, if false: plain pool.
    /// @param _curvePool address of the Curve Pool.
    /// @param _CVX_Deposit_Address address of the convex Booster contract.
    /// @param _extraRewardsAddresses addresses of the extra rewards. If _extraRewards = false set as an array of the zero address.
    /// @param _BASE_TOKEN_MP if metapool should specify the address of the base token of the pool. If plain pool, set to the zero address.
    /// @param _MP_UNDERLYING_LP_POOL if metapool specify address of the underlying LP token's pool (3CRV for example).
    /// @param _numberOfTokensUnderlyingLPPool if metapool: specify the number of tokens in the underlying LP pool (for 3CRV pool set to 3). If plain pool: set to 0.
    /// @param _numberOfTokensPP If pool is a metapool, set to 0. If plain pool, specify the number of coins in the pool.
    /// @param _convexPoolID Indicate the ID of the Convex pool where the LP token should be staked.
    /// @param _chainlinkPriceFeeds array containing the addresses of the chainlink price feeds, should be provided in correct order (refer to coins index in Curve pool)

    constructor(
        address[] memory _zivoeAddresses,  
        bool _metaOrPlainPool, 
        address _curvePool, 
        address _CVX_Deposit_Address,
        address[] memory _extraRewardsAddresses, 
        address _BASE_TOKEN_MP, 
        address _MP_UNDERLYING_LP_POOL,
        uint8 _numberOfTokensUnderlyingLPPool,
        uint8 _numberOfTokensPP, 
        uint256 _convexPoolID,
        address[] memory _chainlinkPriceFeeds) {

        require(_numberOfTokensPP < 5, "e_OCY_CVX_Modular::constructor() max 4 tokens in plain pool");
        if (_extraRewardsAddresses[0] != address(0)) {
            require(_extraRewardsAddresses.length == IConvexRewards(ICVX_Booster(_CVX_Deposit_Address).poolInfo(_convexPoolID).crvRewards).extraRewardsLength(), "e_OCY_CVX_Modular::constructor() number of extra rewards does not correspond to Convex rewards");
        }
        require(_numberOfTokensUnderlyingLPPool < 5, "e_OCY_CVX_Modular::constructor() max 4 tokens in underlying LP pool");
        
        transferOwnership(_zivoeAddresses[0]);
        GBL = _zivoeAddresses[1];
        CVX_Deposit_Address = _CVX_Deposit_Address;
        CVX_Reward_Address = ICVX_Booster(_CVX_Deposit_Address).poolInfo(_convexPoolID).crvRewards;
        metaOrPlainPool = _metaOrPlainPool;
        convexPoolID = _convexPoolID;
        pool = _curvePool;
        POOL_LP_TOKEN = ICVX_Booster(_CVX_Deposit_Address).poolInfo(_convexPoolID).lptoken;

        if (IConvexRewards(CVX_Reward_Address).extraRewardsLength() > 0) {
            extraRewards = true;
        }

        numberOfTokensUnderlyingLPPool = _numberOfTokensUnderlyingLPPool;

        ///init rewards (other than CVX and CRV)
        if (extraRewards == true) {
            for (uint8 i = 0; i < _extraRewardsAddresses.length; i++) {
                extraRewardsAddresses.push(_extraRewardsAddresses[i]);
            }
        }   

        if (metaOrPlainPool == true) {
            require(_chainlinkPriceFeeds.length == (1 + numberOfTokensUnderlyingLPPool) , "e_OCY_CVX_Modular::constructor() no correct amount of price feeds for metapool");
            BASE_TOKEN = _BASE_TOKEN_MP;
            MP_UNDERLYING_LP_POOL = _MP_UNDERLYING_LP_POOL;
        
            for (uint8 i = 0; i < _chainlinkPriceFeeds.length; i++) {
                chainlinkPriceFeeds.push(_chainlinkPriceFeeds[i]);
            }
            if (ICRVMetaPool(pool).coins(0) == _BASE_TOKEN_MP) {
                MP_UNDERLYING_LP_TOKEN = ICRVMetaPool(pool).coins(1);
                indexBASE_TOKEN = 0;
            } else if (ICRVMetaPool(pool).coins(1) == _BASE_TOKEN_MP) {
                MP_UNDERLYING_LP_TOKEN = ICRVMetaPool(pool).coins(0);
                indexBASE_TOKEN = 1;
            }

        }

        if (metaOrPlainPool == false) {
            require(_chainlinkPriceFeeds.length == _numberOfTokensPP, "e_OCY_CVX_Modular::constructor() plain pool: number of price feeds should correspond to number of tokens");

            ///init tokens of the plain pool and sets chainlink price feeds.
            for (uint8 i = 0; i < _numberOfTokensPP; i++) {
                PP_TOKENS.push(ICRVPlainPoolFBP(pool).coins(i));
                chainlinkPriceFeeds.push(_chainlinkPriceFeeds[i]);
            }
        }
    }

    // ---------------
    //    Functions
    // ---------------

    function canPushMulti() public pure override returns (bool) {
        return true;
    }

    function canPullMulti() public pure override returns (bool) {
        return true;
    }

    function canPullPartial() public override pure returns (bool) {
        return true;
    }

}