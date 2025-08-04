// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IERC20Burnable_OCR {
    /// @notice Burns tokens.
    /// @param  amount The number of tokens to burn.
    function burn(uint256 amount) external;
}

interface IZivoeGlobals_OCR {
    /// @notice Returns the address of the Timelock contract.
    function TLC() external view returns (address);

    /// @notice Returns the address of the $zJTT contract.
    function zJTT() external view returns (address);

    /// @notice Returns the address of the $zSTT contract.
    function zSTT() external view returns (address);
}

// AAVE V3 Interfaces
interface IPool {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
}

interface IAToken {
    function balanceOf(address user) external view returns (uint256);
}

/// @notice  OCR stands for "On-Chain Redemption".
///          This locker is responsible for handling redemptions of tranche tokens to stablecoins.
///          Now integrated with AAVE V3 USDC pool for instant redemptions.
contract OCR_Instant is ZivoeLocker, ReentrancyGuard {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;                   /// @dev The ZivoeGlobals contract.
    address public immutable stablecoin;            /// @dev The stablecoin redeemable in this contract (USDC).
    address public immutable zVLT;                  /// @dev The zVLT token contract.
    address public immutable AAVE_V3_POOL;         /// @dev The AAVE V3 Pool contract.
    address public immutable AAVE_V3_USDC_ATOKEN;  /// @dev The AAVE V3 USDC aToken contract.
    
    uint256 public redemptionsFeeBIPS;              /// @dev Fee for redemptions (in BIPS).

    uint256 private constant BIPS = 10000;

    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCR_Instant contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _stablecoin The stablecoin redeemable in this OCR contract (USDC).
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _zVLT The zVLT token contract.
    /// @param  _AAVE_V3_POOL The AAVE V3 Pool contract.
    /// @param  _AAVE_V3_USDC_ATOKEN The AAVE V3 USDC aToken contract.
    /// @param  _redemptionsFeeBIPS Fee for redemptions (in BIPS).
    constructor(
        address DAO, 
        address _stablecoin, 
        address _GBL, 
        address _zVLT,
        address _AAVE_V3_POOL,
        address _AAVE_V3_USDC_ATOKEN,
        uint16 _redemptionsFeeBIPS
    ) {
        require(_redemptionsFeeBIPS <= 2000, "OCR_Instant::constructor() _redemptionsFeeBIPS > 2000");
        transferOwnershipAndLock(DAO);
        stablecoin = _stablecoin;
        GBL = _GBL;
        zVLT = _zVLT;
        AAVE_V3_POOL = _AAVE_V3_POOL;
        AAVE_V3_USDC_ATOKEN = _AAVE_V3_USDC_ATOKEN;
        redemptionsFeeBIPS = _redemptionsFeeBIPS;
    }

    // ------------
    //    Events
    // ------------

    /// @notice Emitted during updateRedemptionsFee().
    /// @param  oldFee The old value of redemptionsFeeBIPS.
    /// @param  newFee The new value of redemptionsFeeBIPS.
    event UpdatedRedemptionsFeeBIPS(uint256 oldFee, uint256 newFee);

    /// @notice Emitted when USDC is deposited to AAVE V3.
    /// @param  amount The amount of USDC deposited.
    /// @param  aTokenBalance The resulting aToken balance.
    event USDCDepositedToAAVE(uint256 amount, uint256 aTokenBalance);

    /// @notice Emitted when USDC is withdrawn from AAVE V3.
    /// @param  amount The amount of USDC withdrawn.
    /// @param  aTokenBurned The amount of aTokens burned.
    event USDCWithdrawnFromAAVE(uint256 amount, uint256 aTokenBurned);

    /// @notice Emitted when zVLT tokens are burned for USDC redemption.
    /// @param  user The user burning zVLT tokens.
    /// @param  zVLTBurned The amount of zVLT tokens burned.
    /// @param  usdcReceived The amount of USDC received.
    /// @param  fee The fee taken.
    event zVLTBurnedForUSDC(address indexed user, uint256 zVLTBurned, uint256 usdcReceived, uint256 fee);

    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice This pulls capital from the DAO and deposits it into AAVE V3 USDC pool.
    /// @param  asset The asset to pull from the DAO.
    /// @param  amount The amount of asset to pull from the DAO.
    /// @param  data Accompanying transaction data.
    function pushToLocker(
        address asset, uint256 amount, bytes calldata data
    ) external override _tickEpoch onlyOwner nonReentrant {
        require(asset == stablecoin, "OCR_Instant::pushToLocker() asset != stablecoin");
        
        // Transfer USDC from DAO to this contract
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
        
        // Approve AAVE V3 Pool to spend USDC
        IERC20(asset).safeApprove(AAVE_V3_POOL, amount);
        
        // Deposit USDC into AAVE V3 pool
        IPool(AAVE_V3_POOL).supply(asset, amount, address(this), 0);
        
        emit USDCDepositedToAAVE(amount, IAToken(AAVE_V3_USDC_ATOKEN).balanceOf(address(this)));
    }

    /// @notice Migrates entire ERC20 balance from locker to owner(), withdrawing from AAVE V3 if needed.
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override _tickEpoch onlyOwner nonReentrant {
        require(
            asset != IZivoeGlobals_OCR(GBL).zJTT() && asset != IZivoeGlobals_OCR(GBL).zSTT(),
            "OCR_Instant::pullFromLocker() asset == zJTT || asset == zSTT"
        );
        
        if (asset == stablecoin) {
            // Withdraw all USDC from AAVE V3 pool
            uint256 aTokenBalance = IAToken(AAVE_V3_USDC_ATOKEN).balanceOf(address(this));
            if (aTokenBalance > 0) {
                IPool(AAVE_V3_POOL).withdraw(asset, type(uint256).max, address(this));
                emit USDCWithdrawnFromAAVE(IERC20(asset).balanceOf(address(this)), aTokenBalance);
            }
        }
        
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner(), withdrawing from AAVE V3 if needed.
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(
        address asset, uint256 amount, bytes calldata data
    ) external override _tickEpoch onlyOwner nonReentrant {
        require(
            asset != IZivoeGlobals_OCR(GBL).zJTT() && asset != IZivoeGlobals_OCR(GBL).zSTT(),
            "OCR_Instant::pullFromLockerPartial() asset == zJTT || asset == zSTT"
        );
        
        if (asset == stablecoin) {
            // Check if we need to withdraw from AAVE V3 to meet the requested amount
            uint256 currentBalance = IERC20(asset).balanceOf(address(this));
            if (currentBalance < amount) {
                uint256 neededFromAAVE = amount - currentBalance;
                uint256 aTokenBalance = IAToken(AAVE_V3_USDC_ATOKEN).balanceOf(address(this));
                
                // Calculate how much we can withdraw (limited by aToken balance)
                uint256 withdrawAmount = neededFromAAVE > aTokenBalance ? aTokenBalance : neededFromAAVE;
                
                if (withdrawAmount > 0) {
                    IPool(AAVE_V3_POOL).withdraw(asset, withdrawAmount, address(this));
                    emit USDCWithdrawnFromAAVE(withdrawAmount, withdrawAmount);
                }
            }
        }
        
        IERC20(asset).safeTransfer(owner(), amount);
    }

    /// @notice Allows users to burn their zVLT tokens to receive USDC.
    /// @param  zVLTAmount The amount of zVLT tokens to burn.
    function burnZVLTForUSDC(uint256 zVLTAmount) external nonReentrant {
        require(zVLTAmount > 0, "OCR_Instant::burnZVLTForUSDC() zVLTAmount == 0");
        
        // Calculate fee
        uint256 fee = (zVLTAmount * redemptionsFeeBIPS) / BIPS;
        uint256 netAmount = zVLTAmount - fee;
        
        // Burn zVLT tokens from user
        IERC20Burnable_OCR(zVLT).burn(zVLTAmount);
        
        // Calculate how much USDC to provide (1:1 ratio for simplicity, can be adjusted)
        uint256 usdcToProvide = netAmount;
        
        // Check if we have enough USDC in contract, if not withdraw from AAVE V3
        uint256 currentUSDCBalance = IERC20(stablecoin).balanceOf(address(this));
        if (currentUSDCBalance < usdcToProvide) {
            uint256 neededFromAAVE = usdcToProvide - currentUSDCBalance;
            uint256 aTokenBalance = IAToken(AAVE_V3_USDC_ATOKEN).balanceOf(address(this));
            
            // Calculate how much we can withdraw (limited by aToken balance)
            uint256 withdrawAmount = neededFromAAVE > aTokenBalance ? aTokenBalance : neededFromAAVE;
            
            if (withdrawAmount > 0) {
                IPool(AAVE_V3_POOL).withdraw(stablecoin, withdrawAmount, address(this));
                emit USDCWithdrawnFromAAVE(withdrawAmount, withdrawAmount);
            }
        }
        
        // Transfer USDC to user
        IERC20(stablecoin).safeTransfer(_msgSender(), usdcToProvide);
        
        emit zVLTBurnedForUSDC(_msgSender(), zVLTAmount, usdcToProvide, fee);
    }

    /// @notice Updates the state variable "redemptionsFeeBIPS".
    /// @param  _redemptionsFeeBIPS The new value for redemptionsFeeBIPS (in BIPS).
    function updateRedemptionsFeeBIPS(uint256 _redemptionsFeeBIPS) external _tickEpoch {
        require(
            _msgSender() == IZivoeGlobals_OCR(GBL).TLC(), 
            "OCR_Instant::updateRedemptionsFeeBIPS() _msgSender() != TLC()"
        );
        require(
            _redemptionsFeeBIPS <= 2000, "OCR_Instant::updateRedemptionsFeeBIPS() _redemptionsFeeBIPS > 2000"
        );
        emit UpdatedRedemptionsFeeBIPS(redemptionsFeeBIPS, _redemptionsFeeBIPS);
        redemptionsFeeBIPS = _redemptionsFeeBIPS;
    }

    /// @notice Returns the current USDC balance available for redemptions.
    /// @return The total USDC balance (contract + AAVE V3).
    function getAvailableUSDCBalance() external view returns (uint256) {
        uint256 contractBalance = IERC20(stablecoin).balanceOf(address(this));
        uint256 aTokenBalance = IAToken(AAVE_V3_USDC_ATOKEN).balanceOf(address(this));
        return contractBalance + aTokenBalance;
    }

    /// @notice Returns the AAVE V3 aToken balance for this contract.
    /// @return The aToken balance.
    function getATokenBalance() external view returns (uint256) {
        return IAToken(AAVE_V3_USDC_ATOKEN).balanceOf(address(this));
    }
}