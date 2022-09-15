// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IERC20 } from "../OpenZeppelin/IERC20.sol";
import { IERC20Metadata } from "../OpenZeppelin/IERC20Metadata.sol";

interface IERC20Mintable is IERC20, IERC20Metadata {
    function mint(address account, uint256 amount) external;
}

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) external;
    function approve(address to, uint256 tokenId) external;
}

interface IERC1155 {
    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
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
    function defaults() external view returns (uint256);
    function maxTrancheRatioBPS() external view returns (uint256);
    function minZVEPerJTTMint() external view returns (uint256);
    function maxZVEPerJTTMint() external view returns (uint256);
    function lowerRatioIncentive() external view returns (uint256);
    function upperRatioIncentive() external view returns (uint256);
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


// https://etherscan.io/address/0x8301ae4fc9c624d1d396cbdaa1ed877821d7c511#code (ETH/CRV)
// https://etherscan.io/address/0xDC24316b9AE028F1497c275EB9192a3Ea0f67022#code (ETH/stETH)
interface ICRVMetaPool {
    // i = token_from
    // j = token_to
    // dx = token_from_change
    // min_dy = token_to_min_receive
    function add_liquidity(uint256[2] memory amounts_in, uint256 min_mint_amount) external payable returns (uint256);
    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);
    function coins(uint256 i) external view returns (address);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function remove_liquidity(uint256 amount, uint256[2] memory min_amounts_out) external returns (uint256[2] memory);
    function remove_liquidity_one_coin(uint256 token_amount, int128 index, uint min_amount) external;
}

// https://etherscan.io/address/0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2#code (FRAX/USDC)
interface ICRVPlainPoolFBP {
    function add_liquidity(uint256[2] memory amounts_in, uint256 min_mint_amount) external returns (uint256);
    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);
    function coins(uint256 i) external view returns (address);
    function remove_liquidity(uint256 amount, uint256[2] memory min_amounts_out) external returns (uint256[2] memory);
    function remove_liquidity_one_coin(uint256 token_amount, int128 index, uint min_amount) external;
}

// https://etherscan.io/address/0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2#code (FRAX/USDC)
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
}

// https://etherscan.io/address/0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f#code
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

/// @title Interface for making arbitrary calls during swap
interface IAggregationExecutor {
    /// @notice Make calls on `msgSender` with specified data
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

/// @title Interface for making arbitrary calls during swap
interface IAggregationRouterV4 {
    function swap(IAggregationExecutor caller, SwapDescription memory desc, bytes calldata data) external payable;
}

interface ILendingPool {

    /**
    * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
    * - E.g. User deposits 100 USDC and gets in return 100 aUSDC
    * @param asset The address of the underlying asset to deposit
    * @param amount The amount to be deposited
    * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
    *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
    *   is a different wallet
    * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
    *   0 if the action is executed directly by the user, without any middle-man
    **/
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
  

    /**
    * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
    * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
    * @param asset The address of the underlying asset to withdraw
    * @param amount The underlying amount to be withdrawn
    *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
    * @param to Address that will receive the underlying, same as msg.sender if the user
    *   wants to receive it on his own wallet, or a different address if the beneficiary is a
    *   different wallet
    * @return The final amount withdrawn
    **/
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
}
