// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Context.sol";

import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { IERC20Metadata } from "./OpenZeppelin/IERC20Metadata.sol";
import { IZivoeGlobals, IERC20Mintable } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract will facilitate the Zivoe ITO ("Initial Tranche Offering").
///         This contract will be permissioned by JuniorTrancheToken, SeniorTrancheToken to call mint().
///         This contract will escrow 10% of $ZVE supply for ITO, claimable post-ITO.
///         This contract will support claiming $ZVE based on proportionate amount of liquidity provided during the ITO.
contract ZivoeITO is Context {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    uint256 public start;       /// @dev The unix when the ITO will commence.
    uint256 public end;         /// @dev The unix when the ITO will conclude (airdrop is claimable).
    
    address public immutable GBL;   /// @dev The ZivoeGlobals contract.

    mapping(address => bool) public stablecoinWhitelist;    /// @dev Whitelist for stablecoins accepted as deposit.

    mapping(address => uint256) public juniorCredits;       /// @dev Tracks amount of credits and individual has for juniorDeposit().
    mapping(address => uint256) public seniorCredits;       /// @dev Tracks amount of credits and individual has for seniorDeposit().



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeITO.sol contract.
    /// @param _start   The unix when the ITO will commence.
    /// @param _end     The unix when the ITO will conclude (airdrop is claimable).
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
    /// @param  trancheTokens The amount of JuniorTrancheToken ($zJTT) minted.
    event JuniorDeposit(address indexed account, address asset, uint256 amount, uint256 credits, uint256 trancheTokens);

    /// @notice Emitted during depositSenior().
    /// @param  account The account depositing stablecoins to senior tranche.
    /// @param  asset The stablecoin deposited.
    /// @param  amount The amount of stablecoins deposited.
    /// @param  credits The amount of credits earned.
    /// @param  trancheTokens The amount of SeniorTrancheToken ($zSTT) minted.
    event SeniorDeposit(address indexed account, address asset, uint256 amount, uint256 credits, uint256 trancheTokens);

    /// @notice Emitted during claim().
    /// @param  account The account withdrawing stablecoins from senior tranche.
    /// @param  zSTTClaimed The amount of SeniorTrancheToken ($zSTT) received.
    /// @param  zJTTClaimed The amount of JuniorTrancheToken ($zJTT) received.
    /// @param  ZVEClaimed The amount of ZivoeToken ($ZVE) received.
    event TokensClaimed(address indexed account, uint256 zSTTClaimed, uint256 zJTTClaimed, uint256 ZVEClaimed);

    // TODO: Consider event logs here for migrate() (?).


    // ---------------
    //    Functions
    // ---------------

    // TODO: Update NatSpec
    /// @notice Claim $ZVE and TrancheTokens after ITO concludes.
    /// @dev    Only callable when block.timestamp > _concludeUnix.
    function claim() external returns (uint256 _zSTT, uint256 _zJTT, uint256 _ZVE) {
        require(block.timestamp > end, "ZivoeITO::claim() block.timestamp <= end");

        address caller = _msgSender();

        require(seniorCredits[caller] > 0 || juniorCredits[caller] > 0, "ZivoeITO::claim() seniorCredits[caller] == 0 && juniorCredits[caller] == 0");

        uint256 seniorCreditsOwned = seniorCredits[caller];
        uint256 juniorCreditsOwned = juniorCredits[caller];

        seniorCredits[caller] = 0;
        juniorCredits[caller] = 0;

        uint256 upper = seniorCreditsOwned + juniorCreditsOwned;
        uint256 middle = IERC20(IZivoeGlobals(GBL).ZVE()).totalSupply() / 10;
        uint256 lower = IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply() * 3 + IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply();

        emit TokensClaimed(caller, seniorCreditsOwned / 3, juniorCreditsOwned, upper * middle / lower);

        IERC20(IZivoeGlobals(GBL).zJTT()).safeTransfer(caller, juniorCreditsOwned);
        IERC20(IZivoeGlobals(GBL).zSTT()).safeTransfer(caller, seniorCreditsOwned / 3);
        IERC20(IZivoeGlobals(GBL).ZVE()).safeTransfer(caller, upper * middle / lower);

        return (
            seniorCreditsOwned / 3,
            juniorCreditsOwned,
            upper * middle / lower
        );
    }

    /// @notice Deposit stablecoins into the junior tranche.
    ///         Mints JuniorTrancheToken ($zJTT) and increases airdrop credits.
    /// @dev    Truncate the input amount.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset to deposit.
    function depositJunior(uint256 amount, address asset) external {
        require(block.timestamp >= start, "ZivoeITO::depositJunior() block.timestamp < start");
        require(block.timestamp < end, "ZivoeITO::depositJunior() block.timestamp >= end");
        require(stablecoinWhitelist[asset], "ZivoeITO::depositJunior() !stablecoinWhitelist[asset]");

        address caller = _msgSender();
        
        uint256 convertedAmount = amount;

        if (IERC20Metadata(asset).decimals() != 18) {
            convertedAmount *= 10 ** (18 - IERC20Metadata(asset).decimals());
        }

        juniorCredits[caller] += convertedAmount;

        emit JuniorDeposit(caller, asset, amount, convertedAmount, amount);

        IERC20(asset).safeTransferFrom(caller, address(this), amount);
        IERC20Mintable(IZivoeGlobals(GBL).zJTT()).mint(address(this), convertedAmount);
    }

    /// @notice Deposit stablecoins into the senior tranche.
    ///         Mints SeniorTrancheToken ($zSTT) and increases airdrop credits.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset to deposit.
    function depositSenior(uint256 amount, address asset) external {
        require(block.timestamp >= start, "ZivoeITO::depositSenior() block.timestamp < start");
        require(block.timestamp < end, "ZivoeITO::depositSenior() block.timestamp >= end");
        require(stablecoinWhitelist[asset], "ZivoeITO::depositSenior() !stablecoinWhitelist[asset]");
        address caller = _msgSender();

        uint256 convertedAmount = amount;

        if (IERC20Mintable(asset).decimals() != 18) {
            convertedAmount *= 10 ** (18 - IERC20Mintable(asset).decimals());
        }

        seniorCredits[caller] += convertedAmount * 3;

        emit SeniorDeposit(caller, asset, amount, convertedAmount * 3, amount);

        IERC20(asset).safeTransferFrom(caller, address(this), amount);
        IERC20Mintable(IZivoeGlobals(GBL).zSTT()).mint(address(this), convertedAmount);
    }

    /// @notice Migrate tokens to DAO post-ITO.
    /// @dev    Only callable when block.timestamp > _concludeUnix.
    function migrateDeposits() external {
        require(block.timestamp > end, "ZivoeITO::claim() block.timestamp <= end");

        IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).safeTransfer(
            IZivoeGlobals(GBL).DAO(),
            IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).balanceOf(address(this))     // DAI
        );
        IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).safeTransfer(
            IZivoeGlobals(GBL).DAO(),
            IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(address(this))     // FRAX
        );
        IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e).safeTransfer(
            IZivoeGlobals(GBL).DAO(),
            IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e).balanceOf(address(this))     // USDC
        );
        IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).safeTransfer(
            IZivoeGlobals(GBL).DAO(),
            IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).balanceOf(address(this))     // USDT
        );
    }

}
