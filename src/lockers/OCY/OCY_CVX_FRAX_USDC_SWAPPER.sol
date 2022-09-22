// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

import "../Utility/LockerSwapper.sol";

import { ICRVPlainPoolFBP, IZivoeGlobals, ICRV_MP_256, ICVX_Booster, IConvexRewards, IUniswapRouterV3, ExactInputSingleParams, IZivoeYDL } from "../../misc/InterfacesAggregated.sol";

/// @dev    This contract is responsible for adding liquidity into Curve (Frax/USDC Pool) and stake LP tokens on Convex.
///         TODO: find method to check wether converting between USDC and Frax would increase LP amount taking conversion fees into account.


contract OCY_CVX_FRAX_USDC is ZivoeLocker, LockerSwapper {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL; /// @dev Zivoe globals.

    address payable public constant oneInchAggregator = payable(0x1111111254fb6c44bAC0beD2854e76F90643097d); /// @dev 1inch aggregator contract for swapping tokens. payable to accept swaps in ETH.

    address public constant UNI_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;  /// @dev UniswapV3 swapRouter contract.

    uint256 public nextYieldDistribution;     /// @dev Determines next available forwardYield() call. 

    uint256 public swapperTimelockStablecoin; /// @dev Determines a timelock period in which ZVL can convert stablecoins through 1inch (before a publicly available swap function)


    /// @dev Stablecoin addresses.
    address public constant DAI  = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    /// @dev WETH address - used for swapping rewards.
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @dev CRV.FI pool addresses (plain-pool, and meta-pool).
    address public constant FRAX_3CRV_MP = 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B;
    address public constant CRV_PP_FRAX_USDC = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address public constant CRV_PP_ETH_CVX = 0xB576491F1E6e5E62f1d8F26062Ee822B40B0E0d4;
    address public constant CRV_PP_ETH_CRV = 0x8301AE4fc9c624d1D396cbDAa1ed877821D7C511;


    /// @dev CRV.FI LP token address.
    address public constant lpFRAX_USDC = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;

    /// @dev Convex addresses.
    address public constant CVX_Deposit_Address = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    address public constant CVX_Reward_Address = 0x7e880867363A7e321f5d260Cade2B0Bb2F717B02;

    /// @dev Reward token addresses.
    address public constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;

    
    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_CVX_FraxUSDC.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.
    
    constructor(address DAO, address _GBL) {
        transferOwnership(DAO);
        GBL = _GBL;
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
            if (amounts[i] > 0) {
                IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
            }
        }

        swapperTimelockStablecoin = block.timestamp + 12 hours;
    }

    // TODO: #1 give Keepers a way to pre-convert assets via 1INCH

    function keeperConvertStablecoin(
        address stablecoin,
        address assetOut,
        bytes calldata data
    ) public {
        require(IZivoeGlobals(GBL).isKeeper(_msgSender()));
        require(stablecoin == DAI || stablecoin == USDT || stablecoin == USDC || stablecoin == FRAX);
        require((assetOut == USDC || assetOut == FRAX) && stablecoin != assetOut);
        convertAsset(stablecoin, assetOut, IERC20(stablecoin).balanceOf(address(this)), data);
    }

    // TODO: #2 give public a way to convert assets if Keepers FAIL

    function publicConvertStablecoins(
        address[] calldata stablecoins 
    ) public {
        require(swapperTimelockStablecoin < block.timestamp);

        for (uint i = 0; i < stablecoins.length; i++) {
            require(stablecoins[i] == DAI || stablecoins[i] == USDT);

            // TODO: Implement the existing public swap via 3CRV.
            if (stablecoins[i] == DAI) {
                int8 tokenToSupply = maxAmountLPTokens(IERC20(stablecoins[i]).balanceOf(address(this)));
                // Convert DAI to "tokenToSupply" via FRAX_3CRV_MP pool.
                IERC20(stablecoins[i]).safeApprove(FRAX_3CRV_MP, IERC20(stablecoins[i]).balanceOf(address(this)));
                ICRV_MP_256(FRAX_3CRV_MP).exchange_underlying(
                    int128(1), int128(tokenToSupply), IERC20(stablecoins[i]).balanceOf(address(this)), 0
                );
            } else if (stablecoins[i] == USDT) {
                int8 tokenToSupply = maxAmountLPTokens(IERC20(stablecoins[i]).balanceOf(address(this)) * 10**12);
                // Convert USDT to "tokenToSupply" via FRAX_3CRV_MP pool.
                IERC20(stablecoins[i]).safeApprove(FRAX_3CRV_MP, IERC20(stablecoins[i]).balanceOf(address(this)));
                ICRV_MP_256(FRAX_3CRV_MP).exchange_underlying(
                    int128(3), int128(tokenToSupply), IERC20(stablecoins[i]).balanceOf(address(this)), 0
                );
            } 
        }
        
        invest();
    }

    // /// @dev    This pulls capital from the DAO, does any necessary pre-conversions, supplies liquidity into the Curve Frax-USDC pool and stakes the LP token on Convex.
    // /// @notice Only callable by the DAO.
    // function pushToLockerMulti(address[] memory assets, uint256[] memory amounts) public override onlyOwner {
    //     require(assets.length <= 4, "OCY_CVX_FRAX_USDC::pullFromLocker() max 4 different stablecoins");

    //     for (uint i = 0; i < assets.length; i++) {
    //         require(assets[i] == DAI || assets[i] == USDT || assets[i] == USDC || assets[i] == FRAX);

    //         if (amounts[i] > 0) {
    //             IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
    //         } else {
    //             continue;
    //         }
    //         //find method to check wether converting between USDC and Frax would increase LP amount taking conversion fees into account.
    //         if (assets[i] == USDC) {
    //             continue;
    //         } else {
    //             if (assets[i] == DAI) {
    //                 int8 tokenToSupply = maxAmountLPTokens(IERC20(assets[i]).balanceOf(address(this)));
    //                 // Convert DAI to "tokenToSupply" via FRAX_3CRV_MP pool.
    //                 IERC20(assets[i]).safeApprove(FRAX_3CRV_MP, IERC20(assets[i]).balanceOf(address(this)));
    //                 ICRV_MP_256(FRAX_3CRV_MP).exchange_underlying(int128(1), int128(tokenToSupply), IERC20(assets[i]).balanceOf(address(this)), 0);
                    
    //             } else if (assets[i] == USDT) {
    //                 int8 tokenToSupply = maxAmountLPTokens(IERC20(assets[i]).balanceOf(address(this)) * 10**12);
    //                 // Convert USDT to "tokenToSupply" via FRAX_3CRV_MP pool.
    //                 IERC20(assets[i]).safeApprove(FRAX_3CRV_MP, IERC20(assets[i]).balanceOf(address(this)));
    //                 ICRV_MP_256(FRAX_3CRV_MP).exchange_underlying(int128(3), int128(tokenToSupply), IERC20(assets[i]).balanceOf(address(this)), 0);
                    
    //             } 
    //         }
    //     }

    //     if (nextYieldDistribution == 0) {
    //         nextYieldDistribution = block.timestamp + 30 days;
    //     }  

    //     invest();  
    // }

    /// @dev    This divests allocation from Convex and Curve pool and returns capital to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  assets The asset to return (in this case, required to be USDC or FRAX).
    function pullFromLockerMulti(address[] calldata assets) public override onlyOwner {
        require(assets[0] == FRAX && assets[1] == USDC , "OCY_CVX_FRAX_USDC::pullFromLocker() asset 1 != FRAX or asset 2 != USDC");
        uint256[2] memory tester;
        IConvexRewards(CVX_Reward_Address).withdrawAllAndUnwrap(true);
        ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).remove_liquidity(IERC20(lpFRAX_USDC).balanceOf(address(this)), tester);

        if(IERC20(CRV).balanceOf(address(this)) > 0) {
            IERC20(CRV).safeTransfer(owner(), IERC20(CRV).balanceOf(address(this)));
        }

        if(IERC20(CVX).balanceOf(address(this)) > 0) {
            IERC20(CVX).safeTransfer(owner(), IERC20(CVX).balanceOf(address(this)));
        }
    }

    /// @dev    This burns a partial amount of LP tokens from the Convex FRAX-USDC staking pool,
    ///         removes the liquidity from Curve and returns resulting coins back to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  asset The LP token to burn.
    /// @param  amount The amount of LP tokens to burn.
    /// TODO: claim rewards or not when pullPartial ?
    function pullFromLockerPartial(address asset, uint256 amount) external override onlyOwner {
        require(asset == CVX_Reward_Address, "OCY_CVX_FRAX_USDC::pullFromLockerPartial() assets != CVX_Reward_Address");

        uint256[2] memory tester;
        IConvexRewards(CVX_Reward_Address).withdrawAndUnwrap(amount, false);
        ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).remove_liquidity(IERC20(lpFRAX_USDC).balanceOf(address(this)), tester);
        IERC20(FRAX).safeTransfer(owner(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));

