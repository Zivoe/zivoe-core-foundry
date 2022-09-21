// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../libraries/OpenZeppelin/IERC20.sol";
import "../libraries/OpenZeppelin/IERC20Metadata.sol";

interface IERC20Mintable is IERC20, IERC20Metadata {
    function mint(address account, uint256 amount) external;
}

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) external;
    function approve(address to, uint256 tokenId) external;
}

interface IERC1155 {
    function setApprovalForAll(address operator, bool approved) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

interface IZivoeRewards {
    function depositReward(address _rewardsToken, uint256 reward) external;
}

interface IZivoeTranches {
    function unlock() external;
}

interface IZivoeYDL {
    function distributeYield() external;
    function passToTranchies(address asset, uint256 _yield) external;
    function unlock() external;
}

interface IZivoeGlobals {
    function DAO() external view returns (address);
    function ITO() external view returns (address);
    function stJTT() external view returns (address);
    function stSTT() external view returns (address);
    function stZVE() external view returns (address);
    function TLC() external view returns (address);
    function vestZVE() external view returns (address);
    function YDL() external view returns (address);
    function zJTT() external view returns (address);
    function zSTT() external view returns (address);
    function ZVE() external view returns (address);
    function ZVL() external view returns (address);
    function ZVT() external view returns (address);
    function isKeeper(address) external view returns (bool);
    function isLocker(address) external view returns (bool);
    function stablecoinWhitelist(address) external view returns (bool);
    function defaults() external view returns (uint256);
    function maxTrancheRatioBPS() external view returns (uint256);
    function minZVEPerJTTMint() external view returns (uint256);
    function maxZVEPerJTTMint() external view returns (uint256);
    function lowerRatioIncentive() external view returns (uint256);
    function upperRatioIncentive() external view returns (uint256);
    function increaseDefaults(uint256) external;
    function decreaseDefaults(uint256) external;
}

interface IZivoeITO {
    function amountWithdrawableSeniorBurn(address asset) external returns (uint256 amt);
    function claim() external returns (uint256 _zJTT, uint256 _zSTT, uint256 _ZVE);
    function end() external view returns (uint256);
}

interface ICRVDeployer {
    function deploy_metapool(
        address _bp, 
        string calldata _name, 
        string calldata _symbol, 
        address _coin, 
        uint256 _A, 
        uint256 _fee
    ) external returns (address);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface ISushiFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV2Router01 {
     function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface ICRVMetaPool {
    function add_liquidity(uint256[2] memory amounts_in, uint256 min_mint_amount) external payable returns (uint256);
    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);
    function coins(uint256 i) external view returns (address);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function remove_liquidity(uint256 amount, uint256[2] memory min_amounts_out) external returns (uint256[2] memory);
    function remove_liquidity_one_coin(uint256 token_amount, int128 index, uint min_amount) external;
}

interface ICRVPlainPoolFBP {
    function add_liquidity(uint256[2] memory amounts_in, uint256 min_mint_amount) external returns (uint256);
    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);
    function coins(uint256 i) external view returns (address);
    function remove_liquidity(uint256 amount, uint256[2] memory min_amounts_out) external returns (uint256[2] memory);
    function remove_liquidity_one_coin(uint256 token_amount, int128 index, uint min_amount) external;
    function calc_token_amount(uint256[2] memory _amounts, bool _is_deposit) external view returns (uint256);
    function get_virtual_price() external view returns (uint256);
    function exchange(int128 indexTokenIn, int128 indexTokenOut, uint256 amountIn, uint256 minToReceive) external returns (uint256 amountReceived);
}

interface ICRVPlainPool3CRV {
    function add_liquidity(uint256[3] memory amounts_in, uint256 min_mint_amount) external;
    function coins(uint256 i) external view returns (address);
    function remove_liquidity(uint256 amount, uint256[3] memory min_amounts_out) external;
}

interface ICRV_PP_128_NP {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}


interface ICRV_MP_256 {
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns (uint256);
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
}

interface ISushiRouter {
     function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IERC104 {
    function pushToLocker(address asset, uint256 amount) external;
    function pullFromLocker(address asset) external;
    function pullFromLockerPartial(address asset, uint256 amount) external;
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) external;
    function pullFromLockerMulti(address[] calldata assets) external;
    function pullFromLockerMultiPartial(address[] calldata assets, uint256[] calldata amounts) external;
    function pushToLockerERC721(address asset, uint256 tokenId, bytes calldata data) external;
    function pullFromLockerERC721(address asset, uint256 tokenId, bytes calldata data) external;
    function pushToLockerERC1155(
        address asset, 
        uint256[] calldata ids, 
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
    function pullFromLockerERC1155(
        address asset, 
        uint256[] calldata ids, 
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
    function canPush() external view returns (bool);
    function canPull() external view returns (bool);
    function canPullPartial() external view returns (bool);
    function canPushMulti() external view returns (bool);
    function canPullMulti() external view returns (bool);
    function canPullMultiPartial() external view returns (bool);
    function canPushERC721() external view returns (bool);
    function canPullERC721() external view returns (bool);
    function canPushERC1155() external view returns (bool);
    function canPullERC1155() external view returns (bool);
}

interface IAggregationExecutor {
    function callBytes(address msgSender, bytes calldata data) external payable;  // 0x2636f7f8
}

struct SwapDescription {
    IERC20 srcToken;
    IERC20 dstToken;
    address payable srcReceiver;
    address payable dstReceiver;
    uint256 amount;
    uint256 minReturnAmount;
    uint256 flags;
    bytes permit;
}

interface IAggregationRouterV4 {
    function swap(IAggregationExecutor caller, SwapDescription memory desc, bytes calldata data) external payable;
}

interface ILendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
}

//Interface for the Convex Booster contract (main deposit contract)
interface ICVX_Booster {
    function deposit(uint256 _pid, uint256 _amount, bool _stake) external returns(bool);
    function withdraw(uint256 _pid, uint256 _amount) external returns(bool);
    function depositAll(uint256 _pid, bool _stake) external returns(bool);
   
}

//Convex BaseRewardPool to claim rewards
interface IConvexRewards {
    function getReward() external returns (bool);
    function withdrawAndUnwrap(uint256 _amount, bool _claim) external returns (bool);
    function withdrawAllAndUnwrap(bool _claim) external;
    function balanceOf(address _account) external view returns(uint256);
}

//Interface for providing liquidity in Angle's overcollateralization pools
interface IAngleStableMasterFront {
    function deposit(uint256 _amount, address _user, address _poolmanager) external;
    function withdraw(uint256 amount, address burner, address dest, address poolManager) external;
    function getCollateralRatio() external view returns (uint256 ratio);
}

//Interface for Angle Pool Manager contract
interface IAnglePoolManager {
    function getTotalAsset() external view returns (uint256);
}

//interface for StakeDAO vaults (to stake Angle LP token)
interface IStakeDAOVault {
    function deposit(address receiver, uint256 numTokens, bool chargeGas) external;
    function withdraw(uint256 shares) external;
    function withdrawAll() external;
}

//interface for StakeDAO Liquidity Gauge contract (keeps track of LP tokens and rewards)
interface IStakeDAOLiquidityGauge {
    function claim_rewards(address claimer, address receiver) external;
}

struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}

struct ExactInputParams {
    bytes path;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

interface IUniswapRouterV3 {
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
    function exactInput(
        ExactInputParams memory params
    ) external returns (uint256 amountOut);
}