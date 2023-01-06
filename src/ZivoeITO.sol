// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../lib/openzeppelin-contracts/contracts/utils/Context.sol";

interface IERC20Mintable_ITO {
    /// @notice Creates ERC20 tokens and assigns them to an address, increasing the total supply.
    /// @param account The address to send the newly created tokens to.
    /// @param amount The amount of tokens to create and send.
    function mint(address account, uint256 amount) external;
}

interface IZivoeGlobals_ITO {
    /// @notice Returns the address of the ZivoeDAO contract.
    function DAO() external view returns (address);

    /// @notice Returns the address of the ZivoeYDL contract.
    function YDL() external view returns (address);

    /// @notice Returns the address of the ZivoeTrancheToken.sol ($zJTT) contract.
    function zJTT() external view returns (address);

    /// @notice Returns the address of the ZivoeTrancheToken.sol ($zSTT) contract.
    function zSTT() external view returns (address);

    /// @notice Returns the address of the ZivoeToken.sol contract.
    function ZVE() external view returns (address);

    /// @notice Returns the Zivoe Laboratory address.
    function ZVL() external view returns (address);

    /// @notice Returns the address of the ZivoeTranches.sol contract.
    function ZVT() external view returns (address);

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param amount The amount of a given "asset".
    /// @param asset The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount The above amount standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);
}

interface IZivoeTranches_ITO {
    /// @notice Unlocks the ZivoeTranches.sol contract for distributions, sets some initial variables.
    function unlock() external;
}

interface IZivoeYDL_ITO {
    /// @notice Unlocks the ZivoeYDL contract for distributions, initializes values.
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

    uint256 public targetAmount;            /// @dev The target amount of the ITO (in wei, standardized).
    uint256 public raisedAmount;            /// @dev The tarraisedget amount of the ITO (in wei, standardized).
    uint256 public operationAllocation;     /// @dev The amount (in BIPS) of ITO proceeds allocated for operations.
    
    address public immutable GBL;   /// @dev The ZivoeGlobals contract.

    bool public migrated;       /// @dev Identifies if ITO has migrated assets to the DAO.

    mapping(address => bool) public stablecoinWhitelist;   /// @dev Whitelist for stablecoins accepted as deposit.
    mapping(address => bool) public airdropClaimed;        /// @dev Whether the airdrop has been claimed or not.

    mapping(address => uint256) public juniorCredits;       /// @dev Tracks amount of credits and individual has for juniorDeposit().
    mapping(address => uint256) public seniorCredits;       /// @dev Tracks amount of credits and individual has for seniorDeposit().


