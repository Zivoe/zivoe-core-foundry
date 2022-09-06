// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./ZivoeLocker.sol";

import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { IERC20Metadata } from "./OpenZeppelin/IERC20Metadata.sol";
import { IZivoeGlobals, IERC20Mintable } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract will facilitate ongoing liquidity provision to Zivoe tranches - Junior, Senior.
///         This contract will be permissioned by JuniorTrancheToken and SeniorTrancheToken to call mint().
///         This contract will support a whitelist for stablecoins to provide as liquidity.
contract ZivoeTranches is ZivoeLocker {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;   /// @dev The ZivoeGlobals contract.

    // TODO: Migrate these into controllable globals values.

    uint256 public constant lowerRatioJTT = 1000; /// @dev Represents 10% ratio zJTT.totalSupply():zSTT.totalSupply().
    uint256 public constant upperRatioJTT = 2500; /// @dev Represents 25% ratio zJTT.totalSupply():zSTT.totalSupply().

    mapping(address => bool) public stablecoinWhitelist;    /// @dev Whitelist for stablecoins accepted as deposit.

    // TODO: Delay ongoing minting until after ITO concludes.


    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeTranches.sol contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address _GBL) {
        stablecoinWhitelist[0x6B175474E89094C44Da98b954EedeAC495271d0F] = true; // DAI
        stablecoinWhitelist[0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48] = true; // USDC
        stablecoinWhitelist[0x853d955aCEf822Db058eb8505911ED77F175b99e] = true; // FRAX
        stablecoinWhitelist[0xdAC17F958D2ee523a2206206994597C13D831ec7] = true; // USDT

        GBL = _GBL;
        transferOwnership(IZivoeGlobals(_GBL).DAO());
    }



    // ------------
    //    Events
    // ------------

    /// @notice This event is emitted when depositJunior() is called.
    /// @param  account The account depositing stablecoins to junior tranche.
    /// @param  asset The stablecoin deposited.
    /// @param  amount The amount of stablecoins deposited.
    event JuniorDeposit(address indexed account, address asset, uint256 amount);

    /// @notice This event is emitted when depositSenior() is called.
    /// @param  account The account depositing stablecoins to senior tranche.
    /// @param  asset The stablecoin deposited.
    /// @param  amount The amount of stablecoins deposited.
    event SeniorDeposit(address indexed account, address asset, uint256 amount);

    /// @notice This event is emitted when modifyStablecoinWhitelist() is called.
    /// @param  asset The stablecoin to update.
    /// @param  allowed The boolean value to assign.
    event ModifyStablecoinWhitelist(address asset, bool allowed);



    // ---------------
    //    Functions
    // ---------------

    function canPush() public override pure returns (bool) {
        return true;
    }

    function canPull() public override pure returns (bool) {
        return true;
    }

    function canPullPartial() public override pure returns (bool) {
        return true;
    }

    // TODO: Consider removing asset == ZVE require statements
    ///      (i.e. using base default ZivoeLocker functions for accessibility to all ERC20 tokens, in case accidental transfer?).

    /// @notice This pulls capital from the DAO, does any necessary pre-conversions, and escrows ZVE for incentives.
    function pushToLocker(address asset, uint256 amount) external override onlyOwner {
        require(asset == IZivoeGlobals(GBL).ZVE(), "ZivoeTranches::pushToLocker() asset != IZivoeGlobals(GBL).ZVE()");
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }

    /// @notice This pulls capital from the DAO, does any necessary pre-conversions, and escrows ZVE for incentives.
    function pullFromLocker(address asset) external override onlyOwner {
        require(asset == IZivoeGlobals(GBL).ZVE(), "ZivoeTranches::pullFromLocker() asset != IZivoeGlobals(GBL).ZVE()");
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice This pulls capital from the DAO, does any necessary pre-conversions, and escrows ZVE for incentives.
    function pullFromLockerPartial(address asset, uint256 amount) external override onlyOwner {
        require(asset == IZivoeGlobals(GBL).ZVE(), "ZivoeTranches::pullFromLockerPartial() asset != IZivoeGlobals(GBL).ZVE()");
        IERC20(asset).safeTransfer(owner(), amount);
    }

    /// @notice Deposit stablecoins into the junior tranche.
    ///         Mints JuniorTrancheToken ($zJTT) in 1:1 ratio.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset (stablecoin) to deposit.
    function depositJunior(uint256 amount, address asset) external {
        require(stablecoinWhitelist[asset], "ZivoeTranches::depositJunior() !stablecoinWhitelist[asset]");

        address depositor = _msgSender();
        emit JuniorDeposit(depositor, asset, amount);

        IERC20(asset).safeTransferFrom(depositor, IZivoeGlobals(GBL).DAO(), amount);
        
        uint256 convertedAmount = amount;

        if (IERC20Metadata(asset).decimals() != 18) {
            convertedAmount *= 10 ** (18 - IERC20Metadata(asset).decimals());
        }

        require(
            convertedAmount + IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply() < 
            IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply() * IZivoeGlobals(GBL).maxTrancheRatioBPS() / 10000,
            "ZivoeTranches::depositJunior() deposit exceeds maxTrancheRatioCapBPS"
        );

        // NOTE: Ordering important, transfer ZVE rewards prior to minting zJTT() due to totalSupply() changes.
        IERC20(IZivoeGlobals(GBL).ZVE()).transfer(depositor, rewardZVEJuniorDeposit(convertedAmount));
        IERC20Mintable(IZivoeGlobals(GBL).zJTT()).mint(depositor, convertedAmount);
    }

    /// @notice Deposit stablecoins into the senior tranche.
    ///         Mints SeniorTrancheToken ($zSTT) in 1:1 ratio.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset (stablecoin) to deposit.
    function depositSenior(uint256 amount, address asset) external {
        require(stablecoinWhitelist[asset], "ZivoeTranches::depositSenior() !stablecoinWhitelist[asset]");

        address depositor = _msgSender();
        emit SeniorDeposit(depositor, asset, amount);

        IERC20(asset).safeTransferFrom(depositor, IZivoeGlobals(GBL).DAO(), amount);
        
        uint256 convertedAmount = amount;

        if (IERC20Metadata(asset).decimals() != 18) {
            convertedAmount *= 10 ** (18 - IERC20Metadata(asset).decimals());
        }

        // NOTE: Ordering important, transfer ZVE rewards prior to minting zJTT() due to totalSupply() changes.
        IERC20(IZivoeGlobals(GBL).ZVE()).transfer(depositor, rewardZVESeniorDeposit(convertedAmount));
        IERC20Mintable(IZivoeGlobals(GBL).zSTT()).mint(depositor, convertedAmount);
    }

    /// @notice Modify whitelist for stablecoins that can be deposited into tranches.
    /// @dev    Only callable by _owner.
    /// @param  asset The asset to update.
    /// @param  allowed The value to assign (true = permitted, false = prohibited).
    function modifyStablecoinWhitelist(address asset, bool allowed) external {
        require(
            _msgSender() == IZivoeGlobals(GBL).ZVL(), 
            "ZivoeTranches::modifyStablecoinWhitelist() _msgSender() != IZivoeGlobals(GBL).ZVL()"
        );
        stablecoinWhitelist[asset] = allowed;
        emit ModifyStablecoinWhitelist(asset, allowed);
    }

    /// @dev Input amount MUST be in wei.
    /// @dev Output amount MUST be in wei.
    function rewardZVEJuniorDeposit(uint256 deposit) public view returns(uint256 reward) {

        uint256 avgRate;    /// @dev The avg ZVE per stablecoin deposit reward, used for reward calculation.

        uint256 diffRate = IZivoeGlobals(GBL).maxZVEPerJTTMint() - IZivoeGlobals(GBL).minZVEPerJTTMint();

        uint256 startRatio = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply() * 10000 / IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();
        uint256 finalRatio = (IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply() + deposit) * 10000 / IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();
        uint256 avgRatio = (startRatio + finalRatio) / 2;

        if (avgRatio <= lowerRatioJTT) {
            // Handle max case (Junior:Senior is 10% or less)
            avgRate = IZivoeGlobals(GBL).maxZVEPerJTTMint();
        } else if (avgRatio >= upperRatioJTT) {
            // Handle min case (Junior:Senior is 25% or more)
            avgRate = IZivoeGlobals(GBL).minZVEPerJTTMint();
        } else {
            // Handle in-between case, avgRatio domain = (1000, 2500).
            avgRate = IZivoeGlobals(GBL).maxZVEPerJTTMint() - diffRate * (avgRatio - 1000) / (1500);
        }

        reward = avgRate * deposit / 1 ether;

        // Reduce if ZVE balance < reward.
        if (IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)) < reward) {
            reward = IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this));
        }
    }


    /// @dev Input amount MUST be in wei.
    /// @dev Output amount MUST be in wei.
    function rewardZVESeniorDeposit(uint256 deposit) public view returns(uint256 reward) {

        uint256 avgRate;    /// @dev The avg ZVE per stablecoin deposit reward, used for reward calculation.

        uint256 diffRate = IZivoeGlobals(GBL).maxZVEPerJTTMint() - IZivoeGlobals(GBL).minZVEPerJTTMint();

        uint256 startRatio = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply() * 10000 / IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();
        uint256 finalRatio = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply() * 10000 / (IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply() + deposit);
        uint256 avgRatio = (startRatio + finalRatio) / 2;

        if (avgRatio <= lowerRatioJTT) {
            // Handle max case (Junior:Senior is 10% or less)
            avgRate = IZivoeGlobals(GBL).minZVEPerJTTMint();
        } else if (avgRatio >= upperRatioJTT) {
            // Handle min case (Junior:Senior is 25% or more)
            avgRate = IZivoeGlobals(GBL).maxZVEPerJTTMint();
        } else {
            // Handle in-between case, avgRatio domain = (1000, 2500).
            avgRate = IZivoeGlobals(GBL).minZVEPerJTTMint() + diffRate * (avgRatio - 1000) / (1500);
        }

        reward = avgRate * deposit / 1 ether;

        // Reduce if ZVE balance < reward.
        if (IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this)) < reward) {
            reward = IERC20(IZivoeGlobals(GBL).ZVE()).balanceOf(address(this));
        }
    }

}