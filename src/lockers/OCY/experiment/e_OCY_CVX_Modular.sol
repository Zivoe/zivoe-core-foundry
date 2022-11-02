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

contract e_OCY_CVX_Modular is ZivoeLocker, ZivoeSwapper {
    
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
    uint256 public yieldOwedToYDL;            /// @dev Part of LP token increase over baseline that is owed to the YDL (needed for accounting when pulling or investing capital)
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
    ///Not able to find a method to determine which of both coins(0,1) is the BASE_TOKEN, thus has to be specified in constructor
    address public BASE_TOKEN;
    address public MP_UNDERLYING_LP_TOKEN;
    address public MP_UNDERLYING_LP_POOL;
    ///Needed to calculate the LP price of the underlying LP Token
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
            require(_extraRewardsAddresses.length == IConvexRewards(ICVX_Booster(_CVX_Deposit_Address).poolInfo(_convexPoolID).crvRewards).extraRewardsLength(), "e_OCY_CVX_Modular::constructor() number of Extra Rewards does not correspond to Convex contract");
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

    function pushToLockerMulti(
        address[] memory assets, 
        uint256[] memory amounts
    ) public override onlyOwner {
        require(
            assets.length <= 4, 
            "e_OCY_CVX_Modular::pushToLocker() assets.length > 4"
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
            require(assets[0] == BASE_TOKEN && assets.length == 1, "e_OCY_CVX_Modular::pullFromLockerMulti() asset not equal to BASE_TOKEN");

            IConvexRewards(CVX_Reward_Address).withdrawAllAndUnwrap(true);
            ICRVMetaPool(pool).remove_liquidity_one_coin(IERC20(POOL_LP_TOKEN).balanceOf(address(this)), indexBASE_TOKEN, 0);
            IERC20(BASE_TOKEN).safeTransfer(owner(), IERC20(BASE_TOKEN).balanceOf(address(this)));

        }

        if (metaOrPlainPool == false) {
            /// We verify that the assets out are equal to the PP_TOKENS.
            for (uint8 i = 0; i < PP_TOKENS.length; i++) {
                require(assets[i] == PP_TOKENS[i], "e_OCY_CVX_Modular::pullFromLockerMulti() assets input array should be equal to PP_TOKENS array and in the same order" );
            }
            
            IConvexRewards(CVX_Reward_Address).withdrawAllAndUnwrap(true);

            removeLiquidityPlainPool(true);

        }

        if (IERC20(CRV).balanceOf(address(this)) > 0) {
            IERC20(CRV).safeTransfer(owner(), IERC20(CRV).balanceOf(address(this)));
        }

        if (IERC20(CVX).balanceOf(address(this)) > 0) {
            IERC20(CVX).safeTransfer(owner(), IERC20(CVX).balanceOf(address(this)));
        }

        if (extraRewards == true) {
            for (uint8 i = 0; i < extraRewardsAddresses.length; i++) {
                if (IERC20(extraRewardsAddresses[i]).balanceOf(address(this)) > 0) {
                    IERC20(extraRewardsAddresses[i]).safeTransfer(owner(), IERC20(extraRewardsAddresses[i]).balanceOf(address(this)));
                }        
            }
        }

        baseline = 0;

    }

    /// @dev    This burns a partial amount of LP tokens from the Convex FRAX-USDC staking pool,
    ///         removes the liquidity from Curve and returns resulting coins back to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  convexRewardAddress The Convex contract to call to withdraw LP tokens.
    /// @param  amount The amount of LP tokens to burn.
    function pullFromLockerPartial(address convexRewardAddress, uint256 amount) external override onlyOwner {
        require(convexRewardAddress == CVX_Reward_Address, "e_OCY_CVX_Modular::pullFromLockerPartial() convexRewardAddress != CVX_Reward_Address");
        require(amount < IERC20(CVX_Reward_Address).balanceOf(address(this)) && amount > 0, "e_OCY_CVX_Modular::pullFromLockerPartial() LP token amount to withdraw should be less than locker balance and greater than 0");

        //Accounts for interest that should be redistributed to YDL
        if (USD_Convertible() > baseline) {
            yieldOwedToYDL += USD_Convertible() - baseline;

        }

        IConvexRewards(CVX_Reward_Address).withdrawAndUnwrap(amount, false);

        if (metaOrPlainPool == true) {
            
            ICRVMetaPool(pool).remove_liquidity_one_coin(IERC20(POOL_LP_TOKEN).balanceOf(address(this)), indexBASE_TOKEN, 0);
            IERC20(BASE_TOKEN).safeTransfer(owner(), IERC20(BASE_TOKEN).balanceOf(address(this)));

        }

        if (metaOrPlainPool == false) {
            removeLiquidityPlainPool(true);
        }

        baseline = USD_Convertible();
    }

    /// @dev    This will remove liquidity from Curve Plain Pools and transfer the tokens to the DAO.
    /// @notice Private function, should only be called through pullFromLockerMulti() and pullFromLockerPartial().
    function removeLiquidityPlainPool(bool _transfer) private {

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

        if (_transfer == true) {
            for (uint8 i = 0; i < PP_TOKENS.length; i++) {
                if (IERC20(PP_TOKENS[i]).balanceOf(address(this)) > 0) {
                    IERC20(PP_TOKENS[i]).safeTransfer(owner(), IERC20(PP_TOKENS[i]).balanceOf(address(this)));
                }       
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
        /// TODO validate baseline when depegging coins with chainlink taking the lowest price for calculation
        if (!IZivoeGlobals(GBL).isKeeper(_msgSender())) {
            require(investTimeLock < block.timestamp, "timelock - restricted to keepers for now" );
        }

        uint256 preBaseline;

        if (baseline != 0) {
            preBaseline = USD_Convertible();
            if (preBaseline > baseline) {
                yieldOwedToYDL += preBaseline - baseline;
            }
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

        //increase baseline
        uint256 postBaseline = USD_Convertible();
        require(postBaseline > preBaseline, "OCY_ANGLE::pushToLockerMulti() postBaseline < preBaseline");

        baseline = postBaseline;
    }
    
    /// @dev    This will stake total balance of LP tokens on Convex
    /// @notice Private function, should only be called through invest().
    function stakeLP() private {
        IERC20(POOL_LP_TOKEN).safeApprove(CVX_Deposit_Address, IERC20(POOL_LP_TOKEN).balanceOf(address(this)));
        ICVX_Booster(CVX_Deposit_Address).depositAll(convexPoolID, true);
    }

    ///@dev returns the value of our LP position in USD.
    function USD_Convertible() public view returns (uint256 _amount) {
        uint256 contractLP = IConvexRewards(CVX_Reward_Address).balanceOf(address(this));

        if (metaOrPlainPool == true) {

            uint256 amountBASE_TOKEN = ICRVMetaPool(pool).calc_withdraw_one_coin(contractLP, indexBASE_TOKEN);
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

    ///@dev public accessible function to harvest yield every 30 days. Yield will have to be transferred to YDL by a keeper via forwardYieldKeeper()
    ///TODO: implement treshold for baseline above which we decide to sell LP tokens as yield ?
    function harvestYield() public {
        require(block.timestamp > nextYieldDistribution);
        nextYieldDistribution = block.timestamp + 30 days;

        //We check initial balances of tokens in order to avoid confusion between tokens that could be pushed through "pushToLockerMulti" at approx same time and not converted yet while we are harvesting. Can optimize by including CRV and CVX to the "extraRewardsAddresses[]".
        uint256 initCRVBalance = IERC20(CRV).balanceOf(address(this));
        uint256 initCVXBalance = IERC20(CVX).balanceOf(address(this));
        uint256[] memory initPoolTokensBalance;
        uint256[] memory initRewardsBalance;

        if (metaOrPlainPool == true) {
            uint256[] memory _initPoolTokensBalance = new uint256[](1);
            _initPoolTokensBalance[0] = IERC20(BASE_TOKEN).balanceOf(address(this));
            initPoolTokensBalance = _initPoolTokensBalance;
        }

        if (metaOrPlainPool == false) {
            uint256[] memory _initPoolTokensBalance = new uint256[](PP_TOKENS.length);
            for (uint8 i = 0; i < PP_TOKENS.length; i++) {
                _initPoolTokensBalance[i] = IERC20(PP_TOKENS[i]).balanceOf(address(this));
            }
            initPoolTokensBalance = _initPoolTokensBalance;
        }

        if (extraRewards == true) {
            uint256[] memory _initRewardsBalance = new uint256[](extraRewardsAddresses.length);
            for (uint8 i = 0; i < extraRewardsAddresses.length; i++) {
                _initRewardsBalance[i] = IERC20(extraRewardsAddresses[i]).balanceOf(address(this));
            }
            initRewardsBalance = _initRewardsBalance;
        }

        //Claiming rewards on Convex
        IConvexRewards(CVX_Reward_Address).getReward();

        //Calculate the rewards to transfer to YDL.
        toForwardCRV = IERC20(CRV).balanceOf(address(this)) - initCRVBalance;
        toForwardCVX = IERC20(CVX).balanceOf(address(this)) - initCVXBalance;

        //If extra rewards, first check if reward = distributedAsset. In case these are the same, transfer the rewards directly to the YDL.
        if (extraRewards == true) {
            uint256[] memory toForwardExtra = new uint256[](extraRewardsAddresses.length);

            for (uint8 i = 0; i < extraRewardsAddresses.length; i++) {
                if (extraRewardsAddresses[i] == IZivoeYDL_P_3(IZivoeGlobals_P_4(GBL).YDL()).distributedAsset()) {
                    IERC20(extraRewardsAddresses[i]).safeTransfer(IZivoeGlobals_P_4(GBL).YDL(), IERC20(extraRewardsAddresses[i]).balanceOf(address(this)) - initRewardsBalance[i]);
                } else {
                    toForwardExtra[i] = IERC20(extraRewardsAddresses[i]).balanceOf(address(this)) - initRewardsBalance[i];
                }
            }

            toForwardExtraRewards = toForwardExtra;
        }

        //Calculate the amount from the baseline that should be transfered.
        uint256 updatedBaseline = USD_Convertible();

        if ((updatedBaseline + yieldOwedToYDL) > baseline) {
            uint256 yieldFromLP = updatedBaseline - baseline + yieldOwedToYDL;

            //determine lpPrice TODO: check if decimals conversion ok.
            uint256 lpPrice = lpPriceInUSD() / 10**9;
            uint256 amountOfLPToSell = (yieldFromLP * 10**9) / lpPrice;

            IConvexRewards(CVX_Reward_Address).withdrawAndUnwrap(amountOfLPToSell, false);
            
            if (metaOrPlainPool == true) {
                uint256[] memory tokensToTransferBaseline = new uint256[](1);
                ICRVMetaPool(pool).remove_liquidity_one_coin(IERC20(POOL_LP_TOKEN).balanceOf(address(this)), indexBASE_TOKEN, 0);
                // if BASE_TOKEN = YDL distributed asset, transfer yield directly to YDL. Otherwise account for yield to convert by ZVL.
                if (BASE_TOKEN == IZivoeYDL_P_3(IZivoeGlobals_P_4(GBL).YDL()).distributedAsset()) {
                    IERC20(BASE_TOKEN).safeTransfer(IZivoeGlobals_P_4(GBL).YDL(), IERC20(BASE_TOKEN).balanceOf(address(this)) - initPoolTokensBalance[0]);
                } else {
                    tokensToTransferBaseline[0] = IERC20(BASE_TOKEN).balanceOf(address(this)) - initPoolTokensBalance[0];
                    toForwardTokensBaseline = tokensToTransferBaseline;
                }
            }

            if (metaOrPlainPool == false) {
                uint256[] memory tokensToTransferBaseline = new uint256[](PP_TOKENS.length);
                removeLiquidityPlainPool(false);
                // if pool token = YDL distributed asset, transfer yield directly to YDL. Otherwise account for yield to convert by ZVL.
                for (uint8 i = 0; i < PP_TOKENS.length; i++) {
                    if (PP_TOKENS[i] == IZivoeYDL_P_3(IZivoeGlobals_P_4(GBL).YDL()).distributedAsset()) {
                        IERC20(PP_TOKENS[i]).safeTransfer(IZivoeGlobals_P_4(GBL).YDL(), IERC20(PP_TOKENS[i]).balanceOf(address(this)) - initPoolTokensBalance[i]);
                    } else {
                        tokensToTransferBaseline[i] = IERC20(PP_TOKENS[i]).balanceOf(address(this)) - initPoolTokensBalance[i];
                    }
                }
                toForwardTokensBaseline = tokensToTransferBaseline;
            }
        }

    }

    /// @dev This function converts and forwards rewards to the YDL.
    /// TODO: check if optimal to call for each asset separately. Will have to check to transfer the rewards that equal to the distributedAsset() (separate public fct ?) + set accounting for rewards to 0.
    function forwardYieldKeeperCRV_CVX(address asset, bytes calldata data) external {
        require(IZivoeGlobals_P_4(GBL).isKeeper(_msgSender()), "e_OCY_CVX_Modular::forwardYieldKeeper() !IZivoeGlobals_P_4(GBL).isKeeper(_msgSender())");
    
        address _toAsset = IZivoeYDL_P_3(IZivoeGlobals_P_4(GBL).YDL()).distributedAsset();
        uint256 amountForConversion;

        if (asset == CRV) {
            amountForConversion = toForwardCRV;
        } else if (asset == CVX) {
            amountForConversion = toForwardCVX;
        }

        // Swap available "amountForConversion" from reward token to YDL.distributedAsset().
        convertAsset(asset, _toAsset, amountForConversion, data);

        // Transfer all _toAsset received to the YDL, then reduce amountForConversion to 0.
        IERC20(_toAsset).safeTransfer(IZivoeGlobals_P_4(GBL).YDL(), IERC20(_toAsset).balanceOf(address(this)));
        
        //reset amounts to 0 (amounts to transfer)
        if (asset == CRV) {
            toForwardCRV = 0;
        } else if (asset == CVX) {
            toForwardCVX = 0;
        }        

    }

    function lpPriceInUSD() public view returns (uint256 price) {
        //TODO: everywhere in contract take into account the decimals of the token for which we calculate the price.
        if (metaOrPlainPool == true) {
            //pool token balances
            uint256 baseTokenBalance = IERC20(BASE_TOKEN).balanceOf(pool);
            uint256 standardizedBaseTokenBalance = IZivoeGlobals_P_4(GBL).standardize(baseTokenBalance, BASE_TOKEN);
            uint256 underlyingLPTokenBalance = IERC20(MP_UNDERLYING_LP_TOKEN).balanceOf(pool);

            //price of base token
            (,int baseTokenPrice,,,) = AggregatorV3Interface(chainlinkPriceFeeds[0]).latestRoundData();
            require(baseTokenPrice >= 0);

            //base token total value
            uint256 baseTokenTotalValue = (standardizedBaseTokenBalance * uint(baseTokenPrice)) / (10** AggregatorV3Interface(chainlinkPriceFeeds[0]).decimals());

            //underlying LP token price
            uint256 totalValueOfUnderlyingPool;

            for (uint8 i = 0; i < numberOfTokensUnderlyingLPPool; i++) {
                address underlyingToken = ICRVMetaPool(MP_UNDERLYING_LP_POOL).coins(i);
                uint256 underlyingTokenAmount = ICRVMetaPool(MP_UNDERLYING_LP_POOL).balances(i);
                (,int underlyingTokenPrice,,,) = AggregatorV3Interface(chainlinkPriceFeeds[i+1]).latestRoundData();
                require(underlyingTokenPrice >= 0);

                uint256 standardizedAmount = IZivoeGlobals_P_4(GBL).standardize(underlyingTokenAmount, underlyingToken);
                totalValueOfUnderlyingPool += (standardizedAmount * uint(underlyingTokenPrice)) / (10** AggregatorV3Interface(chainlinkPriceFeeds[i+1]).decimals());
            }

            uint256 underlyingLPTokenPrice = (totalValueOfUnderlyingPool * 10**9) / (IERC20(MP_UNDERLYING_LP_TOKEN).totalSupply() / 10**9);

            //pool total value
            uint256 poolTotalValue = baseTokenTotalValue + ((underlyingLPTokenPrice/10**9) * (underlyingLPTokenBalance/10**9));
            
            //MP LP Token Price
            uint256 MP_lpTokenPice = (poolTotalValue * 10**9) / (IERC20(POOL_LP_TOKEN).totalSupply()/ 10**9);

            return MP_lpTokenPice;

        }

        if (metaOrPlainPool == false) {
           
            uint256 totalValueInPool;

            for (uint8 i = 0; i < PP_TOKENS.length; i++) {
                address token = PP_TOKENS[i];
                uint256 tokenAmount = ICRVPlainPoolFBP(pool).balances(i);
                (,int tokenPrice,,,) = AggregatorV3Interface(chainlinkPriceFeeds[i]).latestRoundData();
                require(tokenPrice >= 0);

                uint256 standardizedAmount = IZivoeGlobals_P_4(GBL).standardize(tokenAmount, token);
                totalValueInPool += (standardizedAmount * uint(tokenPrice)) / (10** AggregatorV3Interface(chainlinkPriceFeeds[i]).decimals());
            }

            //PP LP Token Price
            uint256 PP_lpTokenPrice = (totalValueInPool * 10**9) / (IERC20(POOL_LP_TOKEN).totalSupply()/10**9);

            return PP_lpTokenPrice;
        }
    }
}