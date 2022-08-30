// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";

/// @dev    This contract handles the global variables for the Zivoe protocol.
contract ZivoeGlobals is Ownable {
    // ---------------------
    //    State Variables
    // ---------------------

    address public DAO;        /// @dev The ZivoeDAO.sol contract.
    address public ITO;        /// @dev The ZivoeITO.sol contract.
    address public RET;        /// @dev The ZivoeRET.sol contract.
    address public stJTT;      /// @dev The ZivoeRewards.sol ($zJTT) contract.
    address public stSTT;      /// @dev The ZivoeRewards.sol ($zSTT) contract.
    address public stZVE;      /// @dev The ZivoeRewards.sol ($ZVE) contract.
    address public vestZVE;    /// @dev The ZivoeRewardsVesting.sol ($ZVE) vesting contract.
    address public YDL;        /// @dev The ZivoeYDL.sol contract.
    address public zJTT;       /// @dev The ZivoeTranches.sol ($zJTT) contract.
    address public zSTT;       /// @dev The ZivoeTranches.sol ($zSTT) contract.
    address public ZVE;        /// @dev The ZivoeToken.sol contract.
    address public ZVL;        /// @dev The one and only ZivoeLabs.
    address public GOV;        /// @dev The Governor contract.
    address public TLC;        /// @dev The Timelock contract.

    mapping(address => bool) public isKeeper; /// @dev Whitelist for keepers, responsible for pre-initiating actions.

    address public FRAX              = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //it might be best ot hard code external addresses as long as they are in one place
    uint256 public yieldDripPeriod   = 30 days; //for rewards parameter
    uint256 public yieldDelta        = 7 days; //length of one timestep
    uint256 public yieldMemoryPeriod = 13 weeks; //retrospection period
    uint256 public targetYield       = uint256(1 ether) / uint256(20);
    uint256 public targetRatio       = 3;

    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the ZivoeGlobals.sol contract.
    constructor() {}

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

        DAO        = globals[0];
        ITO        = globals[1];
        RET        = globals[2];
        stJTT      = globals[3];
        stSTT      = globals[4];
        stZVE      = globals[5];
        vestZVE    = globals[6];
        YDL        = globals[7];
        zJTT       = globals[8];
        zSTT       = globals[9];
        ZVE        = globals[10];
        ZVL        = globals[11];
        GOV        = globals[12];
        TLC        = globals[13];
    }

    // TODO: NatSpec
    function updateKeeper(address keeper, bool status) external onlyZVL {
        isKeeper[keeper] = status;
    }

    /// @notice sets the yieldMemoryPeriod global environment variable.
    function set_yieldMemoryPeriod(uint256 _yieldMemoryPeriod) public onlyZVL {
        yieldMemoryPeriod = _yieldMemoryPeriod;
    }

    /// @notice sets the yieldDripPeriod global environment variable.
    function set_yieldDripPeriod(uint256 _yieldDripPeriod) public onlyZVL {
        yieldDripPeriod = _yieldDripPeriod;
    }

    /// @notice sets the yieldDelta global environment variable.
    function set_yieldDelta(uint256 _yieldDelta) public onlyZVL {
        yieldDelta = _yieldDelta;
    }

    /// @notice sets the targetYield global environment variable.
    function set_targetYield(uint256 _targetYield) public onlyZVL {
        targetYield = _targetYield;
    }

    /// @notice sets the targetRatio global environment variable.
    function set_targetRatio(uint256 _targetRatio) public onlyZVL {
        targetRatio = _targetRatio;
    }
}
