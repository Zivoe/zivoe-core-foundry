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

        assertEq(IZivoeDAO(_DAO).GBL(), _GBL);
        assertEq(IZivoeDAO(_DAO).owner(), live ? _TLC : address(god));
        assertEq(IERC20(_ZVE).balanceOf(_DAO), IERC20(_ZVE).totalSupply() * 35 / 100);  // 35% of ZVE

    }

    function test_DeployCore_ZivoeGlobals() public {

        assertEq(IZivoeGlobals(_GBL).maxTrancheRatioBIPS(), 2000);
        assertEq(IZivoeGlobals(_GBL).minZVEPerJTTMint(), 0);
        assertEq(IZivoeGlobals(_GBL).maxZVEPerJTTMint(), 0);
        assertEq(IZivoeGlobals(_GBL).lowerRatioIncentive(), 1000);
        assertEq(IZivoeGlobals(_GBL).upperRatioIncentive(), 2000);
        assertEq(IZivoeGlobals(_GBL).defaults(), 0);
        
        assert(IZivoeGlobals(_GBL).stablecoinWhitelist(0x6B175474E89094C44Da98b954EedeAC495271d0F));
        assert(IZivoeGlobals(_GBL).stablecoinWhitelist(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
        assert(IZivoeGlobals(_GBL).stablecoinWhitelist(0xdAC17F958D2ee523a2206206994597C13D831ec7));

        if (live) {

        }
        else {
            assertEq(address(DAO), IZivoeGlobals(_GBL).DAO());
            assertEq(address(ITO), IZivoeGlobals(_GBL).ITO());
            assertEq(address(stJTT), IZivoeGlobals(_GBL).stJTT());
            assertEq(address(stSTT), IZivoeGlobals(_GBL).stSTT());
            assertEq(address(stZVE), IZivoeGlobals(_GBL).stZVE());
            assertEq(address(vestZVE), IZivoeGlobals(_GBL).vestZVE());
            assertEq(address(YDL), IZivoeGlobals(_GBL).YDL());
            assertEq(address(zJTT), IZivoeGlobals(_GBL).zJTT());
            assertEq(address(zSTT), IZivoeGlobals(_GBL).zSTT());
            assertEq(address(ZVE), IZivoeGlobals(_GBL).ZVE());
            assertEq(address(zvl), IZivoeGlobals(_GBL).ZVL());
            assertEq(address(ZVT), IZivoeGlobals(_GBL).ZVT());
            assertEq(address(GOV), IZivoeGlobals(_GBL).GOV());
            assertEq(address(god), IZivoeGlobals(_GBL).TLC());
        }

    }

    function test_DeployCore_ZivoeGovernor() public {
        assert(true);
    }

    function test_DeployCore_TimelockController() public {
        assert(true);
    }

    function test_DeployCore_ZivoeITO() public {
        assert(true);
    }

    function test_DeployCore_ZivoeRewards_zJTT() public {
        assert(true);
    }

    function test_DeployCore_ZivoeRewards_zSTT() public {
        assert(true);
    }

    function test_DeployCore_ZivoeRewards_ZVE() public {
        assert(true);
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
