// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

/// @notice Small math helpers for tests.
library MathUtils {
    /// @notice Returns `left - right`, or zero when `right` is larger.
    function nonNegativeDelta(uint256 left, uint256 right) internal pure returns (uint256) {
        if (left < right) {
            return 0;
        }

        return left - right;
    }
}
