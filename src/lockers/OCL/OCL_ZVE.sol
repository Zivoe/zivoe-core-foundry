// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../ZivoeLocker.sol";

import "../Utility/ZivoeSwapper.sol";

interface IZivoeGlobals_OCL_ZVE {
    /// @notice Returns the address of the Timelock contract.
    function TLC() external view returns (address);

    /// @notice Returns the address of the ZivoeYDL.sol contract.
    function YDL() external view returns (address);

    /// @notice Returns the address of the ZivoeToken.sol contract.
    function ZVE() external view returns (address);

    /// @notice Returns true if an address is whitelisted as a keeper.
    /// @return keeper Equals "true" if address is a keeper, "false" if not.
    function isKeeper(address) external view returns (bool keeper);
}

interface IZivoeYDL_OCL_ZVE {
    /// @notice Returns the "stablecoin" that will be distributed via YDL.
    /// @return asset The address of the "stablecoin" that will be distributed via YDL.
    function distributedAsset() external view returns (address asset);
}

interface IRouter_OCL_ZVE {
    /// @notice Adds liquidity in a pool with both ERC20 tokens A and B.
    /// @param tokenA A pool token.
    /// @param tokenB A pool token.
    /// @param amountADesired The amount of tokenA to add as liquidity if the B/A price is <= amountBDesired/amountADesired (A depreciates).
    /// @param amountBDesired The amount of tokenB to add as liquidity if the A/B price is <= amountADesired/amountBDesired (B depreciates).
    /// @param amountAMin Bounds the extent to which the B/A price can go up before the transaction reverts. Must be <= amountADesired.
    /// @param amountBMin Bounds the extent to which the A/B price can go up before the transaction reverts. Must be <= amountBDesired.
    /// @param to Recipient of the liquidity tokens.
    /// @param deadline Unix timestamp after which the transaction will revert.
    /// @return amountA The amount of tokenA sent to the pool.
    /// @return amountB The amount of tokenB sent to the pool.
    /// @return liquidity The amount of liquidity tokens minted.
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Removes liquidity in a pool with both ERC20 tokens A and B.
    /// @param tokenA A pool token.
    /// @param tokenB A pool token.
    /// @param liquidity The amount of liquidity tokens to remove.
    /// @param amountAMin The minimum amount of tokenA that must be received for the transaction not to revert.
    /// @param amountBMin The minimum amount of tokenB that must be received for the transaction not to revert.
    /// @param to Recipient of the underlying assets.
    /// @param deadline Unix timestamp after which the transaction will revert.
    /// @return amountA The amount of tokenA received.
    /// @return amountB The amount of tokenB received.
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

interface IFactory_OCL_ZVE {
    /// @notice Returns the address of the pair for tokenA and tokenB, if it has been created, else address(0).
    /// @param tokenA Address of one of pair's tokens.
    /// @param tokenB Address of pair's other token.
    /// @return pair The address of the pair.
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}



/// @notice This contract manages liquidity provisioning for a Uniswap v2 or Sushi pool.
///         This contract has the following responsibilities:
///           - Allocate capital to a $ZVE/pairAsset pool.
///           - Remove capital from a $ZVE/pairAsset pool.
///           - Forward yield (profits) every 30 days to the YDL with compounding mechanisms.
contract OCL_ZVE is ZivoeLocker, ZivoeSwapper {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    /// @dev Bool that determines whether to use Uniswap v2 or Sushi (true = Uniswap v2, false = Sushi).
    bool public uniswapOrSushi;

    address public immutable GBL;               /// @dev The ZivoeGlobals contract.

    address public pairAsset;                   /// @dev ERC20 that will be paired with $ZVE for Sushi pool.
    address public router;                      /// @dev Address for the Router (Uniswap v2 or Sushi).
    address public factory;                     /// @dev Aaddress for the Factory (Uniswap v2 or Sushi).

    uint256 public baseline;                    /// @dev FRAX convertible, used for forwardYield() accounting.
    uint256 public nextYieldDistribution;       /// @dev Determines next available forwardYield() call.
    uint256 public amountForConversion;         /// @dev The amount of stablecoin in this contract convertible and forwardable to YDL.

    uint256 public compoundingRateBIPS = 5000;  /// @dev The % of returns to retain, in BIPS.

    uint256 private constant BIPS = 10000;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCL_ZVE.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The ZivoeGlobals contract.
    /// @param _pairAsset ERC20 that will be paired with $ZVE for pool.
    constructor(
        address DAO,
        address _GBL,
        address _pairAsset,
        bool _uniswapOrSushi
    ) {
        transferOwnership(DAO);
        GBL = _GBL;
        pairAsset = _pairAsset;
        uniswapOrSushi = _uniswapOrSushi;
        if (_uniswapOrSushi) {
            router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        }
        else {
            router = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
            factory = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
        }
    }



    // ------------
    //    Events   
    // ------------

    /// @notice This event is emitted when updateCompoundingRateBIPS() is called.
    /// @param  oldValue The old value of compoundingRateBIPS.
    /// @param  newValue The new value of compoundingRateBIPS.
    event UpdatedCompoundingRateBIPS(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during forwardYieldKeeper().
    /// @param  asset The "asset" being distributed.
    /// @param  amount The amount distributed.
    event YieldForwarded(address indexed asset, uint256 amount);



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLockerMulti().
    function canPushMulti() public override pure returns (bool) {
        return true;
    }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) {
        return true;
    }

    /// @notice Permission for owner to call pullFromLockerPartial().
    function canPullPartial() public override pure returns (bool) {
        return true;
    }

    /// @notice This pulls capital from the DAO and adds liquidity into a $ZVE/pairAsset pool.
    /// @param assets The assets to pull from the DAO.
    /// @param amounts The amount to pull of each asset respectively.
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts) external override onlyOwner {
        require(
            assets[0] == pairAsset && assets[1] == IZivoeGlobals_OCL_ZVE(GBL).ZVE(),
            "OCL_ZVE::pushToLockerMulti() assets[0] != pairAsset || assets[1] != IZivoeGlobals_OCL_ZVE(GBL).ZVE()"
        );

        for (uint256 i = 0; i < 2; i++) {
            require(amounts[i] >= 10 * 10**6, "OCL_ZVE::pushToLockerMulti() amounts[i] < 10 * 10**6");
            IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
        }

        if (nextYieldDistribution == 0) {
            nextYieldDistribution = block.timestamp + 30 days;
        }

        uint256 preBaseline;
        if (baseline != 0) {
            (preBaseline,) = pairAssetConvertible();
        }

        // Router, addLiquidity()
        IERC20(pairAsset).safeApprove(router, IERC20(pairAsset).balanceOf(address(this)));
        IERC20(IZivoeGlobals_OCL_ZVE(GBL).ZVE()).safeApprove(router, IERC20(IZivoeGlobals_OCL_ZVE(GBL).ZVE()).balanceOf(address(this)));
        IRouter_OCL_ZVE(router).addLiquidity(
            pairAsset, 
            IZivoeGlobals_OCL_ZVE(GBL).ZVE(), 
            IERC20(pairAsset).balanceOf(address(this)),
            IERC20(IZivoeGlobals_OCL_ZVE(GBL).ZVE()).balanceOf(address(this)),
            IERC20(pairAsset).balanceOf(address(this)),
            IERC20(IZivoeGlobals_OCL_ZVE(GBL).ZVE()).balanceOf(address(this)),
            address(this),
            block.timestamp + 14 days
        );
        assert(IERC20(pairAsset).allowance(address(this), router) == 0);
        assert(IERC20(IZivoeGlobals_OCL_ZVE(GBL).ZVE()).allowance(address(this), router) == 0);

        // Increase baseline.
        (uint256 postBaseline,) = pairAssetConvertible();
        require(postBaseline > preBaseline, "OCL_ZVE::pushToLockerMulti() postBaseline < preBaseline");
        baseline = postBaseline - preBaseline;
    }

