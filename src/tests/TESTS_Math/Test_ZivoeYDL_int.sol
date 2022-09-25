pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../libraries/ZivoeCalc.sol";
import "../../ZivoeYDL.sol";

contract proxZivoeYDL is ZivoeYDL {
    constructor(address _GBL, address _recv) ZivoeYDL(_GBL, _recv) {}

    function read_johnTheYieldRipper(uint256 seniorSupp, uint256 juniorSupp)
        external
        returns (
            uint256[] memory _protocol,
            uint256 _seniorTranche,
            uint256 _juniorTranche,
            uint256[] memory _residual
        )
    {
        (
            uint256[] memory _protocol,
            uint256 _seniorTranche,
            uint256 _juniorTranche,
            uint256[] memory _residual
        ) = johnTheYieldRipper(seniorSupp, juniorSupp);
    }
}

contract Test_ZivoeYieldCalc_Math is Utility {
    uint256 juniorRatio = 3 * WAD;
    uint256 targetRate = (5 * WAD) / 100;
    proxZivoeYDL pYDL = new proxZivoeYDL(address(GBL), address(FRAX));

    function setUp() public {
        setUpFundedDAO();
    }

    function test_johnTheYieldRipper() external {
        mint("FRAX", address(this), 100000 ether);
        uint256 juniorSupp = 10000 ether;
        uint256 seniorSupp = 30000 ether;

        (
            uint256[] memory _protocol,
            uint256 _seniorTranche,
            uint256 _juniorTranche,
            uint256[] memory _residual
        ) = pYDL.read_johnTheYieldRipper(seniorSupp, juniorSupp);

        withinDiff(
            (pYDL.targetRatio() * _seniorTranche) / (3 * WAD),
            _juniorTranche,
            10000
        );
    }
}
