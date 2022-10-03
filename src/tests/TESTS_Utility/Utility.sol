// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

// User imports.
import "./users/Admin.sol";
import "./users/Blackhat.sol";
import "./users/Deployer.sol";
import "./users/Lender.sol";
import "./users/TrancheLiquidityProvider.sol";
import "./users/Vester.sol";

// Core imports.
import "../../ZivoeDAO.sol";
import "../../ZivoeGlobals.sol";
import "../../ZivoeGovernor.sol";
import "../../ZivoeITO.sol";
import "../../ZivoeToken.sol";
import "../../ZivoeTranches.sol";
import "../../ZivoeTrancheToken.sol";
import "../../ZivoeYDL.sol";

// Locker imports.
import "../../lockers/OCC/OCC_FRAX.sol";

// External-protocol imports.
import "../../libraries/OpenZeppelin/Governance/TimelockController.sol";
import { ZivoeRewards } from "../../ZivoeRewards.sol";
import { ZivoeRewardsVesting } from "../../ZivoeRewardsVesting.sol";

// Interfaces full imports.
import "../../misc/InterfacesAggregated.sol";

// Test (foundry-rs) imports.
import "../../../lib/forge-std/src/Test.sol";

// Interface imports.
interface Hevm {
    function warp(uint256) external;
    function store(address,bytes32,bytes32) external;
}

interface User {
    function approve(address, uint256) external;
}


