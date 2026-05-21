// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";

/// @notice Shared setup and helpers for Solver7702Delegate tests.
abstract contract BaseTest is Test {
    /// @notice Shared approved callers.
    address[5] internal approvedCallers;

    /// @notice Creates the default approved callers.
    function setUp() public virtual {
        approvedCallers = [
            makeAddr("APPROVED_CALLER_0"),
            makeAddr("APPROVED_CALLER_1"),
            makeAddr("APPROVED_CALLER_2"),
            makeAddr("APPROVED_CALLER_3"),
            makeAddr("APPROVED_CALLER_4")
        ];
    }

    /// @notice Encodes the delegate fallback calldata as a 20-byte target followed by payload.
    function _packedCalldata(address target, bytes memory payload) internal pure returns (bytes memory) {
        return abi.encodePacked(target, payload);
    }
}
