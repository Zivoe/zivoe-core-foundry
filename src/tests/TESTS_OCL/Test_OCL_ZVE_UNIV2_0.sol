// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lockers/OCL/OCL_ZVE_UNIV2_0.sol";

contract Test_OCL_ZVE_UNIV2_0 is Utility {

    OCL_ZVE_UNIV2_0 OCL_UNI;

    function setUp() public {

        setUpFundedDAO();

        // Initialize and whitelist MyAAVELocker
        OCL_UNI = new OCL_ZVE_UNIV2_0(address(DAO), address(GBL));
        god.try_modifyLockerWhitelist(address(DAO), address(OCL_UNI), true);

    }

    function test_OCL_ZVE_UNIV2_0_init() public {
        
        assertEq(OCL_UNI.owner(),               address(DAO));
        
    }

    // Simulate depositing various stablecoins into OCL_ZVE_UNIV2_0.sol from ZivoeDAO.sol via ZivoeDAO::pushToLocker().

    function test_OCL_ZVE_UNIV2_0_pushMulti_FRAX() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_UNI), assets, amounts));


    }

    function buyZVE_FRAX(uint256 amt) public {
        mint("FRAX", address(this), amt);
        IERC20(FRAX).approve(OCL_UNI.UNIV2_ROUTER(), amt);
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
        IUniswapV2Router01(OCL_UNI.UNIV2_ROUTER()).swapExactTokensForTokens(
            amt, 0, path, address(this), block.timestamp + 5 days
        );
    }

    function test_OCL_ZVE_UNIV2_0_pullMulti_FRAX_pullFromLocker() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_UNI), assets, amounts));

        address[] memory assets_pull = new address[](2);
        assets_pull[0] = FRAX;
        assets_pull[1] = address(ZVE);

        assert(god.try_pullMulti(address(DAO), address(OCL_UNI), assets_pull));

    }

    function test_OCL_ZVE_UNIV2_0_pushMulti_FRAX_forwardYield() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = FRAX;
        assets[1] = address(ZVE);

        amounts[0] = 1000000 * 10**18;
        amounts[1] = 200000 * 10**18;

        assert(god.try_pushMulti(address(DAO), address(OCL_UNI), assets, amounts));

        (uint256 amt, uint256 lp) = OCL_UNI.FRAXConvertible();

        emit Debug("a", 11111);
        emit Debug("a", amt);
        emit Debug("a", 11111);
        emit Debug("a", lp);

        emit Debug("baseline", OCL_UNI.baseline());

        buyZVE_FRAX(100000 ether);
        
        (amt, lp) = OCL_UNI.FRAXConvertible();
        emit Debug("a", 22222);
        emit Debug("a", amt);
        emit Debug("a", 22222);
        emit Debug("a", lp);

        emit Debug("baseline", OCL_UNI.baseline());
        
        hevm.warp(block.timestamp + 31 days);
        OCL_UNI.forwardYield();
        
        (amt, lp) = OCL_UNI.FRAXConvertible();
        emit Debug("a", 33333);
        emit Debug("a", amt);
        emit Debug("a", 33333);
        emit Debug("a", lp);

    }

}
