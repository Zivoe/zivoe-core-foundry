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

        uint256 yieldTarget = YieldCalc.yieldTarget(sSTT, sJTT,juniorRatio,targetRate,30 days );

        emit Debug("yieldTarget", yieldTarget);
    }

    function test_rateSeniorNominal() public {
        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();
        uint256 rateSeniorNominal = YieldCalc.rateSeniorNominal(sJTT, sSTT, juniorRatio);

        emit Debug("a", rateSeniorNominal);

        uint256 rateJunior = YieldCalc.rateJunior(juniorRatio, rateSeniorNominal, sSTT, sJTT);

        emit Debug("rateJunior", rateJunior);
    }

    function test_rateSenior_0() public {
        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 rateSenior = YieldCalc.rateSenior(
            25000 ether,
            33500 ether,
            sSTT,
            sJTT,
            juniorRatio,
            targetRate,
            6,
            sSTT,
            sJTT,
            30 days
        );

        emit Debug("rateSenior", rateSenior);

        uint256 rateJunior = YieldCalc.rateJunior(juniorRatio, rateSenior, sSTT, sJTT);

        emit Debug("rateJunior", rateJunior);
    }

    function test_rateSenior_1() public {
        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 rateSenior = YieldCalc.rateSenior(
            100000 ether,
            100000 ether,
            sSTT,
            sJTT,
            juniorRatio,
            targetRate,
            6,
            sSTT,
            sJTT,
            30 days
        );

        emit Debug("rateSenior", rateSenior);

        uint256 rateJunior = YieldCalc.rateJunior(juniorRatio, rateSenior, sSTT, sJTT);

        emit Debug("rateJunior", rateJunior);
    }

    function test_rateJunior() public {
        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 rateJunior = YieldCalc.rateJunior(3 * WAD, (3 * WAD) / 100, sSTT, sJTT);

        emit Debug("rateJunior", rateJunior);
    }

    function test_rateJunior_1() public {
        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();

        uint256 rateJunior = YieldCalc.rateJunior(juniorRatio, 0.30 * 10**18, sSTT, sJTT);

        emit Debug("rateJunior", rateJunior);

        rateJunior = YieldCalc.rateJunior(juniorRatio, 0.40 * 10**18, sSTT, sJTT);

        emit Debug("rateJunior", rateJunior);

        rateJunior = YieldCalc.rateJunior(juniorRatio, 0.50 * 10**18, sSTT, sJTT);

        emit Debug("rateJunior", rateJunior);
    }

            
                    
            
            
            
            
            
            
            
            
                                        
                            
                        
                                
            
            
            
            
            }
