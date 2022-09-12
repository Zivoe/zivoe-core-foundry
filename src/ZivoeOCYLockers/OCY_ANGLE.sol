// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

import { ICRVPlainPoolFBP, IZivoeGlobals, ICRV_MP_256, IUniswapRouterV3, ExactInputParams, ISwap, IStakeDAOVault} from "../interfaces/InterfacesAggregated.sol";

/// @dev    This contract is responsible for adding liquidity into Angle (FRAX/agEUR Pool)(and stake LP tokens on StakeDAO).

///TO Do: we should not be able to withdraw if < 120% collateral ratio (otherwise we'll have some slippage)

contract OCY_ANGLE is ZivoeLocker {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL; /// @dev Zivoe globals.
    address public UNI_ROUTER;  /// @dev UniswapV3 swapRouter contract.
    address payable public oneInchAggregator; /// @dev 1inch aggregator contract for swapping tokens. payable to accept swaps in ETH.
    

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

    /// @dev Angle addresses.
    address public constant FRAX_PoolManager = 0x6b4eE7352406707003bC6f6b96595FD35925af48;
    address public constant sanFRAX_EUR = 0xb3B209Bb213A5Da5B947C56f2C770b3E1015f1FE;
    address public constant AngleDepositContract = 0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87;

    /// @dev StakeDAO addresses.
    address public constant StakeDAO_Vault = 0x1BD865ba36A510514d389B2eA763bad5d96b6ff9;



    uint256 nextYieldDistribution;

    
    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_ANGLE.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.
    
    constructor(address DAO, address _GBL, address _UNI_ROUTER, address _oneInchAggregator) {
        transferOwnership(DAO);
        GBL = _GBL;
        UNI_ROUTER = _UNI_ROUTER;
        oneInchAggregator = payable(_oneInchAggregator);
    }


    // ---------------
    //    Functions
    // ---------------

    function canPushMulti() external pure override returns (bool) {
        return true;
    }

    function canPullMulti() external pure override returns (bool) {
        return true;
    }

    function canPullPartial() external override pure returns (bool) {
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

        invest();  
    }

    /// @dev    This divests allocation from Angle and StakeDAO pool and returns capital to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  assets The asset to return (in this case, required to be USDC or FRAX).
    function pullFromLockerMulti(address[] calldata assets) public override onlyOwner {
        require(assets[0] == FRAX && assets[1] == USDC , "OCY_ANGLE::pullFromLocker() asset 1 != FRAX or asset 2 != USDC");
        uint256[2] memory tester;
        IConvexRewards(CVX_Reward_Address).withdrawAllAndUnwrap(true);
        ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).remove_liquidity(IERC20(lpFRAX_USDC).balanceOf(address(this)), tester);
        IERC20(FRAX).safeTransfer(owner(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
        IERC20(CRV).safeTransfer(owner(), IERC20(CRV).balanceOf(address(this)));
        IERC20(CVX).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
    }

    /// @dev    This burns a partial amount of LP tokens from the Angle FRAX pool,
    ///         and returns resulting coins back to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  asset The LP token to burn.
    /// @param  amount The amount of LP tokens to burn.
    function pullFromLockerPartial(address asset, uint256 amount) external override onlyOwner {
        require(asset == CVX_Reward_Address, "OCY_ANGLE::pullFromLockerPartial() assets != CVX_Reward_Address");

        uint256[2] memory tester;
        IConvexRewards(CVX_Reward_Address).withdrawAndUnwrap(amount, false);
        ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).remove_liquidity(IERC20(lpFRAX_USDC).balanceOf(address(this)), tester);
        IERC20(FRAX).safeTransfer(owner(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
        IERC20(CRV).safeTransfer(owner(), IERC20(CRV).balanceOf(address(this)));
        IERC20(CVX).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
    }


    /// @dev    This directs FRAX into an Angle pool (and then stakes the LP into StakeDAO).
    /// @notice Private function, should only be called through pushToLocker() which can only be called by DAO.
    function invest() private {

        uint256 FRAX_Balance = IERC20(FRAX).balanceOf(address(this));

        IERC20(FRAX).safeApprove(AngleDepositContract, FRAX_Balance);
        IAngle(AngleDepositContract).deposit(FRAX_Balance, address(this), FRAX_PoolManager);
        

        
    }

    /// @dev    This will stake total balance of LP tokens on StakeDAO
    /// @notice Private function, should only be called through invest().
    function stakeLP () private {
        IERC20(sanFRAX_EUR).safeApprove(StakeDAO_Vault, IERC20(sanFRAX_EUR).balanceOf(address(this)));
        IStakeDAOVault(StakeDAO_Vault).deposit(address(this), IERC20(sanFRAX_EUR).balanceOf(address(this)));
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

        IConvexRewards(CVX_Reward_Address).getReward();

        uint256 CVX_Balance = IERC20(CVX).balanceOf(address(this));
        uint256 CRV_Balance = IERC20(CVX).balanceOf(address(this));

        if (CVX_Balance > 0) {
            UniswapExactInputMultihop(CVX, CVX_Balance, WETH, USDC, 10000, 500, address(this));
        }

        if(CRV_Balance > 0) {
            UniswapExactInputMultihop(CRV, CRV_Balance, WETH, USDC, 10000, 500, address(this));
        }

        IERC20(USDC).safeApprove(CRV_PP_FRAX_USDC, IERC20(USDC).balanceOf(address(this)));
        ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).exchange(1, 0, IERC20(USDC).balanceOf(address(this)), 0);
        IERC20(FRAX).safeTransfer(IZivoeGlobals(GBL).YDL(), IERC20(FRAX).balanceOf(address(this)));
    }

    function ZVLForwardYield(bytes memory oneInchDataCRV, bytes memory oneInchDataCVX) external {
        require(IZivoeGlobals(GBL).isKeeper(_msgSender()));
        require(block.timestamp > nextYieldDistribution - 12 hours);

        nextYieldDistribution = block.timestamp + 30 days;

        IConvexRewards(CVX_Reward_Address).getReward();

        uint256 CVX_Balance = IERC20(CVX).balanceOf(address(this));
        uint256 CRV_Balance = IERC20(CVX).balanceOf(address(this));

        if (CVX_Balance > 0) {
            IERC20(CVX).safeApprove(oneInchAggregator, CVX_Balance);
            oneInchAggregator.call(oneInchDataCVX);
        }

        if(CRV_Balance > 0) {
            IERC20(CRV).safeApprove(oneInchAggregator, CRV_Balance);
            oneInchAggregator.call(oneInchDataCRV);
            
        }

        IERC20(FRAX).safeTransfer(IZivoeGlobals(GBL).YDL(), IERC20(FRAX).balanceOf(address(this)));

    }


    /// @dev    This will return the value in USD of the LP tokens owned by this contract.
    ///         This value is a virtual price, meaning it will consider 1 stablecoin = 1 USD.
    function USDConvertible() public view returns (uint256 amount) {
        uint256 contractLP = IConvexRewards(CVX_Reward_Address).balanceOf(address(this));
        uint256 virtualPrice = ICRVPlainPoolFBP(CRV_PP_FRAX_USDC).get_virtual_price();
        amount = contractLP * virtualPrice;

    }

    /// TO DO: nat spec
    function UniswapExactInputMultihop(
        address tokenIn,
        uint256 amountIn, 
        address transitToken, 
        address tokenOut,
        uint24 poolFee1,
        uint24 poolFee2, 
        address recipient) internal returns (uint256 amountOut) {

        IERC20(tokenIn).safeApprove(UNI_ROUTER, amountIn);

        ExactInputParams memory params = ExactInputParams({
            path: abi.encodePacked(tokenIn, poolFee1, transitToken, poolFee2, tokenOut),
            recipient: recipient,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0

        });

        amountOut = IUniswapRouterV3(UNI_ROUTER).exactInput(params);
    }

}
