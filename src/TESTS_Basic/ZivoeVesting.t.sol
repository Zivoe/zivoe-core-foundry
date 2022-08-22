// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./Utility.sol";

contract ZivoeVestingTest is Utility {

    function setUp() public {
        
        createActors();

        ZVE = new ZivoeToken(
            10000000 ether,   // 10 million $ZVE supply
            18,
            'Zivoe',
            'ZVE',
            address(god)
        );
        
        VST = new ZivoeVesting(address(ZVE));

        stZVE = new MultiRewards(
            address(ZVE),
            address(god),
            address(GBL)

        );

        god.transferToken(address(ZVE), address(VST), 4000000 ether);
    }

    // Verify expected initial state of ZivoeVesting.sol.
    function Xtest_ZivoeVesting_init_state() public {
        assertEq(VST.vestingToken(), address(ZVE));
        assertEq(VST.owner(), address(god));
        assertEq(IERC20(address(ZVE)).balanceOf(address(VST)), 4000000 ether);
    }


    // Verify vest() restrictions.
    // Verify vest() state changes.
    
    function Xtest_ZivoeVesting_vest_restrictions() public {
        // "bob" cannot call the vest() function.
        assert(!bob.try_vest(address(VST), address(1), 1, 2, 100 ether));

        // "god" cannot vest more than amount of $ZVE tokens available in the contract.
        assert(!god.try_vest(address(VST), address(2), 1, 2, 4000000 ether + 1));

        // Adding a vesting schedule for address(3).
        assert(god.try_vest(address(VST), address(3), 1, 2, 100 ether));

        // We cannot add another vesting schedule for the same address.
        assert(!god.try_vest(address(VST), address(3), 1, 2, 100 ether));

        // We cannot create a vesting schedule with cliffDays > vestingDay.
        assert(!god.try_vest(address(VST), address(4), 3, 2, 100 ether));
    }

    function Xtest_ZivoeVesting_vest_state_changes() public {

        // Pre-state check.
        (
            uint pre_startUnix, 
            uint pre_cliffUnix, 
            uint pre_endUnix, 
            uint pre_totalVesting, 
            uint pre_totalClaimable, 
            uint pre_vestingPerSecond
        ) = VST.vestingScheduleOf(address(1));

        assertEq(pre_startUnix, 0);
        assertEq(pre_cliffUnix, 0);
        assertEq(pre_endUnix, 0);
        assertEq(pre_totalVesting, 0);
        assertEq(pre_totalClaimable, 0);
        assertEq(pre_vestingPerSecond, 0);

        assertEq(VST.vestingTokenAllocated(), 0);

        assert(!VST.vestingScheduleSet(address(1)));

        // Add vesting schedule for address(1).
        assert(god.try_vest(
            address(VST), // VST address for signature creation
            address(1),   // account
            1,            // daysToVest
            2,            // daysToVest
            100 ether     // amountToVest
        ));

        // Post-state check.
        (
            uint post_startingUnix, 
            uint post_cliffUnix, 
            uint post_endingUnix, 
            uint post_totalVesting, 
            uint post_totalClaimed, 
            uint post_vestingPerSecond
        ) = VST.vestingScheduleOf(address(1));

        assertEq(post_startingUnix, block.timestamp);
        assertEq(post_cliffUnix, block.timestamp + 1 days);
        assertEq(post_endingUnix, block.timestamp + 2 days);
        assertEq(post_totalVesting, 100 ether);
        assertEq(post_totalClaimed, 0);
        withinDiff(post_totalVesting, post_vestingPerSecond * 2 days, post_totalVesting / 10**12);

        assertEq(VST.vestingTokenAllocated(), 100 ether);

        assert(VST.vestingScheduleSet(address(1)));

        // emit Debug('post_startingUnix', post_startingUnix);
        // emit Debug('post_endingUnix', post_endingUnix);
        // emit Debug('post_totalVesting', post_totalVesting);
        // emit Debug('post_totalClaimed', post_totalClaimed);
        // emit Debug('post_vestingPerSecond', post_vestingPerSecond); 
    }

    // Verify amountClaimable() view function, warping through time.

    function Xtest_ZivoeVesting_amountClaimable_warp() public {

        // Add vesting schedule for address(1).
        assert(god.try_vest(
            address(VST),  // VST address for signature creation
            address(1),    // account
            10,            // daysUntilVestingBegins
            20,            // daysToVest
            1000 ether     // amountToVest
        ));

        (
            uint startingUnix, 
            uint cliffUnix, 
            uint endingUnix, 
            uint totalVesting,, 
            uint vestingPerSecond
        ) = VST.vestingScheduleOf(address(1));

        // emit Debug('startingUnix', startingUnix);
        // emit Debug('endingUnix', endingUnix);
        // emit Debug('totalVesting', totalVesting);
        // emit Debug('vestingPerSecond', vestingPerSecond); 

        // Init state. Should return 0 as vesting period has not begun.
        assertEq(VST.amountClaimable(address(1)), 0);

        // Warp to vesting beginning Unix. Should return 0.
        hevm.warp(startingUnix);
        assertEq(VST.amountClaimable(address(1)), 0);

        // Warp 1 second pre cliffUnix. Should return 0.
        hevm.warp(cliffUnix - 1 seconds);
        assertEq(VST.amountClaimable(address(1)), 0);

        // Warp to cliffUnix. Should return vps * seconds passed.
        hevm.warp(cliffUnix + 3 seconds);
        assertEq(VST.amountClaimable(address(1)), vestingPerSecond * (block.timestamp - startingUnix));

        // Warp 1 second prior to vesting period ending. Should return (totalVesting - 1*vps).
        hevm.warp(endingUnix - 1 seconds);
        
        // emit Debug('totalVestingMinus1', totalVesting - (1 * vestingPerSecond));
        // emit Debug('amountClaimable', VST.amountClaimable(address(1)));
        withinDiff(totalVesting - vestingPerSecond, VST.amountClaimable(address(1)), totalVesting / 10**12);

        // Warp to 1 second past the ending date. Should return totalVesting.
        hevm.warp(endingUnix);
        assertEq(VST.amountClaimable(address(1)), totalVesting);

    }

    // Verify claim() state changes while warping through time.

    function Xtest_ZivoeVesting_claim_state_changes_warp() public {

        // Initial Check.
        assert(!tom.try_claim(address(VST), address(tom)));
        assertEq(IERC20(address(ZVE)).balanceOf(address(tom)), 0);
        assertEq(VST.vestingTokenAllocated(), 0);

        // Add vesting schedule for address(1).
        assert(god.try_vest(
            address(VST),  // VST address for signature creation
            address(tom),  // account
            10,            // daysUntilVestingBegins
            20,            // daysToVest
            1000 ether     // amountToVest
        ));

        (
            uint startingUnix,
            uint cliffUnix,
            uint endingUnix,
            uint totalVesting,,
            uint vestingPerSecond
        ) = VST.vestingScheduleOf(address(tom));
        assertEq(VST.vestingTokenAllocated(), 1000 ether);

        // Init state. Should revert since account cannot claim 0 tokens.
        assert(!tom.try_claim(address(VST), address(tom)));

        // Warp to vesting cliffUnix - 1 second, call claim(), should revert since an account cannot claim 0 tokens.
        hevm.warp(cliffUnix - 1);
        assert(!tom.try_claim(address(VST), address(tom)));

        // Warp to cliffUnix, call claim(), should result in vps*3 $ZVE tokens in address(tom).
        hevm.warp(cliffUnix);
        assert(tom.try_claim(address(VST), address(tom)));
        assertEq(IERC20(address(ZVE)).balanceOf(address(tom)), vestingPerSecond * (block.timestamp - startingUnix));
        
        // Verify state change of vestingScheduleSet[address(tom)].totalClaimed to amount transferred to address(tom) previously.
        (,,,, uint postClaim_totalClaimed,) = VST.vestingScheduleOf(address(tom));
        assertEq(IERC20(address(ZVE)).balanceOf(address(tom)), postClaim_totalClaimed);
        assertEq(VST.vestingTokenAllocated(), 1000 ether - postClaim_totalClaimed);

        // Warp to endingUnix, call claim(), and verify amount in address(tom) balance is the full vesting amount.
        hevm.warp(endingUnix);
        assertEq(postClaim_totalClaimed + VST.amountClaimable(address(tom)), totalVesting);
        assert(tom.try_claim(address(VST), address(tom)));
        assertEq(IERC20(address(ZVE)).balanceOf(address(tom)), totalVesting);

        // Verifying the ending state variable values of totalClaimed and amountClaimable.
        (,,,, uint endingClaim_totalClaimed,) = VST.vestingScheduleOf(address(tom));
        assertEq(endingClaim_totalClaimed, totalVesting);
        assertEq(VST.amountClaimable(address(tom)), 0);
        assertEq(VST.vestingTokenAllocated(), 0);
    }

}
