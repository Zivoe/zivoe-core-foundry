// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/OwnableGovernance.sol";

/// @dev    This ERC20 contract outlines the tranche token functionality.
///         This contract should support the following functionalities:
///          - Mintable
///          - Burnable
///         To be determined:
///          - Which contracts should be allowed to mint.
///          - Governance process (over-time) for allowing minting to occur.
contract ZivoeTrancheToken is OwnableGovernance {

    /// TODO: Convert this into ERC20 OpenZeppelin standard.

    // ---------------------
    //    State Variables
    // ---------------------

    uint256 private _totalSupply;   /// @dev Name of token, exposed via totalSupply() view function.
    uint8 private   _decimals;      /// @dev Decimal precision of token, exposed via decimals() view function.

    string private _name;           /// @dev Name of token, exposed via name() view function.
    string private _symbol;         /// @dev Name of token, exposed via symbols() view function.
    
    mapping(address => uint256) private _balances;                          /// @dev Token balance of accounts, exposed in balanceOf() view function.
    mapping(address => mapping(address => uint256)) private _allowances;    /// @dev Allowances of accounts, exposed in allowances() view function.

    mapping(address => bool) private _isMinter;     /// @dev Whitelist for accessibility to mint() function, exposed in isMinter() view function.



    // -----------------
    //    Constructor
    // -----------------

    // TODO: Refactor Governance instantiation, and transfer (?) - depends on minting requirements / best practices.

    /// @notice Initializes the TrancheToken.sol contract ($zTT).
    /// @dev    _totalSupply for this contract initializes to 0.
    /// @param name_ The name (JuniorTrancheToken, SeniorTrancheToken).
    /// @param symbol_ The symbol ($zJTT, $zSTT).
    /// @param god      Governance contract.
    constructor(
        string memory name_,
        string memory symbol_,
        address god
    ) {
        _decimals = 18;
        
        _name = name_;
        _symbol = symbol_;

        transferOwnershipOnce(god);
    }



    // ------------
    //    Events
    // ------------

    /// @notice This event is emitted when transfer() or transferFrom() is called.
    /// @param  from The source account.
    /// @param  to The destination account.
    /// @param  value The number of tokens transferred.
    event Transfer(address from, address to, uint256 value);
    
    /// @notice This event is emitted when approve() is called.
    /// @param  account The source account, approving the spender.
    /// @param  spender The account with approval, who is allowed to spend tokens.
    /// @param  value The number of tokens spender has allowance for transferFrom() calls.
    event Approval(address account, address spender, uint256 value);
    
    /// @notice This event is emitted when burn() is called.
    /// @param  account The source account, burning tokens.
    /// @param  value The amount of tokens burned.
    event Burn(address account, uint256 value);

    /// @notice This event is emitted when changeMinterRole() is called.
    /// @param  account The account who is receiving or losing the minter role.
    /// @param  allowed If true, the account is receiving minter role privlidges, if false the account is losing minter role privlidges.
    event MinterUpdated(address indexed account, bool allowed);



    // ---------------
    //    Modifiers
    // ---------------

    /// @dev Enforces the caller has minter role privlidges.
    modifier isMinterRole() {
        require(_isMinter[_msgSender()], "TrancheToken.sol::isMinterRole() _isMinter[_msgSender()] == False");
        _;
    }



    // ---------------
    //    Functions
    // ---------------
    
    /// @notice Returns the private variable _totalSupply.
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /// @notice Returns the private variable _decimals.
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /// @notice Returns the private variable _name.
    function name() public view returns (string memory) {
        return _name;
    }

    /// @notice Returns the private variable _symbol.
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /// @notice Returns the balance of account (user).
    /// @param account The wallet to view balance of.
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /// @notice Returns the allowance that spender has for account.
    /// @param account The wallet from which tokens are allowed to be spent.
    /// @param spender The wallet which can spend tokens from account.
    function allowance(address account, address spender) public view returns (uint256) {
        return _allowances[account][spender];
    }

    /// @notice Returns the whitelist status of account for accessibility to mint() function.
    /// @param account The account to inspect whitelist status.
    function isMinter(address account) public view returns (bool) {
        return _isMinter[account];
    }

    /// @notice Transfer $zTT tokens from one account to another.
    /// @dev    Public function.
    /// @param  to The account to transfer tokens to (taken from msg.sender).
    /// @param  amount The number of $zTT tokens to transfer.
    function transfer(address to, uint256 amount) public returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /// @notice Transfer $zTT tokens from one account to another.
    /// @dev    Internal function.
    /// @param  from The address to transfer tokens from.
    /// @param  to The account to transfer tokens to (taken from msg.sender).
    /// @param  amount The number of $zTT tokens to transfer.
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "TrancheToken.sol::transfer() from == address(0)");
        require(to != address(0), "TrancheToken.sol::transfer() to == address(0)");
        
        uint256 fromBalance = _balances[from];

        require(fromBalance >= amount, "TrancheToken.sol::transfer() amount exceeds user balance");

        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    /// @notice Transfer $zTT tokens from one account to another, using allowances of msg.sender (_msgSender).
    /// @param  from The account to transfer tokens from.
    /// @param  to The account to transfer tokens to.
    /// @param  amount The number of $zTT tokens to transfer.
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /// @notice Internal function for reducing allowance during a transferFrom() call.
    /// @param  account The account whose tokens are transferred.
    /// @param  spender The account calling transferFrom(), whose allowance is used / reduced.
    /// @param  amount The amount to reduce allowance.
    function _spendAllowance(
        address account,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = allowance(account, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "TrancheToken.sol::_spendAllowance() insufficient allowance");
            unchecked {
                _approve(account, spender, currentAllowance - amount);
            }
        }
    }

    /// @notice Approve a spender to spend tokens on behalf of msg.sender.
    /// @param  spender The account which is allowed to spend $zTT tokens.
    /// @param  amount The amount of $zTT tokens that spender is allowed to spend.
    function approve(address spender, uint256 amount) public returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /// @notice Internal function for setting allowance of "spedner" over the tokens in "account".
    /// @param  account The account that "spender" will be given allowance over.
    /// @param  spender The account that can use allowance in transferFrom() calls for "account".
    /// @param  amount The amount to set allowance to.
    function _approve(
        address account,
        address spender,
        uint256 amount
    ) internal {
        require(account != address(0), "TrancheToken.sol::_spendAllowance() account == address(0)");
        require(spender != address(0), "TrancheToken.sol::_spendAllowance() spender == address(0)");
        _allowances[account][spender] = amount;
        emit Approval(account, spender, amount);
    }

    /// @notice Alternative method of increasing amount of tokens spender can spend on behalf of msg.sender.
    /// @param  account The account to increase allowance of.
    /// @param  amount The additional amount of $zTT tokens that "account" can spend on behalf of msg.sender.
    function increaseAllowance(address account, uint256 amount) public returns (bool) {
        address owner = _msgSender();
        _approve(owner, account, allowance(owner, account) + amount);
        return true;
    }

    /// @notice Alternative method of decreasing amount of tokens spender can spend on behalf of msg.sender
    /// @param  account The account to decrease allowance of.
    /// @param  amount The amount of $zTT tokens reduced that "account" can spend on behalf of msg.sender.
    function decreaseAllowance(address account, uint256 amount) public returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, account);
        require(currentAllowance >= amount, "TrancheToken.sol::decreaseAllowance() underflow, amount decreases allowance < 0");
        unchecked {
            _approve(owner, account, currentAllowance - amount);
        }
        return true;
    }

    /// @notice Mints $zTT tokens.
    /// @dev    Only callable by accounts on the _isMinter whitelist.
    /// @param  account The account to mint tokens for.
    /// @param  amount The amount of $zTT tokens to mint for account.
    function mint(address account, uint256 amount) public isMinterRole {
        _mint(account, amount);
    }

    /// @notice Internal function for minting $zTT tokens.
    /// @param  account The account to mint tokens for.
    /// @param  amount The amount of $zTT tokens to mint for account.
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "TrancheToken.sol::_mint() account == address(0)");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    /// @notice Burns $zTT tokens.
    /// @param  amount The number of $zTT tokens to burn.
    function burn(uint256 amount) public {
         _burn(_msgSender(), amount);
    }

    
    /// @dev    Interal function for burning $zTT tokens.
    /// @param  amount The number of $zTT tokens to burn.
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "TrancheToken.sol::_burn() account == address(0)");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "TrancheToken.sol::_burn() amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;
        
        emit Transfer(account, address(0), amount);
    }

    /// @notice Update an account's permission for access to mint() function.
    /// @dev    Only callable by owner.
    /// @param  account The account to change permissions for.
    /// @param  allowed The permission to give account (true = permitted, false = prohibited).
    function changeMinterRole(address account, bool allowed) onlyGovernance public {
        _isMinter[account] = allowed;
        emit MinterUpdated(account, allowed);
    }
    
}
