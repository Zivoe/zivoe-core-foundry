// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";

interface ZivoeVotes_IZivoeGlobals {
    function stZVE() external view returns (address);
}

abstract contract ZivoeVotes is ERC20Votes {

    /// @notice Custom virtual function for viewing GBL (ZivoeGlobals).
    function GBL() public view virtual returns (address) {
        return address(0);
    }

    /**
     * @dev Move voting power when tokens are transferred.
     *
     * Emits a {IVotes-DelegateVotesChanged} event.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Votes) {
        if (ZivoeVotes_IZivoeGlobals(GBL()).stZVE() == address(0) || (to != ZivoeVotes_IZivoeGlobals(GBL()).stZVE() && from != ZivoeVotes_IZivoeGlobals(GBL()).stZVE())) {
            ERC20Votes._afterTokenTransfer(from, to, amount);
        }
    }
}
