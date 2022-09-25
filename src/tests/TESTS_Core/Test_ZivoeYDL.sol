// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeYDL is Utility {
    function setUp() public {
        setUpFundedDAO();
    }

    function test_ZivoeYDL_distribution() public {
        fundAndRepayBalloonLoan();
    }

    function test_ZivoeYDL_distribution_BIG() public {
        fundAndRepayBalloonLoan_BIG_BACKDOOR();
    }

    function test_distributeYield() public {
        (uint256 sSTT, uint256 sJTT) = YDL.adjustedSupplies();
        mint("FRAX", address(god), 4000000 ether);
        god.transferToken(address(god), address(YDL), 10000 ether);
        uint256 jR = (sJTT * WAD) / sSTT;
        (
            uint256[] memory _protocol,
            uint256 _seniorTranche,
            uint256 _juniorTranche,
            uint256[] memory _residual
        ) = YDL.distributeYield();

        withinDiff(
            (jR * YDL.targetRatio() * _seniorTranche) / (WAD * WAD),
            _juniorTranche,
            _juniorTranche / 1000000
        );
    }
}
