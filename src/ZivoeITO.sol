// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Context.sol";

interface ITO_IERC20Mintable {
    /// @notice Mints ERC20 token(s) for the provided account, increases totalSupply().
    /// @param  account The address to mint tokens for.
    /// @param  amount  The amount of tokens to mint.
    function mint(address account, uint256 amount) external;
}

interface ITO_IZivoeGlobals {
    /// @notice Returns the address of the ZivoeDAO contract.
    function DAO() external view returns (address);

    /// @notice Returns the address of the ZivoeRewardsVesting ($ZVE) vesting contract.
    function vestZVE() external view returns (address);

    /// @notice Returns the address of the ZivoeYDL contract.
    function YDL() external view returns (address);

    /// @notice Returns the address of the ZivoeTrancheToken ($zJTT) contract.
    function zJTT() external view returns (address);

    /// @notice Returns the address of the ZivoeTrancheToken ($zSTT) contract.
    function zSTT() external view returns (address);

    /// @notice Returns the address of the ZivoeToken contract.
    function ZVE() external view returns (address);

    /// @notice Returns the Zivoe Laboratory address.
    function ZVL() external view returns (address);

    /// @notice Returns the address of the ZivoeTranches contract.
    function ZVT() external view returns (address);

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  amount              The amount of a given "asset" to be standardized.
    /// @param  asset               The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount  The input amount, standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);
}

interface ITO_IZivoeRewardsVesting {
    /// @notice Sets the vestingSchedule for an account.
    /// @param  account         The account vesting $ZVE.
    /// @param  daysToCliff     The number of days before vesting is claimable (a.k.a. cliff period).
    /// @param  daysToVest      The number of days for the entire vesting period, from beginning to end.
    /// @param  amountToVest    The amount of tokens being vested.
    /// @param  revokable       If the vested amount can be revoked.
    function vest(address account, uint256 daysToCliff, uint256 daysToVest, uint256 amountToVest, bool revokable) external;
}

interface ITO_IZivoeTranches {
    /// @notice Unlocks the ZivoeTranches contract for distributions, sets initial variables.
    function unlock() external;
}

interface ITO_IZivoeYDL {
    /// @notice Unlocks the ZivoeYDL contract for distributions, initializes values.
    function unlock() external;
}

