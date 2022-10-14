// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

// User imports.
import "./users/Admin.sol";
import "./users/Blackhat.sol";
import "./users/Borrower.sol";
import "./users/Deployer.sol";
import "./users/Manager.sol";
import "./users/Investor.sol";
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

    Admin       god;    /// @dev    Represents "governing" contract of the system, could be individual 
                        ///         (for debugging) or TimelockController (for live governance simulations).
    Admin       zvl;    /// @dev    Represents GnosisSafe multi-sig, handled by Zivoe Labs / Zivoe Dev entity.

    Blackhat    bob;    /// @dev    Bob is a malicious actor that tries to attack the system for profit/mischief.

    Borrower    tim;    /// @dev    Tim borrows money through an OCC_Modular locker.
    
    Deployer    jay;    /// @dev    Jay is responsible handling initial administrative tasks during 
                        ///         deployment, otherwise post-deployment Jay is not utilized.

    Manager     roy;    /// @dev    Roy manages an OCC_Modular locker.

    Investor    sam;    /// @dev    Provides liquidity to the tranches (generally senior tranche).
    Investor    sue;    /// @dev    Provides liquidity to the tranches (generally senior tranche).
    Investor    sal;    /// @dev    Provides liquidity to the tranches (generally senior tranche).
    Investor    sid;    /// @dev    Provides liquidity to the tranches (generally senior tranche).
    Investor    jim;    /// @dev    Provides liquidity to the tranches (generally junior tranche).
    Investor    joe;    /// @dev    Provides liquidity and stakes.
    Investor    jon;    /// @dev    Provides liquidity and stakes.
    Investor    jen;    /// @dev    Provides liquidity and stakes.

    Vester      poe;    /// @dev    Internal (revokable) vester.
    Vester      qcp;    /// @dev    External (non-revokable) vester.
    Vester      moe;    /// @dev    Additional vester.
    Vester      pam;    /// @dev    Additional vester.
    Vester      tia;    /// @dev    Additional vester.



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



    // ---------------
    //    Constants
    // ---------------

    uint256 constant BIPS = 10 ** 4;    // BIPS = Basis Points (1 = 0.01%, 100 = 1.00%, 10000 = 100.00%)
    uint256 constant USD = 10 ** 6;     // USDC / USDT precision
    uint256 constant BTC = 10 ** 8;     // wBTC precision
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;

    uint256 constant MAX_UINT = 2**256 - 1;



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
        // 2 Admins.
        god = new Admin();
        zvl = new Admin();
        
        // 1 Blackhat.
        bob = new Blackhat();

        // 1 Borrower.
        tim = new Borrower();

        // 1 Deployer.
        jay = new Deployer();

        // 1 Manager.
        roy = new Manager();

        // 8 Investors.
        sam = new Investor();
        sue = new Investor();
        sal = new Investor();
        sid = new Investor();
        jim = new Investor();
        joe = new Investor();
        jon = new Investor();
        jen = new Investor();

        // 5 Vesters.
        poe = new Vester();
        qcp = new Vester();
        moe = new Vester();
        pam = new Vester();
        tia = new Vester();
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

    /// @notice Simulates an ITO and calls migrateDeposits()/
    /// @dev    Does not claim / stake tokens.
    function simulateITO(
        uint256 amount_DAI,
        uint256 amount_FRAX,
        uint256 amount_USDC,
        uint256 amount_USDT
    ) public {
        
        // Mint investor's stablecoins.
        mint("DAI", address(sam), amount_DAI);
        mint("DAI", address(sue), amount_DAI);
        mint("DAI", address(sal), amount_DAI);
        mint("DAI", address(sid), amount_DAI);
        mint("DAI", address(jim), amount_DAI);
        mint("DAI", address(joe), amount_DAI);
        mint("DAI", address(jon), amount_DAI);
        mint("DAI", address(jen), amount_DAI);
        
        mint("FRAX", address(sam), amount_FRAX);
        mint("FRAX", address(sue), amount_FRAX);
        mint("FRAX", address(sal), amount_FRAX);
        mint("FRAX", address(sid), amount_FRAX);
        mint("FRAX", address(jim), amount_FRAX);
        mint("FRAX", address(joe), amount_FRAX);
        mint("FRAX", address(jon), amount_FRAX);
        mint("FRAX", address(jen), amount_FRAX);
        
        mint("USDC", address(sam), amount_USDC);
        mint("USDC", address(sue), amount_USDC);
        mint("USDC", address(sal), amount_USDC);
        mint("USDC", address(sid), amount_USDC);
        mint("USDC", address(jim), amount_USDC);
        mint("USDC", address(joe), amount_USDC);
        mint("USDC", address(jon), amount_USDC);
        mint("USDC", address(jen), amount_USDC);
        
        mint("USDT", address(sam), amount_USDT);
        mint("USDT", address(sue), amount_USDT);
        mint("USDT", address(sal), amount_USDT);
        mint("USDT", address(sid), amount_USDT);
        mint("USDT", address(jim), amount_USDT);
        mint("USDT", address(joe), amount_USDT);
        mint("USDT", address(jon), amount_USDT);
        mint("USDT", address(jen), amount_USDT);

        // Warp to start of ITO.
        hevm.warp(ITO.start() + 1 seconds);

        // Approve ITO for stablecoins.
        assert(sam.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(sue.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(sal.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(sid.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(jim.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(joe.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(jon.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(jen.try_approveToken(DAI, address(ITO), amount_DAI));

        assert(sam.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(sue.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(sal.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(sid.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(jim.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(joe.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(jon.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(jen.try_approveToken(FRAX, address(ITO), amount_FRAX));

        assert(sam.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(sue.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(sal.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(sid.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(jim.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(joe.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(jon.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(jen.try_approveToken(USDC, address(ITO), amount_USDC));

        assert(sam.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(sue.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(sal.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(sid.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(jim.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(joe.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(jon.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(jen.try_approveToken(USDT, address(ITO), amount_USDT));

        // Deposit stablecoins.

        // 2 ("sam", "sue") into only senior tranche.
        assert(sam.try_depositSenior(address(ITO), amount_DAI, DAI));
        assert(sam.try_depositSenior(address(ITO), amount_FRAX, FRAX));
        assert(sam.try_depositSenior(address(ITO), amount_USDC, USDC));
        assert(sam.try_depositSenior(address(ITO), amount_USDT, USDT));
        assert(sue.try_depositSenior(address(ITO), amount_DAI, DAI));
        assert(sue.try_depositSenior(address(ITO), amount_FRAX, FRAX));
        assert(sue.try_depositSenior(address(ITO), amount_USDC, USDC));
        assert(sue.try_depositSenior(address(ITO), amount_USDT, USDT));

        // 2 ("jim", "joe") into only junior tranche.
        assert(jim.try_depositJunior(address(ITO), amount_DAI, DAI));
        assert(jim.try_depositJunior(address(ITO), amount_FRAX, FRAX));
        assert(jim.try_depositJunior(address(ITO), amount_USDC, USDC));
        assert(jim.try_depositJunior(address(ITO), amount_USDT, USDT));
        assert(joe.try_depositJunior(address(ITO), amount_DAI, DAI));
        assert(joe.try_depositJunior(address(ITO), amount_FRAX, FRAX));
        assert(joe.try_depositJunior(address(ITO), amount_USDC, USDC));
        assert(joe.try_depositJunior(address(ITO), amount_USDT, USDT));

        // 4 ("sal", "sid", "jon", "jen") into both tranches.
        assert(sal.try_depositSenior(address(ITO), amount_DAI, DAI));
        assert(sal.try_depositJunior(address(ITO), amount_FRAX, FRAX));
        assert(sal.try_depositSenior(address(ITO), amount_USDC, USDC));
        assert(sal.try_depositJunior(address(ITO), amount_USDT, USDT));
        
        assert(sid.try_depositJunior(address(ITO), amount_DAI, DAI));
        assert(sid.try_depositSenior(address(ITO), amount_FRAX, FRAX));
        assert(sid.try_depositJunior(address(ITO), amount_USDC, USDC));
        assert(sid.try_depositSenior(address(ITO), amount_USDT, USDT));
        
        assert(jon.try_depositSenior(address(ITO), amount_DAI, DAI));
        assert(jon.try_depositJunior(address(ITO), amount_FRAX, FRAX));
        assert(jon.try_depositJunior(address(ITO), amount_USDC, USDC));
        assert(jon.try_depositSenior(address(ITO), amount_USDT, USDT));
        
        assert(jen.try_depositJunior(address(ITO), amount_DAI, DAI));
        assert(jen.try_depositSenior(address(ITO), amount_FRAX, FRAX));
        assert(jen.try_depositSenior(address(ITO), amount_USDC, USDC));
        assert(jen.try_depositJunior(address(ITO), amount_USDT, USDT));

        hevm.warp(ITO.end() + 1 seconds);
        
        ITO.migrateDeposits();

    }

    /// @notice Stakes all tokens possible.
    function stakeTokens() public {
        
        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        assert(sue.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sue))));
        assert(sal.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sal))));
        assert(sid.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sid))));
        assert(jim.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim))));
        assert(joe.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(joe))));
        assert(jon.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jon))));
        assert(jen.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jen))));

        assert(sam.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam))));
        assert(sue.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sue))));
        assert(sal.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sal))));
        assert(sid.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sid))));
        assert(jim.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(jim))));
        assert(joe.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(joe))));
        assert(jon.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(jon))));
        assert(jen.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(jen))));

        assert(sam.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sam))));
        assert(sue.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sue))));
        assert(sal.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sal))));
        assert(sid.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sid))));
        assert(jim.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim))));
        assert(joe.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(joe))));
        assert(jon.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jon))));
        assert(jen.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jen))));
    
        assert(sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        assert(sue.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sue))));
        assert(sal.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sal))));
        assert(sid.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sid))));
        assert(jim.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim))));
        assert(joe.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(joe))));
        assert(jon.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jon))));
        assert(jen.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jen))));
        
        assert(sam.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam))));
        assert(sue.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sue))));
        assert(sal.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sal))));
        assert(sid.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sid))));
        // Note: "jim", "joe" did not invest into Senior tranche.
        // assert(jim.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(jim))));
        // assert(joe.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(joe))));
        assert(jon.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(jon))));
        assert(jen.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(jen))));

        // Note: "sam", "sue" did not invest into Junior tranche.
        // assert(sam.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sam))));
        // assert(sue.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sue))));
        assert(sal.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sal))));
        assert(sid.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sid))));
        assert(jim.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim))));
        assert(joe.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(joe))));
        assert(jon.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jon))));
        assert(jen.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jen))));
    }

    /// @notice Claims tokens from ITO ($ZVE, $zJTT, $zSTT) and stakes them.
    function claimITO_and_approveTokens_and_stakeTokens(bool stake) public {

        require(ITO.migrated());

        assert(sam.try_claim(address(ITO)));
        assert(sue.try_claim(address(ITO)));
        assert(sal.try_claim(address(ITO)));
        assert(sid.try_claim(address(ITO)));
        assert(jim.try_claim(address(ITO)));
        assert(joe.try_claim(address(ITO)));
        assert(jon.try_claim(address(ITO)));
        assert(jen.try_claim(address(ITO)));

        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        assert(sue.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sue))));
        assert(sal.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sal))));
        assert(sid.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sid))));
        assert(jim.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim))));
        assert(joe.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(joe))));
        assert(jon.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jon))));
        assert(jen.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jen))));

        assert(sam.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam))));
        assert(sue.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sue))));
        assert(sal.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sal))));
        assert(sid.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sid))));
        assert(jim.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(jim))));
        assert(joe.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(joe))));
        assert(jon.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(jon))));
        assert(jen.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(jen))));

        assert(sam.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sam))));
        assert(sue.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sue))));
        assert(sal.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sal))));
        assert(sid.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sid))));
        assert(jim.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim))));
        assert(joe.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(joe))));
        assert(jon.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jon))));
        assert(jen.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jen))));

        if (stake) {
            assert(sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
            assert(sue.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sue))));
            assert(sal.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sal))));
            assert(sid.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sid))));
            assert(jim.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim))));
            assert(joe.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(joe))));
            assert(jon.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jon))));
            assert(jen.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jen))));
            
            assert(sam.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam))));
            assert(sue.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sue))));
            assert(sal.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sal))));
            assert(sid.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sid))));
            // Note: "jim", "joe" did not invest into Senior tranche.
            // assert(jim.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(jim))));
            // assert(joe.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(joe))));
            assert(jon.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(jon))));
            assert(jen.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(jen))));

            // Note: "sam", "sue" did not invest into Junior tranche.
            // assert(sam.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sam))));
            // assert(sue.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sue))));
            assert(sal.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sal))));
            assert(sid.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sid))));
            assert(jim.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim))));
            assert(joe.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(joe))));
            assert(jon.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jon))));
            assert(jen.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jen))));
        }
        
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
            "ZivoeSeniorTrancheToken",
            "zSTT"
        );

        zJTT = new ZivoeTrancheToken(
            "ZivoeJuniorTrancheToken",
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
        ZVT.transferOwnership(address(DAO));

        // "jay" MUST transfer 5% of ZVE tokens to ZVT.
        jay.transferToken(address(ZVE), address(ZVT), ZVE.totalSupply() * 5 / 100);

        // zJTT.owner() MUST give ZVT minting priviliges.
        // zSTT.owner() MUST give ZVT minting priviliges.
        zJTT.changeMinterRole(address(ZVT), true);
        zSTT.changeMinterRole(address(ZVT), true);

        // Note: At this point, zJTT / zSTT MUST not give minting priviliges to any other contract (ever).
        
        // zJTT.owner() MUST renounce ownership.
        // zSTT.owner() MUST renounce onwership.
        zJTT.renounceOwnership();
        zSTT.renounceOwnership();


        // Step #8 --- Deploy zSTT/zJTT/ZVE staking contracts, through ZivoeRewards.sol.

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


        // Step #9 --- Deploy ZivoeYDL.sol.

        YDL = new ZivoeYDL(
            address(GBL),
            DAI
        );

        // YDL.owner() MUST transer ownership to governance contract ("god").
        YDL.transferOwnership(address(god));


        // Step #10 --- Deploy ZivoeRewardsVesting.sol.

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

        // "zvl" MUST add ZVT to the isLocker whitelist.
        assert(zvl.try_updateIsLocker(address(GBL), address(ZVT), true));

        // Note: This completes the deployment of the core-protocol and facilitates
        //       the addition of a single locker (ZVT) to the whitelist.
        //       From here, the ITO will commence in 3 days (approx.) and last for
        //       exactly 30 days. To simulate this, we use simulateITO().

        // simulateDepositsCoreUtility(1000000, 1000000);

    }

    function stakeTokensHalf() public {

        // "jim" added to Junior tranche.
        jim.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim)));
        jim.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim)));
        jim.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim)) / 2);
        jim.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim)) / 2);

        // "sam" added to Senior tranche.
        sam.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)));
        sam.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
        sam.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)) / 2);
        sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)) / 2);
    }

    function stakeTokensFull() public {

        // "jim" added to Junior tranche.
        jim.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim)));
        jim.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim)));
        jim.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim)));
        jim.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim)));

        // "sam" added to Senior tranche.
        sam.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)));
        sam.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
        sam.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)));
        sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
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
        // "jim" => depositJunior()
        // ------------------------

        mint("DAI",  address(jim), juniorDeposit * 1 ether);
        mint("USDC", address(jim), juniorDeposit * USD);
        mint("USDT", address(jim), juniorDeposit * USD);

        assert(jim.try_approveToken(DAI,  address(ITO), juniorDeposit * 1 ether));
        assert(jim.try_approveToken(USDC, address(ITO), juniorDeposit * USD));
        assert(jim.try_approveToken(USDT, address(ITO), juniorDeposit * USD));

        assert(jim.try_depositJunior(address(ITO), juniorDeposit * 1 ether, address(DAI)));
        assert(jim.try_depositJunior(address(ITO), juniorDeposit * USD, address(USDC)));
        assert(jim.try_depositJunior(address(ITO), juniorDeposit * USD, address(USDT)));

        // Warp to end of ITO, call migrateDeposits() to ensure ZivoeDAO.sol receives capital.
        hevm.warp(ITO.end() + 1);
        ITO.migrateDeposits();

        // Have "jim" and "sam" claim their tokens from the contract.
        jim.try_claim(address(ITO));
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
