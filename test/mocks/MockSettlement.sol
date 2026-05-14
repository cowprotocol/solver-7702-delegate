// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

/// @notice Simple payable settlement target for delegate integration tests.
/// @dev Records sender, value, and payload data so tests can prove calls execute from the delegated solver account.
contract MockSettlement {
    uint256 public callCount;
    address public lastSender;
    uint256 public lastValue;
    bytes32 public lastOrderUid;
    uint256 public lastAmount;
    bytes32 public lastPayloadHash;
    uint256 public lastPayloadLength;

    /// @notice Records a small settlement-like call and returns its order id.
    function settle(bytes32 orderUid, uint256 amount) external payable returns (bytes32) {
        ++callCount;
        lastSender = msg.sender;
        lastValue = msg.value;
        lastOrderUid = orderUid;
        lastAmount = amount;

        return orderUid;
    }

    /// @notice Records a variable-size payload and returns its hash.
    function settlePayload(bytes calldata settlementPayload) external payable returns (bytes32) {
        ++callCount;
        lastSender = msg.sender;
        lastValue = msg.value;
        lastPayloadHash = keccak256(settlementPayload);
        lastPayloadLength = settlementPayload.length;

        return lastPayloadHash;
    }
}
