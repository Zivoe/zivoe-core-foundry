// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

/// @dev specialized math functions that always return uint256 and never revert. 
///      using these make some of the codes shorter. trySub etc from openzeppelin 
///      would have been okay but these tryX math functions return tupples to include information 
///      about the success of the function, which would have resulted in significant waste for our purposes. 
library ZivoeMath {
    
    /// @dev return 0 of div would result in val < 1 or divide by 0
    function zDiv(uint256 x, uint256 y) internal pure returns (uint256) {
        unchecked {
            if (y == 0) return 0;
            if (y > x) return 0;
            return (x / y);
        }
    }

    /// @dev  Subtraction routine that does not revert and returns a singleton, 
    ///         making it cheaper and more suitable for composition and use as an attribute. 
    ///         It returns the closest uint256 to the actual answer if the answer is not in uint256. 
    ///         IE it gives you 0 instead of reverting. It was made to be a cheaper version of openZepelins trySub.
    function zSub(uint256 x, uint256 y) internal pure returns (uint256) {
        unchecked {
            if (y > x) return 0;
            return (x - y);
        }
    }
    
    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}