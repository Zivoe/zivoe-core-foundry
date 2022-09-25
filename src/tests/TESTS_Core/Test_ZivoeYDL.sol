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
        // Initialize and whitelist OCC_B_Frax locker.
        OCC_B_Frax = new OCC_FRAX(address(DAO), address(GBL), address(god));
        god.try_updateIsLocker(address(GBL), address(OCC_B_Frax), true);
        // Create new loan request and fund it.
        uint256 id = OCC_B_Frax.counterID();
        // 400k FRAX loan simulation.
        assert(
            bob.try_requestLoan(
                address(OCC_B_Frax),
                400000 ether,
                3000,
                1500,
                12,
                86400 * 15,
                int8(0)
            )
        );
        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_B_Frax), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);

        assert(god.try_fundLoan(address(OCC_B_Frax), id));
        mint("FRAX", address(bob), 500000 ether);
        assert(bob.try_approveToken(address(FRAX), address(OCC_B_Frax), 500000 ether));
        for (uint8 i = 0; i < 12; i++) {
            assert(bob.try_makePayment(address(OCC_B_Frax), id));
        }
            hevm.warp(block.timestamp + (31 days));
            YDL.distributeYield();
    }
}
