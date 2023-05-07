// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";


interface IBasePool_OCY_Convex_A {
    function add_liquidity(uint256[2] memory _amounts, uint256 _min_mint_amount) external returns(uint256);
    function remove_liquidity(uint256 _burn_amount, uint256[2] memory _min_amounts) external returns(uint256[2] memory);
}

interface IBaseRewardPool_OCY_Convex_A {
    function extraRewards() external returns(address[] memory);
    function extraRewardsLength() external returns(uint256);
    function withdrawAndUnwrap(uint256 _amount, bool _claim) external returns(bool);
}

interface IBooster_OCY_Convex_A {
    function deposit(uint256 _pid, uint256 _amount, bool _stake) external returns(bool);
    function poolInfo(uint256) external view returns(address,address,address,address,address,bool);
}

interface IMetaPool_OCY_Convex_A {
    function add_liquidity(uint256[2] memory _amounts, uint256 _min_mint_amount) external;
    function remove_liquidity(uint256 _burn_amount, uint256[2] memory _min_amounts) external returns(uint256[2] memory);
}

// def remove_liquidity(
//     _burn_amount: uint256,
//     _min_amounts: uint256[N_COINS],
//     _receiver: address = msg.sender
// )

interface IZivoeGlobals_OCY_Convex_A {
    /// @notice Returns the address of the Zivoe Laboratory.
    function ZVL() external view returns (address);
}