/// @notice This contract will facilitate the Zivoe ITO ("Initial Tranche Offering").
///         This contract has the following responsibilities:
///          - Permissioned by $zJTT and $zSTT to call mint() when a user deposits.
///          - Escrow $zJTT and $zSTT until the ITO concludes.
///          - Facilitate claiming of $zJTT and $zSTT when the ITO concludes.
///          - Vest $ZVE simulatenously during claiming (based on $pZVE credits).
///          - Migrate deposits to ZivoeDAO after the ITO concludes.
///          - Migrate a portion of deposits to ZVL after the ITO concludes.
contract ZivoeITO is Context {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    uint256 public start;           /// @dev The unix when the ITO will start.
    uint256 public end;             /// @dev The unix when the ITO will end (airdrop is claimable).
    
    address public immutable GBL;   /// @dev The ZivoeGlobals contract.

    address[] public stables;       /// @dev Stablecoin(s) allowed for juniorDeposit() or seniorDeposit().

    bool public migrated;           /// @dev Triggers (true) when ITO concludes and assets migrate to ZivoeDAO.

    mapping(address => bool) public airdropClaimed;         /// @dev Tracks if an account has claimed their airdrop.

    mapping(address => uint256) public juniorCredits;       /// @dev Tracks $pZVE (credits) an individual has from juniorDeposit().
    mapping(address => uint256) public seniorCredits;       /// @dev Tracks $pZVE (credits) an individual has from seniorDeposit().

    uint256 private constant operationAllocation = 1000;    /// @dev The amount (in BIPS) of ITO proceeds allocated for operations.

    uint256 private constant BIPS = 10000;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeITO contract.
    /// @param _start   The unix when the ITO will start.
    /// @param _end     The unix when the ITO will end (airdrop is claimable).
    /// @param _GBL     The ZivoeGlobals contract.
    /// @param _stables Array of stablecoins representing initial stablecoin inputs.
    constructor (uint256 _start, uint256 _end, address _GBL, address[] memory _stables) {
        require(_start < _end, "ZivoeITO::constructor() _start >= _end");
        start = _start;
        end = _end;
        GBL = _GBL;
        stables = _stables;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during depositJunior().
    /// @param  account         The account depositing stablecoins to junior tranche.
    /// @param  asset           The stablecoin deposited.
    /// @param  amount          The amount of stablecoins deposited.
    /// @param  credits         The amount of credits earned.
    /// @param  trancheTokens   The amount of Zivoe Junior Tranche ($zJTT) tokens minted.
    event JuniorDeposit(address indexed account, address indexed asset, uint256 amount, uint256 credits, uint256 trancheTokens);

    /// @notice Emitted during depositSenior().
    /// @param  account         The account depositing stablecoins to senior tranche.
    /// @param  asset           The stablecoin deposited.
    /// @param  amount          The amount of stablecoins deposited.
    /// @param  credits         The amount of credits earned.
    /// @param  trancheTokens   The amount of Zivoe Senior Tranche ($zSTT) tokens minted.
    event SeniorDeposit(address indexed account, address indexed asset, uint256 amount, uint256 credits, uint256 trancheTokens);

    /// @notice Emitted during claim().
    /// @param  account     The account withdrawing stablecoins from senior tranche.
    /// @param  zSTTClaimed The amount of Zivoe Senior Tranche ($zSTT) tokens received.
    /// @param  zJTTClaimed The amount of Zivoe Junior Tranche ($zJTT) tokens received.
    /// @param  ZVEClaimed  The amount of Zivoe ($ZVE) tokens received.
    event AirdropClaimed(address indexed account, uint256 zSTTClaimed, uint256 zJTTClaimed, uint256 ZVEClaimed);

    /// @notice Emitted during migrateDeposits().
    /// @param  DAI     Total amount of DAI migrated from the ITO to ZivoeDAO and ZVL.
    /// @param  FRAX    Total amount of FRAX migrated from the ITO to ZivoeDAO and ZVL.
    /// @param  USDC    Total amount of USDC migrated from the ITO to ZivoeDAO and ZVL.
    /// @param  USDT    Total amount of USDT migrated from the ITO to ZivoeDAO and ZVL.
    event DepositsMigrated(uint256 DAI, uint256 FRAX, uint256 USDC, uint256 USDT);



    // ---------------
    //    Functions
    // ---------------

    /// @notice Claim $zSTT, $zJTT, and begin a vesting schedule for $ZVE.
    /// @dev    This function MUST only be callable after the ITO concludes.
    /// @return zSTTClaimed Amount of $zSTT airdropped.
    /// @return zJTTClaimed Amount of $zJTT airdropped.
    /// @return ZVEClaimed  Amount of $ZVE airdropped.
    function claim() external returns (uint256 zSTTClaimed, uint256 zJTTClaimed, uint256 ZVEClaimed) {
        require(block.timestamp > end || migrated, "ZivoeITO::claim() block.timestamp <= end && !migrated");

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
        uint256 middle = IERC20(ITO_IZivoeGlobals(GBL).ZVE()).totalSupply() / 10;
        uint256 lower = IERC20(ITO_IZivoeGlobals(GBL).zSTT()).totalSupply() * 3 + IERC20(ITO_IZivoeGlobals(GBL).zJTT()).totalSupply();

        emit AirdropClaimed(caller, seniorCreditsOwned / 3, juniorCreditsOwned, upper * middle / lower);

        IERC20(ITO_IZivoeGlobals(GBL).zJTT()).safeTransfer(caller, juniorCreditsOwned);
        IERC20(ITO_IZivoeGlobals(GBL).zSTT()).safeTransfer(caller, seniorCreditsOwned / 3);

        // IERC20(ITO_IZivoeGlobals(GBL).ZVE()).safeTransfer(caller, upper * middle / lower);
        if (upper * middle / lower > 0) {
            ITO_IZivoeRewardsVesting(ITO_IZivoeGlobals(GBL).vestZVE()).vest(caller, 90, 360, upper * middle / lower, false);
        }
        
        return ( seniorCreditsOwned / 3, juniorCreditsOwned, upper * middle / lower);
    }

    /// @notice Deposit stablecoins into the junior tranche. Mints Zivoe Junior Tranche ($zJTT) tokens and increases airdrop credits.
    /// @dev    This function MUST only be callable during the ITO, and with accepted stablecoins.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset to deposit.
    function depositJunior(uint256 amount, address asset) external { 
        require(block.timestamp >= start, "ZivoeITO::depositJunior() block.timestamp < start");
        require(block.timestamp < end, "ZivoeITO::depositJunior() block.timestamp >= end");
        require(!migrated, "ZivoeITO::depositJunior() migrated");
        require(
            asset == stables[0] || asset == stables[1] || asset == stables[2] || asset == stables[3],
            "ZivoeITO::depositJunior() asset != stables[0] && asset != stables[1] && asset != stables[2] && asset != stables[3]"
        );

        address caller = _msgSender();
        
        uint256 standardizedAmount = ITO_IZivoeGlobals(GBL).standardize(amount, asset);

        juniorCredits[caller] += standardizedAmount;

        emit JuniorDeposit(caller, asset, amount, standardizedAmount, standardizedAmount);

        IERC20(asset).safeTransferFrom(caller, address(this), amount);
        ITO_IERC20Mintable(ITO_IZivoeGlobals(GBL).zJTT()).mint(address(this), standardizedAmount);
    }

    /// @notice Deposit stablecoins into the senior tranche. Mints Zivoe Senior Tranche ($zSTT) tokens and increases airdrop credits.
    /// @dev    This function MUST only be callable during the ITO, and with accepted stablecoins.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset to deposit.
    function depositSenior(uint256 amount, address asset) external {
        require(block.timestamp >= start, "ZivoeITO::depositSenior() block.timestamp < start");
        require(block.timestamp < end, "ZivoeITO::depositSenior() block.timestamp >= end");
        require(!migrated, "ZivoeITO::depositSenior() migrated");
        require(
            asset == stables[0] || asset == stables[1] || asset == stables[2] || asset == stables[3],
            "ZivoeITO::depositSenior() asset != stables[0] && asset != stables[1] && asset != stables[2] && asset != stables[3]"
        );

        address caller = _msgSender();

        uint256 standardizedAmount = ITO_IZivoeGlobals(GBL).standardize(amount, asset);

        seniorCredits[caller] += standardizedAmount * 3;

        emit SeniorDeposit(caller, asset, amount, standardizedAmount * 3, standardizedAmount);

        IERC20(asset).safeTransferFrom(caller, address(this), amount);
        ITO_IERC20Mintable(ITO_IZivoeGlobals(GBL).zSTT()).mint(address(this), standardizedAmount);
    }

    // TODO: Helper function for accepting deposits.

    /// @notice Migrate tokens to ZivoeDAO.
    /// @dev    This function MUST only be callable after the ITO concludes (or earlier at ZVL discretion).
    function migrateDeposits() external {
        if (_msgSender() != ITO_IZivoeGlobals(GBL).ZVL()) {
            require(block.timestamp > end, "ZivoeITO::migrateDeposits() block.timestamp <= end");
        }
        require(!migrated, "ZivoeITO::migrateDeposits() migrated");
        
        migrated = true;

        emit DepositsMigrated(IERC20(stables[0]).balanceOf(address(this)), IERC20(stables[1]).balanceOf(address(this)), IERC20(stables[2]).balanceOf(address(this)), IERC20(stables[3]).balanceOf(address(this)));

        for (uint256 i = 0; i < stables.length; i++) {
            IERC20(stables[i]).safeTransfer(ITO_IZivoeGlobals(GBL).ZVL(),IERC20(stables[i]).balanceOf(address(this)) * operationAllocation / BIPS);
            IERC20(stables[i]).safeTransfer(ITO_IZivoeGlobals(GBL).DAO(), IERC20(stables[i]).balanceOf(address(this)));
        }

        ITO_IZivoeYDL(ITO_IZivoeGlobals(GBL).YDL()).unlock();
        ITO_IZivoeTranches(ITO_IZivoeGlobals(GBL).ZVT()).unlock();
    }

}
