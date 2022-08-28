// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

import { ICRVPlainPoolFBP, ICRV_MP_256, IZivoeGBL, ICVX_Booster, IConvexRewards, IUniswapRouterV3, ExactInputSingleParams} from "../interfaces/InterfacesAggregated.sol";

/// @dev    This contract is responsible for allocating capital to AAVE (v2).
///         TODO: Consider looking into credit delegation.
contract OCY_CVX_FraxUSDC is ZivoeLocker {
    

    // ---------------
    // State Variables
    // ---------------

    address public GBL; /// @dev Zivoe globals.
    

    /// @dev Stablecoin addresses.
    address public constant DAI  = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    /// @dev CRV.FI pool addresses (plain-pool, and meta-pool).
    address public constant CRV_PP = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address public constant FRAX_3CRV_MP = 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B;
    address public constant CRV_PP_FRAX_USDC = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;

    /// @dev CRV.FI LP token address.
    address public constant lpCRV_FraxUSDC = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;

    /// @dev Convex addresses.
    address public constant CVX_Deposit_Address = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    address public constant CVX_Reward_Address = 0x7e880867363A7e321f5d260Cade2B0Bb2F717B02;

    /// @dev Reward token addresses.
    address public constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;

    /// @dev Uniswap swapRouter contract.
    address public constant swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;


    uint256 nextYieldDistribution;
    uint24 public poolFee;


    
    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the OCY_CVX_FraxUSDC.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.
    /// @param _poolFee fee for a swap on UniV3 (3000=0.3%).
    constructor(address DAO, address _GBL, uint24 _poolFee) {
        transferOwnership(DAO);
        GBL = _GBL;
        poolFee = _poolFee;

    }


    // ------
    // Events
    // ------

    /// @notice Emitted during pull().
    /// @param  asset  The asset pulled.
    /// @param  amount The amount of "asset" pulled.
    event Hello(address asset, uint256 amount);

    /// @notice Emitted during push().
    /// @param  asset  The asset returned.
    /// @param  amount The amount of "asset" returned.
    event Goodbye(address asset, uint256 amount);


    // ---------
    // Functions
    // ---------

    function canPush() external pure override returns(bool) {
        return true;
    }

    function canPull() external pure override returns(bool) {
        return true;
    }

    /// @dev    This pulls capital from the DAO, does any necessary pre-conversions, supplies liquidity into the Curve Frax-USDC pool and stakes the LP token on Convex.
    /// @notice Only callable by the DAO.
    function pushToLocker(address asset, uint256 amount) public override onlyOwner {

        require(amount >= 0, "OCY_CVX_FraxUSDC::pushToLocker() amount == 0");

        nextYieldDistribution = block.timestamp + 30 days;
        
        emit Hello(asset, amount);

        IERC20(asset).transferFrom(owner(), address(this), amount);

        //find method to check wether converting between USDC and Frax would increase LP amount taking conversion fees into account.
        if (asset == USDC) {
            invest();
        }
        else {
            if (asset == DAI) {
                int8 tokenToSupply = maxAmountLPTokens(IERC20(asset).balanceOf(address(this)));
                // Convert DAI to "tokenToSupply" via FRAX_3CRV_MP pool.
                IERC20(asset).approve(FRAX_3CRV_MP, IERC20(asset).balanceOf(address(this)));
                ICRV_MP_256(FRAX_3CRV_MP).exchange_underlying(int128(1), int128(tokenToSupply), IERC20(asset).balanceOf(address(this)), 0);
                invest();
            }
            else if (asset == USDT) {
                int8 tokenToSupply = maxAmountLPTokens(IERC20(asset).balanceOf(address(this)) * 10**12);
                // Convert USDT to "tokenToSupply" via FRAX_3CRV_MP pool.
                IERC20(asset).approve(FRAX_3CRV_MP, IERC20(asset).balanceOf(address(this)));
                ICRV_MP_256(CRV_PP).exchange_underlying(int128(3), int128(tokenToSupply), IERC20(asset).balanceOf(address(this)), 0);
                invest();
            }
            else if (asset == FRAX) {
                invest();
            }
            else {
                /// @dev Revert here, given unknown "asset" received (otherwise, "asset" will be locked and/or lost forever).
                revert("OCY_CVX_FraxUSDC::pushToLocker() asset not supported"); 
            }
        }
    }

    /// @dev    This divests allocation from Convex pool and returns capital to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  asset The asset to return (in this case, required to be USDC or FRAX).
    function pullFromLocker(address asset) public override onlyOwner {
        require(asset == USDC || asset == FRAX , "OCY_CVX_FraxUSDC::pullFromLocker() asset != USDC or FRAX");
        divest();
    }

    ///@dev This will calculate the amount of LP tokens received depending on the asset supplied
    ///@notice Private function, should only be called through pushToLocker() which can only be called by DAO.
    ///@param amount the amount of dollar stablecoins we will supply to the pool.
    function maxAmountLPTokens (uint256 amount) private view returns (int8 _tokenToSupply){
        uint256[2] memory inputTokensFrax = [amount, 0];
        uint256[2] memory inputTokensUSDC = [0, amount/(10**12)];
    
        uint256 lpTokensIfFrax = ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).calc_token_amount(inputTokensFrax, true);
        uint256 lpTokensIfUSDC = ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).calc_token_amount(inputTokensUSDC, true);

        if(lpTokensIfFrax >= lpTokensIfUSDC){
            return 0;
        } else {
            return 2;
        }
    }

    /// @dev    This directs USDC or Frax into a Curve Pool and then stakes the LP into Convex.
    /// @notice Private function, should only be called through pushToLocker() which can only be called by DAO.
    function invest() private {

        uint256 fraxBalance = IERC20(FRAX).balanceOf(address(this));
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));

        if(fraxBalance > usdcBalance){
            IERC20(FRAX).approve(CRV_PP_FRAX_USDC, fraxBalance);
            uint256[2] memory deposits_bp;
            deposits_bp[0] = fraxBalance;
            ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).add_liquidity(deposits_bp, 0);
            stakeLP();

        } else{
            IERC20(USDC).approve(CRV_PP_FRAX_USDC, usdcBalance);
            uint256[2] memory deposits_bp;
            deposits_bp[1] = usdcBalance;
            ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).add_liquidity(deposits_bp, 0);
            stakeLP();

        }
    }

    /// @dev    This will stake total balance of LP tokens on Convex
    /// @notice Private function, should only be called through invest().
    function stakeLP() private {
        IERC20(lpCRV_FraxUSDC).approve(CVX_Deposit_Address, IERC20(lpCRV_FraxUSDC).balanceOf(address(this)));
        ICVX_Booster(CVX_Deposit_Address).depositAll(64, true);
    }

    /// @dev    This unstakes LP tokens on Convex and will remove liquidity on Curve.
    /// @notice Private function, should only be called through pullFromLocker() which can only be called by DAO.
    function divest() private {
        uint256 departure;
        emit Goodbye(USDC, departure);
    }

    /// @dev    This forwards yield to the YDL (according to specific conditions as will be discussed).
    function forwardYield() public {
        require(block.timestamp > nextYieldDistribution);
        nextYieldDistribution = block.timestamp + 30 days;
        _forwardYield();
    }

    function _forwardYield() private {
        
        IConvexRewards(CVX_Reward_Address).getReward();

        if (IERC20(CVX).balanceOf(address(this)) >0){
            swapRewardToFrax(CVX);
        }

        if(IERC20(CRV).balanceOf(address(this))>0){
            swapRewardToFrax(CRV);
        }
        
        IERC20(FRAX).transfer(IZivoeGBL(GBL).YDL(), IERC20(FRAX).balanceOf(address(this)));
    }

    /// @dev    This will swap a specific reward token to Frax on Uniswap
    /// @notice Private function, should only be called through _forwardYield.
    function swapRewardToFrax(address _reward) private returns(uint256 amountOut){

        IERC20(_reward).approve(swapRouter, IERC20(_reward).balanceOf(address(this)));

        ExactInputSingleParams memory params = ExactInputSingleParams({
            tokenIn: _reward,
            tokenOut: FRAX,
            fee: poolFee,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: IERC20(_reward).balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0

        });

        amountOut = IUniswapRouterV3(swapRouter).exactInputSingle(params);
    }

    /// @dev    This will update the Uniswap fee to implement a swap
    /// @notice Only callable by the DAO.
    function setPoolFee (uint24 _newFee) public onlyOwner {
        poolFee = _newFee;
    }

}
