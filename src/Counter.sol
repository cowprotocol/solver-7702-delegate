// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8;

/// @title Counter
/// @author CoW DAO developers
/// @notice Simple counter contract used by the template.
contract Counter {
    /// @notice The stored counter value.
    uint256 public number;

    /// @notice Set the counter to a new value.
    /// @param newNumber The value to store.
    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    /// @notice Increase the counter by one.
    function increment() public {
        ++number;
    }
}