/// @notice This contract allocates stablecoins to the alUSD/FRAXBP meta-pool and stakes the LP tokens on Convex.
contract OCY_Convex_A is ZivoeLocker, ReentrancyGuard {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;                   /// @dev The ZivoeGlobals contract.

    address public OCT_YDL;                         /// @dev The OCT_YDL contract.

    uint256 public distributionLast;                /// @dev Timestamp of last distribution.

    uint256 public constant INTERVAL = 14 days;     /// @dev Number of seconds between each distribution.

    /// @dev Tokens.
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;  /// @dev Index 0, BasePool
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;  /// @dev Index 1, BasePool
    address public constant alUSD = 0xBC6DA0FE9aD5f3b0d58160288917AA56653660E9; /// @dev Index 0, MetaPool

    address public constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;


    /// @dev Convex information.
    address public convexPoolToken = 0xB30dA2376F63De30b42dC055C93fa474F31330A5;
    address public convexDeposit = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    address public convexRewards = 0x26598e3E511ADFadefD70ab2C3475Ff741741104;
    uint256 public convexPoolID = 106;

    /// @dev Curve information.
    address public curveBasePool = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address public curveBasePoolToken = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC; /// @dev Index 1, MetaPool
    address public curveMetaPool = 0xB30dA2376F63De30b42dC055C93fa474F31330A5;      /// @dev MetaPool & Token



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
            asset == FRAX || asset == USDC || asset == alUSD, 
            "OCY_Convex_A::pushToLocker() asset != FRAX && asset != USDC && asset != alUSD"
        );
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);

        if (asset == FRAX) {
            // Allocate FRAX to Curve BasePool
            IERC20(FRAX).safeApprove(curveBasePool, amount);
            uint256[2] memory _amounts;
            _amounts[0] = amount;
            IBasePool_OCY_Convex_A(curveBasePool).add_liquidity(_amounts, 0);
            
            // Allocate curveBasePoolToken to Curve MetaPool
            _amounts[0] = 0;
            _amounts[1] = IERC20(curveBasePoolToken).balanceOf(address(this));
            IERC20(curveBasePoolToken).safeApprove(curveMetaPool, _amounts[1]);
            IMetaPool_OCY_Convex_A(curveMetaPool).add_liquidity(_amounts, 0);
        }
        else if (asset == USDC) {
            // Allocate USDC to Curve BasePool
            IERC20(USDC).safeApprove(curveBasePool, amount);
            uint256[2] memory _amounts;
            _amounts[1] = amount;
            IBasePool_OCY_Convex_A(curveBasePool).add_liquidity(_amounts, 0);

            // Allocate curveBasePoolToken to Curve MetaPool
            _amounts[1] = IERC20(curveBasePoolToken).balanceOf(address(this));
            IERC20(curveBasePoolToken).safeApprove(curveMetaPool, _amounts[1]);
            IMetaPool_OCY_Convex_A(curveMetaPool).add_liquidity(_amounts, 0);
        }
        else {
            // Allocate alUSD to Curve MetaPool
            uint256[2] memory _amounts;
            _amounts[0] = amount;
            IERC20(alUSD).safeApprove(curveMetaPool, _amounts[0]);
            IMetaPool_OCY_Convex_A(curveMetaPool).add_liquidity(_amounts, 0);
        }

        // Stake CurveLP tokens to Convex
        IERC20(curveMetaPool).safeApprove(convexDeposit, IERC20(curveMetaPool).balanceOf(address(this)));
        IBooster_OCY_Convex_A(convexDeposit).deposit(convexPoolID, IERC20(curveMetaPool).balanceOf(address(this)), true);
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override onlyOwner {
        require(asset == convexPoolToken, "OCY_Convex_A::pullFromLocker() asset != convexPoolToken");
        
        claimRewards();
        
        // Withdraw from ConvexRewards and unstake CurveLP tokens from ConvexBooster
        IBaseRewardPool_OCY_Convex_A(convexRewards).withdrawAndUnwrap(IERC20(convexRewards).balanceOf(address(this)), false);

        // Burn MetaPool tokens
        uint256[2] memory _min_amounts;
        IMetaPool_OCY_Convex_A(curveMetaPool).remove_liquidity(IERC20(curveMetaPool).balanceOf(address(this)), _min_amounts);

        // Burn BasePool Tokens
        IBasePool_OCY_Convex_A(curveBasePool).remove_liquidity(IERC20(curveBasePoolToken).balanceOf(address(this)), _min_amounts);

        // Return tokens to DAO
        IERC20(alUSD).safeTransfer(owner(), IERC20(alUSD).balanceOf(address(this)));
        IERC20(FRAX).safeTransfer(owner(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));

    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(asset == convexPoolToken, "OCY_Convex_A::pullFromLockerPartial() asset != convexPoolToken");
        
        claimRewards();
        
        IBaseRewardPool_OCY_Convex_A(convexRewards).withdrawAndUnwrap(amount, false);

        // Burn MetaPool tokens
        uint256[2] memory _min_amounts;
        IMetaPool_OCY_Convex_A(curveMetaPool).remove_liquidity(IERC20(curveMetaPool).balanceOf(address(this)), _min_amounts);

        // Burn BasePool Tokens
        IBasePool_OCY_Convex_A(curveBasePool).remove_liquidity(IERC20(curveBasePoolToken).balanceOf(address(this)), _min_amounts);

        // Return tokens to DAO
        IERC20(alUSD).safeTransfer(owner(), IERC20(alUSD).balanceOf(address(this)));
        IERC20(FRAX).safeTransfer(owner(), IERC20(FRAX).balanceOf(address(this)));
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
    }

    /// @notice Claims rewards and forwards them to the OCT_YDL.
    function claimRewards() public nonReentrant {
        
    }

    /// @notice Update the OCT_YDL endpoint.
    /// @dev    This function MUST only be called by ZVL().
    /// @param  _OCT_YDL The new address for OCT_YDL.
    function setOCTYDL(address _OCT_YDL) external {
        require(
            _msgSender() == IZivoeGlobals_OCY_Convex_A(GBL).ZVL(), 
            "OCY_Convex_A::setOCTYDL() _msgSender() != IZivoeGlobals_OCY_Convex_A(GBL).ZVL()"
        );
        emit OCTYDLSetZVL(_OCT_YDL, OCT_YDL);
        OCT_YDL = _OCT_YDL;
    }

}