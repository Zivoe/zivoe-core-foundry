// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;

// User imports.
import "../users/Admin.sol";
import "../users/Blackhat.sol";
import "../users/Lender.sol";
import "../users/TrancheLiquidityProvider.sol";
import "../users/Vester.sol";

// Core imports.
import "../ZivoeDAO.sol";
import "../ZivoeGlobals.sol";
import "../ZivoeGovernor.sol";
import "../ZivoeITO.sol";
import "../ZivoeRET.sol";
import "../ZivoeToken.sol";
import "../ZivoeTrancheToken.sol";
import "../ZivoeYDL.sol";

// Locker imports.
import "../ZivoeOCCLockers/OCC_FRAX.sol";

// External-protocol imports.
import "../OpenZeppelin/Governance/TimelockController.sol";
import { ZivoeRewards } from "../ZivoeRewards.sol";
import { ZivoeRewardsVesting } from "../ZivoeRewardsVesting.sol";

// Test (foundry-rs) imports.
import "../../lib/forge-std/src/Test.sol";

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

    // TODO:    Discuss the naming convention, i.e. "god" vs. "admin" vs. "owner" -or- "own" (3 letter convention).

    Admin                         god;      /// @dev    Represents "governing" contract of the system, could be individual (for debugging) 
                                            ///         or TimelockController (for live governance simulations).

    Admin                         zvl;      /// @dev    Represents GnosisSafe multi-sig, handled by Zivoe Labs.

    Blackhat                      bob;      /// @dev    Bob is a malicious actor that wants to attack the system for profit or mischief.
    
    Lender                        len;      /// @dev    Len(ny) manages a loan origiation locker.

    TrancheLiquidityProvider      jon;      /// @dev    Provides liquidity to the tranches.
    TrancheLiquidityProvider      sam;      /// @dev    Provides liquidity to the tranches.
    TrancheLiquidityProvider      tom;      /// @dev    Provides liquidity to the tranches.

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

    /// @notice IERC20 wrapping for contract imports.
    // IERC20 constant dai  = IERC20(DAI);
    // IERC20 constant usdc = IERC20(USDC);
    // IERC20 constant weth = IERC20(WETH);
    // IERC20 constant wbtc = IERC20(WBTC);

    address constant UNISWAP_V2_ROUTER_02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Uniswap V2 Router.
    address constant UNISWAP_V2_FACTORY   = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Uniswap V2 factory.

    
    /****************************/
    /*** Zivoe Core Contracts ***/
    /****************************/
    ZivoeDAO            DAO;
    ZivoeGlobals        GBL;
    ZivoeGovernor       GOV;
    ZivoeITO            ITO;
    ZivoeRET            RET;
    ZivoeToken          ZVE;
    ZivoeTrancheToken   zSTT;
    ZivoeTrancheToken   zJTT;
    ZivoeYDL            YDL;

    TimelockController  TLC;
    

    /*********************************/
    /*** Zivoe Periphery Contracts ***/
    /*********************************/
    ZivoeRewards    stJTT;
    ZivoeRewards    stSTT;
    ZivoeRewards    stZVE;
    
    ZivoeRewardsVesting    vestZVE;


    /*************************/
    /*** Zivoe DAO Lockers ***/
    /*************************/
    OCC_FRAX    OCC_B_Frax;


    /*****************/
    /*** Constants ***/
    /*****************/
    uint256 constant USD = 10 ** 6;  // USDC precision decimals
    uint256 constant BTC = 10 ** 8;  // WBTC precision decimals
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;


    /*****************/
    /*** Utilities ***/
    /*****************/
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


    /**************************************/
    /*** Actor/Multisig Setup Functions ***/
    /**************************************/
    function createActors() public { 
        god = new Admin();
        zvl = new Admin();
        bob = new Blackhat();
        len = new Lender();
        tom = new TrancheLiquidityProvider();
        sam = new TrancheLiquidityProvider();
        poe = new Vester();
        qcp = new Vester();
    }


    /******************************/
    /*** Test Utility Functions ***/
    /******************************/
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

    /// @dev This is the main Zivoe initialization procedure.
    function initializeZivoe() public {

        // Run initial setup functions.
        createActors();
        setUpTokens();

        // (0) Deploy ZivoeGlobals.sol

        GBL = new ZivoeGlobals();

        // (1) Deploy ZivoeToken.sol

        ZVE = new ZivoeToken(
            "Zivoe",
            "ZVE",
            address(god),
            address(GBL)
        );

        god.try_delegate(address(ZVE), address(god));

        // (2) Deploy ZivoeDAO.sol

        DAO = new ZivoeDAO(address(GBL));
        DAO.transferOwnership(address(god));

        // (3) Deploy "SeniorTrancheToken" through ZivoeTrancheToken.sol
        // (4) Deploy "JuniorTrancheToken" through ZivoeTrancheToken.sol

        zSTT = new ZivoeTrancheToken(
            "SeniorTrancheToken",
            "zSTT"
        );

        zJTT = new ZivoeTrancheToken(
            "JuniorTrancheToken",
            "zJTT"
        );

        zSTT.transferOwnership(address(god));
        zJTT.transferOwnership(address(god));

        // (5) Deploy ZivoeITO.sol

        ITO = new ZivoeITO(
            block.timestamp + 1000 seconds,
            block.timestamp + 5000 seconds,
            address(GBL)
        );

        // (5.5) Deploy ZivoeRET

        RET = new ZivoeRET(
            address(GBL)
        );

        // (6)  Transfer $ZVE from initial distributor to contract

        god.transferToken(address(ZVE), address(DAO), ZVE.totalSupply() / 2);       // 50% of $ZVE allocated to DAO
        god.transferToken(address(ZVE), address(ITO), ZVE.totalSupply() / 10);      // 10% of $ZVE allocated to ITO

        // (7) Give ZivoeITO.sol minterRole() status over zJTT and zSTT.

        god.try_changeMinterRole(address(zJTT), address(ITO), true);
        god.try_changeMinterRole(address(zSTT), address(ITO), true);

        // (9-11) Deploy staking contracts. 

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

        // (12) Deploy ZivoeYDL

        YDL = new ZivoeYDL(
            address(god),
            address(GBL)
        );

        // (13) Initialize vestZVE.

        vestZVE = new ZivoeRewardsVesting(
            address(ZVE),
            address(GBL)
        );

        // (14) Add rewards to ZivoeRewards.sol

        stSTT.addReward(FRAX, 1 days);
        stSTT.addReward(address(ZVE), 1 days);
        stJTT.addReward(FRAX, 1 days);
        stJTT.addReward(address(ZVE), 1 days);
        stZVE.addReward(FRAX, 1 days);
        stZVE.addReward(address(ZVE), 1 days);
        
        // (14.5) Establish Governor/Timelock.

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

        TLC.grantRole(TLC.CANCELLER_ROLE(), address(god));              // TODO: "ZVL" Discuss w/ legal.
        TLC.grantRole(TLC.EXECUTOR_ROLE(), address(0));
        TLC.grantRole(TLC.PROPOSER_ROLE(), address(GOV));
        TLC.revokeRole(TLC.TIMELOCK_ADMIN_ROLE(), address(this));

        // (15) Update the ZivoeGlobals contract

        address[] memory _wallets = new address[](14);

        _wallets[0] = address(DAO);
        _wallets[1] = address(ITO);
        _wallets[2] = address(RET);
        _wallets[3] = address(stJTT);
        _wallets[4] = address(stSTT);
        _wallets[5] = address(stZVE);
        _wallets[6] = address(vestZVE);
        _wallets[7] = address(YDL);
        _wallets[8] = address(zJTT);
        _wallets[9] = address(zSTT);
        _wallets[10] = address(ZVE);
        _wallets[11] = address(god);    // ZVL
        _wallets[12] = address(GOV);
        _wallets[13] = address(TLC);

        GBL.initializeGlobals(_wallets);

        // (16) Initialize the YDL.

        YDL.initialize();
        
        god.transferToken(address(ZVE), address(vestZVE), ZVE.totalSupply() * 4 / 10);  // 40% of $ZVE allocated to Vesting
        vestZVE.addReward(FRAX, 1 days);

        // TODO: Add vesting schedules as required (then transfer ownership).
        vestZVE.transferOwnership(address(zvl));

        // (xx) Deposit 1mm of each DAI, FRAX, USDC, USDT into both SeniorTranche and JuniorTranche
        
        simulateDepositsCoreUtility(1000000, 1000000);

    }

    function setUpFundedDAO() public {

        // Run initial setup functions.
        createActors();
        setUpTokens();

        // (0) Deploy ZivoeGlobals.sol

        GBL = new ZivoeGlobals();

        // (1) Deploy ZivoeToken.sol

        ZVE = new ZivoeToken(
            "Zivoe",
            "ZVE",
            address(god),
            address(GBL)
        );

        god.try_delegate(address(ZVE), address(god));

        // (2) Deploy ZivoeDAO.sol

        DAO = new ZivoeDAO(address(GBL));
        DAO.transferOwnership(address(god));

        // (3) Deploy "SeniorTrancheToken" through ZivoeTrancheToken.sol
        // (4) Deploy "JuniorTrancheToken" through ZivoeTrancheToken.sol

        zSTT = new ZivoeTrancheToken(
            "SeniorTrancheToken",
            "zSTT"
        );

        zJTT = new ZivoeTrancheToken(
            "JuniorTrancheToken",
            "zJTT"
        );

        zSTT.transferOwnership(address(god));
        zJTT.transferOwnership(address(god));

        // (5) Deploy ZivoeITO.sol

        ITO = new ZivoeITO(
            block.timestamp + 1000 seconds,
            block.timestamp + 5000 seconds,
            address(GBL)
        );

        // (5.5) Deploy ZivoeRET

        RET = new ZivoeRET(
            address(GBL)
        );

        // (6)  Transfer $ZVE from initial distributor to contract

        god.transferToken(address(ZVE), address(DAO), ZVE.totalSupply() / 2);       // 50% of $ZVE allocated to DAO
        god.transferToken(address(ZVE), address(ITO), ZVE.totalSupply() / 10);      // 10% of $ZVE allocated to ITO

        // (7) Give ZivoeITO.sol minterRole() status over zJTT and zSTT.

        god.try_changeMinterRole(address(zJTT), address(ITO), true);
        god.try_changeMinterRole(address(zSTT), address(ITO), true);

        // (9-11) Deploy staking contracts. 

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

        // (12) Deploy ZivoeYDL

        YDL = new ZivoeYDL(
            address(god),
            address(GBL)
        );

        // (13) Initialize vestZVE.

        vestZVE = new ZivoeRewardsVesting(
            address(ZVE),
            address(GBL)
        );

        // (14) Add rewards to ZivoeRewards.sol

        stSTT.addReward(FRAX, 1 days);
        stSTT.addReward(address(ZVE), 1 days);
        stJTT.addReward(FRAX, 1 days);
        stJTT.addReward(address(ZVE), 1 days);
        stZVE.addReward(FRAX, 1 days);
        stZVE.addReward(address(ZVE), 1 days);
        
        // (14.5) Establish Governor/Timelock.

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

        TLC.grantRole(TLC.CANCELLER_ROLE(), address(god));              // TODO: "ZVL" Discuss w/ legal.
        TLC.grantRole(TLC.EXECUTOR_ROLE(), address(0));
        TLC.grantRole(TLC.PROPOSER_ROLE(), address(GOV));
        TLC.revokeRole(TLC.TIMELOCK_ADMIN_ROLE(), address(this));

        // (15) Update the ZivoeGlobals contract

        address[] memory _wallets = new address[](14);

        _wallets[0] = address(DAO);
        _wallets[1] = address(ITO);
        _wallets[2] = address(RET);
        _wallets[3] = address(stJTT);
        _wallets[4] = address(stSTT);
        _wallets[5] = address(stZVE);
        _wallets[6] = address(vestZVE);
        _wallets[7] = address(YDL);
        _wallets[8] = address(zJTT);
        _wallets[9] = address(zSTT);
        _wallets[10] = address(ZVE);
        _wallets[11] = address(god);    // ZVL
        _wallets[12] = address(GOV);
        _wallets[13] = address(TLC);

        GBL.initializeGlobals(_wallets);

        // (16) Initialize the YDL.

        YDL.initialize();
        
        // (xx) Transfer ZVE tokens to vestZVE contract.
        god.transferToken(address(ZVE), address(vestZVE), ZVE.totalSupply() * 4 / 10);  // 40% of $ZVE allocated to Vesting
        vestZVE.addReward(FRAX, 1 days);

        // TODO: Add vesting schedules as required (then transfer ownership).
        vestZVE.transferOwnership(address(zvl));

        // (xx) Deposit 1mm of each DAI, FRAX, USDC, USDT into both SeniorTranche and JuniorTranche
        
        simulateDepositsCoreUtility(1000000, 1000000);

    }

    function stakeTokensHalf() public {

        // "tom" added to Junior tranche.
        tom.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(tom)));
        tom.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(tom)));
        tom.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(tom)) / 2);
        tom.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(tom)) / 2);

        // "sam" added to Junior tranche.
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

        // "sam" added to Junior tranche.
        sam.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)));
        sam.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
        sam.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)));
        sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
    }

    
    function fundAndRepayBalloonLoan() public {

        // Initialize and whitelist OCC_B_Frax locker.
        OCC_B_Frax = new OCC_FRAX(address(DAO), address(YDL), address(god));
        god.try_modifyLockerWhitelist(address(DAO), address(OCC_B_Frax), true);

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

        YDL.forwardAssets();

    }

    // Simulates deposits for a junior and a senior tranche depositor.

    function simulateDepositsCoreUtility(uint256 seniorDeposit, uint256 juniorDeposit) public {

        // Warp to ITO start unix.
        hevm.warp(ITO.start());

        // ------------------------
        // "sam" => depositSenior()
        // ------------------------

        mint("DAI",  address(sam), seniorDeposit * 1 ether);
        mint("FRAX", address(sam), seniorDeposit * 1 ether);
        mint("USDC", address(sam), seniorDeposit * USD);
        mint("USDT", address(sam), seniorDeposit * USD);

        assert(sam.try_approveToken(DAI,  address(ITO), seniorDeposit * 1 ether));
        assert(sam.try_approveToken(FRAX, address(ITO), seniorDeposit * 1 ether));
        assert(sam.try_approveToken(USDC, address(ITO), seniorDeposit * USD));
        assert(sam.try_approveToken(USDT, address(ITO), seniorDeposit * USD));

        assert(sam.try_depositSenior(address(ITO), seniorDeposit * 1 ether, address(DAI)));
        assert(sam.try_depositSenior(address(ITO), seniorDeposit * 1 ether, address(FRAX)));
        assert(sam.try_depositSenior(address(ITO), seniorDeposit * USD, address(USDC)));
        assert(sam.try_depositSenior(address(ITO), seniorDeposit * USD, address(USDT)));

        // ------------------------
        // "tom" => depositJunior()
        // ------------------------

        mint("DAI",  address(tom), juniorDeposit * 1 ether);
        mint("FRAX", address(tom), juniorDeposit * 1 ether);
        mint("USDC", address(tom), juniorDeposit * USD);
        mint("USDT", address(tom), juniorDeposit * USD);

        assert(tom.try_approveToken(DAI,  address(ITO), juniorDeposit * 1 ether));
        assert(tom.try_approveToken(FRAX, address(ITO), juniorDeposit * 1 ether));
        assert(tom.try_approveToken(USDC, address(ITO), juniorDeposit * USD));
        assert(tom.try_approveToken(USDT, address(ITO), juniorDeposit * USD));

        assert(tom.try_depositJunior(address(ITO), juniorDeposit * 1 ether, address(DAI)));
        assert(tom.try_depositJunior(address(ITO), juniorDeposit * 1 ether, address(FRAX)));
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
