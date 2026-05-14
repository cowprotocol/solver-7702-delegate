// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

contract MockSettlement {
    uint256 public callCount;
    address public lastSender;
    uint256 public lastValue;
    bytes32 public lastOrderUid;
    uint256 public lastAmount;
    bytes32 public lastPayloadHash;
    uint256 public lastPayloadLength;

    function settle(bytes32 orderUid, uint256 amount) external payable returns (bytes32) {
        ++callCount;
        lastSender = msg.sender;
        lastValue = msg.value;
        lastOrderUid = orderUid;
        lastAmount = amount;

        return orderUid;
    }

    function settlePayload(bytes calldata settlementPayload) external payable returns (bytes32) {
        ++callCount;
        lastSender = msg.sender;
        lastValue = msg.value;
        lastPayloadHash = keccak256(settlementPayload);
        lastPayloadLength = settlementPayload.length;

        return lastPayloadHash;
    }
}
