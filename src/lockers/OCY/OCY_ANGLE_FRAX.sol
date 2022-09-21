// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";
import "../Utility/LockerSwapper.sol";

import { ICRVPlainPoolFBP, IZivoeGlobals, ICRV_MP_256, IUniswapRouterV3, ExactInputSingleParams, IAngleStableMasterFront, IStakeDAOVault, IStakeDAOLiquidityGauge, IUniswapV2Router01, IAnglePoolManager, IZivoeYDL } from "../../misc/InterfacesAggregated.sol";

/// @dev    This contract is responsible for adding liquidity into Angle (FRAX/agEUR Pool)(and stake LP tokens on StakeDAO).

///TODO: we should not be able to withdraw if < 120% collateral ratio (otherwise we'll have some slippage) or notify with a bool that we are ready to withdraw even knowing we'll have slippage + baseline and calculate price of LP token.

contract OCY_ANGLE is ZivoeLocker, LockerSwapper {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL; /// @dev Zivoe globals.
    address payable public constant oneInchAggregator = payable(0x1111111254fb6c44bAC0beD2854e76F90643097d); /// @dev 1inch aggregator contract for swapping tokens. payable to accept swaps in ETH.
    address public constant UNI_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;  /// @dev UniswapV3 swapRouter contract.
    address public constant SUSHI_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F; /// @dev Sushiswap router contract.

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
    address public constant CRV_PP_SDT_ETH = 0xfB8814D005C5f32874391e888da6eB2fE7a27902;

    /// @dev Angle addresses.
    address public constant FRAX_PoolManager = 0x6b4eE7352406707003bC6f6b96595FD35925af48;
    address public constant sanFRAX_EUR = 0xb3B209Bb213A5Da5B947C56f2C770b3E1015f1FE;
    address public constant AngleDepositContract = 0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87;
    address public constant ANGLE = 0x31429d1856aD1377A8A0079410B297e1a9e214c2;
    address public constant agEUR = 0x1a7e4e63778B4f12a199C062f3eFdD288afCBce8;

    /// @dev StakeDAO addresses.
    address public constant StakeDAO_Vault = 0x1BD865ba36A510514d389B2eA763bad5d96b6ff9;
    address public constant sanFRAX_SD_LiquidityGauge = 0xB6261Be83EA2D58d8dd4a73f3F1A353fa1044Ef7;
    address public constant SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;



    uint256 public nextYieldDistribution;   /// @dev Determines next available forwardYield() call.
    uint256 public baseline;                /// @dev FRAX convertible, used for forwardYield() accounting.

    
    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_ANGLE.sol contract.
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

    function canPullPartial() public override pure returns (bool) {
        return true;
    }

    /// @dev    This pulls capital from the DAO, does any necessary pre-conversions, supplies liquidity into the Angle's FRAX/USDC pool and stakes the LP token on STAKEDAO.
    /// @notice Only callable by the DAO.
    function pushToLockerMulti(address[] memory assets, uint256[] memory amounts) public override onlyOwner {
        require(assets.length <= 4, "OCY_ANGLE::pullFromLocker() max 4 different stablecoins");

        for (uint i = 0; i < assets.length; i++) {
            require(assets[i] == DAI || assets[i] == USDT || assets[i] == USDC || assets[i] == FRAX);

            if (amounts[i] > 0) {
                IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
                
            } else {
                continue;
            }
            
            if (assets[i] == USDC) {

                IERC20(assets[i]).safeApprove(CRV_PP_FRAX_USDC, IERC20(assets[i]).balanceOf(address(this)));
                ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).exchange(1, 0, IERC20(assets[i]).balanceOf(address(this)), 0);

            } else {
                if (assets[i] == DAI) {

                    IERC20(assets[i]).safeApprove(FRAX_3CRV_MP, IERC20(assets[i]).balanceOf(address(this)));
                    ICRV_MP_256(FRAX_3CRV_MP).exchange_underlying(int128(1), int128(0), IERC20(assets[i]).balanceOf(address(this)), 0);
                    
                } else if (assets[i] == USDT) {
                    
                    IERC20(assets[i]).safeApprove(FRAX_3CRV_MP, IERC20(assets[i]).balanceOf(address(this)));
                    ICRV_MP_256(FRAX_3CRV_MP).exchange_underlying(int128(3), int128(0), IERC20(assets[i]).balanceOf(address(this)), 0);
                    
                } 
            }
        }

        if (nextYieldDistribution == 0) {
            nextYieldDistribution = block.timestamp + 30 days;
        }

        uint256 preBaseline;
        if (baseline != 0) {
            preBaseline = FRAXConvertible();
        }

        invest();  

        //increase baseline

        uint256 postBaseline = FRAXConvertible();
        require(postBaseline > preBaseline, "OCY_ANGLE::pushToLockerMulti() postBaseline < preBaseline");

        baseline = postBaseline;

    }


    /// @dev    This burns a partial amount of LP tokens from the Angle FRAX pool,
    ///         and returns resulting coins back to the DAO. (the order is 1: burn LP tokens on StakeDAO
    ///         then 2: burn LP tokens on Angle)
    /// @notice Only callable by the DAO.
    /// @param  asset The LP token to burn.
    /// @param  amount The amount of LP tokens to burn.
    function pullFromLockerPartial(address asset, uint256 amount) public override onlyOwner {
        require(asset == sanFRAX_SD_LiquidityGauge, "OCY_ANGLE::pullFromLockerPartial() assets != sanFRAX_SD_LiquidityVault");

        IStakeDAOVault(StakeDAO_Vault).withdraw(amount);
        IStakeDAOLiquidityGauge(sanFRAX_SD_LiquidityGauge).claim_rewards(address(this), address(this));
        IAngleStableMasterFront(AngleDepositContract).withdraw(IERC20(sanFRAX_EUR).balanceOf(address(this)), address(this), address(this), FRAX_PoolManager);

        IERC20(FRAX).safeTransfer(owner(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(SDT).safeTransfer(owner(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(ANGLE).safeTransfer(owner(), IERC20(FRAX).balanceOf(address(this)));

        baseline = FRAXConvertible();

    }


    /// @dev    This directs FRAX into an Angle pool (and then stakes the LP into StakeDAO).
    /// @notice Private function, should only be called through pushToLocker() which can only be called by DAO.
    function invest() private {

        uint256 FRAX_Balance = IERC20(FRAX).balanceOf(address(this));

        IERC20(FRAX).safeApprove(AngleDepositContract, FRAX_Balance);
        IAngleStableMasterFront(AngleDepositContract).deposit(FRAX_Balance, address(this), FRAX_PoolManager);
        stakeLP();
        
    }

    /// @dev    This will stake total balance of LP tokens on StakeDAO
    /// @notice Private function, should only be called through invest().
    /// ToDo    check third variable of vault (confirm true or false)
    function stakeLP () private {
        IERC20(sanFRAX_EUR).safeApprove(StakeDAO_Vault, IERC20(sanFRAX_EUR).balanceOf(address(this)));
        IStakeDAOVault(StakeDAO_Vault).deposit(address(this), IERC20(sanFRAX_EUR).balanceOf(address(this)), false);
    }


    /// @dev    This forwards yield to the YDL (according to specific conditions as will be discussed).
    function forwardYield() public {
        if (IZivoeGlobals(GBL).isKeeper(_msgSender())) {
            require(
                block.timestamp > nextYieldDistribution - 12 hours, 
                "OCY_ANGLE::forwardYield() block.timestamp <= nextYieldDistribution - 12 hours"
            );
        }
        else {
            require(block.timestamp > nextYieldDistribution, "OCY_ANGLE::forwardYield() block.timestamp <= nextYieldDistribution");
        }
        nextYieldDistribution = block.timestamp + 30 days;
        _forwardYield();
    }

    function _forwardYield() private {

        uint256 newBaseline = FRAXConvertible();
        
        if(newBaseline > baseline) {
            uint256 yieldFromLP = newBaseline - baseline;
            uint256 LP_USD_Price = sanFRAX_EUR_PRICE();
            uint256 LPTokensToSell = yieldFromLP/LP_USD_Price;
            IStakeDAOVault(StakeDAO_Vault).withdraw(LPTokensToSell);
            IAngleStableMasterFront(AngleDepositContract).withdraw(LPTokensToSell, address(this), address(this), FRAX_PoolManager);

        }
        
        IStakeDAOLiquidityGauge(sanFRAX_SD_LiquidityGauge).claim_rewards(address(this), address(this));

        uint256 SDT_balance = IERC20(SDT).balanceOf(address(this));
        uint256 ANGLE_balance = IERC20(ANGLE).balanceOf(address(this));

        if(SDT_balance > 0) {
            IERC20(SDT).safeApprove(CRV_PP_SDT_ETH, IERC20(SDT).balanceOf(address(this)));
            ICRVPlainPoolFBP(CRV_PP_SDT_ETH).exchange(1, 0, IERC20(SDT).balanceOf(address(this)), 0);
            UniswapExactInputSingle(WETH, USDC, 500, address(this), IERC20(WETH).balanceOf(address(this)));
            
        }

        if(ANGLE_balance > 0) {
            address[] memory tokens;
            tokens[0] = ANGLE;
            tokens[1] = agEUR;
            IUniswapV2Router01(SUSHI_ROUTER).swapExactTokensForTokens(ANGLE_balance, 0, tokens, address(this), block.timestamp);
            UniswapExactInputSingle(agEUR, USDC, 100, address(this), IERC20(agEUR).balanceOf(address(this)));
            
        }

        IERC20(USDC).safeApprove(CRV_PP_FRAX_USDC, IERC20(USDC).balanceOf(address(this)));
        ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).exchange(1, 0, IERC20(USDC).balanceOf(address(this)), 0);
        IERC20(FRAX).safeTransfer(IZivoeGlobals(GBL).YDL(), IERC20(FRAX).balanceOf(address(this)));

        baseline = FRAXConvertible();
    }

    function ZVLForwardYield(bytes memory oneInchDataSDT, bytes memory oneInchDataANGLE) external {
        require(IZivoeGlobals(GBL).isKeeper(_msgSender()));
        require(block.timestamp > nextYieldDistribution - 12 hours);

        //address distributedAsset = IZivoeYDL(IZivoeGlobals(GBL).YDL()).distributedAsset();
        nextYieldDistribution = block.timestamp + 30 days;

        IStakeDAOLiquidityGauge(sanFRAX_SD_LiquidityGauge).claim_rewards(address(this), address(this));

        uint256 SDT_Balance = IERC20(SDT).balanceOf(address(this));
        uint256 ANGLE_Balance = IERC20(ANGLE).balanceOf(address(this));

        if (SDT_Balance > 0) {
            IERC20(SDT).safeApprove(oneInchAggregator, SDT_Balance);
            //convertAsset(SDT, distributedAsset, IERC20(SDT).balanceOf(address(this)), oneInchDataSDT);
        }

        if(ANGLE_Balance > 0) {
            IERC20(ANGLE).safeApprove(oneInchAggregator, ANGLE_Balance);
            //convertAsset(ANGLE, distributedAsset, IERC20(ANGLE).balanceOf(address(this)), oneInchDataANGLE);            
            
        }

        IERC20(FRAX).safeTransfer(IZivoeGlobals(GBL).YDL(), IERC20(FRAX).balanceOf(address(this)));

    }


    /// @dev    This will return the value in USD of the LP tokens owned by this contract.
    ///         This value is a virtual price, meaning it will consider 1 stablecoin = 1 USD.
    function FRAXConvertible() public view returns (uint256 amount) {
        uint256 ZivoeAngleLP = IERC20(sanFRAX_SD_LiquidityGauge).balanceOf(address(this));
        uint256 totalLP = IERC20(sanFRAX_EUR).totalSupply();
        uint256 totalAssets = IAnglePoolManager(FRAX_PoolManager).getTotalAsset();
        amount = (ZivoeAngleLP/totalLP) * totalAssets;

    }

    function getPoolCollateralRatio() external view returns (uint256 ratio) {
        ratio = IAngleStableMasterFront(AngleDepositContract).getCollateralRatio();
    }

    function sanFRAX_EUR_PRICE() public view returns (uint256 price) {
        uint256 totalLP = IERC20(sanFRAX_EUR).totalSupply();
        uint256 totalAssets = IAnglePoolManager(FRAX_PoolManager).getTotalAsset();
        price = totalAssets/totalLP;
    }


    function UniswapExactInputSingle(
        address _tokenIn,
        address _tokenOut, 
        uint24 _fee, 
        address _recipient,
        uint256 _amountIn) internal returns (uint256 amountOut) {

        IERC20(_tokenIn).safeApprove(UNI_V3_ROUTER, _amountIn);

        ExactInputSingleParams memory params = ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: _fee,
            recipient: _recipient,
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0

        });

        amountOut = IUniswapRouterV3(UNI_V3_ROUTER).exactInputSingle(params);
    }

}