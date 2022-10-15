// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../libraries/OpenZeppelin/ERC721URIStorage.sol";
import "../../../libraries/OpenZeppelin/Counters.sol";

contract ERC721_Generic is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("ZivoeNFT", "ZFT") { }

    function mintGenericNFT(address receiver, string memory tokenURI)
        public
        returns (uint256)
    {
        uint256 newItemId = _tokenIds.current();
        _mint(receiver, newItemId);
        _setTokenURI(newItemId, tokenURI);

        _tokenIds.increment();
        return newItemId;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs::";
    }
}