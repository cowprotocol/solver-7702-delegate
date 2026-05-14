// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

contract RawReturnTarget {
    function returnRaw(bytes calldata rawReturnData) external payable {
        bytes memory returnData = rawReturnData;
        assembly {
            return(add(returnData, 0x20), mload(returnData))
        }
    }
}
