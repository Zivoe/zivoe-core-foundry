// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/Ownable.sol";
import "./calc/YieldDisector.sol";

import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { IZivoeRewards, IZivoeRET, IZivoeGlobals } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract is modular and can facilitate distributions of assets held in escrow.
///         Distributions can be made on a preset schedule.
///         Assets can be held in escrow within this contract prior to distribution.
///         Assets can be converted to another asset prior to distribution.
///         Assets can be migrated to OCYLockers prior to distribution.
contract ZivoeYDL is Ownable {
    
    using SafeERC20 for IERC20;

    address public immutable GBL;    /// @dev The ZivoeGlobals contract.

    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;

    address[5] public wallets;

    bool public walletsSet;


    
    uint256 public yieldTimeUnit = 7 days;                 /// @dev The period between yield distributions.
    uint256 public retrospectionTime = 13;              /// @dev The historical period to track shortfall in units of yieldTime.

    uint256 public targetRatio = 3*10**18;                      /// @dev The target ratio of junior tranche yield relative to senior, in basis points.
    uint256 public targetYield = uint256(1 ether)/uint256(20);  /// @dev The target yield in wei, per token.
    
    uint256 public r_ZVE = uint256(5 ether)/uint256(100);
    uint256 public r_RET = uint256(15 ether)/uint256(100);
    uint256 public r_ZVE_resid = uint256(90 ether)/uint256(100);
    uint256 public r_RET_resid = uint256(10 ether)/uint256(100);



    // -----------------
    //    Constructor
    // -----------------

    // TODO: Refactor governacne implementation.

    /// @notice Initialize the ZivoeYDL.sol contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor (
        address _GBL
    ) {
        GBL = _GBL;
    }
    


    // ---------
    // Functions
    // ---------

    // TODO: NatSpec
    function initialize() public {
        require(!walletsSet, "ZivoeYDL::initialize() walletsSet");
        address[] memory _wallets = new address[](5);
        _wallets[0] = IZivoeGlobals(GBL).stSTT();
        _wallets[1] = IZivoeGlobals(GBL).stJTT();
        _wallets[2] = IZivoeGlobals(GBL).stZVE();
        _wallets[3] = IZivoeGlobals(GBL).vestZVE();
        _wallets[4] = IZivoeGlobals(GBL).RET();
        wallets = _wallets;
    }

///    function yieldDisect() internal view returns(uint256[5] memory amounts) {
///        _seniorRate = 
///        _juniorRate =     
///    }
///    
///
///    function pay() public {
///
///
///    }
///
    function forwardAssets() public {
        return 0;
    }
    /// @notice Updates the retrospectionTime variable.
    function set_retrospectionTime(uint256 _retrospectionTime) external onlyOwner {
        retrospectionTime = _retrospectionTime;
    }

    /// @notice Updates the yieldTimeUnit variable.
    function set_yieldTimeUnit(uint256 _yieldTimeUnit) external onlyOwner {
        yieldTimeUnit = _yieldTimeUnit;
    }

    /// @notice Updates the targetRatio variable.
    function set_targetRatio(uint256 _targetRatio) external onlyOwner {
        targetRatio = _targetRatio;
    }

    /// @notice Updates the targetYield variable.
    function set_targetYield(uint256 _targetYield) external onlyOwner {
        targetYield = _targetYield;
    }

    // -------------------------
    //     Calculations
    // -------------------------

} 
