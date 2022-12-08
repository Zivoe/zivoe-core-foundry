// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../lib/OpenZeppelin/Context.sol";
import "../lib/OpenZeppelin/IERC20.sol";
import "../lib/OpenZeppelin/IERC20Metadata.sol";
import "../lib/OpenZeppelin/SafeERC20.sol";

interface IERC20Mintable_P_0 {
    function mint(address account, uint256 amount) external;
}

interface IZivoeGlobals_P_0 {
    function DAO() external view returns (address);
    function YDL() external view returns (address);
    function zJTT() external view returns (address);
    function zSTT() external view returns (address);
    function ZVE() external view returns (address);
    function ZVT() external view returns (address);
    function standardize(uint256, address) external view returns (uint256);
}

interface IZivoeTranches_P_0 {
    function unlock() external;
}

interface IZivoeYDL_P_0 {
    function unlock() external;
}

/// @notice This contract will facilitate the Zivoe ITO ("Initial Tranche Offering").
///         This contract will be permissioned by $zJTT and $zSTT to call mint().
///         This contract will escrow 10% of $ZVE supply for ITO, claimable post-ITO.
///         This contract will support claiming $ZVE based on proportionate amount of liquidity provided during the ITO.
contract ZivoeITO is Context {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    uint256 public start;       /// @dev The unix when the ITO will start.
    uint256 public end;         /// @dev The unix when the ITO will end (airdrop is claimable).
    
    address public immutable GBL;   /// @dev The ZivoeGlobals contract.

    bool public migrated;       /// @dev Identifies if ITO has migrated assets to the DAO.

    mapping(address => bool) public stablecoinWhitelist;   /// @dev Whitelist for stablecoins accepted as deposit.
    mapping(address => bool) public airdropClaimed;        /// @dev Whether the airdrop has been claimed or not.

    mapping(address => uint256) public juniorCredits;       /// @dev Tracks amount of credits and individual has for juniorDeposit().
    mapping(address => uint256) public seniorCredits;       /// @dev Tracks amount of credits and individual has for seniorDeposit().



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeITO.sol contract.
    /// @param _start   The unix when the ITO will start.
    /// @param _end     The unix when the ITO will end (airdrop is claimable).
    /// @param _GBL     The ZivoeGlobals contract.
    constructor (
        uint256 _start,
        uint256 _end,
        address _GBL
    ) {

        require(_start < _end, "ZivoeITO::constructor() _start >= _end");

        start = _start;
        end = _end;
        GBL = _GBL;

        stablecoinWhitelist[0x6B175474E89094C44Da98b954EedeAC495271d0F] = true; // DAI
        stablecoinWhitelist[0x853d955aCEf822Db058eb8505911ED77F175b99e] = true; // FRAX
        stablecoinWhitelist[0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48] = true; // USDC
        stablecoinWhitelist[0xdAC17F958D2ee523a2206206994597C13D831ec7] = true; // USDT

    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during depositJunior().
    /// @param  account The account depositing stablecoins to junior tranche.
    /// @param  asset The stablecoin deposited.
    /// @param  amount The amount of stablecoins deposited.
    /// @param  credits The amount of credits earned.
    /// @param  trancheTokens The amount of Zivoe Junior Tranche ($zJTT) tokens minted.
    event JuniorDeposit(address indexed account, address indexed asset, uint256 amount, uint256 credits, uint256 trancheTokens);

    /// @notice Emitted during depositSenior().
    /// @param  account The account depositing stablecoins to senior tranche.
    /// @param  asset The stablecoin deposited.
    /// @param  amount The amount of stablecoins deposited.
    /// @param  credits The amount of credits earned.
    /// @param  trancheTokens The amount of Zivoe Senior Tranche ($zSTT) tokens minted.
    event SeniorDeposit(address indexed account, address indexed asset, uint256 amount, uint256 credits, uint256 trancheTokens);

    /// @notice Emitted during claim().
    /// @param  account The account withdrawing stablecoins from senior tranche.
    /// @param  zSTTClaimed The amount of Zivoe Senior Tranche ($zSTT) tokens received.
    /// @param  zJTTClaimed The amount of Zivoe Junior Tranche ($zJTT) tokens received.
    /// @param  ZVEClaimed The amount of Zivoe ($ZVE) tokens received.
    event AirdropClaimed(address indexed account, uint256 zSTTClaimed, uint256 zJTTClaimed, uint256 ZVEClaimed);

    /// @notice Emitted during migrateDeposits().
    /// @param  DAI The amount of DAI migrated to DAO.
    /// @param  FRAX The amount of FRAX migrated to DAO.
    /// @param  USDC The amount of USDC migrated to DAO.
    /// @param  USDT The amount of USDT migrated to DAO.
    event DepositsMigrated(uint256 DAI, uint256 FRAX, uint256 USDC, uint256 USDT);



    // ---------------
    //    Functions
    // ---------------

    /// @notice Claim $zSTT, $zJTT, and $ZVE after ITO concludes.
    /// @return zSTTClaimed Amount of $zSTT airdropped.
    /// @return zJTTClaimed Amount of $zJTT airdropped.
    /// @return ZVEClaimed Amount of $ZVE airdropped.
    function claim() external returns (uint256 zSTTClaimed, uint256 zJTTClaimed, uint256 ZVEClaimed) {
        require(block.timestamp > end, "ZivoeITO::claim() block.timestamp <= end");

        address caller = _msgSender();

        require(!airdropClaimed[caller], "ZivoeITO::claim() airdropClaimeded[caller]");
        require(seniorCredits[caller] > 0 || juniorCredits[caller] > 0, "ZivoeITO::claim() seniorCredits[caller] == 0 && juniorCredits[caller] == 0");

        airdropClaimed[caller] = true;

        uint256 seniorCreditsOwned = seniorCredits[caller];
        uint256 juniorCreditsOwned = juniorCredits[caller];

        seniorCredits[caller] = 0;
        juniorCredits[caller] = 0;

        uint256 upper = seniorCreditsOwned + juniorCreditsOwned;
        uint256 middle = IERC20(IZivoeGlobals_P_0(GBL).ZVE()).totalSupply() / 10;
        uint256 lower = IERC20(IZivoeGlobals_P_0(GBL).zSTT()).totalSupply() * 3 + IERC20(IZivoeGlobals_P_0(GBL).zJTT()).totalSupply();

        emit AirdropClaimed(caller, seniorCreditsOwned / 3, juniorCreditsOwned, upper * middle / lower);

        IERC20(IZivoeGlobals_P_0(GBL).zJTT()).safeTransfer(caller, juniorCreditsOwned);
        IERC20(IZivoeGlobals_P_0(GBL).zSTT()).safeTransfer(caller, seniorCreditsOwned / 3);
        IERC20(IZivoeGlobals_P_0(GBL).ZVE()).safeTransfer(caller, upper * middle / lower);

        return (
            seniorCreditsOwned / 3,
            juniorCreditsOwned,
            upper * middle / lower
        );
    }

    /// @notice Deposit stablecoins into the junior tranche.
    ///         Mints Zivoe Junior Tranche ($zJTT) tokens and increases airdrop credits.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset to deposit.
    function depositJunior(uint256 amount, address asset) external {
        require(block.timestamp >= start, "ZivoeITO::depositJunior() block.timestamp < start");
        require(block.timestamp < end, "ZivoeITO::depositJunior() block.timestamp >= end");
        require(stablecoinWhitelist[asset], "ZivoeITO::depositJunior() !stablecoinWhitelist[asset]");

        address caller = _msgSender();
        
        uint256 standardizedAmount = IZivoeGlobals_P_0(GBL).standardize(amount, asset);

        juniorCredits[caller] += standardizedAmount;

        emit JuniorDeposit(caller, asset, amount, standardizedAmount, amount);

        IERC20(asset).safeTransferFrom(caller, address(this), amount);
        IERC20Mintable_P_0(IZivoeGlobals_P_0(GBL).zJTT()).mint(address(this), standardizedAmount);
    }

    /// @notice Deposit stablecoins into the senior tranche.
    ///         Mints Zivoe Senior Tranche ($zSTT) tokens and increases airdrop credits.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset to deposit.
    function depositSenior(uint256 amount, address asset) external {
        require(block.timestamp >= start, "ZivoeITO::depositSenior() block.timestamp < start");
        require(block.timestamp < end, "ZivoeITO::depositSenior() block.timestamp >= end");
        require(stablecoinWhitelist[asset], "ZivoeITO::depositSenior() !stablecoinWhitelist[asset]");

        address caller = _msgSender();

        uint256 standardizedAmount = IZivoeGlobals_P_0(GBL).standardize(amount, asset);

        seniorCredits[caller] += standardizedAmount * 3;

        emit SeniorDeposit(caller, asset, amount, standardizedAmount * 3, amount);

        IERC20(asset).safeTransferFrom(caller, address(this), amount);
        IERC20Mintable_P_0(IZivoeGlobals_P_0(GBL).zSTT()).mint(address(this), standardizedAmount);
    }

    /// @notice Migrate tokens to DAO post-ITO.
    /// @dev    Only callable when block.timestamp > _concludeUnix.
    function migrateDeposits() external {
        require(block.timestamp > end, "ZivoeITO::migrateDeposits() block.timestamp <= end");
        require(!migrated, "ZivoeITO::migrateDeposits() migrated");
        
        migrated = true;

        emit DepositsMigrated(
            IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).balanceOf(address(this)),
            IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e).balanceOf(address(this)),
            IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(address(this)),
            IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).balanceOf(address(this))
        );
    
        IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).safeTransfer(
            IZivoeGlobals_P_0(GBL).DAO(),
            IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).balanceOf(address(this))     // DAI
        );
        IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e).safeTransfer(
            IZivoeGlobals_P_0(GBL).DAO(),
            IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e).balanceOf(address(this))     // FRAX
        );
        IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).safeTransfer(
            IZivoeGlobals_P_0(GBL).DAO(),
            IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(address(this))     // USDC
        );
        IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).safeTransfer(
            IZivoeGlobals_P_0(GBL).DAO(),
            IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).balanceOf(address(this))     // USDT
        );

        IZivoeYDL_P_0(IZivoeGlobals_P_0(GBL).YDL()).unlock();
        IZivoeTranches_P_0(IZivoeGlobals_P_0(GBL).ZVT()).unlock();
    }

}
