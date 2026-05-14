// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

/// @notice Target that returns arbitrary bytes without ABI wrapping.
/// @dev Used to prove that Solver7702Delegate bubbles returndata exactly.
contract RawReturnTarget {
    /// @notice Returns `rawReturnData` as the complete returndata payload.
    function returnRaw(bytes calldata rawReturnData) external payable {
        bytes memory returnData = rawReturnData;
        assembly {
            return(add(returnData, 0x20), mload(returnData))
        }
    }
}
