// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "./libraries/FloorMath.sol";
import "./libraries/OwnableLocked.sol";

import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice This contract contains global variables for the Zivoe protocol.
///         This contract MUST be owned by TimelockController. This ownership MUST be locked through OwnableLocked.
///         This contract has the following responsibilities:
///          - Maintain accounting of all defaults within the system in aggregate.
///          - Manage a whitelist of "keepers" which are allowed to execute proposals in the TLC in advance.
///          - Manage a whitelist of "lockers" which ZivoeDAO can push/pull to.
///          - Manage a whitelist of "stablecoins" which are accepted in other Zivoe contracts.
///          - Expose a view function for standardized ERC20 precision handling.
///          - Expose a view function for adjusting the supplies of tranches (accounting purposes).
contract ZivoeGlobals is OwnableLocked {

    using FloorMath for uint256;

    // ---------------------
    //    State Variables
    // ---------------------

    address public DAO;         /// @dev The ZivoeDAO contract.
    address public ITO;         /// @dev The ZivoeITO contract.
    address public stJTT;       /// @dev The ZivoeRewards ($zJTT) contract.
    address public stSTT;       /// @dev The ZivoeRewards ($zSTT) contract.
    address public stZVE;       /// @dev The ZivoeRewards ($ZVE) contract.
    address public vestZVE;     /// @dev The ZivoeRewardsVesting ($ZVE) vesting contract.
    address public YDL;         /// @dev The ZivoeYDL contract.
    address public zJTT;        /// @dev The ZivoeTrancheToken ($zJTT) contract.
    address public zSTT;        /// @dev The ZivoeTrancheToken ($zSTT) contract.
    address public ZVE;         /// @dev The ZivoeToken contract.
    address public ZVL;         /// @dev The Zivoe Laboratory.
    address public ZVT;         /// @dev The ZivoeTranches contract.
    address public GOV;         /// @dev The Governor contract.
    address public TLC;         /// @dev The Timelock contract.
    
    uint256 public defaults;    /// @dev Tracks net defaults in system.

    mapping(address => bool) public isKeeper;               /// @dev Whitelist for keepers, responsible for pre-initiating actions.
    mapping(address => bool) public isLocker;               /// @dev Whitelist for lockers, for DAO interactions and accounting accessibility.
    mapping(address => bool) public stablecoinWhitelist;    /// @dev Whitelist for acceptable stablecoins throughout system (ZVE, YDL).



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeGlobals contract.
    constructor() { }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during initializeGlobals().
    /// @param controller The address representing Zivoe Labs / Dev entity.
    event AccessControlSetZVL(address indexed controller);

    /// @notice Emitted during decreaseNetDefaults().
    /// @param locker The locker updating the default amount.
    /// @param amount Amount of defaults decreased.
    /// @param updatedDefaults Total defaults funds after event.
    event DefaultsDecreased(address indexed locker, uint256 amount, uint256 updatedDefaults);

    /// @notice Emitted during increaseNetDefaults().
    /// @param locker The locker updating the default amount.
    /// @param amount Amount of defaults increased.
    /// @param updatedDefaults Total defaults after event.
    event DefaultsIncreased(address indexed locker, uint256 amount, uint256 updatedDefaults);

    /// @notice Emitted during updateIsLocker().
    /// @param  locker  The locker whose status as a locker is being modified.
    /// @param  allowed The boolean value to assign.
    event UpdatedLockerStatus(address indexed locker, bool allowed);

    /// @notice Emitted during updateIsKeeper().
    /// @param  account The address whose status as a keeper is being modified.
    /// @param  status The new status of "account".
    event UpdatedKeeperStatus(address indexed account, bool status);

    /// @notice Emitted during updateStablecoinWhitelist().
    /// @param  asset The stablecoin to update.
    /// @param  allowed The boolean value to assign.
    event UpdatedStablecoinWhitelist(address indexed asset, bool allowed);



    // ---------------
    //    Modifiers
    // ---------------

    modifier onlyZVL() {
        require(_msgSender() == ZVL, "ZivoeGlobals::onlyZVL() _msgSender() != ZVL");
        _;
    }



    // ---------------
    //    Functions
    // ---------------

    /// @notice Call when a default is resolved, decreases net defaults system-wide.
    /// @dev    The value "amount" should be standardized to WEI.
    /// @param  amount The default amount that has been resolved.
    function decreaseDefaults(uint256 amount) external {
        require(isLocker[_msgSender()], "ZivoeGlobals::decreaseDefaults() !isLocker[_msgSender()]");

        defaults -= amount;
        emit DefaultsDecreased(_msgSender(), amount, defaults);
    }

    /// @notice Call when a default occurs, increases net defaults system-wide.
    /// @dev    The value "amount" should be standardized to WEI.
    /// @param  amount The default amount.
    function increaseDefaults(uint256 amount) external {
        require(isLocker[_msgSender()], "ZivoeGlobals::increaseDefaults() !isLocker[_msgSender()]");

        defaults += amount;
        emit DefaultsIncreased(_msgSender(), amount, defaults);
    }

    /// @notice Initialze the variables within this contract (after all contracts have been deployed).
    /// @dev    This function should only be called once.
    /// @param  globals Array of addresses representing all core system contracts.
    /// @param  stables Array of stablecoins representing initial stablecoin inputs.
    function initializeGlobals(
        address[] calldata globals,
        address[] calldata stables
    ) external onlyOwner {
        require(DAO == address(0), "ZivoeGlobals::initializeGlobals() DAO != address(0)");

        emit AccessControlSetZVL(globals[10]);

        DAO     = globals[0];
        ITO     = globals[1];
        stJTT   = globals[2];
        stSTT   = globals[3];
        stZVE   = globals[4];
        vestZVE = globals[5];
        YDL     = globals[6];
        zJTT    = globals[7];
        zSTT    = globals[8];
        ZVE     = globals[9];
        ZVL     = globals[10];
        GOV     = globals[11];
        TLC     = globals[12];
        ZVT     = globals[13];

        stablecoinWhitelist[stables[0]] = true; // DAI
        stablecoinWhitelist[stables[1]] = true; // USDC
        stablecoinWhitelist[stables[2]] = true; // USDT
    }

    /// @notice Transfer ZVL access control to another account.
    /// @param  _ZVL The new address for ZVL.
    function transferZVL(address _ZVL) external onlyZVL {
        ZVL = _ZVL;
        emit AccessControlSetZVL(_ZVL);
    }

    /// @notice Updates the keeper whitelist.
    /// @param  keeper The address of the keeper.
    /// @param  status The status to assign to the "keeper" (true = allowed, false = restricted).
    function updateIsKeeper(address keeper, bool status) external onlyZVL {
        emit UpdatedKeeperStatus(keeper, status);
        isKeeper[keeper] = status;
    }

    /// @notice Modifies the locker whitelist.
    /// @param  locker  The locker to update.
    /// @param  allowed The value to assign (true = permitted, false = prohibited).
    function updateIsLocker(address locker, bool allowed) external onlyZVL {
        emit UpdatedLockerStatus(locker, allowed);
        isLocker[locker] = allowed;
    }

    /// @notice Modifies the stablecoin whitelist.
    /// @param  stablecoin The stablecoin to update.
    /// @param  allowed The value to assign (true = permitted, false = prohibited).
    function updateStablecoinWhitelist(address stablecoin, bool allowed) external onlyZVL {
        emit UpdatedStablecoinWhitelist(stablecoin, allowed);
        stablecoinWhitelist[stablecoin] = allowed;
    }

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param amount The amount of a given "asset".
    /// @param asset The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount The above amount standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount) {
        standardizedAmount = amount;
        
        if (IERC20Metadata(asset).decimals() < 18) {
            standardizedAmount *= 10 ** (18 - IERC20Metadata(asset).decimals());
        } else if (IERC20Metadata(asset).decimals() > 18) {
            standardizedAmount /= 10 ** (IERC20Metadata(asset).decimals() - 18);
        }
    }

    /// @notice Returns total circulating supply of zSTT and zJTT, accounting for defaults via markdowns.
    /// @return zSTTSupply zSTT.totalSupply() adjusted for defaults.
    /// @return zJTTSupply zJTT.totalSupply() adjusted for defaults.
    function adjustedSupplies() external view returns (uint256 zSTTSupply, uint256 zJTTSupply) {
        // Junior tranche decrease by amount of defaults, to a floor of zero.
        uint256 zJTTSupply_unadjusted = IERC20(zJTT).totalSupply();
        zJTTSupply = zJTTSupply_unadjusted.zSub(defaults);

        uint256 zSTTSupply_unadjusted = IERC20(zSTT).totalSupply();
        // Senior tranche decreases if excess defaults exist beyond junior tranche size.
        if (defaults > zJTTSupply_unadjusted) {
            zSTTSupply = zSTTSupply_unadjusted.zSub(defaults.zSub(zJTTSupply_unadjusted));
        }
        else { zSTTSupply = zSTTSupply_unadjusted; }
    }

}
