// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

import "../Utility/ZivoeSwapper.sol";

import { IZivoeGlobals, IUniswapV2Router01, IUniswapV2Factory } from "../../misc/InterfacesAggregated.sol";

/// @dev    This contract manages liquidity provisioning for a UniV2 $ZVE/pairAsset pool.
///         This contract has the following responsibilities:
///           - Allocate capital to a UniV2 $ZVE/pairAsset pool.
///           - Remove capital from a UniV2 $ZVE/pairAsset pool.
///           - Forward yield (profits) every 30 days to the YDL with compounding mechanisms.
contract OCL_ZVE_UNIV2 is ZivoeLocker, ZivoeSwapper {
    
    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    address constant public UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant public UNIV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    
    address public immutable GBL;               /// @dev Zivoe globals contract.

    address public pairAsset;                   /// @dev ERC20 that will be paired with $ZVE for UNIV2 pool.

    uint256 public baseline;                    /// @dev pairAsset convertible, used for forwardYield() accounting.
    uint256 public nextYieldDistribution;       /// @dev Determines next available forwardYield() call.
    uint256 public amountForConversion;         /// @dev The amount of stablecoin in this contract convertible and forwardable to YDL.

    uint256 public compoundingRateBIPS = 5000;  /// @dev The % of returns to retain, in BIPS.

    uint256 private constant BIPS = 10000;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCL_ZVE_UNIV2_0.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.
    /// @param _pairAsset ERC20 that will be paired with $ZVE for UNIV2 pool.
    constructor(
        address DAO,
        address _GBL,
        address _pairAsset
    ) {
        transferOwnership(DAO);
        GBL = _GBL;
        pairAsset = _pairAsset;
    }



    // ------------
    //    Events   
    // ------------

    /// @notice This event is emitted when updateCompoundingRateBIPS() is called.
    /// @param  oldValue The old value of compoundingRateBIPS.
    /// @param  newValue The new value of compoundingRateBIPS.
    event UpdatedCompoundingRateBIPS(uint256 oldValue, uint256 newValue);

    // TODO: Consider event logs here for yield distributions.



    // ---------------
    //    Functions
    // ---------------

    function canPushMulti() public override pure returns (bool) {
        return true;
    }

    function canPull() public override pure returns (bool) {
        return true;
    }

    function canPullPartial() public override pure returns (bool) {
        return true;
    }

    /// @dev    This pulls capital from the DAO and adds liquidity into a UniswapV2 ZVE/pairAsset pool.
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) external override onlyOwner {
        require(
            assets[0] == pairAsset && assets[1] == IZivoeGlobals(GBL).ZVE(),
            "OCL_ZVE_UNIV2::pushToLockerMulti() assets[0] != pairAsset || assets[1] != IZivoeGlobals(GBL).ZVE()"
        );

        for (uint i = 0; i < 2; i++) {
            IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
        }

        if (nextYieldDistribution == 0) {
            nextYieldDistribution = block.timestamp + 30 days;
        }

        uint256 preBaseline;
        if (baseline != 0) {
            (preBaseline,) = pairAssetConvertible();
        }

        // UniswapRouter, addLiquidity()
        // TODO: Enforce allowance == 0 after all safeApprove() instances.
        IERC20(pairAsset).safeApprove(UNIV2_ROUTER, IERC20(pairAsset).balanceOf(address(this)));
        IERC20(IZivoeGlobals(GBL).ZVE()).safeApprove(UNIV2_ROUTER, IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        IUniswapV2Router01(UNIV2_ROUTER).addLiquidity(
            pairAsset, 
            IZivoeGlobals(GBL).ZVE(), 
            IERC20(pairAsset).balanceOf(address(this)),
            IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)),
            IERC20(pairAsset).balanceOf(address(this)),
            IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)),
            address(this),
            block.timestamp + 14 days
        );

        // Increase baseline.
        (uint256 postBaseline,) = pairAssetConvertible();
        require(postBaseline > preBaseline, "OCL_ZVE_UNIV2::pushToLockerMulti() postBaseline < preBaseline");
        baseline = postBaseline - preBaseline;
    }

    /// @dev    This burns LP tokens from the Sushi ZVE/pairAsset pool and returns them to the DAO.
    /// @param  asset The asset to burn.
    function pullFromLocker(address asset) external override onlyOwner {
        address pair = IUniswapV2Factory(UNIV2_FACTORY).getPair(pairAsset, IZivoeGlobals(GBL).ZVE());
        require(asset == pair, "OCL_ZVE_UNIV2::pullFromLocker() asset != pair");
        
        // TODO: Enforce allowance == 0 after all safeApprove() instances.
        // TODO: Determine if we need safeApprove() here.
        IERC20(pair).safeApprove(UNIV2_ROUTER, IERC20(pairAsset).balanceOf(pair));
        IUniswapV2Router01(UNIV2_ROUTER).removeLiquidity(
            pairAsset, 
            IZivoeGlobals(GBL).ZVE(), 
            IERC20(pairAsset).balanceOf(pair), 
            0, 
            0,
            address(this),
            block.timestamp + 14 days
        );

        IERC20(pairAsset).safeTransfer(owner(), IERC20(pairAsset).balanceOf(address(this)));
        IERC20(IZivoeGlobals(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        baseline = 0;
    }

    /// @dev    This burns LP tokens from the UNIV2 ZVE/pairAsset pool and returns them to the DAO.
    /// @param  asset The asset to burn.
    /// @param  amount The amount of "asset" to burn.
    function pullFromLockerPartial(address asset, uint256 amount) external override onlyOwner {
        address pair = IUniswapV2Factory(UNIV2_FACTORY).getPair(pairAsset, IZivoeGlobals(GBL).ZVE());
        require(asset == pair, "OCL_ZVE_UNIV2::pullFromLockerPartial() asset != pair");
        
        // TODO: Enforce allowance == 0 after all safeApprove() instances.
        // TODO: Determine if we need safeApprove() here.
        IERC20(pair).safeApprove(UNIV2_ROUTER, amount);
        IUniswapV2Router01(UNIV2_ROUTER).removeLiquidity(
            pairAsset, 
            IZivoeGlobals(GBL).ZVE(), 
            amount, 
            0, 
            0,
            address(this),
            block.timestamp + 14 days
        );

        IERC20(pairAsset).safeTransfer(owner(), IERC20(pairAsset).balanceOf(address(this)));
        IERC20(IZivoeGlobals(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        (baseline,) = pairAssetConvertible();
    }

    /// @notice Updates the compounding rate of this contract.
    /// @dev    A value of 2,000 represent 20% of the earnings stays in this contract, compounding.
    /// @param  _compoundingRateBIPS The new compounding rate value.
    function updateCompoundingRateBIPS(uint256 _compoundingRateBIPS) external {
        require(_msgSender() == IZivoeGlobals(GBL).TLC(), "_msgSender() != IZivoeGlobals(GBL).TLC()");
        require(_compoundingRateBIPS <= 10000, "OCL_ZVE_UNIV2::updateCompoundingRateBIPS() ratio > 10000");
        emit UpdatedCompoundingRateBIPS(compoundingRateBIPS, _compoundingRateBIPS);
        compoundingRateBIPS = _compoundingRateBIPS;
    }

    /// @dev    This forwards yield to the YDL in the form of pairAsset.
    function forwardYield() external {
        if (IZivoeGlobals(GBL).isKeeper(_msgSender())) {
            require(
                block.timestamp > nextYieldDistribution - 12 hours, 
                "OCL_ZVE_UNIV2::forwardYield() block.timestamp <= nextYieldDistribution - 12 hours"
            );
        }
        else {
            require(block.timestamp > nextYieldDistribution, "OCL_ZVE_UNIV2::forwardYield() block.timestamp <= nextYieldDistribution");
        }
        (uint256 amt, uint256 lp) = pairAssetConvertible();
        require(amt > baseline, "OCL_ZVE_UNIV2::forwardYield() amt <= baseline");
        nextYieldDistribution = block.timestamp + 30 days;
        _forwardYield(amt, lp);
    }

    /// @dev Returns information on how much pairAsset is convertible via current LP tokens.
    /// @return amt Current pairAsset harvestable.
    /// @return lp Current ZVE/pairAsset LP tokens.
    /// @notice The withdrawal mechanism is ZVE/pairAsset_LP => pairAsset.
    function pairAssetConvertible() public view returns (uint256 amt, uint256 lp) {
        address pair = IUniswapV2Factory(UNIV2_FACTORY).getPair(pairAsset, IZivoeGlobals(GBL).ZVE());
        uint256 balance_pairAsset = IERC20(pairAsset).balanceOf(pair);
        uint256 totalSupply_PAIR = IERC20(pair).totalSupply();
        lp = IERC20(pair).balanceOf(address(this));
        amt = lp * balance_pairAsset / totalSupply_PAIR;
    }

    function _forwardYield(uint256 amt, uint256 lp) private {
        uint256 lpBurnable = (amt - baseline) * lp / amt * compoundingRateBIPS / 10000;
        address pair = IUniswapV2Factory(UNIV2_FACTORY).getPair(pairAsset, IZivoeGlobals(GBL).ZVE());
        // TODO: Enforce allowance == 0 after all safeApprove() instances.
        IERC20(pair).safeApprove(UNIV2_ROUTER, lpBurnable);
        IUniswapV2Router01(UNIV2_ROUTER).removeLiquidity(
            pairAsset,
            IZivoeGlobals(GBL).ZVE(),
            lpBurnable,
            0,
            0,
            address(this),
            block.timestamp + 14 days
        );
        IERC20(pairAsset).safeTransfer(IZivoeGlobals(GBL).YDL(), IERC20(pairAsset).balanceOf(address(this)));
        IERC20(IZivoeGlobals(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        (baseline,) = pairAssetConvertible();
    }

}