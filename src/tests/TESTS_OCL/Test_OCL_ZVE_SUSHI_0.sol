// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCL/OCL_ZVE_SUSHI_0.sol";

contract Test_OCL_ZVE_SUSHI_0 is Utility {

    OCL_ZVE_SUSHI_0 OCL_SUSHI;

    function setUp() public {

        deployCore(false);

        // Initialize and whitelist MyAAVELocker
        OCL_SUSHI = new OCL_ZVE_SUSHI_0(address(DAO), address(GBL));
        god.try_updateIsLocker(address(GBL), address(OCL_SUSHI), true);

    }

    function xtest_OCL_ZVE_SUSHI_0_init() public {

        assertEq(OCL_SUSHI.owner(),               address(DAO));
        
    }

    // Simulate depositing various stablecoins into OCL_ZVE_SUSHI_0.sol from ZivoeDAO.sol via ZivoeDAO::pushToLocker().

    function xtest_OCL_ZVE_SUSHI_0_pushMulti_FRAX_generic() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_SUSHI), assets, amounts));


    }

    function buyZVE_FRAX(uint256 amt) public {
        mint("FRAX", address(this), amt);
        IERC20(FRAX).approve(OCL_SUSHI.SUSHI_ROUTER(), amt);
        // function swapExactTokensForTokens(
        //     uint amountIn,
        //     uint amountOutMin,
        //     address[] calldata path,
        //     address to,
        //     uint deadline
        // ) external returns (uint[] memory amounts);
        address[] memory path = new address[](2);
        path[0] = FRAX;
        path[1] = address(ZVE);
        ISushiRouter(OCL_SUSHI.SUSHI_ROUTER()).swapExactTokensForTokens(
            amt, 0, path, address(this), block.timestamp + 5 days
        );
    }

    function xtest_OCL_ZVE_SUSHI_0_pullMulti_FRAX_pullFromLocker() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_SUSHI), assets, amounts));

        address[] memory assets_pull = new address[](2);
        assets_pull[0] = FRAX;
        assets_pull[1] = address(ZVE);

        assert(god.try_pullMulti(address(DAO), address(OCL_SUSHI), assets_pull));

    }

    function xtest_OCL_ZVE_SUSHI_0_pushMulti_FRAX_forwardYield() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_SUSHI), assets, amounts));

        (uint256 amt, uint256 lp) = OCL_SUSHI.FRAXConvertible();

        emit Debug("a", 11111);
        emit Debug("a", amt);
        emit Debug("a", 11111);
        emit Debug("a", lp);

        emit Debug("baseline", OCL_SUSHI.baseline());

        buyZVE_FRAX(100000 ether);
        
        (amt, lp) = OCL_SUSHI.FRAXConvertible();
        emit Debug("a", 22222);
        emit Debug("a", amt);
        emit Debug("a", 22222);
        emit Debug("a", lp);

        emit Debug("baseline", OCL_SUSHI.baseline());
        
        hevm.warp(block.timestamp + 31 days);
        OCL_SUSHI.forwardYield();
        
        (amt, lp) = OCL_SUSHI.FRAXConvertible();
        emit Debug("a", 33333);
        emit Debug("a", amt);
        emit Debug("a", 33333);
        emit Debug("a", lp);

    }

}