/// @notice This is the primary Utility contract for testing and debugging.
contract Utility is DSTest {

    Hevm hevm;      /// @dev The core import of Hevm from Test.sol to support simulations.

    // ------------
    //    Actors
    // ------------

    Admin                         god;      /// @dev    Represents "governing" contract of the system, could be individual 
                                            ///         (for debugging) or TimelockController (for live governance simulations).

    Admin                         zvl;      /// @dev    Represents GnosisSafe multi-sig, handled by Zivoe Labs / Zivoe Dev entity.

    Blackhat                      bob;      /// @dev    Bob is a malicious actor that tries to attack the system for profit/mischief.
    
    Deployer                      jay;      /// @dev    Jay is responsible handling initial administrative tasks during 
                                            ///         deployment, otherwise post-deployment Jay is not utilized.

    Lender                        len;      /// @dev    Len(ny) manages a loan origiation locker.

    TrancheLiquidityProvider      sam;      /// @dev    Provides liquidity to the tranches (generally senior tranche).
    TrancheLiquidityProvider      tom;      /// @dev    Provides liquidity to the tranches (generally junior tranche).

    Vester                        poe;      /// @dev    Internal (revokable) vester.
    Vester                        qcp;      /// @dev    External (non-revokable) vester.



    // --------------------------------
    //    Mainnet Contract Addresses   
    // --------------------------------

    /// @notice Stablecoin contracts.
    address constant DAI   = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant FRAX  = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address constant TUSD  = 0x0000000000085d4780B73119b644AE5ecd22b376;    /// TrueUSD.
    address constant USDC  = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;    
    address constant USDT  = 0xdAC17F958D2ee523a2206206994597C13D831ec7;    /// Tether.

    address constant WETH  = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;    /// WrappedETH.
    address constant WBTC  = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;    /// WrappedBTC.

    address constant UNISWAP_V2_ROUTER_02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Uniswap V2 Router.
    address constant UNISWAP_V2_FACTORY   = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Uniswap V2 factory.


    
    // --------------------------
    //    Zivoe Core Contracts
    // --------------------------

    ZivoeDAO            DAO;
    ZivoeGlobals        GBL;
    ZivoeGovernor       GOV;
    ZivoeITO            ITO;
    ZivoeToken          ZVE;
    ZivoeTranches       ZVT;
    ZivoeTrancheToken   zSTT;
    ZivoeTrancheToken   zJTT;
    ZivoeYDL            YDL;

    TimelockController  TLC;
    


    // -------------------------------
    //    Zivoe Periphery Contracts
    // -------------------------------

    ZivoeRewards    stJTT;
    ZivoeRewards    stSTT;
    ZivoeRewards    stZVE;
    
    ZivoeRewardsVesting    vestZVE;



    // -----------------------
    //    Zivoe DAO Lockers
    // -----------------------

    OCC_FRAX    OCC_B_Frax;



    // ---------------
    //    Constants
    // ---------------

    uint256 constant BIPS = 10 ** 4;    // BIPS = Basis Points (1 = 0.01%, 100 = 1.00%, 10000 = 100.00%)
    uint256 constant USD = 10 ** 6;     // USDC / USDT precision
    uint256 constant BTC = 10 ** 8;     // wBTC precision
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;



    // ---------------
    //    Utilities
    // ---------------

    struct Token {
        address addr; // ERC20 Mainnet address
        uint256 slot; // Balance storage slot
        address orcl; // Chainlink oracle address
    }
 
    mapping (bytes32 => Token) tokens;

    struct TestObj {
        uint256 pre;
        uint256 post;
    }

    event Debug(string, uint256);
    event Debug(string, address);
    event Debug(string, bool);

    constructor() { hevm = Hevm(address(bytes20(uint160(uint256(keccak256("hevm cheat code")))))); }

    /// @notice Creates protocol actors.
    function createActors() public { 
        god = new Admin();
        zvl = new Admin();
        bob = new Blackhat();
        jay = new Deployer();
        len = new Lender();
        tom = new TrancheLiquidityProvider();
        sam = new TrancheLiquidityProvider();
        poe = new Vester();
        qcp = new Vester();
    }

    /// @notice Creates mintable tokens via mint().
    function setUpTokens() public {

        tokens["USDC"].addr = USDC;
        tokens["USDC"].slot = 9;

        tokens["DAI"].addr = DAI;
        tokens["DAI"].slot = 2;

        tokens["FRAX"].addr = FRAX;
        tokens["FRAX"].slot = 0;

        tokens["USDT"].addr = USDT;
        tokens["USDT"].slot = 2;

        tokens["WETH"].addr = WETH;
        tokens["WETH"].slot = 3;

        tokens["WBTC"].addr = WBTC;
        tokens["WBTC"].slot = 0;
    }

    /// @notice Deploys the core protocol.
    /// @dev    Set input param to true for using TLC as governance contract, otherwise
    ///         set input param to false for using "gov" (user) as governance contract
    ///         for more simplistic control over governance-based actions (and testing).
    function deployCore(bool live) public {


        // Step #0 --- Run initial setup functions for simulations.

        createActors();
        setUpTokens();


        // Step #1 --- Deploy ZivoeGlobals.sol.
        
        GBL = new ZivoeGlobals();


        // Step #2 --- Deploy ZivoeToken.sol.
       
        ZVE = new ZivoeToken(
            "Zivoe",
            "ZVE",
            address(jay),       // Note: "jay" receives all $ZVE tokens initially.
            address(GBL)
        );

        // "jay" SHOULD delegate all tokens to himself initially so all future owners have delegation natively in perpetuity.
        jay.try_delegate(address(ZVE), address(jay));


        // Step #3 --- Deploy governance contracts, TimelockController.sol and ZivoeGovernor.sol.

        address[] memory proposers;
        address[] memory executors;

        TLC = new TimelockController(
            1,
            proposers,
            executors,
            address(GBL)
        );

        GOV = new ZivoeGovernor(
            IVotes(address(ZVE)),
            TLC
        );

        // TLC.owner() MUST grant "EXECUTOR_ROLE" to address(0) for public execution of proposals.
        TLC.grantRole(TLC.EXECUTOR_ROLE(), address(0));

        // TLC.owner() MUST grant "PROPOSE_ROLE" to GOV for handling pass-through of proposals.
        TLC.grantRole(TLC.PROPOSER_ROLE(), address(GOV));

        // TLC.owner() MUST revoke role as "TIMELOCK_ADMIN_ROLE" after completing both grantRole() commands above.
        TLC.revokeRole(TLC.TIMELOCK_ADMIN_ROLE(), address(this));


        // Step #4 --- Deploy ZivoeDAO.sol,

        DAO = new ZivoeDAO(address(GBL));

        // "jay" MUST transfer 35% of ZVE tokens to DAO.
        jay.transferToken(address(ZVE), address(DAO), ZVE.totalSupply() * 35 / 100);

        // DAO.owner() MUST transfer ownership to governance contract.
        DAO.transferOwnership(live ? address(TLC) : address(god));


        // Step #5 --- Deploy Senior/Junior tranche token, through ZivoeTrancheToken.sol.

        zSTT = new ZivoeTrancheToken(
            "SeniorTrancheToken",
            "zSTT"
        );

        zJTT = new ZivoeTrancheToken(
            "JuniorTrancheToken",
            "zJTT"
        );


        // Step #6 --- Deploy ZivoeITO.sol.

        ITO = new ZivoeITO(
            block.timestamp + 3 days,
            block.timestamp + 33 days,
            address(GBL)
        );

        // "jay" MUST transfer 10% of ZVE tokens to ITO.
        jay.transferToken(address(ZVE), address(ITO), ZVE.totalSupply() / 10);

        // zJTT.owner() MUST give ITO minting priviliges.
        // zSTT.owner() MUST give ITO minting priviliges.
        zJTT.changeMinterRole(address(ITO), true);
        zSTT.changeMinterRole(address(ITO), true);


        // Step #7 --- Deploy ZivoeTranches.sol.

        ZVT = new ZivoeTranches(
            address(GBL)
        );

        // ZVT.owner() MUST transfer ownership to governance contract.
        ZVT.transferOwnership(live ? address(TLC) : address(god));

        // TODO: Rearrange this component somewhere else.
        // "zvl" MUST add ZVT to the DAO's whitelist (as initial administrative task).
        // assert(zvl.try_updateIsLocker(address(GBL), address(ZVT), true));

        // zJTT.owner() MUST give ZVT minting priviliges.
        // zSTT.owner() MUST give ZVT minting priviliges.
        zJTT.changeMinterRole(address(ZVT), true);
        zSTT.changeMinterRole(address(ZVT), true);

        // Note: At this point, zJTT / zSTT MUST not give minting priviliges to any other contract (ever).
        
        // zJTT.owner() MUST renounce ownership.
        // zSTT.owner() MUST renounce onwership.
        zJTT.renounceOwnership();
        zSTT.renounceOwnership();


        // Step #7 --- Deploy zSTT/zJTT/ZVE staking contracts, through ZivoeRewards.sol.

        stSTT = new ZivoeRewards(
            address(zSTT),
            address(GBL)
        );

        stJTT = new ZivoeRewards(
            address(zJTT),
            address(GBL)
        );

        stZVE = new ZivoeRewards(
            address(ZVE),
            address(GBL)
        );

        // stSTT.owner() must add DAI and ZVE as rewardToken's with "30 days" rewardDuration's.
        // stJTT.owner() must add DAI and ZVE as rewardToken's with "30 days" rewardDuration's.
        // stZVE.owner() must add DAI and ZVE as rewardToken's with "30 days" rewardDuration's.
        stSTT.addReward(DAI, 30 days);
        stSTT.addReward(address(ZVE), 30 days);
        stJTT.addReward(DAI, 30 days);
        stJTT.addReward(address(ZVE), 30 days);
        stZVE.addReward(DAI, 30 days);
        stZVE.addReward(address(ZVE), 30 days);

        // stSTT.owner() MUST transfer ownership to Zivoe Labs/Dev ("zvl").
        // stJTT.owner() MUST transfer ownership to Zivoe Labs/Dev ("zvl").
        // stZVE.owner() MUST transfer ownership to Zivoe Labs/Dev ("zvl").
        stSTT.transferOwnership(address(zvl));
        stJTT.transferOwnership(address(zvl));
        stZVE.transferOwnership(address(zvl));


        // Step #8 --- Deploy ZivoeYDL.sol.

        YDL = new ZivoeYDL(
            address(GBL),
            DAI
        );

        // YDL.owner() MUST transer ownership to governance contract ("god").
        YDL.transferOwnership(address(god));


        // Step #9 --- Deploy ZivoeRewardsVesting.sol.

        vestZVE = new ZivoeRewardsVesting(
            address(ZVE),
            address(GBL)
        );

        // "jay" MUST transfer 50% of ZVE tokens to vestZVE.
        jay.transferToken(address(ZVE), address(vestZVE), ZVE.totalSupply() / 2);
        
        // vestZVE.owner() MUST add DAI as a rewardToken with "30 days" for rewardsDuration.
        vestZVE.addReward(DAI, 30 days);

        // vestZVE.owner() MUST transfer ownership to Zivoe Labs / Dev ("zvl").
        vestZVE.transferOwnership(address(zvl));

        
        


        // Step #11 - Update the ZivoeGlobals.sol contract.

        address[] memory _wallets = new address[](14);

        _wallets[0] = address(DAO);      // _wallets[0]  == DAO     == ZivoeDAO.sol
        _wallets[1] = address(ITO);      // _wallets[1]  == ITO     == ZivoeITO.sol
        _wallets[2] = address(stJTT);    // _wallets[2]  == stJTT   == ZivoeRewards.sol
        _wallets[3] = address(stSTT);    // _wallets[3]  == stSTT   == ZivoeRewards.sol
        _wallets[4] = address(stZVE);    // _wallets[4]  == stZVE   == ZivoeRewards.sol
        _wallets[5] = address(vestZVE);  // _wallets[5]  == vestZVE == ZivoeRewardsVesting.sol
        _wallets[6] = address(YDL);      // _wallets[6]  == YDL     == ZivoeYDL.sol
        _wallets[7] = address(zJTT);     // _wallets[7]  == zJTT    == ZivoeTranchesToken.sol
        _wallets[8] = address(zSTT);     // _wallets[8]  == zSTT    == ZivoeTranchesToken.sol
        _wallets[9] = address(ZVE);      // _wallets[9]  == ZVE     == ZivoeToken.sol
        _wallets[10] = address(zvl);     // _wallets[10] == ZVL     == address(zvl) "Multi-Sig"
        _wallets[11] = address(GOV);     // _wallets[11] == GOV     == ZivoeGovernor.sol
                                         // _wallets[12] == TLC     == TimelockController.sol
        _wallets[12] = live ? address(TLC) : address(god);     
        _wallets[13] = address(ZVT);     // _wallets[13] == ZVT     == ZivoeTranches.sol

        // GBL.owner() MUST call initializeGlobals() with the above address array.
        GBL.initializeGlobals(_wallets);

        // GBL.owner() MUST transfer ownership to governance contract ("god").
        GBL.transferOwnership(address(god));

        // simulateDepositsCoreUtility(1000000, 1000000);

    }

    function stakeTokensHalf() public {

        // "tom" added to Junior tranche.
        tom.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(tom)));
        tom.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(tom)));
        tom.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(tom)) / 2);
        tom.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(tom)) / 2);

        // "sam" added to Senior tranche.
        sam.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)));
        sam.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
        sam.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)) / 2);
        sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)) / 2);
    }

    function stakeTokensFull() public {

        // "tom" added to Junior tranche.
        tom.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(tom)));
        tom.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(tom)));
        tom.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(tom)));
        tom.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(tom)));

        // "sam" added to Senior tranche.
        sam.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)));
        sam.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
        sam.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)));
        sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
    }

    
    function fundAndRepayBalloonLoan_FRAX() public {

        // Initialize and whitelist OCC_B_Frax locker.
        OCC_B_Frax = new OCC_FRAX(address(DAO), address(GBL), address(god));
        god.try_updateIsLocker(address(GBL), address(OCC_B_Frax), true);

        // Create new loan request and fund it.
        uint256 id = OCC_B_Frax.counterID();

        // 400k FRAX loan simulation.
        assert(bob.try_requestLoan(
            address(OCC_B_Frax),
            400000 ether,
            3000,
            1500,
            12,
            86400 * 15,
            int8(0)
        ));


        // Add more FRAX into contract.
        assert(god.try_push(address(DAO), address(OCC_B_Frax), address(USDC), 500000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(god.try_fundLoan(address(OCC_B_Frax), id));

        // Mint BOB 500k FRAX and approveToken
        mint("FRAX", address(bob), 500000 ether);
        assert(bob.try_approveToken(address(FRAX), address(OCC_B_Frax), 500000 ether));

        // 12 payments.
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));

        hevm.warp(block.timestamp + 31 days);

        YDL.distributeYield();

    }

    function fundAndRepayBalloonLoan_BIG_BACKDOOR_FRAX() public {

        // Initialize and whitelist OCC_B_Frax locker.
        OCC_B_Frax = new OCC_FRAX(address(DAO), address(GBL), address(god));
        god.try_updateIsLocker(address(GBL), address(OCC_B_Frax), true);

        // Create new loan request and fund it.
        uint256 id = OCC_B_Frax.counterID();

        // 2.5mm FRAX loan simulation.
        assert(bob.try_requestLoan(
            address(OCC_B_Frax),
            2500000 ether,
            3000,
            1500,
            12,
            86400 * 15,
            int8(0)
        ));


        // Add more FRAX into contract.
        mint("USDC", address(DAO), 3000000 * 10**6);
        assert(god.try_push(address(DAO), address(OCC_B_Frax), address(USDC), 3000000 * 10**6));

        // Fund loan (5 days later).
        hevm.warp(block.timestamp + 5 days);
        assert(god.try_fundLoan(address(OCC_B_Frax), id));

        // Mint BOB 4mm FRAX and approveToken
        mint("FRAX", address(bob), 4000000 ether);
        assert(bob.try_approveToken(address(FRAX), address(OCC_B_Frax), 4000000 ether));

        // 12 payments.
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        
        assert(bob.try_makePayment(address(OCC_B_Frax), id));
        assert(bob.try_makePayment(address(OCC_B_Frax), id));

        hevm.warp(block.timestamp + 31 days);

        YDL.distributeYield();

    }

    // Simulates deposits for a junior and a senior tranche depositor.

    function simulateDepositsCoreUtility(uint256 seniorDeposit, uint256 juniorDeposit) public {

        // Warp to ITO start unix.
        hevm.warp(ITO.start());

        // ------------------------
        // "sam" => depositSenior()
        // ------------------------

        mint("DAI",  address(sam), seniorDeposit * 1 ether);
        mint("USDC", address(sam), seniorDeposit * USD);
        mint("USDT", address(sam), seniorDeposit * USD);

        assert(sam.try_approveToken(DAI,  address(ITO), seniorDeposit * 1 ether));
        assert(sam.try_approveToken(USDC, address(ITO), seniorDeposit * USD));
        assert(sam.try_approveToken(USDT, address(ITO), seniorDeposit * USD));

        assert(sam.try_depositSenior(address(ITO), seniorDeposit * 1 ether, address(DAI)));
        assert(sam.try_depositSenior(address(ITO), seniorDeposit * USD, address(USDC)));
        assert(sam.try_depositSenior(address(ITO), seniorDeposit * USD, address(USDT)));

        // ------------------------
        // "tom" => depositJunior()
        // ------------------------

        mint("DAI",  address(tom), juniorDeposit * 1 ether);
        mint("USDC", address(tom), juniorDeposit * USD);
        mint("USDT", address(tom), juniorDeposit * USD);

        assert(tom.try_approveToken(DAI,  address(ITO), juniorDeposit * 1 ether));
        assert(tom.try_approveToken(USDC, address(ITO), juniorDeposit * USD));
        assert(tom.try_approveToken(USDT, address(ITO), juniorDeposit * USD));

        assert(tom.try_depositJunior(address(ITO), juniorDeposit * 1 ether, address(DAI)));
        assert(tom.try_depositJunior(address(ITO), juniorDeposit * USD, address(USDC)));
        assert(tom.try_depositJunior(address(ITO), juniorDeposit * USD, address(USDT)));

        // Warp to end of ITO, call migrateDeposits() to ensure ZivoeDAO.sol receives capital.
        hevm.warp(ITO.end() + 1);
        ITO.migrateDeposits();

        // Have "tom" and "sam" claim their tokens from the contract.
        tom.try_claim(address(ITO));
        sam.try_claim(address(ITO));
    }

    // Manipulate mainnet ERC20 balance
    function mint(bytes32 symbol, address account, uint256 amt) public {
        address addr = tokens[symbol].addr;
        uint256 slot  = tokens[symbol].slot;
        uint256 bal = IERC20(addr).balanceOf(account);

        hevm.store(
            addr,
            keccak256(abi.encode(account, slot)), // Mint tokens
            bytes32(bal + amt)
        );

        assertEq(IERC20(addr).balanceOf(account), bal + amt); // Assert new balance
    }

    // Verify equality within accuracy decimals
    function withinPrecision(uint256 val0, uint256 val1, uint256 accuracy) public {
        uint256 diff  = val0 > val1 ? val0 - val1 : val1 - val0;
        if (diff == 0) return;

        uint256 denominator = val0 == 0 ? val1 : val0;
        bool check = ((diff * RAY) / denominator) < (RAY / 10 ** accuracy);

        if (!check){
            emit log_named_uint("Error: approx a == b not satisfied, accuracy digits ", accuracy);
            emit log_named_uint("  Expected", val0);
            emit log_named_uint("    Actual", val1);
            fail();
        }
    }

    // Verify equality within difference
    function withinDiff(uint256 val0, uint256 val1, uint256 expectedDiff) public {
        uint256 actualDiff = val0 > val1 ? val0 - val1 : val1 - val0;
        bool check = actualDiff <= expectedDiff;

        if (!check) {
            emit log_named_uint("Error: approx a == b not satisfied, accuracy difference ", expectedDiff);
            emit log_named_uint("  Expected", val0);
            emit log_named_uint("    Actual", val1);
            fail();
        }
    }

    function constrictToRange(uint256 val, uint256 min, uint256 max) public pure returns (uint256) {
        return constrictToRange(val, min, max, false);
    }

    function constrictToRange(uint256 val, uint256 min, uint256 max, bool nonZero) public pure returns (uint256) {
        if      (val == 0 && !nonZero) return 0;
        else if (max == min)           return max;
        else                           return val % (max - min) + min;
    }
    
}
