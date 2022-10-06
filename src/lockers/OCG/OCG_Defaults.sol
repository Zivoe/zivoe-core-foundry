// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

interface IZivoeGlobals_P_1 {
    function TLC() external view returns (address);
    function decreaseDefaults(uint256) external;
    function increaseDefaults(uint256) external;
}

/// @dev    This contract is for testing default adjustments via ZivoeLocker.
contract OCG_Defaults is ZivoeLocker {
    
    
    // ---------------------
    //    State Variables
    // ---------------------

    address public GBL;  /// @dev The ZivoeGlobals contract.


    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_Generic.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    constructor(address DAO, address _GBL) {
        transferOwnership(DAO);
        GBL = _GBL;
    }



    // ---------------
    //    Modifiers
    // ---------------

    modifier onlyGovernance {
        require(_msgSender() == IZivoeGlobals_P_1(GBL).TLC());
        _;
    }



    // ---------------
    //    Functions
    // ---------------

    function decreaseDefaults(uint256 amount) public onlyGovernance {
        IZivoeGlobals_P_1(GBL).decreaseDefaults(amount);
    }

    function increaseDefaults(uint256 amount) public onlyGovernance {
        IZivoeGlobals_P_1(GBL).increaseDefaults(amount);
    }

}
