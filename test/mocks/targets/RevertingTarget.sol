// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

/// @notice Target with normal Solidity revert shapes.
/// @dev Used to cover custom errors, revert strings, panic data, and empty revert data.
contract RevertingTarget {
    error TargetCustomError(address sender, uint256 value, bytes payload);

    /// @notice Reverts with a typed custom error carrying sender, value, and payload.
    function revertWithCustomError(uint256 value, bytes calldata payload) external payable {
        revert TargetCustomError(msg.sender, value, payload);
    }

    /// @notice Reverts with the standard `Error(string)` ABI payload.
    function revertWithString(string calldata reason) external pure {
        revert(reason);
    }

    /// @notice Triggers Solidity panic code 0x11 for arithmetic underflow.
    function revertWithPanic() external pure {
        uint256 value;
        --value;
    }

    /// @notice Reverts with no data.
    function revertWithoutData() external pure {
        assembly {
            revert(0, 0)
        }
    }
}
