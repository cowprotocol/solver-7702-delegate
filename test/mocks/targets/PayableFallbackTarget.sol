// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

/// @notice Payable target that records fallback and receive calls.
/// @dev Used to prove that Solver7702Delegate forwards sender context, ETH value, and payload bytes unchanged.
contract PayableFallbackTarget {
    uint256 private callCount;

    /// @notice Counts plain ETH receives with empty calldata.
    receive() external payable {
        ++callCount;
    }

    /// @notice Returns observed call data so tests can assert exact forwarding.
    fallback() external payable {
        ++callCount;

        bytes memory returnData = abi.encode(msg.sender, msg.value, msg.data, address(this).balance);
        assembly {
            return(add(returnData, 0x20), mload(returnData))
        }
    }

    /// @notice Returns `rawReturnData` as the complete returndata payload.
    function returnRaw(bytes calldata rawReturnData) external payable {
        bytes memory returnData = rawReturnData;
        assembly {
            return(add(returnData, 0x20), mload(returnData))
        }
    }
}
