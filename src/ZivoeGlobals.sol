// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";

/// @dev    This contract handles the global variables for the Zivoe protocol.
contract ZivoeGlobals is Ownable {

    // ---------------------
    //    State Variables
    // ---------------------

    address public DAO;       /// @dev The ZivoeDAO.sol contract.
    address public ITO;       /// @dev The ZivoeITO.sol contract.
    address public RET;       /// @dev The ZivoeRET.sol contract.
    address public stJTT;     /// @dev The ZivoeRewards.sol ($zJTT) contract.
    address public stSTT;     /// @dev The ZivoeRewards.sol ($zSTT) contract.
    address public stZVE;     /// @dev The ZivoeRewards.sol ($ZVE) contract.
    address public vestZVE;   /// @dev The ZivoeRewardsVesting.sol ($ZVE) vesting contract.
    address public YDL;       /// @dev The ZivoeYDL.sol contract.
    address public zJTT;      /// @dev The ZivoeTranches.sol ($zJTT) contract.
    address public zSTT;      /// @dev The ZivoeTranches.sol ($zSTT) contract.
    address public ZVE;       /// @dev The ZivoeToken.sol contract.
    address public ZVL;       /// @dev The one and only ZivoeLabs.
    address public GOV;       /// @dev The Governor contract.
    address public TLC;       /// @dev The Timelock contract.

    /// @dev This ratio represents the maximum size allowed for junior tranche, relative to senior tranche.
    ///      A value of 3,000 represent 30%, thus junior tranche at maximum can be 20% the size of senior tranche.
    uint256 public maxTrancheRatioBPS = 3000;

    /// @dev These two values control the min/max $ZVE minted per stablecoin deposited to ZivoeTranches.sol.
    uint256 public minZVEPerJTTMint = 0;
    uint256 public maxZVEPerJTTMint = 0.01 * 10**18;

    mapping(address => bool) public isKeeper;    /// @dev Whitelist for keepers, responsible for pre-initiating actions.

    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the ZivoeGlobals.sol contract.
    constructor() { }


    // TODO: Consider event logs here for specific actions / conversions.

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

    // TODO: NatSpec
    function initializeGlobals(address[] calldata globals) external onlyOwner {

        /// @notice This require statement ensures this function is callable only once.
        require(DAO == address(0), "ZivoeGlobals::initializeGlobals() DAO != address(0)");

        DAO     = globals[0];
        ITO     = globals[1];
        RET     = globals[2];
        stJTT   = globals[3];
        stSTT   = globals[4];
        stZVE   = globals[5];
        vestZVE = globals[6];
        YDL     = globals[7];
        zJTT    = globals[8];
        zSTT    = globals[9];
        ZVE     = globals[10];
        ZVL     = globals[11];
        GOV     = globals[12];
        TLC     = globals[13];
        
    }

    /// @notice Updates thitelist for keepers, responsible for pre-initiating actions.
    /// @dev    Only callable by ZVL.
    /// @param  keeper The address of the keeper.
    /// @param  status The status to assign to the "keeper" (true = allowed, false = restricted).
    function updateKeeper(address keeper, bool status) external onlyZVL { isKeeper[keeper] = status; }

    // TODO: Consider range-bound on maxTrancheRatioBPS.

    /// @notice Updates the maximum size of junior tranche, relative to senior tranche.
    /// @dev    A value of 2,000 represent 20% (basis points), meaning the junior tranche 
    ///         at maximum can be 20% the size of senior tranche.
    /// @dev    Only callable by $ZVE governance.
    /// @param  ratio The new ratio value.
    function updateMaxTrancheRatio(uint256 ratio) external onlyOwner { maxTrancheRatioBPS = ratio; }

    /// @notice Updates the min $ZVE minted per stablecoin deposited to ZivoeTranches.sol.
    /// @dev    Only callable by $ZVE governance.
    /// @param  min Minimum $ZVE minted per stablecoin.
    function updateMinZVEPerJTTMint(uint256 min) external onlyOwner {
        require(min < maxZVEPerJTTMint, "ZivoeGlobals::updateMinZVEPerJTTMint() min >= maxZVEPerJTTMint");
        minZVEPerJTTMint = min;
    }

    // TODO: Consider upper-bound on maxTrancheRatioBPS.

    /// @notice Updates the max $ZVE minted per stablecoin deposited to ZivoeTranches.sol.
    /// @dev    Only callable by $ZVE governance.
    /// @param  max Maximum $ZVE minted per stablecoin.
    function updateMaxZVEPerJTTMint(uint256 max) external onlyOwner {
        require(max < 0.1 * 10**18, "ZivoeGlobals::updateMinZVEPerJTTMint() max >= 0.1 * 10**18");
        maxZVEPerJTTMint = max; 
    }

}
