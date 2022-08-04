// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function transfer(address recipient, uint256 amount) external;
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external;
    function mint(address account, uint256 amount) external;
    function burn(uint256 amount) external;
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
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

interface CRVMultiAssetRewards {
    function notifyRewardAmount(address _rewardsToken, uint256 reward) external;
}

interface IZivoeYDL {
    function forwardAssets() external;
    function passThrough(address asset, uint256 amount, address location) external;
}

interface IZivoeAMP {
    function increaseAmplification(address account, uint256 amount) external;
    function decreaseAmplification(address account, uint256 amount) external;
}

interface IWETH {
    function deposit() external payable;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function withdraw(uint256) external;
}

interface IZivoeITO {
    function amountWithdrawableSeniorBurn(address asset) external returns(uint256 amt);
    function claim() external returns(uint256 _zJTT, uint256 _zSTT, uint256 _ZVE);
}

interface IERC104 {
    function pushToLocker(address asset, uint256 amount) external;
    function pullFromLocker(address asset) external;
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
    function canPush() external view returns(bool);
    function canPull() external view returns(bool);
    function canPushERC721() external view returns(bool);
    function canPullERC721() external view returns(bool);
    function canPushERC1155() external view returns(bool);
    function canPullERC1155() external view returns(bool);
}

// Curve.fi: DAI/USDC/USDT Pool
// https://etherscan.io/address/0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7#code
interface ICRV_PP_128_NP {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface ICRV_PP_256_NP {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy, bool use_eth) external;
}

interface ICRV_PP_256_P {
    function exchange_underlying(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable returns(uint256);
}

// Frax Finance: FRAX3CRV-f Token
// https://etherscan.io/address/0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B#code
interface ICRV_MP_256 {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns(uint256);
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns(uint256);
}

// AAVE v2 LendingPool Interface
// Docs:   https://docs.aave.com/developers/v/2.0/the-core-protocol/lendingpool
// Source: https://github.com/aave/protocol-v2/blob/master/contracts/interfaces/ILendingPool.sol

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