// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockStablecoin is ERC20 {
    uint8 dec;

    constructor(
        string memory name,
        string memory symbol,
        uint8 _dec
    ) ERC20(name, symbol) {
        dec = _dec;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return dec;
    }
}
