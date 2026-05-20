// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

/// @title Solver7702Delegate
/// @author CoW Foundation
/// @notice ERC-7702 delegation target for solver EOAs
contract Solver7702Delegate {
    /// @notice Error thrown when a caller is unauthorized
    error Unauthorized(address sender);

    /// @notice Address of the first approved caller
    address private immutable APPROVED_CALLER_0;

    /// @notice Address of the second approved caller
    address private immutable APPROVED_CALLER_1;

    /// @notice Address of the third approved caller
    address private immutable APPROVED_CALLER_2;

    /// @notice Address of the fourth approved caller
    address private immutable APPROVED_CALLER_3;

    /// @notice Address of the fifth approved caller
    address private immutable APPROVED_CALLER_4;

    /// @notice Constructor to initialize the approved callers
    /// @param approvedCallers The addresses of the approved callers
    constructor(address[5] memory approvedCallers) {
        APPROVED_CALLER_0 = approvedCallers[0];
        APPROVED_CALLER_1 = approvedCallers[1];
        APPROVED_CALLER_2 = approvedCallers[2];
        APPROVED_CALLER_3 = approvedCallers[3];
        APPROVED_CALLER_4 = approvedCallers[4];
    }

    /// @notice Fallback function to handle calls to the delegate
    fallback() external payable {
        // Possibly short circuit by recognizing one of the approved callers
        if (
            msg.sender == APPROVED_CALLER_0 || msg.sender == APPROVED_CALLER_1 || msg.sender == APPROVED_CALLER_2
                || msg.sender == APPROVED_CALLER_3 || msg.sender == APPROVED_CALLER_4
        ) return _callThrough();

        // Accept ETH from anyone, even if unauthorized
        if (msg.value > 0) return;
        revert Unauthorized(msg.sender);
    }

    function _callThrough() internal {
        // Receive ETH and exit when no target address is encoded.
        if (msg.data.length < 20) return;

        // Extract the first 20 bytes of calldata as the target address.
        address target = address(bytes20(msg.data[0:20]));

        assembly {
            // Extract calldata in range (target, len(msg.data)).
            // We take full control of memory in this inline assembly block because it will not return to Solidity code.
            // This is why we overwrite the Solidity scratch pad at memory position 0.
            calldatacopy(0x00, 20, sub(calldatasize(), 20))

            // Call the implementation
            let result :=
                call(
                    gas(), // gas - forward all of it
                    target, // target to call
                    callvalue(), // value - forward all Ether
                    0x00, // input offset - pointer to calldata
                    sub(calldatasize(), 20), // input size - length of calldata
                    0x00, // output offset - read via returndatacopy below
                    0x00 // output size - read via returndatacopy below
                )

            // Copy return data into memory
            returndatacopy(0x00, 0x00, returndatasize())

            // Handle return data, 0 = revert / 1 = success
            switch result
            case 0 {
                revert(0x00, returndatasize())
            }
            default {
                return(0x00, returndatasize())
            }
        }
    }
}
