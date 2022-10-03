// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

// import "./Test_DeployCore_Interfaces.sol";

contract Test_DeployCore_Modular is Utility {

    address _GBL;

    bool live = false;

    function setUp() public {

        // Deploy the core protocol.
        deployCore(live);

        // Note: Replace _GBL value with main-net address of GBL for live post-deployment validation.
        _GBL = address(GBL);
        // _GBL = 0x00000...;

    }

    function test_DeployCore_ZivoeDAO() public {

        address _DAO = IZivoeGlobals(_GBL).DAO();
        address _TLC = IZivoeGlobals(_GBL).TLC();
        address _ZVE = IZivoeGlobals(_GBL).ZVE();

        // State variables.
        assertEq(IZivoeDAO(_DAO).GBL(), _GBL);

        // Ownership.
        assertEq(IZivoeDAO(_DAO).owner(), live ? _TLC : address(god));

        // $ZVE balance (should be 35% of total supply).
        assertEq(IERC20(_ZVE).balanceOf(_DAO), IERC20(_ZVE).totalSupply() * 35 / 100);

    }

    function test_DeployCore_ZivoeGlobals() public {

        // State variables.
        assertEq(IZivoeGlobals(_GBL).maxTrancheRatioBIPS(), 2000);
        assertEq(IZivoeGlobals(_GBL).minZVEPerJTTMint(),    0);
        assertEq(IZivoeGlobals(_GBL).maxZVEPerJTTMint(),    0);
        assertEq(IZivoeGlobals(_GBL).lowerRatioIncentive(), 1000);
        assertEq(IZivoeGlobals(_GBL).upperRatioIncentive(), 2000);
        assertEq(IZivoeGlobals(_GBL).defaults(),            0);
        
        assert(IZivoeGlobals(_GBL).stablecoinWhitelist(DAI));
        assert(IZivoeGlobals(_GBL).stablecoinWhitelist(USDC));
        assert(IZivoeGlobals(_GBL).stablecoinWhitelist(USDT));

        if (live) {
            // Note: Replace the address(0) below with live addresses for live verification purposes.
            assertEq(address(0), IZivoeGlobals(_GBL).DAO());
            assertEq(address(0), IZivoeGlobals(_GBL).ITO());
            assertEq(address(0), IZivoeGlobals(_GBL).stJTT());
            assertEq(address(0), IZivoeGlobals(_GBL).stSTT());
            assertEq(address(0), IZivoeGlobals(_GBL).stZVE());
            assertEq(address(0), IZivoeGlobals(_GBL).vestZVE());
            assertEq(address(0), IZivoeGlobals(_GBL).YDL());
            assertEq(address(0), IZivoeGlobals(_GBL).zJTT());
            assertEq(address(0), IZivoeGlobals(_GBL).zSTT());
            assertEq(address(0), IZivoeGlobals(_GBL).ZVE());
            assertEq(address(0), IZivoeGlobals(_GBL).ZVL());
            assertEq(address(0), IZivoeGlobals(_GBL).ZVT());
            assertEq(address(0), IZivoeGlobals(_GBL).GOV());
            assertEq(address(0), IZivoeGlobals(_GBL).TLC());
        }
        else {
            assertEq(address(DAO),      IZivoeGlobals(_GBL).DAO());
            assertEq(address(ITO),      IZivoeGlobals(_GBL).ITO());
            assertEq(address(stJTT),    IZivoeGlobals(_GBL).stJTT());
            assertEq(address(stSTT),    IZivoeGlobals(_GBL).stSTT());
            assertEq(address(stZVE),    IZivoeGlobals(_GBL).stZVE());
            assertEq(address(vestZVE),  IZivoeGlobals(_GBL).vestZVE());
            assertEq(address(YDL),      IZivoeGlobals(_GBL).YDL());
            assertEq(address(zJTT),     IZivoeGlobals(_GBL).zJTT());
            assertEq(address(zSTT),     IZivoeGlobals(_GBL).zSTT());
            assertEq(address(ZVE),      IZivoeGlobals(_GBL).ZVE());
            assertEq(address(zvl),      IZivoeGlobals(_GBL).ZVL());
            assertEq(address(ZVT),      IZivoeGlobals(_GBL).ZVT());
            assertEq(address(GOV),      IZivoeGlobals(_GBL).GOV());
            assertEq(address(god),      IZivoeGlobals(_GBL).TLC());
        }

        address _TLC = IZivoeGlobals(_GBL).TLC();
        
        // Ownership.
        assertEq(IZivoeDAO(_GBL).owner(), live ? _TLC : address(god));

    }

    function test_DeployCore_ZivoeGovernor() public {

        address _GOV = IZivoeGlobals(_GBL).GOV();
        address _TLC = live ? IZivoeGlobals(_GBL).TLC() : address(TLC);
        address _ZVE = IZivoeGlobals(_GBL).ZVE();

        assertEq(IZivoeGovernor(_GOV).votingDelay(), 1);
        assertEq(IZivoeGovernor(_GOV).votingPeriod(), 45818);
        assertEq(IZivoeGovernor(_GOV).quorum(block.timestamp - 1), 0);
        assertEq(IZivoeGovernor(_GOV).proposalThreshold(), 0);
        assertEq(IZivoeGovernor(_GOV).name(), 'ZivoeGovernor');
        assertEq(IZivoeGovernor(_GOV).version(), '1');
        assertEq(IZivoeGovernor(_GOV).COUNTING_MODE(), 'support=bravo&quorum=for,abstain');
        assertEq(IZivoeGovernor(_GOV).quorumNumerator(), 10);
        assertEq(IZivoeGovernor(_GOV).quorumDenominator(), 100);
        assertEq(IZivoeGovernor(_GOV).timelock(), _TLC);
        assertEq(IZivoeGovernor(_GOV).token(), _ZVE);

    }

    function test_DeployCore_ZivoeITO() public {

        address _ITO = IZivoeGlobals(_GBL).ITO();
        
        assertEq(IZivoeITO(_ITO).start(), block.timestamp + 3 days);
        assertEq(IZivoeITO(_ITO).end(), block.timestamp + 33 days);
        
        assert(IZivoeITO(_ITO).stablecoinWhitelist(DAI));
        assert(IZivoeITO(_ITO).stablecoinWhitelist(FRAX));
        assert(IZivoeITO(_ITO).stablecoinWhitelist(USDC));
        assert(IZivoeITO(_ITO).stablecoinWhitelist(USDT));
    
    }

    function test_DeployCore_TimelockController() public {

        address _TLC = live ? IZivoeGlobals(_GBL).TLC() : address(TLC);
        address _GOV = IZivoeGlobals(_GBL).GOV();

        assertEq(ITimelockController(_TLC).GBL(), _GBL);
        assertEq(ITimelockController(_TLC).getMinDelay(), 1);
        assertEq(ITimelockController(_TLC).getRoleAdmin(keccak256('TIMELOCK_ADMIN_ROLE')), keccak256('TIMELOCK_ADMIN_ROLE'));
        assertEq(ITimelockController(_TLC).getRoleAdmin(keccak256('PROPOSER_ROLE')), keccak256('TIMELOCK_ADMIN_ROLE'));
        assertEq(ITimelockController(_TLC).getRoleAdmin(keccak256('EXECUTOR_ROLE')), keccak256('TIMELOCK_ADMIN_ROLE'));
        assertEq(ITimelockController(_TLC).getRoleAdmin(keccak256('CANCELLER_ROLE')), keccak256('TIMELOCK_ADMIN_ROLE'));
        
        assert(ITimelockController(_TLC).hasRole(keccak256('EXECUTOR_ROLE'), address(0)));
        assert(ITimelockController(_TLC).hasRole(keccak256('PROPOSER_ROLE'), _GOV));
        assert(ITimelockController(_TLC).hasRole(keccak256('TIMELOCK_ADMIN_ROLE'), _TLC));

    }

    function test_DeployCore_ZivoeRewards_zJTT() public {

        address _stJTT = IZivoeGlobals(_GBL).stJTT();
        address _zJTT = IZivoeGlobals(_GBL).zJTT();
        address _ZVE = IZivoeGlobals(_GBL).ZVE();

        // TODO: Identify why EvmError: Revert thrown on below.

        // address[] memory _rewardsTokens = IZivoeRewards(_stJTT).rewardTokens();

        // assertEq(_rewardsTokens[0], _ZVE);
        // assertEq(_rewardsTokens[1], DAI);

        Reward memory _rewardZVE = IZivoeRewards(_stJTT).rewardData(_ZVE);
        Reward memory _rewardDAI = IZivoeRewards(_stJTT).rewardData(DAI);

        assertEq(_rewardZVE.rewardsDuration, 30 days);
        assertEq(_rewardDAI.rewardsDuration, 30 days);
        assertEq(_rewardZVE.periodFinish, 0);
        assertEq(_rewardDAI.periodFinish, 0);
        assertEq(_rewardZVE.rewardRate, 0);
        assertEq(_rewardDAI.rewardRate, 0);
        assertEq(_rewardZVE.lastUpdateTime, 0);
        assertEq(_rewardDAI.lastUpdateTime, 0);
        assertEq(_rewardZVE.rewardPerTokenStored, 0);
        assertEq(_rewardDAI.rewardPerTokenStored, 0);

        assertEq(IZivoeRewards(_stJTT).GBL(), _GBL);
        assertEq(IZivoeRewards(_stJTT).stakingToken(), _zJTT);
        
    }

    function test_DeployCore_ZivoeRewards_zSTT() public {
        
        address _stSTT = IZivoeGlobals(_GBL).stSTT();
        address _zSTT = IZivoeGlobals(_GBL).zSTT();
        address _ZVE = IZivoeGlobals(_GBL).ZVE();

        // TODO: Identify why EvmError: Revert thrown on below.

        // address[] memory _rewardsTokens = IZivoeRewards(_stSTT).rewardTokens();

        // assertEq(_rewardsTokens[0], _ZVE);
        // assertEq(_rewardsTokens[1], DAI);

        Reward memory _rewardZVE = IZivoeRewards(_stSTT).rewardData(_ZVE);
        Reward memory _rewardDAI = IZivoeRewards(_stSTT).rewardData(DAI);

        assertEq(_rewardZVE.rewardsDuration, 30 days);
        assertEq(_rewardDAI.rewardsDuration, 30 days);
        assertEq(_rewardZVE.periodFinish, 0);
        assertEq(_rewardDAI.periodFinish, 0);
        assertEq(_rewardZVE.rewardRate, 0);
        assertEq(_rewardDAI.rewardRate, 0);
        assertEq(_rewardZVE.lastUpdateTime, 0);
        assertEq(_rewardDAI.lastUpdateTime, 0);
        assertEq(_rewardZVE.rewardPerTokenStored, 0);
        assertEq(_rewardDAI.rewardPerTokenStored, 0);

        assertEq(IZivoeRewards(_stSTT).GBL(), _GBL);
        assertEq(IZivoeRewards(_stSTT).stakingToken(), _zSTT);

    }

    function test_DeployCore_ZivoeRewards_ZVE() public {
        
        address _stZVE = IZivoeGlobals(_GBL).stZVE();
        address _ZVE = IZivoeGlobals(_GBL).ZVE();

        // TODO: Identify why EvmError: Revert thrown on below.

        // address[] memory _rewardsTokens = IZivoeRewards(_stZVE).rewardTokens();

        // assertEq(_rewardsTokens[0], _ZVE);
        // assertEq(_rewardsTokens[1], DAI);

        Reward memory _rewardZVE = IZivoeRewards(_stZVE).rewardData(_ZVE);
        Reward memory _rewardDAI = IZivoeRewards(_stZVE).rewardData(DAI);

        assertEq(_rewardZVE.rewardsDuration, 30 days);
        assertEq(_rewardDAI.rewardsDuration, 30 days);
        assertEq(_rewardZVE.periodFinish, 0);
        assertEq(_rewardDAI.periodFinish, 0);
        assertEq(_rewardZVE.rewardRate, 0);
        assertEq(_rewardDAI.rewardRate, 0);
        assertEq(_rewardZVE.lastUpdateTime, 0);
        assertEq(_rewardDAI.lastUpdateTime, 0);
        assertEq(_rewardZVE.rewardPerTokenStored, 0);
        assertEq(_rewardDAI.rewardPerTokenStored, 0);

        assertEq(IZivoeRewards(_stZVE).GBL(), _GBL);
        assertEq(IZivoeRewards(_stZVE).stakingToken(), _ZVE);

    }

    function test_DeployCore_ZivoeRewardsVesting() public {
        assert(true);
    }

    function test_DeployCore_ZivoeToken() public {
        assert(true);
    }

    function test_DeployCore_ZivoeTranchesToken_zJTT() public {
        assert(true);
    }

    function test_DeployCore_ZivoeTranchesToken_zSTT() public {
        assert(true);
    }

    function test_DeployCore_ZivoeYDL() public {
        assert(true);
    }

}
