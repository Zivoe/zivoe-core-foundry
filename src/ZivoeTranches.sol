// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./ZivoeLocker.sol";

import { SafeERC20 } from "./OpenZeppelin/SafeERC20.sol";
import { IERC20 } from "./OpenZeppelin/IERC20.sol";
import { IERC20Metadata } from "./OpenZeppelin/IERC20Metadata.sol";
import { IZivoeGlobals, IERC20Mintable } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract will facilitate ongoing liquidity provision to Zivoe tranches (Junior, Senior).
///         This contract will be permissioned by JuniorTrancheToken and SeniorTrancheToken to call mint().
///         This contract will support a whitelist for stablecoins to provide as liquidity.
contract ZivoeTranches is ZivoeLocker {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;   /// @dev The ZivoeGlobals contract.

    mapping(address => bool) public stablecoinWhitelist;    /// @dev Whitelist for stablecoins accepted as deposit.

    // 15% ZVE
    // 3,375,000 ZVE
    // minZVEPerMint() => 0.001
    // maxZVEPerMint() => 0.01
    // extZVEPerSTT()  => equation [0, 0.01]
    // extZVEPerJTT()  => equation [0, 0.01]
    // mint zSTT = 1 zSTT + minZVEPerMint() + extZVEPerSTT()
    // mint zJTT = 1 zJTT + minZVEPerMint() + extZVEPerJTT()

    // TODO: Consideration, maxZVEPerMint(), governable or immutable

    // zJTT.totalSupply() => 10mm
    // zSTT.totalSupply() => 100mm

    // 10% RATIO

    // 3,375,000 ZVE ... 0.01 ZVE / mint(zJTT/zSTT) ... rewards will last 300,000,000

    uint256 zvePerSTTMinted;
    uint256 zvePerJTTMinted;

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

    // TODO: Expose canPush() / canPull()
    // TODO: Implement pushToLocker() / pullFromLocker() / pullFromLockerPartial()

    /// @notice Deposit stablecoins into the junior tranche.
    ///         Mints JuniorTrancheToken ($zJTT) in 1:1 ratio.
    /// @param  amount The amount to deposit.
    /// @param  asset The asset (stablecoin) to deposit.
    function depositJunior(uint256 amount, address asset) external {
        require(stablecoinWhitelist[asset], "ZivoeTranches::depositJunior() !stablecoinWhitelist[asset]");

        // TODO: Cap the amount of deposits in junior tranche relative to senior tranche size (zSTT.totalSupply()).
        // TODO: Enable this percentage/portion to be adjustable via GBL reference.

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

}