// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

import { IZivoeGlobals, ICRVDeployer, ICRVMetaPool, ICRVPlainPoolFBP } from "../../misc/InterfacesAggregated.sol";

// NOTE: This contract is considered defunct, no intention to use CRV for $ZVE secondary market purposes.
// NOTE: This contract is maintained in the repository for future reference and implementation purposes.

contract OCL_ZVE_CRV_0 is ZivoeLocker {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public constant CRV_Deployer = 0xB9fC157394Af804a3578134A6585C0dc9cc990d4;  /// @dev CRV.FI deployer for meta-pools.
    address public constant FBP_BP = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;        /// @dev FRAX BasePool (FRAX/USDC) for CRV Finance.
    address public constant FBP_TOKEN = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;     /// @dev Frax BasePool LP token address.
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;          /// @dev The FRAX stablecoin.
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;          /// @dev The USDC stablecoin.

    address public ZVE_MP;          /// @dev To be determined upon pool deployment via constructor().
    address public immutable GBL;   /// @dev The ZivoeGlobals contract.

    uint256 public baseline;                /// @dev FRAX convertible, used for forwardYield() accounting.
    uint256 public nextYieldDistribution;   /// @dev Determines next available forwardYield() call.
    
    // -----------
    // Constructor
    // -----------

    /// @notice Initializes the OCL_ZVE_CRV_0.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The ZivoeGlobals contract.
    constructor(
        address DAO,
        address _GBL
    ) {
        transferOwnership(DAO);
        GBL = _GBL;
        ZVE_MP = ICRVDeployer(CRV_Deployer).deploy_metapool(
            FBP_BP,                     /// The base-pool (FBP = FraxBasePool).
            "ZVE_MetaPool_FBP",         /// Name of meta-pool.
            "ZVE/FBP",                  /// Symbol of meta-pool.
            IZivoeGlobals(_GBL).ZVE(),  /// Coin paired with base-pool. ($ZVE).
            250,                        /// Amplifier.
            20000000                    /// 0.20% fee.
        );
    }

    // ---------
    // Functions
    // ---------

    function canPullPartial() public override pure returns (bool) {
        return true;
    }

    function canPushMulti() public override pure returns (bool) {
        return true;
    }

    function canPullMulti() public override pure returns (bool) {
        return true;
    }

    /// @dev    This pulls capital from the DAO, does any necessary pre-conversions, and adds liquidity into ZVE MetaPool.
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) external override onlyOwner {
        require(
            (assets[0] == FRAX || assets[0] == USDC) && assets[1] == IZivoeGlobals(GBL).ZVE(),
            "OCL_ZVE_CRV_0::pushToLockerMulti() (assets[0] != FRAX && assets[0] == USDC) || assets[1] != IZivoeGlobals(GBL).ZVE()"
        );

        for (uint256 i = 0; i < 2; i++) {
            IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
        }
        if (nextYieldDistribution == 0) {
            nextYieldDistribution = block.timestamp + 30 days;
        }
        uint256 preBaseline;
        if (baseline != 0) {
            (preBaseline,) = FRAXConvertible();
        }
        // FRAX || USDC, BasePool Deposit
        // FBP.coins(0) == FRAX
        // FBP.coins(1) == USDC
        if (assets[0] == FRAX) {
            IERC20(FRAX).safeApprove(FBP_BP, IERC20(FRAX).balanceOf(address(this)));
            uint256[2] memory deposits_bp;
            deposits_bp[0] = IERC20(FRAX).balanceOf(address(this));
            ICRVPlainPoolFBP(FBP_BP).add_liquidity(deposits_bp, 0);
        }
        else {
            IERC20(USDC).safeApprove(FBP_BP, IERC20(USDC).balanceOf(address(this)));
            uint256[2] memory deposits_bp;
            deposits_bp[1] = IERC20(USDC).balanceOf(address(this));
            ICRVPlainPoolFBP(FBP_BP).add_liquidity(deposits_bp, 0);
        }
        // FBP && ZVE, MetaPool Deposit
        // ZVE_MP.coins(0) == ZVE
        // ZVE_MP.coins(1) == FBP
        IERC20(FBP_TOKEN).safeApprove(ZVE_MP, IERC20(FBP_TOKEN).balanceOf(address(this)));
        IERC20(IZivoeGlobals(GBL).ZVE()).safeApprove(ZVE_MP, IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        uint256[2] memory deposits_mp;
        deposits_mp[0] = IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this));
        deposits_mp[1] = IERC20(FBP_TOKEN).balanceOf(address(this));
        ICRVMetaPool(ZVE_MP).add_liquidity(deposits_mp, 0);
        // Increase baseline.
        (uint256 postBaseline,) = FRAXConvertible();
        require(postBaseline > preBaseline, "OCL_ZVE_CRV_0::pushToLockerMulti() postBaseline < preBaseline");
        baseline = postBaseline - preBaseline;
    }

    /// @dev    This burns LP tokens from the ZVE MetaPool, and returns resulting coins back to the DAO.
    /// @param  assets The assets to return.
    function pullFromLockerMulti(address[] calldata assets) external override onlyOwner {
        require(
            assets[0] == USDC && assets[1] == FRAX && assets[2] == IZivoeGlobals(GBL).ZVE(),
            "OCL_ZVE_CRV_0::pullFromLockerMulti() assets[0] != USDC || assets[1] != FRAX || assets[2] != IZivoeGlobals(GBL).ZVE()"
        );

        uint256[2] memory tester;
        ICRVMetaPool(ZVE_MP).remove_liquidity(
            IERC20(ZVE_MP).balanceOf(address(this)), tester
        );
        ICRVPlainPoolFBP(FBP_BP).remove_liquidity(
            IERC20(FBP_TOKEN).balanceOf(address(this)), tester
        );
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
        IERC20(FRAX).safeTransfer(owner(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(IZivoeGlobals(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        baseline = 0;
    }

    /// @dev    This burns a partial amount of LP tokens from the ZVE MetaPool, and returns resulting coins back to the DAO.
    /// @param  asset The LP token to burn.
    /// @param  amount The amount of LP tokens to burn.
    function pullFromLockerPartial(address asset, uint256 amount) external override onlyOwner {
        require(asset == ZVE_MP, "OCL_ZVE_CRV_0::pullFromLockerPartial() assets != ZVE_MP");

        uint256[2] memory tester;
        ICRVMetaPool(ZVE_MP).remove_liquidity(
            amount, tester
        );
        ICRVPlainPoolFBP(FBP_BP).remove_liquidity(
            IERC20(FBP_TOKEN).balanceOf(address(this)), tester
        );
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
        IERC20(FRAX).safeTransfer(owner(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(IZivoeGlobals(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        baseline = 0;
    }

    /// @dev    This forwards yield to the YDL.
    function forwardYield() external {
        if (IZivoeGlobals(GBL).isKeeper(_msgSender())) {
            require(
                block.timestamp > nextYieldDistribution - 12 hours, 
                "OCL_ZVE_CRV_0::forwardYield() block.timestamp <= nextYieldDistribution - 12 hours"
            );
        }
        else {
            require(block.timestamp > nextYieldDistribution, "OCL_ZVE_CRV_0::forwardYield() block.timestamp <= nextYieldDistribution");
        }
        (uint256 amount, uint256 lp) = FRAXConvertible();
        require(amount > baseline, "OCL_ZVE_CRV_0::forwardYield() amount <= baseline");
        nextYieldDistribution = block.timestamp + 30 days;
        _forwardYield(amount, lp);
    }

    /// @dev Returns information on how much FRAX is convertible via current LP tokens.
    /// @return amount Current FRAX harvestable.
    /// @return lp Current ZVE_MP tokens.
    /// @notice The withdrawal mechanism is ZVE_MP => FBP => Frax.
    function FRAXConvertible() public view returns (uint256 amount, uint256 lp) {
        lp = IERC20(ZVE_MP).balanceOf(address(this));
        amount = ICRVPlainPoolFBP(FBP_BP).calc_withdraw_one_coin(
            ICRVMetaPool(ZVE_MP).calc_withdraw_one_coin(lp, int128(1)), int128(0)
        );
    }

    function _forwardYield(uint256 amount, uint256 lp) private {
        uint256 lpBurnable = (amount - baseline) * lp / amount / 2; 
        ICRVMetaPool(ZVE_MP).remove_liquidity_one_coin(lpBurnable, 1, 0);
        ICRVPlainPoolFBP(FBP_BP).remove_liquidity_one_coin(IERC20(FBP_TOKEN).balanceOf(address(this)), int128(0), 0);
        IERC20(FRAX).safeTransfer(IZivoeGlobals(GBL).YDL(), IERC20(FRAX).balanceOf(address(this)));
        (baseline,) = FRAXConvertible();
    }

}
