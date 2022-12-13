// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../TESTS_Utility/Utility.sol";

import "../../../lockers/OCY/deprecated/Deprecated_OCY_AAVE.sol";

contract OCY_AAVETest is Utility {

    OCY_AAVE OCY_AAVE_0;

    function setUp() public {

        deployCore(false);

        // Initialize and whitelist MyAAVELocker
        OCY_AAVE_0 = new OCY_AAVE(address(DAO), address(GBL));
        god.try_updateIsLocker(address(GBL), address(OCY_AAVE_0), true);

    }

    function xtest_OCY_AAVE_init() public {
        assertEq(OCY_AAVE_0.owner(),                address(DAO));
        assertEq(OCY_AAVE_0.GBL(),                  address(GBL));
        assertEq(OCY_AAVE_0.DAI(),                  DAI);
        assertEq(OCY_AAVE_0.FRAX(),                 FRAX);
        assertEq(OCY_AAVE_0.USDC(),                 USDC);
        assertEq(OCY_AAVE_0.USDT(),                 USDT);
        assertEq(OCY_AAVE_0.CRV_PP(),               0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);    // 3pool
        assertEq(OCY_AAVE_0.FRAX3CRV_MP(),          0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B);    // meta-pool (FRAX/3CRV)
        assertEq(OCY_AAVE_0.AAVE_V2_LendingPool(),  0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);    // aave v2 "router"
    }

    // Simulate depositing various stablecoins into OCYLocker_AAVE.sol from ZivoeDAO.sol via ZivoeDAO::pushToLocker().

    function xtest_OCY_AAVE_push() public {

        // Pre-state checks.
        // NOTE: address within IERC20() is aUSDC
        assertEq(IERC20(0xBcca60bB61934080951369a648Fb03DF4F96263C).balanceOf(address(OCY_AAVE_0)), 0);

        // Push 1mm USDC + USDT + DAI + FRAX to locker.
        assert(god.try_push(address(DAO), address(OCY_AAVE_0), address(USDC), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCY_AAVE_0), address(USDT), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCY_AAVE_0), address(DAI),  1000000 * 10**18));
        assert(god.try_push(address(DAO), address(OCY_AAVE_0), address(FRAX), 1000000 * 10**18));

        // Post-state checks.
        // Ensuring aUSDC received is within 5000 (out of 4mm, so .125% slippage/fees allowed here, increase if needed depending on main-net state).
        withinDiff(IERC20(0xBcca60bB61934080951369a648Fb03DF4F96263C).balanceOf(address(OCY_AAVE_0)), 4000000 * 10**6, 5000 * 10**6);

    }

    event LogData(string, uint256);

    function xtest_OCY_AAVE_pull() public {

        // Push 1mm USDC, USDT, DAI, and FRAX to locker.
        assert(god.try_push(address(DAO), address(OCY_AAVE_0), address(USDC), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCY_AAVE_0), address(USDT), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCY_AAVE_0), address(DAI),  1000000 * 10**18));
        assert(god.try_push(address(DAO), address(OCY_AAVE_0), address(FRAX), 1000000 * 10**18));

        // NOTE: Uncomment line below to simulate passing of time, and generate actual yield.
        hevm.warp(block.timestamp + 365 days);

        // Pre-state check.
        assertEq(IERC20(USDC).balanceOf(address(DAO)), 1000000 * 10**6);
        withinDiff(IERC20(0xBcca60bB61934080951369a648Fb03DF4F96263C).balanceOf(address(OCY_AAVE_0)), 4000000 * 10**6, 35000 * 10**6);

        // Pull capital from locker (divesting from AAVE v2, returning capital to DAO).
        assert(god.try_pull(address(DAO), address(OCY_AAVE_0), USDC));

        // Post-state check.
        withinDiff(IERC20(USDC).balanceOf(address(DAO)), 5000000 * 10**6, 35000 * 10**6);
        assertEq(IERC20(0xBcca60bB61934080951369a648Fb03DF4F96263C).balanceOf(address(OCY_AAVE_0)), 0);

    }

    function xtest_OCY_AAVE_yieldForward() public {

        // Push 1mm USDC, USDT, DAI, and FRAX to locker.
        assert(god.try_push(address(DAO), address(OCY_AAVE_0), address(USDC), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCY_AAVE_0), address(USDT), 1000000 * 10**6));
        assert(god.try_push(address(DAO), address(OCY_AAVE_0), address(DAI),  1000000 * 10**18));
        assert(god.try_push(address(DAO), address(OCY_AAVE_0), address(FRAX), 1000000 * 10**18));

        // NOTE: Uncomment line below to simulate passing of time, and generate actual yield.
        hevm.warp(block.timestamp + 365 days);

        // Pre-state check.
        assertEq(IERC20(USDC).balanceOf(address(DAO)), 1000000 * 10**6);
        withinDiff(IERC20(0xBcca60bB61934080951369a648Fb03DF4F96263C).balanceOf(address(OCY_AAVE_0)), 4000000 * 10**6, 35000 * 10**6);

        // Ensure yield is forwarded properly.
        OCY_AAVE_0.forwardYield();

        // Post-state check.
        // withinDiff(IERC20(USDC).balanceOf(address(DAO)), 5000000 * 10**6, 35000 * 10**6);
        // assertEq(IERC20(0xBcca60bB61934080951369a648Fb03DF4F96263C).balanceOf(address(OCY_AAVE_0)), 0);

    }

}