    uint256 private constant BIPS = 10000;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeITO.sol contract.
    /// @param _start The unix when the ITO will start.
    /// @param _end The unix when the ITO will end (airdrop is claimable).
    /// @param _GBL The ZivoeGlobals contract.
    /// @param _targetAmount The target amount of the ITO (in wei, standardized).
    /// @param _operationAllocation The amount (in BIPS) of ITO proceeds allocated for operations.
    constructor (
        uint256 _start,
        uint256 _end,
        address _GBL,
        uint256 _targetAmount,
        uint256 _operationAllocation
    ) {

        require(_start < _end, "ZivoeITO::constructor() _start >= _end");

        start = _start;
        end = _end;
        GBL = _GBL;
        targetAmount = _targetAmount;
        operationAllocation = _operationAllocation;

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
    /// @param  DAI Total amount of DAI migrated from the ITO to the DAO and ZVL.
    /// @param  FRAX Total amount of FRAX migrated from the ITO to the DAO and ZVL.
    /// @param  USDC Total amount of USDC migrated from the ITO to the DAO and ZVL.
    /// @param  USDT Total amount of USDT migrated from the ITO to the DAO and ZVL.
    event DepositsMigrated(uint256 DAI, uint256 FRAX, uint256 USDC, uint256 USDT);



    // ---------------
    //    Functions
    // ---------------

    /// @notice Claim $zSTT, $zJTT, and $ZVE after ITO concludes.
    /// @return zSTTClaimed Amount of $zSTT airdropped.
    /// @return zJTTClaimed Amount of $zJTT airdropped.
    /// @return ZVEClaimed Amount of $ZVE airdropped.
    function claim() external returns (uint256 zSTTClaimed, uint256 zJTTClaimed, uint256 ZVEClaimed) {

        // TODO: Update require statement here
        require(block.timestamp > end, "ZivoeITO::claim() block.timestamp <= end");

        address caller = _msgSender();

        require(!airdropClaimed[caller], "ZivoeITO::claim() airdropClaimeded[caller]");
        require(seniorCredits[caller] > 0 || juniorCredits[caller] > 0, "ZivoeITO::claim() seniorCredits[caller] == 0 && juniorCredits[caller] == 0");

        airdropClaimed[caller] = true;

        // Temporarily store credit values, decrease them to 0 immediately after.
        uint256 seniorCreditsOwned = seniorCredits[caller];
        uint256 juniorCreditsOwned = juniorCredits[caller];

        seniorCredits[caller] = 0;
        juniorCredits[caller] = 0;

        // Calculate proportion of $ZVE awarded based on $pZVE credits.
        uint256 upper = seniorCreditsOwned + juniorCreditsOwned;
        uint256 middle = IERC20(IZivoeGlobals_ITO(GBL).ZVE()).totalSupply() / 10;
        uint256 lower = IERC20(IZivoeGlobals_ITO(GBL).zSTT()).totalSupply() * 3 + IERC20(IZivoeGlobals_ITO(GBL).zJTT()).totalSupply();

        emit AirdropClaimed(caller, seniorCreditsOwned / 3, juniorCreditsOwned, upper * middle / lower);

        IERC20(IZivoeGlobals_ITO(GBL).zJTT()).safeTransfer(caller, juniorCreditsOwned);
        IERC20(IZivoeGlobals_ITO(GBL).zSTT()).safeTransfer(caller, seniorCreditsOwned / 3);
        IERC20(IZivoeGlobals_ITO(GBL).ZVE()).safeTransfer(caller, upper * middle / lower);

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
        
        uint256 standardizedAmount = IZivoeGlobals_ITO(GBL).standardize(amount, asset);

        juniorCredits[caller] += standardizedAmount;
        raisedAmount += standardizedAmount;

        emit JuniorDeposit(caller, asset, amount, standardizedAmount, standardizedAmount);

        IERC20(asset).safeTransferFrom(caller, address(this), amount);
        IERC20Mintable_ITO(IZivoeGlobals_ITO(GBL).zJTT()).mint(address(this), standardizedAmount);
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

        uint256 standardizedAmount = IZivoeGlobals_ITO(GBL).standardize(amount, asset);

        seniorCredits[caller] += standardizedAmount * 3;
        raisedAmount += standardizedAmount;

        emit SeniorDeposit(caller, asset, amount, standardizedAmount * 3, standardizedAmount);

        IERC20(asset).safeTransferFrom(caller, address(this), amount);
        IERC20Mintable_ITO(IZivoeGlobals_ITO(GBL).zSTT()).mint(address(this), standardizedAmount);
    }

    /// @notice Migrate tokens to DAO post-ITO.
    /// @dev    Only callable when block.timestamp > _concludeUnix.
    function migrateDeposits() external {
        if (_msgSender() == IZivoeGlobals_ITO(GBL).ZVL()) {
            require(
                raisedAmount >= targetAmount, 
                "ZivoeITO::migrateDeposits() raisedAmount < targetAmount"
            );
        }
        else {
            require(
                block.timestamp > end,  
                "ZivoeITO::migrateDeposits() block.timestamp <= end"
            );
        }
        require(!migrated, "ZivoeITO::migrateDeposits() migrated");
        
        migrated = true;

        emit DepositsMigrated(
            IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).balanceOf(address(this)),
            IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e).balanceOf(address(this)),
            IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(address(this)),
            IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).balanceOf(address(this))
        );
    
        IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).safeTransfer(
            IZivoeGlobals_ITO(GBL).ZVL(),
            IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).balanceOf(address(this)) * operationAllocation / BIPS // DAI
        );
        IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e).safeTransfer(
            IZivoeGlobals_ITO(GBL).ZVL(),
            IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e).balanceOf(address(this)) * operationAllocation / BIPS // FRAX
        );
        IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).safeTransfer(
            IZivoeGlobals_ITO(GBL).ZVL(),
            IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(address(this)) * operationAllocation / BIPS // USDC
        );
        IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).safeTransfer(
            IZivoeGlobals_ITO(GBL).ZVL(),
            IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).balanceOf(address(this)) * operationAllocation / BIPS // USDT
        );
    
        IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).safeTransfer(
            IZivoeGlobals_ITO(GBL).DAO(),
            IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F).balanceOf(address(this))     // DAI
        );
        IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e).safeTransfer(
            IZivoeGlobals_ITO(GBL).DAO(),
            IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e).balanceOf(address(this))     // FRAX
        );
        IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).safeTransfer(
            IZivoeGlobals_ITO(GBL).DAO(),
            IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).balanceOf(address(this))     // USDC
        );
        IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).safeTransfer(
            IZivoeGlobals_ITO(GBL).DAO(),
            IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).balanceOf(address(this))     // USDT
        );

        IZivoeYDL_ITO(IZivoeGlobals_ITO(GBL).YDL()).unlock();
        IZivoeTranches_ITO(IZivoeGlobals_ITO(GBL).ZVT()).unlock();
    }

}
