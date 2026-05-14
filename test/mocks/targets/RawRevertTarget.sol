// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

contract RawRevertTarget {
    function revertRaw(bytes calldata rawRevertData) external payable {
        bytes memory revertData = rawRevertData;
        assembly {
            revert(add(revertData, 0x20), mload(revertData))
        }
    }
}
