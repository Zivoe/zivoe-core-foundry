// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// TODO: Interface for Chainlink Oracle

/// @notice This contract facilitates a presale for Zivoe.
contract Presale {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public oracle;                  /// @dev Chainlink oracle for ETH.

    uint public pointsFloor = 250;          /// @dev Minimum amount of points earnable, per stablecoin deposit.

    uint public pointsCeiling = 5000;       /// @dev Maximum amount of points earnable, per stablecoin deposit.

    uint public presaleStart;               /// @dev The timestamp at which the presale starts.
    
    uint public presaleDays = 21;           /// @dev The number of days the presale will last.

    mapping(address => bool) public stablecoinWhitelist;    /// @dev Whitelist for stablecoins.

    mapping(address => uint) public points;    /// @dev Track points per user.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the Presale contract.
    /// @param  stablecoins The permitted stablecoins for deposit.
    /// @param  _oracle Chainlink oracle for ETH.
    constructor(address[] memory stablecoins, address _oracle) {

        // DAI, FRAX, USDC, USDT
        stablecoinWhitelist[stablecoins[0]] = true;
        stablecoinWhitelist[stablecoins[1]] = true;
        stablecoinWhitelist[stablecoins[2]] = true;
        stablecoinWhitelist[stablecoins[3]] = true;

        oracle = _oracle;

    }

    // ------------
    //    Events
    // ------------



    // ---------------
    //    Functions
    // ---------------

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  amount              The amount of a given "asset".
    /// @param  asset               The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount  The input "amount" standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount) {
        standardizedAmount = amount;
        if (IERC20Metadata(asset).decimals() < 18) { 
            standardizedAmount *= 10 ** (18 - IERC20Metadata(asset).decimals()); 
        } 
        else if (IERC20Metadata(asset).decimals() > 18) { 
            standardizedAmount /= 10 ** (IERC20Metadata(asset).decimals() - 18);
        }
    }

    


}