    /// @notice This burns LP tokens from the Sushi ZVE/pairAsset pool and returns them to the DAO.
    /// @param  asset The asset to burn.
    function pullFromLocker(address asset) external override onlyOwner {
        address pair = IFactory_OCL_ZVE(factory).getPair(pairAsset, IZivoeGlobals_OCL_ZVE(GBL).ZVE());
        
        // pair = LP Token
        // pairAsset = Stablecoin (generally)
        if (asset == pair) {
            IERC20(pair).safeApprove(router, IERC20(pair).balanceOf(address(this)));
            IRouter_OCL_ZVE(router).removeLiquidity(
                pairAsset, 
                IZivoeGlobals_OCL_ZVE(GBL).ZVE(), 
                IERC20(pair).balanceOf(address(this)), 
                0, 
                0,
                address(this),
                block.timestamp + 14 days
            );
            assert(IERC20(pair).allowance(address(this), router) == 0);

            IERC20(pairAsset).safeTransfer(owner(), IERC20(pairAsset).balanceOf(address(this)));
            IERC20(IZivoeGlobals_OCL_ZVE(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals_OCL_ZVE(GBL).ZVE()).balanceOf(address(this)));
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

    /// @notice This burns LP tokens from the Sushi ZVE/pairAsset pool and returns them to the DAO.
    /// @param  asset The asset to burn.
    /// @param  amount The amount of "asset" to burn.
    function pullFromLockerPartial(address asset, uint256 amount) external override onlyOwner {
        address pair = IFactory_OCL_ZVE(factory).getPair(pairAsset, IZivoeGlobals_OCL_ZVE(GBL).ZVE());
        
        // pair = LP Token
        // pairAsset = Stablecoin (generally)
        if (asset == pair) {
            IERC20(pair).safeApprove(router, amount);
            IRouter_OCL_ZVE(router).removeLiquidity(
                pairAsset, 
                IZivoeGlobals_OCL_ZVE(GBL).ZVE(), 
                amount, 
                0, 
                0,
                address(this),
                block.timestamp + 14 days
            );
            assert(IERC20(pair).allowance(address(this), router) == 0);
            
            IERC20(pairAsset).safeTransfer(owner(), IERC20(pairAsset).balanceOf(address(this)));
            IERC20(IZivoeGlobals_OCL_ZVE(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals_OCL_ZVE(GBL).ZVE()).balanceOf(address(this)));
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
        require(
            _msgSender() == IZivoeGlobals_OCL_ZVE(GBL).TLC(), 
            "OCL_ZVE::updateCompoundingRateBIPS() _msgSender() != IZivoeGlobals_OCL_ZVE(GBL).TLC()"
        );
        require(_compoundingRateBIPS <= 10000, "OCL_ZVE::updateCompoundingRateBIPS() ratio > 10000");
        emit UpdatedCompoundingRateBIPS(compoundingRateBIPS, _compoundingRateBIPS);
        compoundingRateBIPS = _compoundingRateBIPS;
    }

    /// @notice This forwards yield to the YDL in the form of pairAsset.
    function forwardYield() external {
        if (IZivoeGlobals_OCL_ZVE(GBL).isKeeper(_msgSender())) {
            require(
                block.timestamp > nextYieldDistribution - 12 hours, 
                "OCL_ZVE::forwardYield() block.timestamp <= nextYieldDistribution - 12 hours"
            );
        }
        else {
            require(block.timestamp > nextYieldDistribution, "OCL_ZVE::forwardYield() block.timestamp <= nextYieldDistribution");
        }
        (uint256 amount, uint256 lp) = pairAssetConvertible();
        require(amount > baseline, "OCL_ZVE::forwardYield() amount <= baseline");
        nextYieldDistribution = block.timestamp + 30 days;
        _forwardYield(amount, lp);
    }

    /// @notice Returns information on how much pairAsset is convertible via current LP tokens.
    /// @dev    The withdrawal mechanism is ZVE/pairAsset_LP => pairAsset.
    /// @return amount Current pairAsset harvestable.
    /// @return lp Current ZVE/pairAsset LP tokens.
    function pairAssetConvertible() public view returns (uint256 amount, uint256 lp) {
        address pair = IFactory_OCL_ZVE(factory).getPair(pairAsset, IZivoeGlobals_OCL_ZVE(GBL).ZVE());
        uint256 balance_pairAsset = IERC20(pairAsset).balanceOf(pair);
        uint256 totalSupply_PAIR = IERC20(pair).totalSupply();
        lp = IERC20(pair).balanceOf(address(this));
        amount = lp * balance_pairAsset / totalSupply_PAIR;
    }

    /// @notice This forwards yield to the YDL in the form of pairAsset.
    /// @dev    Private function, only callable via forwardYield().
    /// @param  amount Current pairAsset harvestable.
    /// @param  lp Current ZVE/pairAsset LP tokens.
    function _forwardYield(uint256 amount, uint256 lp) private {
        uint256 lpBurnable = (amount - baseline) * lp / amount * compoundingRateBIPS / 10000;
        address pair = IFactory_OCL_ZVE
        (factory).getPair(pairAsset, IZivoeGlobals_OCL_ZVE(GBL).ZVE());
        IERC20(pair).safeApprove(router, lpBurnable);
        IRouter_OCL_ZVE(router).removeLiquidity(
            pairAsset,
            IZivoeGlobals_OCL_ZVE(GBL).ZVE(),
            lpBurnable,
            0,
            0,
            address(this),
            block.timestamp + 14 days
        );
        assert(IERC20(pair).allowance(address(this), router) == 0);
        if (pairAsset != IZivoeYDL_OCL_ZVE(IZivoeGlobals_OCL_ZVE(GBL).YDL()).distributedAsset()) {
            amountForConversion = IERC20(pairAsset).balanceOf(address(this));
        }
        else {
            IERC20(pairAsset).safeTransfer(IZivoeGlobals_OCL_ZVE(GBL).YDL(), IERC20(pairAsset).balanceOf(address(this)));
        }
        IERC20(IZivoeGlobals_OCL_ZVE(GBL).ZVE()).safeTransfer(owner(), IERC20(IZivoeGlobals_OCL_ZVE(GBL).ZVE()).balanceOf(address(this)));
        (baseline,) = pairAssetConvertible();
    }

    /// @notice This function converts and forwards available "amountForConversion" to YDL.distributeAsset().
    /// @param data The data retrieved from 1inch API in order to execute the swap.
    function forwardYieldKeeper(bytes calldata data) external {
        require(IZivoeGlobals_OCL_ZVE(GBL).isKeeper(_msgSender()), "OCL_ZVE::forwardYieldKeeper() !IZivoeGlobals_OCL_ZVE(GBL).isKeeper(_msgSender())");
        address _toAsset = IZivoeYDL_OCL_ZVE(IZivoeGlobals_OCL_ZVE(GBL).YDL()).distributedAsset();
        require(_toAsset != pairAsset, "OCL_ZVE::forwardYieldKeeper() _toAsset == pairAsset");

        // Swap available "amountForConversion" from stablecoin to YDL.distributedAsset().
        convertAsset(pairAsset, _toAsset, amountForConversion, data);

        emit YieldForwarded(_toAsset, IERC20(_toAsset).balanceOf(address(this)));
        
        // Transfer all _toAsset received to the YDL, then reduce amountForConversion to 0.
        IERC20(_toAsset).safeTransfer(IZivoeGlobals_OCL_ZVE(GBL).YDL(), IERC20(_toAsset).balanceOf(address(this)));
        amountForConversion = 0;
    }
}