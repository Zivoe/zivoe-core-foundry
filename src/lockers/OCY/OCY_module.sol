// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

import "../Utility/LockerSwapper.sol";

import { ICRVPlainPoolFBP, IZivoeGlobals, ICRVMetaPool, ICVX_Booster, IConvexRewards, IUniswapRouterV3, ExactInputSingleParams, IZivoeYDL } from "../../misc/InterfacesAggregated.sol";

/// @dev    This contract is responsible for adding liquidity into Curve (Frax/USDC Pool) and stake LP tokens on Convex.
///         TODO: find method to check wether converting between USDC and Frax would increase LP amount taking conversion fees into account.

contract OCY_CVX_FRAX_USDC is ZivoeLocker, LockerSwapper {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL; /// @dev Zivoe globals.
    address payable public oneInchAggregator;
    uint256 public nextYieldDistribution;     /// @dev Determines next available forwardYield() call. 
    uint256 public swapperTimelockStablecoin; /// @dev Determines a timelock period in which ZVL can convert stablecoins through 1inch (before a publicly available swap function)
    bool public MP_locker;
    bool public PP_locker;
    bool public PP_initialized;
    bool public MP_initialized;


    /// @dev Stablecoin addresses.
    address public constant DAI  = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public STABLE4;

    /// @dev Convex addresses.
    address public CVX_Deposit_Address;
    address public CVX_Reward_Address;

    /// @dev Reward addresses.
    address public constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address public extraReward;

    /// @dev Curve 3pool;
    address public CRV3POOL;

    /// @dev If Metapool, provide following info:
    address public metapool;
    address public BASE_TOKEN;
    address public BASE_LP_TOKEN;
    address public LP_Pool_Origin;
    address[] public LP_Pool_Coins;

    /// @dev If Plain Pool, both tokens are the following:
    /// note: at least one MP should exist for one of both tokens if we want public to be able to convert stablecoins.
    address public plainpool;
    address public PP_TOKEN1;
    bool public MP1_exist;
    address public PP_TOKEN2;
    bool public MP2_exist;
    address public MP1;
    /// The 3CRV lp token will always be set at second position
    address[] public tokensMP1;
    address public MP2;
    /// The 3CRV lp token will always be set at second position
    address[] public tokensMP2;

    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_CVX_FraxUSDC.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.

    constructor(address DAO, address _GBL, bool _MP_locker, bool _PP_locker, address _oneInchAggregator, address _stable4, address _CVX_Deposit_Address, address _CVX_Reward_Address, address _extraReward, address _CRV3POOL) {
        require(_MP_locker != _PP_locker,"OCYL::constructor() should be either MP locker or PP locker");
        transferOwnership(DAO);
        GBL = _GBL;
        oneInchAggregator = payable(_oneInchAggregator);
        STABLE4 = _stable4;
        CVX_Deposit_Address = _CVX_Deposit_Address;
        CVX_Reward_Address = _CVX_Reward_Address;
        extraReward = _extraReward;
        MP_locker = _MP_locker;
        PP_locker = _PP_locker;
        PP_initialized = false;
        MP_initialized = false;
        CRV3POOL = _CRV3POOL;
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

    function initPP(address _plainpool, address _PP_TOKEN1, bool _MP1_exist, address _PP_TOKEN2,  bool _MP2_exist, address _MP1, address _MP2) external {
        require(IZivoeGlobals(GBL).isKeeper(_msgSender()));
        require(PP_locker == true);
        require(PP_initialized == false);
        require(ICRVPlainPoolFBP(_plainpool).coins(0) == _PP_TOKEN1 || ICRVPlainPoolFBP(_plainpool).coins(0) == _PP_TOKEN2);
        require(ICRVPlainPoolFBP(_plainpool).coins(1) == _PP_TOKEN1 || ICRVPlainPoolFBP(_plainpool).coins(1) == _PP_TOKEN2);

        if (_MP1_exist == true) {
            require(ICRVMetaPool(MP1).coins(0) == CRV3POOL || ICRVMetaPool(MP1).coins(1) == CRV3POOL);
            require(ICRVMetaPool(MP1).coins(0) == _PP_TOKEN1 || ICRVMetaPool(MP1).coins(1) == __PP_TOKEN1);
        }
        if (_MP2_exist == true) {
            require(ICRVMetaPool(MP2).coins(0) == CRV3POOL || ICRVMetaPool(MP2).coins(1) == CRV3POOL);
            require(ICRVMetaPool(MP2).coins(0) == _PP_TOKEN2 || ICRVMetaPool(MP2).coins(1) == __PP_TOKEN2);
        }        

        PP_initialized = true;
        plainpool = _plainpool;
        PP_TOKEN1 = _PP_TOKEN1;
        PP_TOKEN2 = _PP_TOKEN2;
        MP1_exist = _MP1_exist;
        MP2_exist = _MP2_exist;
        MP1 = _MP1;
        MP2 = _MP2;

    }

    function initMP(address _metapool, address _BASE_TOKEN, address _BASE_LP_TOKEN, address[] memory _LP_Pool_Coins) external {
        require(IZivoeGlobals(GBL).isKeeper(_msgSender()));
        require(MP_locker == true);
        require(MP_initialized == false);
        require(_BASE_TOKEN != _BASE_LP_TOKEN);
        require(ICRVMetaPool(_metapool).coins(0) == _BASE_TOKEN || ICRVMetaPool(_metapool).coins(0) == _BASE_LP_TOKEN);
        require(ICRVMetaPool(_metapool).coins(1) == _BASE_TOKEN || ICRVMetaPool(_metapool).coins(1) == _BASE_LP_TOKEN);

        MP_initialized = true;
        metapool = _metapool;
        BASE_TOKEN = _BASE_TOKEN;
        BASE_LP_TOKEN = _BASE_LP_TOKEN;
        LP_Pool_Origin = ICRVMetaPool(metapool).base_pool();
        //for (uint8 i = 0; i < 4; i++) {
        //    require(ICRVPlainPoolFBP(LP_Pool_origin).coins(i) == _LP_Pool_Coins[0] )
        //}
        ICRVPlainPoolFBP(LP_Pool_origin).coins(0)



        
    }

    function pushToLockerMulti(
        address[] memory assets, 
        uint256[] memory amounts
    ) public override onlyOwner {
        require(
            assets.length <= 4, 
            "OCY_CVX_FRAX_USDC::pullFromLocker() assets.length > 4"
        );
        for (uint i = 0; i < assets.length; i++) {
            require(assets[i] == DAI || assets[i] == USDT || assets[i] == USDC || assets[i] == STABLE4);
            if (amounts[i] > 0) {
                IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
            }
        }

        swapperTimelockStablecoin = block.timestamp + 12 hours;
    }   

    ///@dev give Keepers a way to pre-convert assets via 1INCH
    function keeperConvertStablecoin(
        address stablecoin,
        address assetOut,
        bytes calldata data
    ) public {
        require(IZivoeGlobals(GBL).isKeeper(_msgSender()));
        require(stablecoin == DAI || stablecoin == USDT || stablecoin == USDC || stablecoin == STABLE4);
        if (MP_locker == true) {
            require((assetOut == DAI || assetOut == USDT || stablecoin == USDC || assetOut == STABLE4) && stablecoin != assetOut);
        }
        if (PP_locker == true) {
            require((assetOut == PP_Token1 || assetOut == PP_Token2) && stablecoin != assetOut);
        }

        convertAsset(stablecoin, assetOut, IERC20(stablecoin).balanceOf(address(this)), data);
    } 

    function publicConvertStablecoins(
        address[] calldata stablecoins 
    ) public {
        require(swapperTimelockStablecoin < block.timestamp);

        for (uint i = 0; i < stablecoins.length; i++) {
            if (PP_locker == true) {
                require(stablecoins[i] != PP_Token1 || stablecoins[i] != PP_Token2);
                if (stablecoins[i] == DAI) {
                    int8 tokenToSupply = maxAmountLPTokens(IERC20(stablecoins[i]).balanceOf(address(this)));
                    // Convert DAI to "tokenToSupply" via FRAX_3CRV_MP pool.
                    IERC20(stablecoins[i]).safeApprove(FRAX_3CRV_MP, IERC20(stablecoins[i]).balanceOf(address(this)));
                    ICRVMetaPool(FRAX_3CRV_MP).exchange_underlying(
                        int128(1), int128(tokenToSupply), IERC20(stablecoins[i]).balanceOf(address(this)), 0
                    );                    
            }
            require(stablecoins[i] == DAI || stablecoins[i] == USDT);

            // TODO: Implement the existing public swap via 3CRV.
            if (stablecoins[i] == DAI) {
                int8 tokenToSupply = maxAmountLPTokens(IERC20(stablecoins[i]).balanceOf(address(this)));
                // Convert DAI to "tokenToSupply" via FRAX_3CRV_MP pool.
                IERC20(stablecoins[i]).safeApprove(FRAX_3CRV_MP, IERC20(stablecoins[i]).balanceOf(address(this)));
                ICRVMetaPool(FRAX_3CRV_MP).exchange_underlying(
                    int128(1), int128(tokenToSupply), IERC20(stablecoins[i]).balanceOf(address(this)), 0
                );
            } else if (stablecoins[i] == USDT) {
                int8 tokenToSupply = maxAmountLPTokens(IERC20(stablecoins[i]).balanceOf(address(this)) * 10**12);
                // Convert USDT to "tokenToSupply" via FRAX_3CRV_MP pool.
                IERC20(stablecoins[i]).safeApprove(FRAX_3CRV_MP, IERC20(stablecoins[i]).balanceOf(address(this)));
                ICRVMetaPool(FRAX_3CRV_MP).exchange_underlying(
                    int128(3), int128(tokenToSupply), IERC20(stablecoins[i]).balanceOf(address(this)), 0
                );
            } 
        }
        
        invest();
    }

}