// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

// Interface for ZivoeGlobals
interface IZivoeGlobals_OCC_Variable { 
    function YDL() external view returns (address);
    function DAO() external view returns (address);
}

/// @notice  OCC stands for "On-Chain Credit", and Variable refers to supporting a variable payment.
///          This locker is responsible for handling draw limits.
///          This locker is responsible for handling payments, distributions, and for storing payment data.
contract OCC_Cycle is ZivoeLocker, ReentrancyGuard {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;                   /// @dev The ZivoeGlobals contract.
    address public immutable USDC;                  /// @dev The USDC token contract.
    address public immutable underwriter;           /// @dev The entity that manages draw limits.

    mapping(address => uint256) public limit;      /// @dev The draw limit mapping.
    mapping(address => uint256) public usage;      /// @dev The draw usage mapping.
    mapping(address => bool) public cycleList;     /// @dev The cycle whitelist.


    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCC_Variable contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _USDC The USDC token contract.
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _underwriter The entity that manages draw limits.
    constructor(
        address DAO, 
        address _USDC, 
        address _GBL,
        address _underwriter
    ) {
        transferOwnershipAndLock(DAO);
        USDC = _USDC;
        GBL = _GBL;
        underwriter = _underwriter;

        limit[0xC8d6248fFbc59BFD51B23E69b962C60590d5f026] = uint(20_000_000 * 10**6);
        limit[0x50C72Ff8c5e7498F64BEAeB8Ed5BE83CABEB0Fd5] = uint(20_000_000 * 10**6);
        usage[0xC8d6248fFbc59BFD51B23E69b962C60590d5f026] = uint(5_000_000 * 10**6);
        usage[0x50C72Ff8c5e7498F64BEAeB8Ed5BE83CABEB0Fd5] = uint(1_000_000 * 10**6);
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted when a user draws USDC.
    /// @param  amount The amount drawn.
    /// @param  user The user that drew the funds.
    event Draw(uint256 amount, address indexed user);

    /// @notice Emitted when a user repays USDC.
    /// @param  amount The amount repaid.
    /// @param  base The base amount repaid.
    /// @param  user The user that repaid the funds.
    event Repay(uint256 amount, uint256 base, address indexed user);

    /// @notice Emitted when a user cycles USDC.
    /// @param  amount The amount cycled.
    /// @param  base The new base amount.
    /// @param  user The user cycled for.
    event Cycle(uint256 amount, uint256 base, address indexed user);

    /// @notice Emitted when the underwriter adjusts a draw limit.
    /// @param  amount The amount to adjust the limit to.
    /// @param  user The user to adjust the limit for.
    event AdjustLimit(uint256 amount, address indexed user);

    /// @notice Emitted when the underwriter adjusts usage.
    /// @param  amount The amount to adjust the usage to.
    /// @param  user The user to adjust the usage for.
    event AdjustUsage(uint256 amount, address indexed user);
    

    // ---------------
    //    Modifiers
    // ---------------

    /// @notice This modifier ensures that the caller is the entity that is allowed to issue loans.
    modifier isUnderwriter() {
        require(_msgSender() == underwriter, "OCC_Cycle::isUnderwriter() _msgSender() != underwriter");
        _;
    }

    /// @notice This modifier ensures that the caller is on the cycle whitelist.
    modifier isCycler() {
        require(cycleList[_msgSender()], "OCC_Cycle::isCycler() !isCycler[_msgSender()]");
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

    /// @notice This pulls capital from the DAO and deposits it into this contract
    /// @param  asset The asset to pull from the DAO.
    /// @param  amount The amount of asset to pull from the DAO.
    /// @param  data Accompanying transaction data.
    function pushToLocker(
        address asset, uint256 amount, bytes calldata data
    ) external override onlyOwner nonReentrant {
        require(asset == USDC, "OCC_Cycle::pushToLocker() asset != USDC");
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override onlyOwner nonReentrant {
        require(asset == USDC, "OCC_Cycle::pullFromLocker() asset != USDC");
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(
        address asset, uint256 amount, bytes calldata data
    ) external override onlyOwner nonReentrant {
        require(asset == USDC, "OCC_Cycle::pullFromLockerPartial() asset != USDC");
        IERC20(USDC).safeTransfer(owner(), amount);
    }

    /// @notice Adjusts the limit for a particular user.
    /// @param  user The address to adjust the cycle list for.
    /// @param  status The status to set the cycle list to.
    function adjustCycleList(address user, bool status) external isUnderwriter { 
        cycleList[user] = status;
    }

    /// @notice Adjusts the limit for a particular user.
    /// @param  amount The amount to adjust the limit to.
    /// @param  user The user to adjust the limit for.
    function adjustLimit(uint256 amount, address user) external isUnderwriter { 
        limit[user] = amount;
        emit AdjustLimit(amount, user);
    }

    /// @notice Adjusts the usage for a particular user.
    /// @param  amount The amount to adjust the usage to.
    /// @param  user The user to adjust the usage for.
    function adjustUsage(uint256 amount, address user) external isUnderwriter { 
        usage[user] = amount;
        emit AdjustUsage(amount, user);
    }

    /// @notice Draw from OCC_Variable.
    /// @param  amount The amount to draw.
    function draw(uint256 amount) external { 
        require(amount + usage[_msgSender()] <= limit[_msgSender()], "OCC_Cycle::draw() amount + usage > limit");
        usage[_msgSender()] += amount;
        IERC20(USDC).safeTransfer(_msgSender(), amount);
        emit Draw(amount, _msgSender());
    }

    /// @notice Repay to OCC_Variable.
    /// @param  amount The amount to repay.
    /// @param  base The base amount to repay.
    function repay(uint256 amount, uint256 base) external { 
        require(base <= amount, "OCC_Cycle::repay() base > amount");
        require(amount <= usage[_msgSender()], "OCC_Cycle::repay() amount > usage");
        IERC20(USDC).safeTransferFrom(_msgSender(), address(this), amount);

        // "Amount - base" is forwarded to YDL.
        IERC20(USDC).safeTransfer(IZivoeGlobals_OCC_Variable(GBL).YDL(), amount - base);
        
        // "Base" is forwarded to DAO.
        if (base > 0) {
            IERC20(USDC).safeTransfer(IZivoeGlobals_OCC_Variable(GBL).DAO(), base);
            usage[_msgSender()] -= base;
        }

        emit Repay(amount, base, _msgSender());
    }

    /// @notice Cycle USDC for compounding base.
    /// @param  amounts The amounts to cycle.
    /// @param  users The users to cycle for.
    function cycle(uint256[] calldata amounts, address[] calldata users) external isCycler { 
        require(amounts.length == users.length, "OCC_Cycle::cycle() amounts.length != users.length");
        for (uint i = 0; i < amounts.length; i++) {
            usage[users[i]] += amounts[i];
            IERC20(USDC).safeTransferFrom(_msgSender(), IZivoeGlobals_OCC_Variable(GBL).YDL(), amounts[i]);
            emit Cycle(amounts[i], usage[users[i]], users[i]);
        }
    }


}