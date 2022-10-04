// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "./ZivoeLocker.sol";

import "./libraries/ZivoeMath.sol";

import "./libraries/OpenZeppelin/IERC20.sol";
import "./libraries/OpenZeppelin/IERC20Metadata.sol";
import "./libraries/OpenZeppelin/SafeERC20.sol";

import { IZivoeGlobals, IERC20Mintable, IZivoeITO } from "./misc/InterfacesAggregated.sol";

/// @dev    This contract will facilitate ongoing liquidity provision to Zivoe tranches - Junior, Senior.
///         This contract will be permissioned by JuniorTrancheToken and SeniorTrancheToken to call mint().
///         This contract will support a whitelist for stablecoins to provide as liquidity.
contract ZivoeTranches is ZivoeLocker {

    using SafeERC20 for IERC20;
    using ZivoeMath for uint256;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;   /// @dev The ZivoeGlobals contract.

    bool public unlocked;           /// @dev Prevents contract from supporting functionality until unlocked.

    uint256 private constant BIPS = 10000;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeTranches.sol contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address _GBL) {
        GBL = _GBL;
    }



    // ------------
    //    Events
    // ------------

    /// @notice This event is emitted when depositJunior() is called.
    /// @param  account The account depositing stablecoins to junior tranche.
    /// @param  asset The stablecoin deposited.
    /// @param  amount The amount of stablecoins deposited.
    /// @param  incentives The amount of incentives ($ZVE) distributed.
    event JuniorDeposit(address indexed account, address asset, uint256 amount, uint256 incentives);

    /// @notice This event is emitted when depositSenior() is called.
    /// @param  account The account depositing stablecoins to senior tranche.
    /// @param  asset The stablecoin deposited.
    /// @param  amount The amount of stablecoins deposited.
    /// @param  incentives The amount of incentives ($ZVE) distributed.
    event SeniorDeposit(address indexed account, address asset, uint256 amount, uint256 incentives);



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

    // TODO: Determine if $ZVE will start in ZivoeTranches to begin with, or it must go through a DAO vote.
    // TODO: Determine (if yes to above) how much $ZVE to add to ZivoeTranches initially
    // TODO: Determine if $ZVE can be pulled from ZivoeTranches

    // TODO: Discuss removing asset == ZVE require statements
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

    /// @notice Returns total circulating supply of zSTT and zJTT, accounting for defaults via markdowns.
    /// @return zSTTSupplyAdjusted zSTT.totalSupply() adjusted for defaults.
    /// @return zJTTSupplyAdjusted zJTT.totalSupply() adjusted for defaults.
    function adjustedSupplies() public view returns (uint256 zSTTSupplyAdjusted, uint256 zJTTSupplyAdjusted) {
        uint256 zSTTSupply = IERC20(IZivoeGlobals(GBL).zSTT()).totalSupply();
        uint256 zJTTSupply = IERC20(IZivoeGlobals(GBL).zJTT()).totalSupply();
        // TODO: Verify if statements below are accurate in certain default states.
        zJTTSupplyAdjusted = zJTTSupply.zSub(IZivoeGlobals(GBL).defaults());
        zSTTSupplyAdjusted = (zSTTSupply + zJTTSupply).zSub(
            IZivoeGlobals(GBL).defaults().zSub(zJTTSupplyAdjusted)
        );
    }

    /// @notice Converts the amount based on the asset's number of decimals.
    /// @param  amount The amount to convert.
    /// @param  asset The asset (stablecoin) to convert.
    function convertAmount(uint256 amount, address asset) internal view returns (uint256) {
        uint256 convertedAmount = amount;

        if (IERC20Metadata(asset).decimals() < 18) {
            convertedAmount *= 10 ** (18 - IERC20Metadata(asset).decimals());
        } else if (IERC20Metadata(asset).decimals() > 18) {
            convertedAmount *= 10 ** (IERC20Metadata(asset).decimals() - 18);
        }

        return convertedAmount;
    }

    /// @notice Checks if stablecoins deposits into the Junior Tranche are open.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset (stablecoin) to deposit.
    function isJuniorOpen(uint256 amount, address asset) external view returns (bool) {
         uint256 convertedAmount = convertAmount(amount, asset);

        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();

        return convertedAmount + juniorSupp < seniorSupp * IZivoeGlobals(GBL).maxTrancheRatioBIPS() / BIPS;
    }

    /// @notice Deposit stablecoins into the junior tranche.
    ///         Mints JuniorTrancheToken ($zJTT) in 1:1 ratio.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset (stablecoin) to deposit.
    function depositJunior(uint256 amount, address asset) external {
        require(IZivoeGlobals(GBL).stablecoinWhitelist(asset), "ZivoeTranches::depositJunior() !IZivoeGlobals(GBL).stablecoinWhitelist(asset)");
        require(unlocked, "ZivoeTranches::depositJunior() !unlocked");

        address depositor = _msgSender();

        IERC20(asset).safeTransferFrom(depositor, IZivoeGlobals(GBL).DAO(), amount);
        
        uint256 convertedAmount = convertAmount(amount, asset);

        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();

        require(
            convertedAmount + juniorSupp < seniorSupp * IZivoeGlobals(GBL).maxTrancheRatioBIPS() / BIPS,
            "ZivoeTranches::depositJunior() deposit exceeds maxTrancheRatioCapBIPS"
        );

        uint256 incentives = rewardZVEJuniorDeposit(convertedAmount);
        emit JuniorDeposit(depositor, asset, amount, incentives);

        // NOTE: Ordering important, transfer ZVE rewards prior to minting zJTT() due to totalSupply() changes.
        IERC20(IZivoeGlobals(GBL).ZVE()).transfer(depositor, incentives);
        IERC20Mintable(IZivoeGlobals(GBL).zJTT()).mint(depositor, convertedAmount);
    }

    /// @notice Deposit stablecoins into the senior tranche.
    ///         Mints SeniorTrancheToken ($zSTT) in 1:1 ratio.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset (stablecoin) to deposit.
    function depositSenior(uint256 amount, address asset) external {
        require(IZivoeGlobals(GBL).stablecoinWhitelist(asset), "ZivoeTranches::depositSenior() !IZivoeGlobals(GBL).stablecoinWhitelist(asset)");
        require(unlocked, "ZivoeTranches::depositSenior() !unlocked");

        address depositor = _msgSender();

        IERC20(asset).safeTransferFrom(depositor, IZivoeGlobals(GBL).DAO(), amount);
        
        uint256 convertedAmount = convertAmount(amount, asset);

        uint256 incentives = rewardZVESeniorDeposit(convertedAmount);
        emit SeniorDeposit(depositor, asset, amount, incentives);

        // NOTE: Ordering important, transfer ZVE rewards prior to minting zJTT() due to totalSupply() changes.
        IERC20(IZivoeGlobals(GBL).ZVE()).transfer(depositor, incentives);
        IERC20Mintable(IZivoeGlobals(GBL).zSTT()).mint(depositor, convertedAmount);
    }

    /// @dev Input amount MUST be in wei.
    /// @dev Output amount MUST be in wei.
    function rewardZVEJuniorDeposit(uint256 deposit) public view returns(uint256 reward) {

        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();

        uint256 avgRate;    /// @dev The avg ZVE per stablecoin deposit reward, used for reward calculation.

        uint256 diffRate = IZivoeGlobals(GBL).maxZVEPerJTTMint() - IZivoeGlobals(GBL).minZVEPerJTTMint();

        uint256 startRatio = juniorSupp * BIPS / seniorSupp;
        uint256 finalRatio = (juniorSupp + deposit) * BIPS / seniorSupp;
        uint256 avgRatio = (startRatio + finalRatio) / 2;

        if (avgRatio <= IZivoeGlobals(GBL).lowerRatioIncentive()) {
            // Handle max case (Junior:Senior is 10% or less)
            avgRate = IZivoeGlobals(GBL).maxZVEPerJTTMint();
        } else if (avgRatio >= IZivoeGlobals(GBL).upperRatioIncentive()) {
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

        (uint256 seniorSupp, uint256 juniorSupp) = adjustedSupplies();

        uint256 avgRate;    /// @dev The avg ZVE per stablecoin deposit reward, used for reward calculation.

        uint256 diffRate = IZivoeGlobals(GBL).maxZVEPerJTTMint() - IZivoeGlobals(GBL).minZVEPerJTTMint();

        uint256 startRatio = juniorSupp * BIPS / seniorSupp;
        uint256 finalRatio = juniorSupp * BIPS / (seniorSupp + deposit);
        uint256 avgRatio = (startRatio + finalRatio) / 2;

        if (avgRatio <= IZivoeGlobals(GBL).lowerRatioIncentive()) {
            // Handle max case (Junior:Senior is 10% or less)
            avgRate = IZivoeGlobals(GBL).minZVEPerJTTMint();
        } else if (avgRatio >= IZivoeGlobals(GBL).upperRatioIncentive()) {
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

    /// @notice Unlocks this contract for distributions, sets some initial variables.
    function unlock() external {
        require(_msgSender() == IZivoeGlobals(GBL).ITO(), "ZivoeYDL::unlock() _msgSender() != IZivoeGlobals(GBL).ITO()");
        unlocked = true;
    }

}