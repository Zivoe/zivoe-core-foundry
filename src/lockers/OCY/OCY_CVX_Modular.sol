// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

import "../Utility/ZivoeSwapper.sol";

import {ICRVPlainPoolFBP, IZivoeGlobals, ICRVMetaPool, ICVX_Booster, IConvexRewards, IZivoeYDL, AggregatorV3Interface} from "../../misc/InterfacesAggregated.sol";

/// @dev    This contract aims at deploying lockers that will invest in Convex pools. 
///         Plain pools should contain only stablecoins denominated in same currency (otherwise USD_Convertible won't be correct)

contract OCY_CVX_Modular is ZivoeLocker, ZivoeSwapper {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL; /// @dev Zivoe globals.
    uint256 public nextYieldDistribution;     /// @dev Determines next available forwardYield() call. 
    uint256 public investTimeLock; /// @dev defines a period for keepers to invest before public accessible function.
    bool public metaOrPlainPool;  /// @dev If true = metapool, if false = plain pool
    bool public extraRewards;     /// @dev If true, extra rewards are distributed on top of CRV and CVX. If false, no extra rewards.

    /// @dev Convex addresses.
    address public CVX_Deposit_Address;
    address public CVX_Reward_Address;

    /// @dev Convex staking pool ID.
    uint256 public convexPoolID;

    /// @dev Reward addresses.
    address public constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address[] public rewardsAddresses;

    /// @dev Curve addresses:
    address public pool;
    address public POOL_LP_TOKEN;

    /// @dev Metapool parameters:
    ///Not able to find a method to determine which of both coins(0,1) is the BASE_TOKEN, thus has to be specified in constructor
    address public BASE_TOKEN;

    /// @dev Plain Pool parameters:
    address[] public PP_TOKENS; 

    /// @dev chainlink price feeds:
    address[] public chainlinkPriceFeeds;

    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_CVX_Modular.sol contract.
    /// @param _DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.
    /// @param _metaOrPlainPool If true: metapool, if false: plain pool.
    /// @param _curvePool address of the Curve Pool.
    /// @param _CVX_Deposit_Address address of the convex Booster contract.
    /// @param _extraRewards if true: extra rewards distributed on top of CRV or CVX.
    /// @param _rewardsAddresses addresses of the extra rewards. If _extraRewards = false set as an array of the zero address.
    /// @param _BASE_TOKEN_MP if metapool should specify the address of the base token of the pool. If plain pool, set to the zero address.
    /// @param _numberOfTokensPP If pool is a metapool, set to 0. If plain pool, specify the number of coins in the pool.
    /// @param _convexPoolID Indicate the ID of the Convex pool where the LP token should be staked.
    /// @param _chainlinkPriceFeeds array containing the addresses of the chainlink price feeds, should be provided in correct order (refer to coins index in Curve pool)

    constructor(
        address _DAO, 
        address _GBL, 
        bool _metaOrPlainPool, 
        address _curvePool, 
        address _CVX_Deposit_Address, 
        bool _extraRewards,
        address[] memory _rewardsAddresses, 
        address _BASE_TOKEN_MP, 
        uint8 _numberOfTokensPP, 
        uint256 _convexPoolID,
        address[] memory _chainlinkPriceFeeds) {

        require(_numberOfTokensPP < 4, "OCY_CVX_Modular::constructor() max 4 tokens in plain pool");

        transferOwnership(_DAO);
        GBL = _GBL;
        CVX_Deposit_Address = _CVX_Deposit_Address;
        CVX_Reward_Address = ICVX_Booster(_CVX_Deposit_Address).poolInfo(_convexPoolID).crvRewards;
        metaOrPlainPool = _metaOrPlainPool;
        convexPoolID = _convexPoolID;
        extraRewards = _extraRewards;

        ///init rewards (other than CVX and CRV)
        if (_extraRewards == true) {
            for (uint8 i = 0; i < _rewardsAddresses.length; i++) {
                rewardsAddresses.push(_rewardsAddresses[i]);
            }
        }    

        if (metaOrPlainPool == true) {
            require(_chainlinkPriceFeeds.length == 1, "OCY_CVX_Modular::constructor() for metapool max 1 price feed");
            pool = _curvePool;
            POOL_LP_TOKEN = ICVX_Booster(_CVX_Deposit_Address).poolInfo(_convexPoolID).lptoken;
            BASE_TOKEN = _BASE_TOKEN_MP;
            chainlinkPriceFeeds.push(_chainlinkPriceFeeds[0]);
        }

        if (metaOrPlainPool == false) {
            require(_chainlinkPriceFeeds.length == _numberOfTokensPP, "OCY_CVX_Modular::constructor() plain pool: number of price feeds should correspond to number of tokens");
            pool = _curvePool;
            POOL_LP_TOKEN = ICVX_Booster(_CVX_Deposit_Address).poolInfo(_convexPoolID).lptoken;

            ///init tokens of the plain pool and sets chainlink price feeds.
            ///TODO: check if possible to require that price feeds submitted in right order.
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

    function pushToLockerMulti(
        address[] memory assets, 
        uint256[] memory amounts
    ) public override onlyOwner {
        require(
            assets.length <= 4, 
            "OCY_CVX_Modular::pushToLocker() assets.length > 4"
        );
        for (uint i = 0; i < assets.length; i++) {
            if (amounts[i] > 0) {
                IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
            }
        }

        /// Gives keepers time to convert the stablecoins to the Curve pool assets.
        investTimeLock = block.timestamp + 24 hours;
    }   

    /// @dev    This divests allocation from Convex and Curve pool and returns capital to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  assets The assets to return.
    /// TODO: check for duplicate assets + should we use the assets parameter ? + Check rewards in the future in tests.
    function pullFromLockerMulti(address[] calldata assets) public override onlyOwner {

        if (metaOrPlainPool == true) {
            /// We verify that the asset out is equal to the BASE_TOKEN.
            require(assets[0] == BASE_TOKEN && assets.length == 1, "OCY_CVX_Modular::pullFromLockerMulti() asset not equal to BASE_TOKEN");

            int128 index;

            if (ICRVMetaPool(pool).coins(0) == BASE_TOKEN) {
                index = 0;
            } else if (ICRVMetaPool(pool).coins(1) == BASE_TOKEN) {
                index = 1;
            }

            IConvexRewards(CVX_Reward_Address).withdrawAllAndUnwrap(true);
            ICRVMetaPool(pool).remove_liquidity_one_coin(IERC20(POOL_LP_TOKEN).balanceOf(address(this)), index, 0);
            IERC20(BASE_TOKEN).safeTransfer(owner(), IERC20(BASE_TOKEN).balanceOf(address(this)));

        }

        if (metaOrPlainPool == false) {
            /// We verify that the assets out are equal to the PP_TOKENS.
            for (uint8 i = 0; i < PP_TOKENS.length; i++) {
                require(assets[i] == PP_TOKENS[i], "OCY_CVX_Modular::pullFromLockerMulti() assets input array should be equal to PP_TOKENS array and in the same order" );
            }
            
            IConvexRewards(CVX_Reward_Address).withdrawAllAndUnwrap(true);

            removeLiquidityPlainPoolAndTransfer();

        }

        if (IERC20(CRV).balanceOf(address(this)) > 0) {
            IERC20(CRV).safeTransfer(owner(), IERC20(CRV).balanceOf(address(this)));
        }

        if (IERC20(CVX).balanceOf(address(this)) > 0) {
            IERC20(CVX).safeTransfer(owner(), IERC20(CVX).balanceOf(address(this)));
        }

        if (extraRewards == true) {
            for (uint8 i = 0; i < rewardsAddresses.length; i++) {
                if (IERC20(rewardsAddresses[i]).balanceOf(address(this)) > 0) {
                    IERC20(rewardsAddresses[i]).safeTransfer(owner(), IERC20(rewardsAddresses[i]).balanceOf(address(this)));
                }        
            }
        }

    }

    /// @dev    This burns a partial amount of LP tokens from the Convex FRAX-USDC staking pool,
    ///         removes the liquidity from Curve and returns resulting coins back to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  convexRewardAddress The Convex contract to call to withdraw LP tokens.
    /// @param  amount The amount of LP tokens to burn.
    function pullFromLockerPartial(address convexRewardAddress, uint256 amount) external override onlyOwner {
        require(convexRewardAddress == CVX_Reward_Address, "OCY_CVX_Modular::pullFromLockerPartial() convexRewardAddress != CVX_Reward_Address");
        require(amount < IERC20(CVX_Reward_Address).balanceOf(address(this)) && amount > 0, "OCY_CVX_Modular::pullFromLockerPartial() LP token amount to withdraw should be less than locker balance and greater than 0");

        IConvexRewards(CVX_Reward_Address).withdrawAndUnwrap(amount, false);

        if (metaOrPlainPool == true) {

            int128 index;

            if (ICRVMetaPool(pool).coins(0) == BASE_TOKEN) {
                index = 0;
            } else if (ICRVMetaPool(pool).coins(1) == BASE_TOKEN) {
                index = 1;
            }
            
            ICRVMetaPool(pool).remove_liquidity_one_coin(IERC20(POOL_LP_TOKEN).balanceOf(address(this)), index, 0);
            IERC20(BASE_TOKEN).safeTransfer(owner(), IERC20(BASE_TOKEN).balanceOf(address(this)));

        }

        if (metaOrPlainPool == false) {

            removeLiquidityPlainPoolAndTransfer();

        }
    }

    /// @dev    This will remove liquidity from Curve Plain Pools and transfer the tokens to the DAO.
    /// @notice Private function, should only be called through pullFromLockerMulti() and pullFromLockerPartial().
    function removeLiquidityPlainPoolAndTransfer() private {

        if (PP_TOKENS.length == 2) {
            uint256[2] memory minAmountsOut;
            ICRVPlainPoolFBP(pool).remove_liquidity(IERC20(POOL_LP_TOKEN).balanceOf(address(this)), minAmountsOut);
        }

        if (PP_TOKENS.length == 3) {
            uint256[3] memory minAmountsOut;
            ICRVPlainPoolFBP(pool).remove_liquidity(IERC20(POOL_LP_TOKEN).balanceOf(address(this)), minAmountsOut);
        }

        if (PP_TOKENS.length == 4) {
            uint256[4] memory minAmountsOut;
            ICRVPlainPoolFBP(pool).remove_liquidity(IERC20(POOL_LP_TOKEN).balanceOf(address(this)), minAmountsOut);
        } 

        for (uint8 i = 0; i < PP_TOKENS.length; i++) {
            if (IERC20(PP_TOKENS[i]).balanceOf(address(this)) > 0) {
                IERC20(PP_TOKENS[i]).safeTransfer(owner(), IERC20(PP_TOKENS[i]).balanceOf(address(this)));
            }
        }   
        
    }

    ///@dev give Keepers a way to pre-convert assets via 1INCH
    function keeperConvertStablecoin(
        address stablecoin,
        address assetOut,
        bytes calldata data
    ) public {
        require(IZivoeGlobals(GBL).isKeeper(_msgSender()));

        if (metaOrPlainPool == true) {
            /// We verify that the asset out is equal to the BASE_TOKEN.
            require(assetOut == BASE_TOKEN && stablecoin != assetOut);
        }

        if (metaOrPlainPool == false) {
            bool assetOutIsCorrect;
            for (uint8 i = 0; i < PP_TOKENS.length; i++) {
                if (PP_TOKENS[i] == assetOut) {
                    assetOutIsCorrect = true;
                    break;
                }
            }
            require(assetOutIsCorrect == true && stablecoin != assetOut);
        }

        IERC20(stablecoin).safeApprove(router1INCH_V4, IERC20(stablecoin).balanceOf(address(this)));
        convertAsset(stablecoin, assetOut, IERC20(stablecoin).balanceOf(address(this)), data);

        /// Once the keepers have started converting stablecoins, allow them 12 hours to invest those assets.
        investTimeLock = block.timestamp + 12 hours;
    } 

    /// @dev  This directs tokens into a Curve Pool and then stakes the LP into Convex.
    function invest() public {
        /// TODO validate condition below
        if (!IZivoeGlobals(GBL).isKeeper(_msgSender())) {
            require(investTimeLock < block.timestamp, "timelock - restricted to keepers for now" );
        }

        if (nextYieldDistribution == 0) {
            nextYieldDistribution = block.timestamp + 30 days;
        } 

        if (metaOrPlainPool == true) {
            
            uint256[2] memory deposits_mp;

            if (ICRVMetaPool(pool).coins(0) == BASE_TOKEN) {
                deposits_mp[0] = IERC20(BASE_TOKEN).balanceOf(address(this));
            } else if (ICRVMetaPool(pool).coins(1) == BASE_TOKEN) {
                deposits_mp[1] = IERC20(BASE_TOKEN).balanceOf(address(this));
            }
            IERC20(BASE_TOKEN).safeApprove(pool, IERC20(BASE_TOKEN).balanceOf(address(this)));
            ICRVMetaPool(pool).add_liquidity(deposits_mp, 0);

        }

        if (metaOrPlainPool == false) {

            if (PP_TOKENS.length == 2) {
                uint256[2] memory deposits_pp;

                for (uint8 i = 0; i < PP_TOKENS.length; i++) {
                    deposits_pp[i] = IERC20(PP_TOKENS[i]).balanceOf(address(this));
                    if (IERC20(PP_TOKENS[i]).balanceOf(address(this)) > 0) {
                        IERC20(PP_TOKENS[i]).safeApprove(pool, IERC20(PP_TOKENS[i]).balanceOf(address(this)));
                    }

                }

                ICRVPlainPoolFBP(pool).add_liquidity(deposits_pp, 0);

            } else if (PP_TOKENS.length == 3) {
                uint256[3] memory deposits_pp;

                for (uint8 i = 0; i < PP_TOKENS.length; i++) {
                    deposits_pp[i] = IERC20(PP_TOKENS[i]).balanceOf(address(this));
                    if (IERC20(PP_TOKENS[i]).balanceOf(address(this)) > 0) {
                        IERC20(PP_TOKENS[i]).safeApprove(pool, IERC20(PP_TOKENS[i]).balanceOf(address(this)));
                    }

                } 

                ICRVPlainPoolFBP(pool).add_liquidity(deposits_pp, 0);

            } else if (PP_TOKENS.length == 4) {
                uint256[4] memory deposits_pp;

                for (uint8 i = 0; i < PP_TOKENS.length; i++) {
                    deposits_pp[i] = IERC20(PP_TOKENS[i]).balanceOf(address(this));
                    if (IERC20(PP_TOKENS[i]).balanceOf(address(this)) > 0) {
                        IERC20(PP_TOKENS[i]).safeApprove(pool, IERC20(PP_TOKENS[i]).balanceOf(address(this)));
                    }

                } 

                ICRVPlainPoolFBP(pool).add_liquidity(deposits_pp, 0);         

                }

        }

        stakeLP();
    }
    
    /// @dev    This will stake total balance of LP tokens on Convex
    /// @notice Private function, should only be called through invest().
    function stakeLP() private {
        IERC20(POOL_LP_TOKEN).safeApprove(CVX_Deposit_Address, IERC20(POOL_LP_TOKEN).balanceOf(address(this)));
        ICVX_Booster(CVX_Deposit_Address).depositAll(convexPoolID, true);
    }

    function USD_Convertible() public view returns (uint256 _amount) {
        uint256 contractLP = IConvexRewards(CVX_Reward_Address).balanceOf(address(this));

        if (metaOrPlainPool == true) {

            int128 index;

            if (ICRVMetaPool(pool).coins(0) == BASE_TOKEN) {
                index = 0;
            } else if (ICRVMetaPool(pool).coins(1) == BASE_TOKEN) {
                index = 1;
            }

            uint256 amountBASE_TOKEN = ICRVMetaPool(pool).calc_withdraw_one_coin(contractLP, index);
            (,int price,,,) = AggregatorV3Interface(chainlinkPriceFeeds[0]).latestRoundData();
            require(price >= 0);
            _amount = (uint(price) * amountBASE_TOKEN) / (10** AggregatorV3Interface(chainlinkPriceFeeds[0]).decimals());


        }

        if (metaOrPlainPool == false) {

            // we query the latest price from each feed and take the minimum price
            int256[] memory prices = new int256[](PP_TOKENS.length);

            for (uint8 i = 0; i < PP_TOKENS.length; i++) {
                (, prices[i],,,) = AggregatorV3Interface(chainlinkPriceFeeds[i]).latestRoundData();
            }

            int256 minPrice = prices[0];
            uint128 index = 0;

            for (uint128 i = 1; i < prices.length; i++) {
                if (prices[i] < minPrice) {
                    minPrice = prices[i];
                    index = i;
                }
            }

            require(minPrice >= 0);

            uint256 amountOfPP_TOKEN = ICRVPlainPoolFBP(pool).calc_withdraw_one_coin(contractLP, int128(index));

            _amount = (uint(minPrice) * amountOfPP_TOKEN) / (10**AggregatorV3Interface(chainlinkPriceFeeds[uint128(index)]).decimals());
            
        }
        

    }


}