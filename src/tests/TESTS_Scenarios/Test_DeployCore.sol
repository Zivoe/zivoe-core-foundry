// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_DeployCore_Modular is Utility {

    address _GBL;

    bool live = false;

    function setUp() public {

        // Deploy the core protocol.
        deployCore(live);

        // Note: Replace _GBL value with main-net address of GBL for 
        //       live post-deployment validation.
        _GBL = address(GBL);
        // _GBL = 0x00000...;

    }

    function test_DeployCore_ZivoeDAO() public {

        address _TLC = live ? IZivoeGlobals(_GBL).TLC() : address(god);

        address _DAO = IZivoeGlobals(_GBL).DAO();
        address _ZVE = IZivoeGlobals(_GBL).ZVE();

        // Ownership.
        assertEq(IZivoeDAO(_DAO).owner(), _TLC);

        // State variables.
        assertEq(IZivoeDAO(_DAO).GBL(), _GBL);

        // $ZVE balance (should be 35% of total supply).
        assertEq(IERC20(_ZVE).balanceOf(_DAO), IERC20(_ZVE).totalSupply() * 35 / 100);

    }

    function test_DeployCore_ZivoeGlobals() public {

        address _TLC = live ? IZivoeGlobals(_GBL).TLC() : address(god);

        // Ownership.
        assertEq(IZivoeDAO(_GBL).owner(), _TLC);

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

    }

    function test_DeployCore_ZivoeGovernor() public {

        address _TLC = live ? IZivoeGlobals(_GBL).TLC() : address(TLC);

        address _GOV = IZivoeGlobals(_GBL).GOV();
        address _ZVE = IZivoeGlobals(_GBL).ZVE();

        // Note: No ownership for ZivoeGovernor.sol

        // State variables.
        assertEq(IZivoeGovernor(_GOV).votingDelay(), 1);
        assertEq(IZivoeGovernor(_GOV).votingPeriod(), 45818);
        assertEq(IZivoeGovernor(_GOV).quorum(0), 0);
        assertEq(IZivoeGovernor(_GOV).proposalThreshold(), 125000 ether);
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
        address _ZVE = IZivoeGlobals(_GBL).ZVE();

        // Note: No ownership for ZivoeITO.sol
        
        // State variables.
        assertEq(IZivoeITO(_ITO).start(), block.timestamp + 3 days);
        assertEq(IZivoeITO(_ITO).end(), block.timestamp + 33 days);
        
        assert(IZivoeITO(_ITO).stablecoinWhitelist(DAI));
        assert(IZivoeITO(_ITO).stablecoinWhitelist(FRAX));
        assert(IZivoeITO(_ITO).stablecoinWhitelist(USDC));
        assert(IZivoeITO(_ITO).stablecoinWhitelist(USDT));
    
        // $ZVE balance (should be 10% of total supply).
        assertEq(IERC20(_ZVE).balanceOf(_ITO), IERC20(_ZVE).totalSupply() * 10 / 100);
    }

    function test_DeployCore_ZivoeTimelockController() public {

        address _TLC = live ? IZivoeGlobals(_GBL).TLC() : address(TLC);

        address _GOV = IZivoeGlobals(_GBL).GOV();

        // Note: No ownership for ZivoeTimelockController.sol

        // State variables.
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
        address _ZVL = IZivoeGlobals(_GBL).ZVL();

        // Ownership.
        assertEq(IZivoeRewards(_stJTT).owner(), _ZVL);

        // State variables.
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
        address _ZVL = IZivoeGlobals(_GBL).ZVL();

        // Ownership.
        assertEq(IZivoeRewards(_stSTT).owner(), _ZVL);

        // State variables.
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
        address _ZVL = IZivoeGlobals(_GBL).ZVL();

        // Ownership.
        assertEq(IZivoeRewards(_stZVE).owner(), _ZVL);

        // State variables.
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
        
        address _vestZVE = IZivoeGlobals(_GBL).vestZVE();
        address _ZVE = IZivoeGlobals(_GBL).ZVE();
        address _ZVL = IZivoeGlobals(_GBL).ZVL();

        // Ownership.
        assertEq(IZivoeRewardsVesting(_vestZVE).owner(), _ZVL);

        // State variables.
        Reward memory _rewardZVE = IZivoeRewardsVesting(_vestZVE).rewardData(DAI);

        assertEq(_rewardZVE.rewardsDuration, 30 days);
        assertEq(_rewardZVE.periodFinish, 0);
        assertEq(_rewardZVE.rewardRate, 0);
        assertEq(_rewardZVE.lastUpdateTime, 0);
        assertEq(_rewardZVE.rewardPerTokenStored, 0);

        assertEq(IZivoeRewardsVesting(_vestZVE).GBL(), _GBL);
        assertEq(IZivoeRewardsVesting(_vestZVE).stakingToken(), _ZVE);

        // $ZVE balance (should be 50% of total supply).
        assertEq(IERC20(_ZVE).balanceOf(_vestZVE), IERC20(_ZVE).totalSupply() * 50 / 100);
    }

    function test_DeployCore_ZivoeToken() public {
        
        address _ZVE = IZivoeGlobals(_GBL).ZVE();

        // Note: No ownership for ZivoeToken.sol

        // State variables.
        assertEq(IZivoeToken(_ZVE).name(), "Zivoe");
        assertEq(IZivoeToken(_ZVE).symbol(), "ZVE");
        assertEq(IZivoeToken(_ZVE).decimals(), 18);
        assertEq(IZivoeToken(_ZVE).GBL(), _GBL);
        assertEq(IZivoeToken(_ZVE).totalSupply(), 25000000 ether);   // 25mm total supply

    }

    function test_DeployCore_ZivoeTranches() public {

        address _ZVT = IZivoeGlobals(_GBL).ZVT();
        address _ZVE = IZivoeGlobals(_GBL).ZVE();

        // Ownership.
        assertEq(IZivoeTranches(_ZVT).owner(), address(DAO));

        // State variables.
        assertEq(IZivoeTranches(_ZVT).GBL(), _GBL);

        assert(!IZivoeTranches(_ZVT).tranchesUnlocked());
        assert(IZivoeTranches(_ZVT).canPush());
        assert(IZivoeTranches(_ZVT).canPull());
        assert(IZivoeTranches(_ZVT).canPullPartial());

        // $ZVE balance (should be 5% of total supply).
        assertEq(IERC20(_ZVE).balanceOf(_ZVT), IERC20(_ZVE).totalSupply() * 5 / 100);

    }

    function test_DeployCore_ZivoeTranchesToken_zJTT() public {

        address _zJTT = IZivoeGlobals(_GBL).zJTT();
        address _ITO = IZivoeGlobals(_GBL).ITO();
        address _ZVT = IZivoeGlobals(_GBL).ZVT();

        // Ownership.
        assertEq(IZivoeTrancheToken(_zJTT).owner(), address(0));

        // State variables.
        assertEq(IZivoeTrancheToken(_zJTT).name(), "ZivoeJuniorTrancheToken");
        assertEq(IZivoeTrancheToken(_zJTT).symbol(), "zJTT");
        assertEq(IZivoeTrancheToken(_zJTT).decimals(), 18);
        assertEq(IZivoeTrancheToken(_zJTT).totalSupply(), 0);

        assert(IZivoeTrancheToken(_zJTT).isMinter(_ITO));
        assert(IZivoeTrancheToken(_zJTT).isMinter(_ZVT));

    }

    function test_DeployCore_ZivoeTranchesToken_zSTT() public {

        address _zSTT = IZivoeGlobals(_GBL).zSTT();
        address _ITO = IZivoeGlobals(_GBL).ITO();
        address _ZVT = IZivoeGlobals(_GBL).ZVT();

        // Ownership.
        assertEq(IZivoeTrancheToken(_zSTT).owner(), address(0));

        // State variables.
        assertEq(IZivoeTrancheToken(_zSTT).name(), "ZivoeSeniorTrancheToken");
        assertEq(IZivoeTrancheToken(_zSTT).symbol(), "zSTT");
        assertEq(IZivoeTrancheToken(_zSTT).decimals(), 18);
        assertEq(IZivoeTrancheToken(_zSTT).totalSupply(), 0);

        assert(IZivoeTrancheToken(_zSTT).isMinter(_ITO));
        assert(IZivoeTrancheToken(_zSTT).isMinter(_ZVT));

    }

    function test_DeployCore_ZivoeYDL() public {

        address _YDL = IZivoeGlobals(_GBL).YDL();

        // Ownership.
        assertEq(IZivoeYDL(_YDL).owner(), address(0));

        // State variables.
        assertEq(IZivoeYDL(_YDL).GBL(), _GBL);
        assertEq(IZivoeYDL(_YDL).distributedAsset(), DAI);
        assertEq(IZivoeYDL(_YDL).emaSTT(), 0);
        assertEq(IZivoeYDL(_YDL).emaJTT(), 0);
        assertEq(IZivoeYDL(_YDL).emaYield(), 0);
        assertEq(IZivoeYDL(_YDL).numDistributions(), 0);
        assertEq(IZivoeYDL(_YDL).lastDistribution(), 0);
        assertEq(IZivoeYDL(_YDL).targetAPYBIPS(), 800);
        assertEq(IZivoeYDL(_YDL).targetRatioBIPS(), 16250);
        assertEq(IZivoeYDL(_YDL).protocolEarningsRateBIPS(), 2000);
        assertEq(IZivoeYDL(_YDL).daysBetweenDistributions(), 30);
        assertEq(IZivoeYDL(_YDL).retrospectiveDistributions(), 6);

        assert(!IZivoeYDL(_YDL).unlocked());

    }

}
