// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeDAO is Utility {

    function setUp() public {

        deployCore(false);
        
    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate push() state changes.
    // Validate push() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - "locker" must have canPush() exposed as true value.

    function test_ZivoeDAO_push_restrictions() public {

    }

    function test_ZivoeDAO_push_state() public {
        
    }

    // Validate pull() state changes.
    // Validate pull() restrictions.
    // This includes:
    //   - "locker" must have canPull() exposed as true value.

    function test_ZivoeDAO_pull_restrictions() public {

    }

    function test_ZivoeDAO_pull_state() public {
        
    }

    // Validate pullPartial() state changes.
    // Validate pullPartial() restrictions.
    // This includes:
    //   - "locker" must have canPullPartial() exposed as true value.

    function test_ZivoeDAO_pullPartial_restrictions() public {

    }

    function test_ZivoeDAO_pullPartial_state() public {
        
    }

    // Validate pushMulti() state changes.
    // Validate pushMulti() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - assets.length == amounts.length (length of input arrays must equal)
    //   - "locker" must have canPushMulti() exposed as true value.

    function test_ZivoeDAO_pushMulti_restrictions() public {

    }

    function test_ZivoeDAO_pushMulti_state() public {
        
    }

    // Validate pullMulti() state changes.
    // Validate pullMulti() restrictions.
    // This includes:
    //   - "locker" must have canPullMulti() exposed as true value.

    function test_ZivoeDAO_pullMulti_restrictions() public {

    }

    function test_ZivoeDAO_pullMulti_state() public {
        
    }

    // Validate pullMultiPartial() state changes.
    // Validate pullMultiPartial() restrictions.
    // This includes:
    //   - "locker" must have canPullMultiPartial() exposed as true value.
    //   - assets.length == amounts.length (length of input arrays must equal)

    function test_ZivoeDAO_pullMultiPartial_restrictions() public {

    }

    function test_ZivoeDAO_pullMultiPartial_state() public {
        
    }

    // Validate pushERC721() state changes.
    // Validate pushERC721() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - "locker" must have canPushERC721() exposed as true value.

    function test_ZivoeDAO_pushERC721_restrictions() public {

    }

    function test_ZivoeDAO_pushERC721_state() public {
        
    }

    // Validate pushMultiERC721() state changes.
    // Validate pushMultiERC721() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - assets.length == tokenIds.length (length of input arrays must equal)
    //   - tokenIds.length == data.length (length of input arrays must equal)
    //   - "locker" must have canPushMultiERC721() exposed as true value.

    function test_ZivoeDAO_pushMultiERC721_restrictions() public {

    }

    function test_ZivoeDAO_pushMultiERC721_state() public {
        
    }

    // Validate pullERC721() state changes.
    // Validate pullERC721() restrictions.
    // This includes:
    //   - "locker" must have canPullERC721() exposed as true value.

    function test_ZivoeDAO_pullERC721_restrictions() public {

    }

    function test_ZivoeDAO_pullERC721_state() public {
        
    }

    // Validate pullMultiERC721() state changes.
    // Validate pullMultiERC721() restrictions.
    // This includes:
    //   - "locker" must have canPullMultiERC721() exposed as true value.
    //   - assets.length == tokenIds.length (length of input arrays must equal)
    //   - tokenIds.length == data.length (length of input arrays must equal)

    function test_ZivoeDAO_pullMultiERC721_restrictions() public {

    }

    function test_ZivoeDAO_pullMultiERC721_state() public {
        
    }

    // Validate pushERC1155Batch() state changes.
    // Validate pushERC1155Batch() restrictions.
    // This includes:
    //   - "locker" must be whitelisted
    //   - ids.length == amounts.length (length of input arrays must equal)
    //   - "locker" must have canPushERC1155() exposed as true value.

    function test_ZivoeDAO_pushERC1155Batch_restrictions() public {

    }

    function test_ZivoeDAO_pushERC1155Batch_state() public {
        
    }

    // Validate pullERC1155Batch() state changes.
    // Validate pullERC1155Batch() restrictions.
    // This includes:
    //   - "locker" must have canPullERC1155() exposed as true value.
    //   - ids.length == amounts.length (length of input arrays must equal)

    function test_ZivoeDAO_pullERC1155Batch_restrictions() public {

    }

    function test_ZivoeDAO_pullERC1155Batch_state() public {
        
    }

}
