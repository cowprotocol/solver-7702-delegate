// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

contract FallbackTarget {
    uint256 private callCount;

    receive() external payable {
        ++callCount;
    }

    fallback() external payable {
        ++callCount;

        bytes memory returnData = abi.encode(msg.sender, msg.value, msg.data, address(this).balance);
        assembly {
            return(add(returnData, 0x20), mload(returnData))
        }
    }
}
