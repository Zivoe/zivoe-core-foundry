// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../libraries/OwnableLocked.sol";

import "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IPresale_Oracle {
    /// @notice Returns the latest answer (price) from the oracle.
    function latestAnswer() external view returns (int256);
}

/// @notice This contract facilitates a presale for Zivoe.
contract Presale is OwnableLocked, ReentrancyGuard {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public oracle;                  /// @dev Chainlink oracle for ETH.

    address public treasury;                /// @dev The treasury for the presale.

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
    /// @param  _treasury Chainlink oracle for ETH.
    constructor(address[] memory stablecoins, address _oracle, address _treasury) {

        // DAI, FRAX, USDC, USDT
        stablecoinWhitelist[stablecoins[0]] = true;
        stablecoinWhitelist[stablecoins[1]] = true;
        stablecoinWhitelist[stablecoins[2]] = true;
        stablecoinWhitelist[stablecoins[3]] = true;

        oracle = _oracle;

        treasury = _treasury;

    }



    // ------------
    //    Events
    // ------------

    event StablecoinDeposited(
        address indexed depositor,
        address indexed stablecoin,
        uint256 amount,
        uint256 pointsAwarded
    );

    event ETHDeposited(
        address indexed depositor,
        uint256 amount,
        uint256 oraclePrice,
        uint256 pointsAwarded
    );



    // ---------------
    //    Functions
    // ---------------

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  amount              The amount of a given "asset".
    /// @param  asset               The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount  The input "amount" standardized to 18 decimals.
    function standardize(uint256 amount, address asset) public view returns (uint256 standardizedAmount) {
        standardizedAmount = amount;
        if (IERC20Metadata(asset).decimals() < 18) { 
            standardizedAmount *= 10 ** (18 - IERC20Metadata(asset).decimals()); 
        } 
        else if (IERC20Metadata(asset).decimals() > 18) { 
            standardizedAmount /= 10 ** (IERC20Metadata(asset).decimals() - 18);
        }
    }

    /// @notice Handles deposits for stablecoins, awards points to depositor.
    /// @param  stablecoin The stablecoin to deposit.
    /// @param  amount The amount of stablecoin to deposit.
    function depositStablecoin(address stablecoin, uint256 amount) public {
        require(stablecoinWhitelist[stablecoin], "Presale::depositStablecoin() !stablecoinWhitelist[stablecoin]");
        IERC20(stablecoin).transferFrom(_msgSender(), treasury, amount);
        uint256 amountDeposited = standardize(amount, stablecoin);
    }

    /// @notice Handles deposits for ETH, awards points to depositor.
    function depositETH() nonReentrant public payable {

    }

    /// @notice Read data for price point from Chainlink oracle.
    /// @return price The price, which assumes the precision is 10**8 units.
    function oraclePrice() public view returns (uint256 price) {
        price = uint(IPresale_Oracle(oracle).latestAnswer());
    }

}