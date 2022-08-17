// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "../ZivoeLocker.sol";

import { IZivoeGBL, ICRVDeployer, ICRVMetaPool, ICRVPlainPool3CRV } from "../interfaces/InterfacesAggregated.sol";


contract OCL_ZVE_CRV_1 is ZivoeLocker {
    
    // ---------------
    // State Variables
    // ---------------

    address public constant CRV_Deployer = 0xB9fC157394Af804a3578134A6585C0dc9cc990d4;  /// @dev CRV.FI deployer for meta-pools.
    address public constant _3CRV_BP = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;      /// @dev 3CRV 3Pool (DAI/USDC/USDT) for CRV Finance.
    address public constant _3CRV_TOKEN = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;   /// @dev 3CRV 3Pool LP token address.
    address public constant FRAX_3CRV_MP = 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B;  /// @dev 3CRV 3Pool LP token address.
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;           /// @dev The USDC stablecoin.
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;          /// @dev The FRAX stablecoin.
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;          /// @dev The USDC stablecoin.
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;          /// @dev The USDC stablecoin.

    address public ZVE_MP;      /// @dev To be determined upon pool deployment via constructor().
    address public GBL;         /// @dev Zivoe globals.

    uint256 public baseline;                /// @dev FRAX convertible, used for forwardYield() accounting.
    uint256 public nextYieldDistribution;   /// @dev Determines next available forwardYield() call.
    
    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the OCL_ZVE_CRV_0.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.
    constructor(
        address DAO,
        address _GBL
    ) {
        transferOwnership(DAO);
        GBL = _GBL;
        ZVE_MP = ICRVDeployer(CRV_Deployer).deploy_metapool(
            _3CRV_BP,                   /// The base-pool (3CRV = 3Pool).
            "ZVE_MetaPool_3CRV",        /// Name of meta-pool.
            "ZVE/3CRV",                 /// Symbol of meta-pool.
            IZivoeGBL(_GBL).ZVE(),      /// Coin paired with base-pool. ($ZVE).
            250,                        /// Amplifier, TODO: Research optimal value.
            20000000                    /// 0.20% fee.
        );
    }



    // ------
    // Events
    // ------

    event Debug(address);
    event Debug(uint256[]);
    event Debug(uint256);
    event Debug(string);

    // ---------
    // Functions
    // ---------

    function canPushMulti() external pure override returns(bool) {
        return true;
    }

    function canPullMulti() external pure override returns(bool) {
        return true;
    }

    /// @dev    This pulls capital from the DAO, does any necessary pre-conversions, and adds liquidity into ZVE MetaPool.
    /// @notice Only callable by the DAO.
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) public override onlyOwner {
        require((assets[0] == DAI || assets[0] == USDC || assets[0] == USDT) && assets[1] == IZivoeGBL(GBL).ZVE());
        for (uint i = 0; i < 2; i++) {
            IERC20(assets[i]).transferFrom(owner(), address(this), amounts[i]);
        }
        if (nextYieldDistribution == 0) {
            nextYieldDistribution = block.timestamp + 30 days;
        }
        uint256 preBaseline;
        if (baseline != 0) {
            (preBaseline,) = _FRAXConvertible();
        }
        // DAI || USDC || USDT, BasePool Deposit
        // 3CRV.coins(0) == DAI
        // 3CRV.coins(1) == USDC
        // 3CRV.coins(2) == USDT
        if (assets[0] == DAI) {
            IERC20(DAI).approve(_3CRV_BP, IERC20(DAI).balanceOf(address(this)));
            uint256[3] memory deposits_bp;
            deposits_bp[0] = IERC20(DAI).balanceOf(address(this));
            ICRVPlainPool3CRV(_3CRV_BP).add_liquidity(deposits_bp, 0);
        }
        else if (assets[0] == USDC) {
            IERC20(USDC).approve(_3CRV_BP, IERC20(USDC).balanceOf(address(this)));
            uint256[3] memory deposits_bp;
            deposits_bp[1] = IERC20(USDC).balanceOf(address(this));
            ICRVPlainPool3CRV(_3CRV_BP).add_liquidity(deposits_bp, 0);
        }
        else {
            IERC20(USDT).approve(_3CRV_BP, IERC20(USDT).balanceOf(address(this)));
            uint256[3] memory deposits_bp;
            deposits_bp[2] = IERC20(USDT).balanceOf(address(this));
            ICRVPlainPool3CRV(_3CRV_BP).add_liquidity(deposits_bp, 0);
        }
        // 3CRV && ZVE, MetaPool Deposit
        // ZVE_MP.coins(0) == ZVE
        // ZVE_MP.coins(1) == 3CRV
        IERC20(_3CRV_TOKEN).approve(ZVE_MP, IERC20(_3CRV_TOKEN).balanceOf(address(this)));
        IERC20(IZivoeGBL(GBL).ZVE()).approve(ZVE_MP, IERC20(IZivoeGBL(GBL).ZVE()).balanceOf(address(this)));
        uint256[2] memory deposits_mp;
        deposits_mp[0] = IERC20(IZivoeGBL(GBL).ZVE()).balanceOf(address(this));
        deposits_mp[1] = IERC20(_3CRV_TOKEN).balanceOf(address(this));
        ICRVMetaPool(ZVE_MP).add_liquidity(deposits_mp, 0);
        // Increase baseline.
        (uint256 postBaseline,) = _FRAXConvertible();
        require(postBaseline > preBaseline);
        baseline = postBaseline - preBaseline;
    }

    /// @dev    This burns LP tokens from the ZVE MetaPool, and returns resulting coins back to the DAO.
    /// @notice Only callable by the DAO.
    /// @param  assets The assets to return.
    function pullFromLockerMulti(address[] calldata assets) public override onlyOwner {
        // TODO: Consider need for "key"-like activation/approval of withdrawal below.
        require(assets[0] == DAI && assets[1] == USDC && assets[2] == USDT && assets[3] == IZivoeGBL(GBL).ZVE());
        uint256[2] memory tester;
        uint256[3] memory tester2;
        ICRVMetaPool(ZVE_MP).remove_liquidity(
            IERC20(ZVE_MP).balanceOf(address(this)), tester
        );
        ICRVPlainPool3CRV(_3CRV_BP).remove_liquidity(
            IERC20(_3CRV_TOKEN).balanceOf(address(this)), tester2
        );
        IERC20(DAI).transfer(owner(), IERC20(DAI).balanceOf(address(this)));
        IERC20(USDC).transfer(owner(), IERC20(USDC).balanceOf(address(this)));
        IERC20(USDT).transfer(owner(), IERC20(USDT).balanceOf(address(this)));
        IERC20(IZivoeGBL(GBL).ZVE()).transfer(owner(), IERC20(IZivoeGBL(GBL).ZVE()).balanceOf(address(this)));
        baseline = 0;
    }

    /// @dev    This forwards yield to the YDL (according to specific conditions as will be discussed).
    function forwardYield() public {
        require(block.timestamp > nextYieldDistribution);
        (uint256 amt, uint256 lp) = _FRAXConvertible();
        require(amt > baseline);
        nextYieldDistribution = block.timestamp + 30 days;
        _forwardYield(amt, lp);
    }

    function _forwardYield(uint256 amt, uint256 lp) private {
        uint256 lpBurnable = (amt - baseline) * lp / amt / 2; 
        ICRVMetaPool(ZVE_MP).remove_liquidity_one_coin(lpBurnable, 1, 0);
        IERC20(_3CRV_TOKEN).approve(FRAX_3CRV_MP, IERC20(_3CRV_TOKEN).balanceOf(address(this)));
        ICRVMetaPool(FRAX_3CRV_MP).exchange(int128(1), int128(0), IERC20(_3CRV_TOKEN).balanceOf(address(this)), 0);
        IERC20(FRAX).transfer(IZivoeGBL(GBL).YDL(), IERC20(FRAX).balanceOf(address(this)));
        (baseline,) = _FRAXConvertible();
    }

    /// @dev Returns information on how much FRAX is convertible via current LP tokens.
    /// @return amt Current FRAX harvestable.
    /// @return lp Current ZVE_MP tokens. 
    function _FRAXConvertible() public view returns(uint256 amt, uint256 lp) {
        lp = IERC20(ZVE_MP).balanceOf(address(this));
        /// ZVE_3CRV_MP_TOKEN => 3CRV => Frax
        amt = ICRVMetaPool(FRAX_3CRV_MP).calc_withdraw_one_coin(
            ICRVMetaPool(ZVE_MP).calc_withdraw_one_coin(lp, int128(1)), int128(0)
        );
    }

}
