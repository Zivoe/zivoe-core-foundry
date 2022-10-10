// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCY/OCY_CVX_Modular.sol";

contract Test_OCY_CVX_Modular is Utility {

    OCY_CVX_Modular OCY_CVX_FRAX_USDC;
    OCY_CVX_Modular OCY_CVX_mUSD_CRV3;

    function setUp() public {

        OCY_CVX_FRAX_USDC = new OCY_CVX_Modular();
        OCY_CVX_mUSD_CRV3 = new OCY_CVX_Modular();

        
    }

}
