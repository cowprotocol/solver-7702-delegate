// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

/// @notice Target that reverts with arbitrary bytes without ABI wrapping.
/// @dev Used to prove that Solver7702Delegate bubbles revert data exactly, including empty data.
contract RawRevertTarget {
    /// @notice Reverts with `rawRevertData` as the complete revert payload.
    function revertRaw(bytes calldata rawRevertData) external payable {
        bytes memory revertData = rawRevertData;
        assembly {
            revert(add(revertData, 0x20), mload(revertData))
        }
    }
}
