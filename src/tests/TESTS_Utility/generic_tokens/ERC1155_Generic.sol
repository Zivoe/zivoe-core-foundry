// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../../lib/OpenZeppelin/ERC1155.sol";

contract ERC1155_Generic is ERC1155 {

    uint256 public constant GOLD = 0;
    uint256 public constant SILVER = 1;
    uint256 public constant THORS_HAMMER = 2;
    uint256 public constant SWORD = 3;
    uint256 public constant SHIELD = 4;

    constructor(address _to) ERC1155("https://game.example/api/item/{id}.json") {
        _mint(_to, GOLD, 10**18, "");
        _mint(_to, SILVER, 10**27, "");
        _mint(_to, THORS_HAMMER, 1, "");
        _mint(_to, SWORD, 10**9, "");
        _mint(_to, SHIELD, 10**9, "");
    }
    
}