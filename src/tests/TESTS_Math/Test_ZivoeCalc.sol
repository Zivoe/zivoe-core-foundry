
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../libraries/ZivoeCalc.sol";

contract Test_ZivoeYieldCalc_Math is Utility {
    uint256 juniorRatio = 3 * WAD;
    uint256 targetRate = (5 * WAD) / 100;



    function setUp() public {
        setUpFundedDAO();
    }
    function test_yieldTarget() public {
        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 yieldTarget = YieldCalc.yieldTarget(sSTT, sJTT,juniorRatio,targetRate,6,30 days );
        assert(yieldTarget > ((sSTT+sJTT)*targetRate)/(12*WAD));

        emit Debug("yieldTarget", yieldTarget);
    }


}
