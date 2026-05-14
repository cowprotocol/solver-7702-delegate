// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

/// @notice Nonpayable target used to test value forwarding into a rejecting target.
/// @dev Calls with ETH fail before fallback body execution and return empty revert data.
contract NonpayableTarget {
    event Called(bytes payload);

    /// @notice Emits payload when called without ETH.
    fallback() external {
        emit Called(msg.data);
    }
}
