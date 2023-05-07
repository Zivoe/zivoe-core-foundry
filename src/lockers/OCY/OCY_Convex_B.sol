// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IBasePool_OCY_Convex_B {
    function add_liquidity(uint256[4] memory _amounts, uint256 _min_mint_amount) external;
}

interface IBaseRewardPool_OCY_Convex_B {
    function extraRewards() external returns(address[] memory);
    function extraRewardsLength() external returns(uint256);
}

interface IBooster_OCY_Convex_B {
    function deposit(uint256 _pid, uint256 _amount, bool _stake) external returns(bool);
    function withdraw(uint256 _pid, uint256 _amount) external returns(bool);
}

interface IZivoeGlobals_OCY_Convex_B {
    /// @notice Returns the address of the Zivoe Laboratory.
    function ZVL() external view returns (address);
}

/// @notice This contract allocates stablecoins to the sUSD base-pool and stakes the LP tokens on Convex.
contract OCY_Convex_B is ZivoeLocker, ReentrancyGuard {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;                   /// @dev The ZivoeGlobals contract.

    address public OCT_YDL;                         /// @dev The OCT_YDL contract.

    uint256 public distributionLast;                /// @dev Timestamp of last distribution.

    uint256 public constant INTERVAL = 14 days;     /// @dev Number of seconds between each distribution.

    /// @dev Tokens.
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;   /// @dev Index 0, BasePool
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;  /// @dev Index 1, BasePool
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;  /// @dev Index 2, BasePool
    address public constant sUSD = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;  /// @dev Index 3, BasePool

    address public constant SNX = 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F;
    address public constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;

    /// @dev Convex information.
    address public convexPoolToken = 0xC25a3A3b969415c80451098fa907EC722572917F;
    address public convexDeposit = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    address public convexRewards = 0x22eE18aca7F3Ee920D01F25dA85840D12d98E8Ca;
    uint256 public convexPoolID = 4;

    /// @dev Curve information.
    address public curveBasePool = 0xA5407eAE9Ba41422680e2e00537571bcC53efBfD;
    address public curveBasePoolToken = 0xC25a3A3b969415c80451098fa907EC722572917F;


    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_OUSD contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _OCT_YDL The OCT_YDL (Treasury and ZivoeSwapper) contract.
    constructor(address DAO, address _GBL, address _OCT_YDL) {
        transferOwnership(DAO);
        GBL = _GBL;
        OCT_YDL = _OCT_YDL;
        distributionLast = block.timestamp;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during setOCTYDL().
    /// @param  newOCT The new OCT_YDL contract.
    /// @param  oldOCT The old OCT_YDL contract.
    event OCTYDLSetZVL(address indexed newOCT, address indexed oldOCT);

    /// @notice Emitted during forwardYield().
    /// @param  amount The amount of OUSD forwarded.
    /// @param  newBasis The new basis value.
    event YieldForwarded(uint256 amount, uint256 newBasis);


    // ---------------
    //    Functions
    // ---------------

    function canPush() public pure override returns (bool) {
        return true;
    }

    function canPull() public pure override returns (bool) {
        return true;
    }

    function canPullPartial() public override pure returns (bool) {
        return true;
    }

    /// @notice Migrates specific amount of ERC20 from owner() to locker.
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLocker(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(
            asset == DAI || asset == USDC || asset == USDT || asset == sUSD, 
            "OCY_Convex_B::pushToLocker() asset != DAI && asset != USDC && asset != USDT && asset != sUSD"
        );
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);

        if (asset == DAI) {
            // Allocate DAI to Curve BasePool
            IERC20(DAI).safeApprove(curveBasePool, amount);
            uint256[4] memory _amounts;
            _amounts[0] = amount;
            IBasePool_OCY_Convex_B(curveBasePool).add_liquidity(_amounts, 0);
        }
        else if (asset == USDC) {
            // Allocate USDC to Curve BasePool
            IERC20(USDC).safeApprove(curveBasePool, amount);
            uint256[4] memory _amounts;
            _amounts[1] = amount;
            IBasePool_OCY_Convex_B(curveBasePool).add_liquidity(_amounts, 0);
        }
        else if (asset == USDT) {
            // Allocate USDT to Curve BasePool
            IERC20(USDT).safeApprove(curveBasePool, amount);
            uint256[4] memory _amounts;
            _amounts[2] = amount;
            IBasePool_OCY_Convex_B(curveBasePool).add_liquidity(_amounts, 0);
        }
        else {
            // Allocate sUSD to Curve BasePool
            IERC20(sUSD).safeApprove(curveBasePool, amount);
            uint256[4] memory _amounts;
            _amounts[3] = amount;
            IBasePool_OCY_Convex_B(curveBasePool).add_liquidity(_amounts, 0);
        }

        // Stake CurveLP tokens to Convex
        IERC20(curveBasePoolToken).safeApprove(convexDeposit, IERC20(curveBasePoolToken).balanceOf(address(this)));
        IBooster_OCY_Convex_B(convexDeposit).deposit(convexPoolID, IERC20(curveBasePoolToken).balanceOf(address(this)), true);
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override onlyOwner {
        require(asset == convexPoolToken, "OCY_Convex_B::pullFromLocker() asset != convexPoolToken");
        
        claimRewards();

        // TODO: Unstake CurveLP tokens from Convex
        // TODO: Burn CurveLP tokens for stablecoins
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(asset == convexPoolToken, "OCY_Convex_B::pullFromLockerPartial() asset != convexPoolToken");
        
        claimRewards();

        // TODO: Unstake CurveLP tokens from Convex
        // TODO: Burn CurveLP tokens for stablecoins
    }

    /// @notice Claims rewards and forwards them to the OCT_YDL.
    function claimRewards() public nonReentrant {
        require(
            block.timestamp > distributionLast + INTERVAL, 
            "OCY_Convex_B::claimRewards() block.timestamp <= distributionLast + INTERVAL"
        );
        distributionLast = block.timestamp;

        // TODO: Claim rewards + extra rewards
    }

    /// @notice Update the OCT_YDL endpoint.
    /// @dev    This function MUST only be called by ZVL().
    /// @param  _OCT_YDL The new address for OCT_YDL.
    function setOCTYDL(address _OCT_YDL) external {
        require(
            _msgSender() == IZivoeGlobals_OCY_Convex_B(GBL).ZVL(), 
            "OCY_Convex_B::setOCTYDL() _msgSender() != IZivoeGlobals_OCY_Convex_B(GBL).ZVL()"
        );
        emit OCTYDLSetZVL(_OCT_YDL, OCT_YDL);
        OCT_YDL = _OCT_YDL;
    }

}