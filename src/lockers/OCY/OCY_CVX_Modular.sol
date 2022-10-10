// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

import "../Utility/ZivoeSwapper.sol";

import { ICRVPlainPoolFBP, IZivoeGlobals, ICRVMetaPool, ICVX_Booster, IConvexRewards, IZivoeYDL } from "../../misc/InterfacesAggregated.sol";

/// @dev    This contract is responsible for adding liquidity into Curve (Frax/USDC Pool) and stake LP tokens on Convex.
///         TODO: find method to check wether converting between USDC and Frax would increase LP amount taking conversion fees into account.

contract OCY_CVX_Modular is ZivoeLocker, ZivoeSwapper {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL; /// @dev Zivoe globals.
    address payable public oneInchAggregator;
    uint256 public nextYieldDistribution;     /// @dev Determines next available forwardYield() call. 
    uint256 public swapperTimelockStablecoin; /// @dev Determines a timelock period in which ZVL can convert stablecoins through 1inch (before a publicly available swap function)
    /// If true = metapool, if false = plain pool
    bool public MP_locker;


    /// @dev Stablecoin addresses.
    address public constant DAI  = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public STABLE4;

    /// @dev Convex addresses.
    address public CVX_Deposit_Address;
    address public CVX_Reward_Address;

    /// @dev Convex staking pool ID.
    uint256 public convexPoolID;

    /// @dev Reward addresses.
    address public constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address public extraReward;

    /// @dev Curve addresses:
    address public pool;
    address public POOL_LP_TOKEN;

    /// @dev Metapool parameters:
    ///Not able to find a method to determine which of both coins(0,1) is the BASE_TOKEN, thus has to be specified in constructor
    address public BASE_TOKEN;

    /// @dev Plain Pool parameters:
    address[] public PP_TOKENS;  

    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_CVX_Modular.sol contract.
    /// @param _DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.
    /// @param _MP_locker If true: metapool, if false: plain pool.
    /// @param _curveAddresses First item should be the Curve pool address, second item the LP token address of the pool. For a metapool specify a third item which is the address of the base token of the pool.
    /// @param _BASE_TOKEN_MP if metapool should specify the address of the base token of the pool. If plain pool, set to the zero address.
    /// @param _numberOfTokensPP If pool is a metapool, set to 0. If plain pool, specify the number of coins in the pool.
    /// @param _convexPoolID Indicate the ID of the Convex pool where the LP token should be staked.

    constructor(address _DAO, address _GBL, bool _MP_locker, address _oneInchAggregator, address _stable4, address _CVX_Deposit_Address, address _CVX_Reward_Address, address _extraReward, address[2] memory _curveAddresses, address _BASE_TOKEN_MP, uint8 _numberOfTokensPP, uint256 _convexPoolID) {
        require(_numberOfTokensPP < 4, "OCY_CVX_Modular::constructor() max 4 tokens in plain pool");
        transferOwnership(_DAO);
        GBL = _GBL;
        oneInchAggregator = payable(_oneInchAggregator);
        STABLE4 = _stable4;
        CVX_Deposit_Address = _CVX_Deposit_Address;
        CVX_Reward_Address = _CVX_Reward_Address;
        extraReward = _extraReward;
        MP_locker = _MP_locker;
        convexPoolID = _convexPoolID;

        if (_MP_locker == true) {
            require(_curveAddresses.length == 2, "OCY_CVX_Modular::constructor() A metapool needs 2 addresses as input in array _curveAddresses");
            pool = _curveAddresses[0];
            POOL_LP_TOKEN = _curveAddresses[1];
            BASE_TOKEN = _BASE_TOKEN_MP;
        }

        if (_MP_locker == false) {
            require(_curveAddresses.length == 2, "OCY_CVX_Modular::constructor() A plain pool needs 2 addresses as input in array _curveAddresses");
            pool = _curveAddresses[0];
            POOL_LP_TOKEN = _curveAddresses[1];

            ///init tokens of the plain pool
            for (uint8 i = 0; i < _numberOfTokensPP; i++) {
                PP_TOKENS.push(ICRVPlainPoolFBP(pool).coins(i));
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

    /* ///@dev give Keepers a way to pre-convert assets via 1INCH
    function keeperConvertStablecoin(
        address stablecoin,
        address assetOut,
        bytes calldata data
    ) public {
        require(IZivoeGlobals(GBL).isKeeper(_msgSender()));
        require(stablecoin == DAI || stablecoin == USDT || stablecoin == USDC || stablecoin == STABLE4);
        if (MP_locker == true) {
            /// We verify that the asset out is equal to one of the underlying tokens of the LP or the BASE_TOKEN.
            uint8 test;
            for (uint8 i = 0; i < LP_Underlying_Coins.length; i++) {
                if (LP_Underlying_Coins[i] == assetOut) {
                    test += 1;
                    break;
    
                }
            }
            require((test > 0 || assetOut == BASE_TOKEN) && stablecoin != assetOut);
        }

        if (PP_locker == true) {
            require((assetOut == PP_TOKEN1 || assetOut == PP_TOKEN2) && stablecoin != assetOut);
        }

        convertAsset(stablecoin, assetOut, IERC20(stablecoin).balanceOf(address(this)), data);
    } 

    /// @dev  This directs tokens into a Curve Pool and then stakes the LP into Convex.
    function invest() public {
        /// TODO validate condition below
        if (!IZivoeGlobals(GBL).isKeeper(_msgSender())) {
            require(swapperTimelockStablecoin < block.timestamp);
        }

        if (nextYieldDistribution == 0) {
            nextYieldDistribution = block.timestamp + 30 days;
        } 

        if (MP_locker == true) {
            ///Check if we have coins that still needs to be deposited to LP_Underlying_Pool to get the LP token
            uint8 length = LP_Underlying_Coins.length;
            uint256[length] memory deposits_bp;
            uint8 test;

            for (uint8 i = 0; i < length; i++) {
                uint256 tokenBalance = IERC20(LP_Underlying_Coins[i].balanceOf(address(this)));
                deposits_bp[i] = tokenBalance;
                if (tokenBalance > 0) {
                    IERC20(LP_Underlying_Coins[i]).safeApprove(LP_Underlying_Pool, tokenBalance);
                } else {
                    test += 1;
                }
            }
            /// if test = length it means all amounts = 0 and no need to get the LP token.
            if (test < length) {
                ICRVPlainPoolFBP(LP_Underlying_Pool).add_liquidity(deposits_bp, 0);
            }

            uint256 coin0Balance = IERC20(ICRVMetaPool(metapool).coins(0)).balanceOf(address(this));
            uint256 coin1Balance = IERC20(ICRVMetaPool(metapool).coins(1)).balanceOf(address(this));

            if (coin0Balance > 0) {
                IERC20(ICRVMetaPool(metapool).coins(0)).safeApprove(metapool, coin0Balance);
            }
            if (coin1Balance > 0) {
                IERC20(ICRVMetaPool(metapool).coins(1)).safeApprove(metapool, coin1Balance);
            }

            address[2] memory deposits_mp = [coin0Balance, coin1Balance];
            ICRVMetaPool(metapool).add_liquidity(deposits_mp, 0);



        }

    }

    /// @dev    This will stake total balance of LP tokens on Convex
    /// @notice Private function, should only be called through invest().
    function stakeLP() private {
        if (MP_locker == true) {
            IERC20(METAPOOL_LP_TOKEN).safeApprove(CVX_Deposit_Address, IERC20(METAPOOL_LP_TOKEN).balanceOf(address(this)));
            ICVX_Booster(CVX_Deposit_Address).depositAll(convexPoolID_mp, true);
        }
        IERC20(lpFRAX_USDC).safeApprove(CVX_Deposit_Address, IERC20(lpFRAX_USDC).balanceOf(address(this)));
        ICVX_Booster(CVX_Deposit_Address).depositAll(100, true);
    } */

}