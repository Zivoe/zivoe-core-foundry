// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCL/OCL_ZVE_UNIV2.sol";

contract Test_OCL_ZVE_UNIV2 is Utility {

    OCL_ZVE_UNIV2 OCL_ZVE_UNIV2_DAI;
    OCL_ZVE_UNIV2 OCL_ZVE_UNIV2_FRAX;
    OCL_ZVE_UNIV2 OCL_ZVE_UNIV2_USDC;
    OCL_ZVE_UNIV2 OCL_ZVE_UNIV2_USDT;

    function setUp() public {

        deployCore(false);

        // Simulate ITO (10mm * 8 * 4), DAI/FRAX/USDC/USDT.
        simulateITO(10_000_000 ether, 10_000_000 ether, 10_000_000 * USD, 10_000_000 * USD);

        // Initialize and whitelist OCL_ZVE_UNIV2 locker's.
        OCL_ZVE_UNIV2_DAI = new OCL_ZVE_UNIV2(address(DAO), address(GBL), DAI);
        OCL_ZVE_UNIV2_FRAX = new OCL_ZVE_UNIV2(address(DAO), address(GBL), FRAX);
        OCL_ZVE_UNIV2_USDC = new OCL_ZVE_UNIV2(address(DAO), address(GBL), USDC);
        OCL_ZVE_UNIV2_USDT = new OCL_ZVE_UNIV2(address(DAO), address(GBL), USDT);

        god.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_DAI), true);
        god.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_FRAX), true);
        god.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_USDC), true);
        god.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_USDT), true);

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function buyZVE(uint256 amt, address pairAsset) public {
        
        address UNIV2_ROUTER = OCL_ZVE_UNIV2_DAI.UNIV2_ROUTER();
        address[] memory path = new address[](2);
        path[1] = address(ZVE);

        if (pairAsset == DAI) {
            mint("DAI", address(this), amt);
            IERC20(DAI).approve(UNIV2_ROUTER, amt);
            path[0] = DAI;
        }
        else if (pairAsset == FRAX) {
            mint("FRAX", address(this), amt);
            IERC20(FRAX).approve(UNIV2_ROUTER, amt);
            path[0] = FRAX;
        }
        else if (pairAsset == USDC) {
            mint("USDC", address(this), amt);
            IERC20(USDC).approve(UNIV2_ROUTER, amt);
            path[0] = USDC;
        }
        else if (pairAsset == USDT) {
            mint("USDT", address(this), amt);
            IERC20(USDT).approve(UNIV2_ROUTER, amt);
            path[0] = USDT;
        }
        else { revert(); }

        // function swapExactTokensForTokens(
        //     uint amountIn,
        //     uint amountOutMin,
        //     address[] calldata path,
        //     address to,
        //     uint deadline
        // ) external returns (uint[] memory amounts);
        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokens(
            amt, 
            0, 
            path, 
            address(this), 
            block.timestamp + 5 days
        );
    }



    // ----------------
    //    Unit Tests
    // ----------------

    function test_OCL_ZVE_UNIV2_init() public {
        
        // Adjustable variables based on constructor().
        assertEq(OCL_ZVE_UNIV2_DAI.pairAsset(), DAI);
        assertEq(OCL_ZVE_UNIV2_FRAX.pairAsset(), FRAX);
        assertEq(OCL_ZVE_UNIV2_USDC.pairAsset(), USDC);
        assertEq(OCL_ZVE_UNIV2_USDT.pairAsset(), USDT);

        assertEq(OCL_ZVE_UNIV2_DAI.owner(), address(DAO));
        assertEq(OCL_ZVE_UNIV2_FRAX.owner(), address(DAO));
        assertEq(OCL_ZVE_UNIV2_USDC.owner(), address(DAO));
        assertEq(OCL_ZVE_UNIV2_USDT.owner(), address(DAO));

        assertEq(OCL_ZVE_UNIV2_DAI.GBL(), address(GBL));
        assertEq(OCL_ZVE_UNIV2_FRAX.GBL(), address(GBL));
        assertEq(OCL_ZVE_UNIV2_USDC.GBL(), address(GBL));
        assertEq(OCL_ZVE_UNIV2_USDT.GBL(), address(GBL));

        // Constants check, only need to check one instance.
        assertEq(OCL_ZVE_UNIV2_DAI.UNIV2_ROUTER(), 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        assertEq(OCL_ZVE_UNIV2_DAI.UNIV2_FACTORY(), 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        assertEq(OCL_ZVE_UNIV2_DAI.baseline(), 0);
        assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), 0);
        assertEq(OCL_ZVE_UNIV2_DAI.amountForConversion(), 0);
        assertEq(OCL_ZVE_UNIV2_DAI.compoundingRateBIPS(), 5000);

        assert(OCL_ZVE_UNIV2_DAI.canPushMulti());
        assert(OCL_ZVE_UNIV2_DAI.canPull());
        assert(OCL_ZVE_UNIV2_DAI.canPullPartial());
    }


    // Validate pushToLockerMulti() state changes (initial call).
    // Validate pushToLockerMulti() state changes (subsequent calls).
    // Validate pushToLockerMulti() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.
    //  - Only callable if assets[0] == pairAsset && assets[1] == $ZVE

    // Validate pullFromLocker() state changes.
    // Validate pullFromLocker() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.
    //  - Only callable if asset == pair (the UNIV2 LP token).

    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.
    //  - Only callable if asset == pair (the UNIV2 LP token).

    // Validate setExponentialDecayPerSecond() state changes.
    // Validate setExponentialDecayPerSecond() restrictions.
    // This includes:
    //  - Only governance contract (TLC / "god") may call this function.

    // Validate forwardYield() state changes.
    // Validate forwardYield() restrictions.
    // This includes:
    //  - Only governance contract (TLC / "god") may call this function.
    //  - Time constraints based on isKeeper(_msgSender()) status.

}
