// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

import "../Utility/ZivoeSwapper.sol";

import { IZivoeGlobals, ISushiRouter, ISushiFactory } from "../../misc/InterfacesAggregated.sol";

interface IZivoeGlobals_P_4 {
    function YDL() external view returns (address);
    function isKeeper(address) external view returns (bool);
}

interface IZivoeYDL_P_3 {
    function distributedAsset() external view returns (address);
}

/// @dev    This contract manages liquidity provisioning for a Sushi $ZVE/pairAsset pool.
///         This contract has the following responsibilities:
///           - Allocate capital to a Sushi $ZVE/pairAsset pool.
///           - Remove capital from a Sushi $ZVE/pairAsset pool.
///           - Forward yield (profits) every 30 days to the YDL with compounding mechanisms.
contract OCL_ZVE_SUSHI is ZivoeLocker, ZivoeSwapper {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    address constant public SUSHI_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address constant public SUSHI_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    
    address public immutable GBL;               /// @dev Zivoe globals contract.

    address public pairAsset;                   /// @dev ERC20 that will be paired with $ZVE for Sushi pool.

    uint256 public baseline;                    /// @dev FRAX convertible, used for forwardYield() accounting.
    uint256 public nextYieldDistribution;       /// @dev Determines next available forwardYield() call.
    uint256 public amountForConversion;         /// @dev The amount of stablecoin in this contract convertible and forwardable to YDL.

    uint256 public compoundingRateBIPS = 5000;  /// @dev The % of returns to retain, in BIPS.

    uint256 private constant BIPS = 10000;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCL_ZVE_SUSHI.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The Zivoe globals contract.
    /// @param _pairAsset ERC20 that will be paired with $ZVE for SUSHI pool.
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

    /// @dev    This pulls capital from the DAO and adds liquidity into a Sushi ZVE/pairAsset pool.
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) external override onlyOwner {
        require(
            assets[0] == pairAsset && assets[1] == IZivoeGlobals(GBL).ZVE(),
            "OCL_ZVE_SUSHI::pushToLockerMulti() assets[0] != pairAsset || assets[1] != IZivoeGlobals(GBL).ZVE()"
        );

        for (uint i = 0; i < 2; i++) {
            require(amounts[i] >= 10 * 10**6, "OCL_ZVE_SUSHI::pushToLockerMulti() amounts[i] < 10 * 10**6");
            IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
        }

        if (nextYieldDistribution == 0) {
            nextYieldDistribution = block.timestamp + 30 days;
        }

        uint256 preBaseline;
        if (baseline != 0) {
            (preBaseline,) = pairAssetConvertible();
        }

        // SushiRouter, addLiquidity()
        IERC20(pairAsset).safeApprove(SUSHI_ROUTER, IERC20(pairAsset).balanceOf(address(this)));
        IERC20(IZivoeGlobals(GBL).ZVE()).safeApprove(SUSHI_ROUTER, IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        ISushiRouter(SUSHI_ROUTER).addLiquidity(
            pairAsset, 
            IZivoeGlobals(GBL).ZVE(), 
            IERC20(pairAsset).balanceOf(address(this)),
            IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)),
            IERC20(pairAsset).balanceOf(address(this)),
            IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)),
            address(this),
            block.timestamp + 14 days
        );
        assert(IERC20(pairAsset).allowance(address(this), SUSHI_ROUTER) == 0);
        assert(IERC20(IZivoeGlobals(GBL).ZVE()).allowance(address(this), SUSHI_ROUTER) == 0);

        // Increase baseline.
        (uint256 postBaseline,) = pairAssetConvertible();
        require(postBaseline > preBaseline, "OCL_ZVE_SUSHI::pushToLockerMulti() postBaseline < preBaseline");
        baseline = postBaseline - preBaseline;
    }

    /// @dev    This burns LP tokens from the Sushi ZVE/pairAsset pool and returns them to the DAO.
    /// @param  asset The asset to burn.
    function pullFromLocker(address asset) external override onlyOwner {
        address pair = ISushiFactory(SUSHI_FACTORY).getPair(pairAsset, IZivoeGlobals(GBL).ZVE());
        
        if (asset == pair) {
            IERC20(pair).safeApprove(SUSHI_ROUTER, IERC20(pair).balanceOf(address(this)));
            ISushiRouter(SUSHI_ROUTER).removeLiquidity(
                pairAsset, 
                IZivoeGlobals(GBL).ZVE(), 
                IERC20(pair).balanceOf(address(this)), 
                0, 
                0,
                address(this),
                block.timestamp + 14 days
            );
            assert(IERC20(pair).allowance(address(this), SUSHI_ROUTER) == 0);

            IERC20(pairAsset).safeTransfer(owner(), IERC20(pairAsset).balanceOf(address(this)));
            IERC20(IZivoeGlobals(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
            baseline = 0;
        }
        else if (asset == pairAsset) {
            IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
            amountForConversion = 0;
        }
        else {
            IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
        }
    }

    /// @dev    This burns LP tokens from the Sushi ZVE/pairAsset pool and returns them to the DAO.
    /// @param  asset The asset to burn.
    /// @param  amount The amount of "asset" to burn.
    function pullFromLockerPartial(address asset, uint256 amount) external override onlyOwner {
        address pair = ISushiFactory(SUSHI_FACTORY).getPair(pairAsset, IZivoeGlobals(GBL).ZVE());
        
        if (asset == pair) {
            IERC20(pair).safeApprove(SUSHI_ROUTER, amount);
            ISushiRouter(SUSHI_ROUTER).removeLiquidity(
                pairAsset, 
                IZivoeGlobals(GBL).ZVE(), 
                amount, 
                0, 
                0,
                address(this),
                block.timestamp + 14 days
            );
            assert(IERC20(pair).allowance(address(this), SUSHI_ROUTER) == 0);
            
            IERC20(pairAsset).safeTransfer(owner(), IERC20(pairAsset).balanceOf(address(this)));
            IERC20(IZivoeGlobals(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
            (baseline,) = pairAssetConvertible();
        }
        else if (asset == pairAsset) {
            IERC20(asset).safeTransfer(owner(), amount);
            amountForConversion = IERC20(pairAsset).balanceOf(address(this));
        }
        else {
            IERC20(asset).safeTransfer(owner(), amount);
        }
    }

    /// @notice Updates the compounding rate of this contract.
    /// @dev    A value of 2,000 represent 20% of the earnings stays in this contract, compounding.
    /// @param  _compoundingRateBIPS The new compounding rate value.
    function updateCompoundingRateBIPS(uint256 _compoundingRateBIPS) external {
        require(_msgSender() == IZivoeGlobals(GBL).TLC(), "OCL_ZVE_SUSHI::updateCompoundingRateBIPS() _msgSender() != IZivoeGlobals(GBL).TLC()");
        require(_compoundingRateBIPS <= 10000, "OCL_ZVE_SUSHI::updateCompoundingRateBIPS() ratio > 10000");
        emit UpdatedCompoundingRateBIPS(compoundingRateBIPS, _compoundingRateBIPS);
        compoundingRateBIPS = _compoundingRateBIPS;
    }

    /// @dev    This forwards yield to the YDL in the form of pairAsset.
    function forwardYield() external {
        if (IZivoeGlobals(GBL).isKeeper(_msgSender())) {
            require(
                block.timestamp > nextYieldDistribution - 12 hours, 
                "OCL_ZVE_SUSHI::forwardYield() block.timestamp <= nextYieldDistribution - 12 hours"
            );
        }
        else {
            require(block.timestamp > nextYieldDistribution, "OCL_ZVE_SUSHI::forwardYield() block.timestamp <= nextYieldDistribution");
        }
        (uint256 amt, uint256 lp) = pairAssetConvertible();
        require(amt > baseline, "OCL_ZVE_SUSHI::forwardYield() amt <= baseline");
        nextYieldDistribution = block.timestamp + 30 days;
        _forwardYield(amt, lp);
    }

    /// @dev Returns information on how much pairAsset is convertible via current LP tokens.
    /// @return amt Current pairAsset harvestable.
    /// @return lp Current ZVE/pairAsset LP tokens.
    /// @notice The withdrawal mechanism is ZVE/pairAsset_LP => pairAsset.
    function pairAssetConvertible() public view returns (uint256 amt, uint256 lp) {
        address pair = ISushiFactory(SUSHI_FACTORY).getPair(pairAsset, IZivoeGlobals(GBL).ZVE());
        uint256 balance_pairAsset = IERC20(pairAsset).balanceOf(pair);
        uint256 totalSupply_PAIR = IERC20(pair).totalSupply();
        lp = IERC20(pair).balanceOf(address(this));
        amt = lp * balance_pairAsset / totalSupply_PAIR;
    }

    function _forwardYield(uint256 amt, uint256 lp) private {
        uint256 lpBurnable = (amt - baseline) * lp / amt * compoundingRateBIPS / 10000;
        address pair = ISushiFactory(SUSHI_FACTORY).getPair(pairAsset, IZivoeGlobals(GBL).ZVE());
        IERC20(pair).safeApprove(SUSHI_ROUTER, lpBurnable);
        ISushiRouter(SUSHI_ROUTER).removeLiquidity(
            pairAsset,
            IZivoeGlobals(GBL).ZVE(),
            lpBurnable,
            0,
            0,
            address(this),
            block.timestamp + 14 days
        );
        assert(IERC20(pair).allowance(address(this), SUSHI_ROUTER) == 0);
        if (pairAsset != IZivoeYDL_P_3(IZivoeGlobals_P_4(GBL).YDL()).distributedAsset()) {
            amountForConversion = IERC20(pairAsset).balanceOf(address(this));
        }
        else {
            IERC20(pairAsset).safeTransfer(IZivoeGlobals(GBL).YDL(), IERC20(pairAsset).balanceOf(address(this)));
        }
        IERC20(IZivoeGlobals(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)));
        (baseline,) = pairAssetConvertible();
    }

    /// @dev This function converts and forwards available "amountForConversion" to YDL.distributeAsset().
    function forwardYieldKeeper(bytes calldata data) external {
        require(IZivoeGlobals_P_4(GBL).isKeeper(_msgSender()), "OCL_ZVE_SUSHI::forwardYieldKeeper() !IZivoeGlobals_P_4(GBL).isKeeper(_msgSender())");
        address _toAsset = IZivoeYDL_P_3(IZivoeGlobals_P_4(GBL).YDL()).distributedAsset();
        require(_toAsset != pairAsset, "OCL_ZVE_SUSHI::forwardInterestKeeper() _toAsset == pairAsset");

        // Swap available "amountForConversion" from stablecoin to YDL.distributedAsset().
        convertAsset(pairAsset, _toAsset, amountForConversion, data);

        // Transfer all _toAsset received to the YDL, then reduce amountForConversion to 0.
        IERC20(_toAsset).safeTransfer(IZivoeGlobals_P_4(GBL).YDL(), IERC20(_toAsset).balanceOf(address(this)));
        amountForConversion = 0;
    }

}