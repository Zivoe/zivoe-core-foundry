// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract ZivoeRETTest is Utility {

    function setUp() public {

        setUpFundedDAO();
        
        fundAndRepayBalloonLoan();
        
        RET.transferOwnership(address(god));
    }

    // Verify initial state ZivoeRETTest.sol constructor().

    function test_ZivoeRET_init_state() public {
        assertEq(RET.GBL(), address(GBL));
        assertEq(RET.owner(), address(god));
        
        // Should have about 11k FRAX available (more than 10k).
        assert(IERC20(FRAX).balanceOf(address(RET)) > 10000 ether);
    }


    // Verify pushAsset() state changes.
    // Verify pushAsset() restrictions.

    function test_ZivoeRET_pushAsset_state_changes() public {
        
        // Pre-state check.

        // Push asset (FRAX).

        // Post-state check.

    }

    function test_ZivoeRET_pushAsset_restrictions() public {

        // Any user except "god" cannot call pushAsset().
        assert(!bob.try_pushAsset(address(RET), FRAX, address(bob), 10000 ether));
    }


    // Verify passThroughYDL_stSTT() state changes.
    // Verify passThroughYDL_stJTT() state changes.
    // Verify passThroughYDL_stZVE() state changes.
    // Verify passThroughYDL_vestZVE() state changes.

    function test_ZivoeRET_passThroughYDL_stSTT_state_changes() public {
        
        // Pre-state check.
        uint256 pre_FRAX_RET = IERC20(FRAX).balanceOf(address(RET));
        uint256 pre_FRAX_stSTT = IERC20(FRAX).balanceOf(address(stSTT));

        // Pass through YDL (FRAX => stSTT).
        assert(god.try_passThroughYDL(address(RET), FRAX, 10000 ether, address(stSTT)));

        uint256 post_FRAX_RET = IERC20(FRAX).balanceOf(address(RET));
        uint256 post_FRAX_stSTT = IERC20(FRAX).balanceOf(address(stSTT));

        // Post-state check.
        assertEq(pre_FRAX_RET - post_FRAX_RET, 10000 ether);
        assertEq(post_FRAX_stSTT - pre_FRAX_stSTT, 10000 ether);

    }

    function test_ZivoeRET_passThroughYDL_stJTT_state_changes() public {
        
        // Pre-state check.
        uint256 pre_FRAX_RET = IERC20(FRAX).balanceOf(address(RET));
        uint256 pre_FRAX_stJTT = IERC20(FRAX).balanceOf(address(stJTT));

        // Pass through YDL (FRAX => stJTT).
        assert(god.try_passThroughYDL(address(RET), FRAX, 10000 ether, address(stJTT)));

        uint256 post_FRAX_RET = IERC20(FRAX).balanceOf(address(RET));
        uint256 post_FRAX_stJTT = IERC20(FRAX).balanceOf(address(stJTT));

        // Post-state check.
        assertEq(pre_FRAX_RET - post_FRAX_RET, 10000 ether);
        assertEq(post_FRAX_stJTT - pre_FRAX_stJTT, 10000 ether);

    }

    function test_ZivoeRET_passThroughYDL_stZVE_state_changes() public {
        
        // Pre-state check.
        uint256 pre_FRAX_RET = IERC20(FRAX).balanceOf(address(RET));
        uint256 pre_FRAX_stZVE = IERC20(FRAX).balanceOf(address(stZVE));

        // Pass through YDL (FRAX => stZVE).
        assert(god.try_passThroughYDL(address(RET), FRAX, 10000 ether, address(stZVE)));

        uint256 post_FRAX_RET = IERC20(FRAX).balanceOf(address(RET));
        uint256 post_FRAX_stZVE = IERC20(FRAX).balanceOf(address(stZVE));

        // Post-state check.
        assertEq(pre_FRAX_RET - post_FRAX_RET, 10000 ether);
        assertEq(post_FRAX_stZVE - pre_FRAX_stZVE, 10000 ether);

    }

    function test_ZivoeRET_passThroughYDL_vestZVE_state_changes() public {
        
        // Pre-state check.
        uint256 pre_FRAX_RET = IERC20(FRAX).balanceOf(address(RET));
        uint256 pre_FRAX_vestZVE = IERC20(FRAX).balanceOf(address(vestZVE));

        // Pass through YDL (FRAX => vestZVE).
        assert(god.try_passThroughYDL(address(RET), FRAX, 10000 ether, address(vestZVE)));

        uint256 post_FRAX_RET = IERC20(FRAX).balanceOf(address(RET));
        uint256 post_FRAX_vestZVE = IERC20(FRAX).balanceOf(address(vestZVE));

        // Post-state check.
        assertEq(pre_FRAX_RET - post_FRAX_RET, 10000 ether);
        assertEq(post_FRAX_vestZVE - pre_FRAX_vestZVE, 10000 ether);

    }

    // Verify passThroughYield() restrictions.

    function test_ZivoeRET_passThroughYield_restrictions() public {

        // Any user except "god" cannot call passThroughYield().
        assert(!bob.try_passThroughYDL(address(RET), FRAX, 10000 ether, address(GBL.stZVE())));
    }
    
}