/*         if(IERC20(CRV).balanceOf(address(this)) > 0) {
            IERC20(CRV).safeTransfer(owner(), IERC20(CRV).balanceOf(address(this)));
        }

        if(IERC20(CVX).balanceOf(address(this)) > 0) {
            IERC20(CVX).safeTransfer(owner(), IERC20(CVX).balanceOf(address(this)));
        } */
    }


    ///@dev          This will calculate the amount of LP tokens received depending on the asset supplied
    ///@notice       Private function, should only be called through pushToLocker() which can only be called by DAO.
    ///@param amount The amount of dollar stablecoins we will supply to the pool.
    function maxAmountLPTokens(uint256 amount) private view returns (int8 _tokenToSupply){
        uint256[2] memory inputTokensFrax = [amount, 0];
        uint256[2] memory inputTokensUSDC = [0, amount/(10**12)];
    
        uint256 lpTokensIfFrax = ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).calc_token_amount(inputTokensFrax, true);
        uint256 lpTokensIfUSDC = ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).calc_token_amount(inputTokensUSDC, true);

        if (lpTokensIfFrax >= lpTokensIfUSDC) 
            return 0;
        else 
            return 2;
        
    }

    /// @dev    This directs USDC or Frax into a Curve Pool and then stakes the LP into Convex.
    function invest() public {
        /// TODO validate condition below
        if (!IZivoeGlobals(GBL).isKeeper(_msgSender())) {
            require(swapperTimelockStablecoin < block.timestamp);
        }

        if (nextYieldDistribution == 0) {
            nextYieldDistribution = block.timestamp + 30 days;
        } 

        uint256 FRAX_Balance = IERC20(FRAX).balanceOf(address(this));
        uint256 USDC_Balance = IERC20(USDC).balanceOf(address(this));

        if (FRAX_Balance > 0 && USDC_Balance > 0) {
            IERC20(FRAX).safeApprove(CRV_PP_FRAX_USDC, FRAX_Balance);
            IERC20(USDC).safeApprove(CRV_PP_FRAX_USDC, USDC_Balance);
            uint256[2] memory deposits_bp;
            deposits_bp = [FRAX_Balance, USDC_Balance];
            ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).add_liquidity(deposits_bp, 0);
            stakeLP();
        } else if (FRAX_Balance > 0) {
            IERC20(FRAX).safeApprove(CRV_PP_FRAX_USDC, FRAX_Balance);
            uint256[2] memory deposits_bp;
            deposits_bp[0] = FRAX_Balance;
            ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).add_liquidity(deposits_bp, 0);
            stakeLP();
        } else if (USDC_Balance > 0) {
            IERC20(USDC).safeApprove(CRV_PP_FRAX_USDC, USDC_Balance);
            uint256[2] memory deposits_bp;
            deposits_bp[1] = USDC_Balance;
            ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).add_liquidity(deposits_bp, 0);
            stakeLP();
        }
    }

    /// @dev    This will stake total balance of LP tokens on Convex
    /// @notice Private function, should only be called through invest().
    function stakeLP() private {
        IERC20(lpFRAX_USDC).safeApprove(CVX_Deposit_Address, IERC20(lpFRAX_USDC).balanceOf(address(this)));
        ICVX_Booster(CVX_Deposit_Address).depositAll(100, true);
    }


    /// @dev    This forwards yield to the YDL (according to specific conditions as will be discussed).
    /// TODO:   Do we keep a public forwardYield fct (for example a FRAX3CRV pool if distributed asset is one of 4 stablecoins)
    function forwardYield() public {
        if (IZivoeGlobals(GBL).isKeeper(_msgSender())) {
            require(
                block.timestamp > nextYieldDistribution - 12 hours, 
                "OCY_CVX_FRAX_USD::forwardYield() block.timestamp <= nextYieldDistribution - 12 hours"
            );
        }
        else {
            require(block.timestamp > nextYieldDistribution, "OCY_CVX_FRAX_USD::forwardYield() block.timestamp <= nextYieldDistribution");
        }
        
        _forwardYield();
    }

    function _forwardYield() private {

        IConvexRewards(CVX_Reward_Address).getReward();
        nextYieldDistribution = block.timestamp + 30 days;

        uint256 CVX_Balance = IERC20(CVX).balanceOf(address(this));
        uint256 CRV_Balance = IERC20(CRV).balanceOf(address(this));

        if (CVX_Balance > 0) {
            //Curve.fi trade to WETH
            IERC20(CVX).safeApprove(CRV_PP_ETH_CVX, CVX_Balance);
            ICRVPlainPoolFBP(CRV_PP_ETH_CVX).exchange(1, 0, CVX_Balance, 0);

        }

        if (CRV_Balance > 0) {
            //Curve.fi trade to WETH
            IERC20(CRV).safeApprove(CRV_PP_ETH_CRV, CRV_Balance);
            ICRVPlainPoolFBP(CRV_PP_ETH_CRV).exchange(1, 0, CRV_Balance, 0);
    
        }
        
        
        //Uniswap trade to USDC (0.05% or 0.3% pools on UNIV3)
        UniswapExactInputSingle(WETH, USDC, 500, IERC20(WETH).balanceOf(address(this)));
        //Curve.fi trade to FRAX
        IERC20(USDC).safeApprove(CRV_PP_FRAX_USDC, IERC20(USDC).balanceOf(address(this)));
        ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).exchange(1, 0, IERC20(USDC).balanceOf(address(this)), 0);
        //Transfer FRAX to YDL
        IERC20(FRAX).safeTransfer(IZivoeGlobals(GBL).YDL(), IERC20(FRAX).balanceOf(address(this)));

    }

    function ZVLForwardYield(bytes memory oneInchDataCRV, bytes memory oneInchDataCVX) external {
        require(IZivoeGlobals(GBL).isKeeper(_msgSender()));
        require(block.timestamp > nextYieldDistribution - 12 hours);

        //address distributedAsset = IZivoeYDL(IZivoeGlobals(GBL).YDL()).distributedAsset();
        nextYieldDistribution = block.timestamp + 30 days;

        IConvexRewards(CVX_Reward_Address).getReward();

        uint256 CVX_Balance = IERC20(CVX).balanceOf(address(this));
        uint256 CRV_Balance = IERC20(CVX).balanceOf(address(this));

        if (CVX_Balance > 0) {
            IERC20(CVX).safeApprove(oneInchAggregator, CVX_Balance);
            //convertAsset(CVX, distributedAsset, IERC20(CVX).balanceOf(address(this)), oneInchDataCVX);
        }

        if(CRV_Balance > 0) {
            IERC20(CRV).safeApprove(oneInchAggregator, CRV_Balance);
            //convertAsset(CRV, distributedAsset, IERC20(CRV).balanceOf(address(this)), oneInchDataCRV);
            
        }

        //IERC20(distributedAsset).safeTransfer(IZivoeGlobals(GBL).YDL(), IERC20(distributedAsset).balanceOf(address(this)));
    
    }


    /// @dev    This will return the value in USD of the LP tokens owned by this contract.
    ///         This value is a virtual price, meaning it will consider 1 stablecoin = 1 USD.
    function USDConvertible() public view returns (uint256 amount) {
        uint256 contractLP = IConvexRewards(CVX_Reward_Address).balanceOf(address(this));
        uint256 virtualPrice = ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).get_virtual_price();
        amount = contractLP * virtualPrice;

    }

    /// TO DO: nat spec
    function UniswapExactInputSingle(
        address _tokenIn,
        address _tokenOut, 
        uint24 _fee,
        uint256 _amountIn
        ) internal returns (uint256 amountOut) {

        IERC20(_tokenIn).safeApprove(UNI_V3_ROUTER, _amountIn);

        ExactInputSingleParams memory params = ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: _fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0

        });

        amountOut = IUniswapRouterV3(UNI_V3_ROUTER).exactInputSingle(params);
    }

}