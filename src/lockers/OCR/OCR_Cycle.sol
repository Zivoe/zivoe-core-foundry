// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

// ERC-4626 Vault interface for zVLT
interface IERC4626 {
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
}

// Interface for zSTT burning
interface IERC20Burnable_OCR { 
    function burn(uint256 amount) external; 
}

// Interface for ZivoeGlobals
interface IZivoeGlobals_OCR { 
    function ZVL() external view returns (address);
}

// AAVE V3 Pool interface
interface IPool_OCR {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IOCC_OCR {
    function cycle(uint256[] calldata amounts, address[] calldata destinations) external;
}

/// @notice  OCR stands for "On-Chain Redemption".
///          This locker is responsible for handling redemptions of zVLT for stablecoins.
///          Integrated with AAVE V3 USDC pool for yield generation.
///          Supports recycling USDC for interest payments.
contract OCR_Cycle is ZivoeLocker, ReentrancyGuard {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;                   /// @dev The ZivoeGlobals contract.
    address public immutable USDC;                  /// @dev The USDC token contract.
    address public immutable zVLT;                  /// @dev The zVLT ERC-4626 vault token contract.
    address public immutable zSTT;                  /// @dev The zSTT underlying asset token contract.
    address public immutable AAVE_V3_POOL;          /// @dev The AAVE V3 Pool contract.
    address public immutable aUSDC;                 /// @dev The AAVE V3 USDC aToken contract.
    address public immutable OCC;                   /// @dev The OCC_Cycle contract.
    address public immutable underwriter;           /// @dev The entity that manages draw limits.
    
    uint256 public redemptionFeeBIPS;               /// @dev Fee for redemptions (in BIPS).

    uint256 private constant BIPS = 10000;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCR_Cycle contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _USDC The USDC token contract.
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _zVLT The zVLT ERC-4626 vault token contract.
    /// @param  _zSTT The zSTT underlying asset token contract.
    /// @param  _AAVE_V3_POOL The AAVE V3 Pool contract.
    /// @param  _aUSDC The AAVE V3 USDC aToken contract.
    /// @param  _OCC The OCC_Cycle contract.
    /// @param  _underwriter The entity that manages draw limits.
    /// @param  _redemptionFeeBIPS Fee for redemptions (in BIPS).
    constructor(
        address DAO, 
        address _USDC, 
        address _GBL, 
        address _zVLT,
        address _zSTT,
        address _AAVE_V3_POOL,
        address _aUSDC,
        address _OCC,
        address _underwriter,
        uint16 _redemptionFeeBIPS
    ) {
        require(_redemptionFeeBIPS <= 1000, "OCR_Cycle::constructor() _redemptionFeeBIPS > 1000");
        transferOwnershipAndLock(DAO);
        USDC = _USDC;
        GBL = _GBL;
        zVLT = _zVLT;
        zSTT = _zSTT;
        AAVE_V3_POOL = _AAVE_V3_POOL;
        aUSDC = _aUSDC;
        OCC = _OCC;
        underwriter = _underwriter;
        redemptionFeeBIPS = _redemptionFeeBIPS;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during updateRedemptionFee().
    /// @param  oldFee The old value of redemptionFeeBIPS.
    /// @param  newFee The new value of redemptionFeeBIPS.
    event UpdatedRedemptionFeeBIPS(uint256 oldFee, uint256 newFee);

    /// @notice Emitted when USDC is deposited to AAVE V3.
    /// @param  amount The amount of USDC deposited.
    /// @param  aTokenBalance The resulting aToken balance.
    event USDCDepositedToAAVE(uint256 amount, uint256 aTokenBalance);

    /// @notice Emitted when USDC is withdrawn from AAVE V3.
    /// @param  amount The amount of USDC withdrawn.
    /// @param  aTokenBalance The resulting aToken balance.
    event USDCWithdrawnFromAAVE(uint256 amount, uint256 aTokenBalance);

    /// @notice Emitted when zVLT tokens are burned for USDC redemption.
    /// @param  user The user burning zVLT tokens.
    /// @param  zVLTBurned The amount of zVLT tokens burned.
    /// @param  USDCRedeemed The amount of USDC sent to user.
    /// @param  fee The fee taken.
    event zVLTBurnedForUSDC(address indexed user, uint256 zVLTBurned, uint256 USDCRedeemed, uint256 fee);
    


    // ---------------
    //    Modifiers
    // ---------------

    /// @notice This modifier ensures that the caller is the entity that is allowed to issue loans.
    modifier isUnderwriter() {
        require(_msgSender() == underwriter, "OCR_Cycle::isUnderwriter() _msgSender() != underwriter");
        _;
    }



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
    ) external override onlyOwner nonReentrant {
        require(asset == USDC, "OCR_Cycle::pushToLocker() asset != USDC");
        
        // Transfer USDC from DAO to this contract
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
        
        // Approve AAVE V3 Pool to spend USDC
        IERC20(asset).safeApprove(AAVE_V3_POOL, amount);
        
        // Deposit USDC into AAVE V3 pool
        IPool_OCR(AAVE_V3_POOL).supply(asset, amount, address(this), 0);
        
        emit USDCDepositedToAAVE(amount, IERC20(aUSDC).balanceOf(address(this)));
    }

    /// @notice Migrates entire ERC20 balance from locker to owner(), withdrawing from AAVE V3 if needed.
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override onlyOwner nonReentrant {
        require(asset == aUSDC, "OCR_Cycle::pullFromLocker() asset != aUSDC");
        
        // Withdraw all USDC from AAVE V3 pool
        uint256 aTokenBalance = IERC20(aUSDC).balanceOf(address(this));
        IPool_OCR(AAVE_V3_POOL).withdraw(USDC, aTokenBalance, address(this));
        emit USDCWithdrawnFromAAVE(IERC20(USDC).balanceOf(address(this)), 0);
        
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner(), withdrawing from AAVE V3 if needed.
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(
        address asset, uint256 amount, bytes calldata data
    ) external override onlyOwner nonReentrant {
        require(asset == aUSDC, "OCR_Cycle::pullFromLockerPartial() asset != aUSDC");
        
        // Withdraw USDC from AAVE V3 pool for the requested aUSDC amount
        IPool_OCR(AAVE_V3_POOL).withdraw(USDC, amount, address(this));
        emit USDCWithdrawnFromAAVE(amount, IERC20(aUSDC).balanceOf(address(this)));
        
        // Transfer all USDC in the locker to the owner
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
    }

    /// @notice Helper view function to determine how much USDC a given amount of zVLT will redeem for.
    /// @param  zVLTAmount The amount of zVLT tokens to calculate redemption for.
    /// @return usdcAmount The amount of USDC that would be received after fees.
    /// @return fee The fee amount that would be taken.
    function calculateRedemptionAmount(uint256 zVLTAmount) external view returns (uint256 usdcAmount, uint256 fee) {
        require(zVLTAmount > 0, "OCR_Cycle::calculateRedemptionAmount() zVLTAmount == 0");
        
        // Calculate how much zSTT would be received from unwrapping zVLT
        uint256 zSTTReceived = IERC4626(zVLT).convertToAssets(zVLTAmount);
        
        // Calculate fee based on zSTT amount (same logic as redeemUSDC)
        fee = ((zSTTReceived * redemptionFeeBIPS) / BIPS) / 10**12;
        
        // Calculate net USDC amount after fees
        usdcAmount = zSTTReceived / 10**12 - fee;
        
        return (usdcAmount, fee);
    }
    

    /// @notice Allows users to burn their zVLT tokens to receive USDC.
    /// @param  zVLTAmount The amount of zVLT tokens to burn.
    function redeemUSDC(uint256 zVLTAmount) external nonReentrant {
        require(zVLTAmount > 0, "OCR_Cycle::redeemUSDC() zVLTAmount == 0");
        
        // Transfer zVLT tokens from user to this contract
        IERC20(zVLT).safeTransferFrom(_msgSender(), address(this), zVLTAmount);
        
        // Unwrap zVLT to get zSTT (underlying asset)
        uint256 zSTTReceived = IERC4626(zVLT).redeem(zVLTAmount, address(this), address(this));

        // Burn zSTT
        IERC20Burnable_OCR(zSTT).burn(zSTTReceived);

        // Calculate fee
        uint256 fee = ((zSTTReceived * redemptionFeeBIPS) / BIPS) / 10**12;
        uint256 netAmount = zSTTReceived / 10**12 - fee;

        // Revert if aUSDC balance is less than zSTTReceived
        uint256 aUSDCBalance = IERC20(aUSDC).balanceOf(address(this));
        require(aUSDCBalance >= zSTTReceived / 10**12 - fee, "OCR_Cycle::redeemUSDC() aUSDCBalance < zSTTReceived / 10**12 - fee");

        // Calculate how much USDC to provide (1:1 ratio with zSTT burned, decimal precision rounded down 10**12)
        IPool_OCR(AAVE_V3_POOL).withdraw(USDC, netAmount, address(this));

        // Transfer USDC to user
        IERC20(USDC).safeTransfer(_msgSender(), netAmount);
        
        emit zVLTBurnedForUSDC(_msgSender(), zVLTAmount, netAmount, fee);
    }

    /// @notice Updates the state variable "redemptionFeeBIPS".
    /// @param  _redemptionFeeBIPS The new value for redemptionFeeBIPS (in BIPS).
    function updateRedemptionFeeBIPS(uint256 _redemptionFeeBIPS) external {
        require(
            _msgSender() == IZivoeGlobals_OCR(GBL).ZVL(), 
            "OCR_Cycle::updateRedemptionFeeBIPS() _msgSender() != ZVL()"
        );
        require(
            _redemptionFeeBIPS <= 1000, "OCR_Cycle::updateRedemptionFeeBIPS() _redemptionFeeBIPS > 1000"
        );
        emit UpdatedRedemptionFeeBIPS(redemptionFeeBIPS, _redemptionFeeBIPS);
        redemptionFeeBIPS = _redemptionFeeBIPS;
    }

    /// @notice Cycles USDC for compounding base.
    /// @param amounts The amount of USDC to cycle (increases base by this much).
    /// @param users The users to cycle USDC for (increases base for this user).
    function cycle(uint256[] calldata amounts, address[] calldata users) external isUnderwriter {
        require(amounts.length == users.length, "OCR_Cycle::cycle() amounts.length != users.length");
        uint totalAmount;
        for (uint i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        IPool_OCR(AAVE_V3_POOL).withdraw(USDC, totalAmount, address(this));
        IERC20(USDC).safeApprove(OCC, totalAmount);
        IOCC_OCR(OCC).cycle(amounts, users);
    }

}