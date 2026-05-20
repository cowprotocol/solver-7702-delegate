// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

import {Solver7702Delegate} from "src/Solver7702Delegate.sol";
import {BaseTest} from "test/BaseTest.t.sol";

contract Solver7702DelegateTest is BaseTest {
    uint256 internal constant MSG_VALUE = 1 ether;

    address internal unauthorizedCaller;
    address internal fallbackTarget;
    address internal rawRevertTarget;
    Solver7702Delegate internal delegateContract;

    function setUp() public override {
        super.setUp();

        unauthorizedCaller = makeAddr("UNAUTHORIZED_CALLER");
        fallbackTarget = makeAddr("FALLBACK_TARGET");
        rawRevertTarget = makeAddr("RAW_REVERT_TARGET");
        delegateContract = new Solver7702Delegate(approvedCallers);
    }

    function test_unit_fallback_success_unauthorizedCallerReceivesEth() public {
        vm.deal(unauthorizedCaller, MSG_VALUE);

        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = address(delegateContract).call{value: MSG_VALUE}("");
        vm.snapshotGasLastCall("unauthorized caller - success - receives ETH");

        assertTrue(success, "unauthorized caller ETH transfer should succeed");
        assertEq(returnData.length, 0, "ETH transfer should return no data");
        assertEq(address(delegateContract).balance, MSG_VALUE, "delegate should receive ETH");
    }

    function test_unit_fallback_success_shortCalldataReturnsEmpty() public {
        bytes memory shortCalldata = _randomBytesWithLength(19, bytes32(uint256(19)));

        vm.prank(approvedCallers[0]);
        (bool success, bytes memory returnData) = address(delegateContract).call(shortCalldata);
        vm.snapshotGasLastCall("approved caller short calldata - success - returns empty");

        assertTrue(success, "approved caller short calldata should succeed");
        assertEq(returnData.length, 0, "short calldata should return no data");
        assertEq(address(delegateContract).balance, 0, "delegate balance should not change");
    }

    function test_unit_fallback_success_shortCalldataReceivesEth() public {
        bytes memory shortCalldata = _randomBytesWithLength(19, bytes32(uint256(19)));
        uint256 delegateBalanceBefore = address(delegateContract).balance;

        vm.deal(approvedCallers[0], MSG_VALUE);
        vm.prank(approvedCallers[0]);
        (bool success, bytes memory returnData) = address(delegateContract).call{value: MSG_VALUE}(shortCalldata);
        vm.snapshotGasLastCall("approved caller short calldata - success - receives ETH");

        assertTrue(success, "approved caller short calldata ETH transfer should succeed");
        assertEq(returnData.length, 0, "short calldata should return no data");
        assertEq(address(delegateContract).balance, delegateBalanceBefore + MSG_VALUE, "delegate should receive ETH");
    }

    function test_unit_fallback_success_forwardsEmptyPayload() public {
        bytes memory emptyPayload;
        vm.mockCall(fallbackTarget, uint256(0), emptyPayload, "");
        vm.expectCall(fallbackTarget, uint256(0), emptyPayload);

        vm.prank(approvedCallers[0]);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(fallbackTarget, emptyPayload));
        vm.snapshotGasLastCall("approved caller empty target payload - success - forwards");

        assertTrue(success, "empty target payload should forward");
        assertEq(returnData.length, 0, "empty target payload should return no data");
    }

    function test_unit_fallback_success_forwardsPayload() public {
        bytes memory payload = hex"abcdef";
        vm.deal(approvedCallers[0], MSG_VALUE);
        vm.mockCall(fallbackTarget, MSG_VALUE, payload, "");
        vm.expectCall(fallbackTarget, MSG_VALUE, payload);

        vm.prank(approvedCallers[0]);
        (bool success, bytes memory returnData) =
            address(delegateContract).call{value: MSG_VALUE}(_packedCalldata(fallbackTarget, payload));
        vm.snapshotGasLastCall("approved caller target payload - success - forwards");

        assertTrue(success, "approved caller should forward payload");
        assertEq(returnData.length, 0, "target return data should be empty");
    }

    function test_unit_fallback_success_bubblesReturnData() public {
        bytes memory expectedReturnData = hex"010203040506";
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("returnRaw(bytes)")), expectedReturnData);
        vm.mockCall(fallbackTarget, payload, expectedReturnData);

        vm.prank(approvedCallers[0]);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(fallbackTarget, payload));
        vm.snapshotGasLastCall("approved caller target return data - success - bubbles return data");

        assertTrue(success, "target call should succeed");
        assertEq(returnData, expectedReturnData, "return data should match target output");
    }

    function test_fuzz_fallback_success_forwardsPayloadFromApprovedCaller(
        uint8 callerIndex,
        bytes memory payload,
        uint96 value,
        bytes memory expectedReturnData
    ) public {
        address caller = approvedCallers[uint256(callerIndex) % approvedCallers.length];
        vm.deal(caller, value);
        vm.mockCall(fallbackTarget, value, payload, expectedReturnData);
        vm.expectCall(fallbackTarget, value, payload);

        vm.prank(caller);
        (bool success, bytes memory returnData) =
            address(delegateContract).call{value: value}(_packedCalldata(fallbackTarget, payload));

        assertTrue(success, "fuzzed approved caller should forward payload");
        assertEq(returnData, expectedReturnData, "target return data should bubble");
    }

    function test_unit_fallback_revertsWith_UnauthorizedCaller() public {
        bytes memory payload = hex"12345678";

        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(fallbackTarget, payload));
        vm.snapshotGasLastCall("unauthorized caller no value - reverts - unauthorized");

        assertFalse(success, "unauthorized caller should revert");
        assertEq(
            returnData,
            abi.encodeWithSelector(Solver7702Delegate.Unauthorized.selector, unauthorizedCaller),
            "revert data should match Unauthorized error"
        );
    }

    function test_unit_fallback_revertsWith_NonEmptyRevertData() public {
        bytes memory expectedRevertData =
            abi.encodeWithSelector(bytes4(keccak256("RawRevert(uint256,string)")), uint256(42), "bad call");
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("revertRaw(bytes)")), expectedRevertData);
        vm.mockCallRevert(rawRevertTarget, payload, expectedRevertData);

        vm.prank(approvedCallers[0]);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(rawRevertTarget, payload));
        vm.snapshotGasLastCall("approved caller target revert data - reverts - bubbles non-empty data");

        assertFalse(success, "target revert should bubble failure");
        assertEq(returnData, expectedRevertData, "revert data should match target revert");
    }

    function test_unit_fallback_revertsWith_EmptyRevertData() public {
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("revertRaw(bytes)")), "");
        vm.mockCallRevert(rawRevertTarget, payload, "");

        vm.prank(approvedCallers[0]);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(rawRevertTarget, payload));
        vm.snapshotGasLastCall("approved caller target empty revert - reverts - bubbles empty data");

        assertFalse(success, "empty target revert should bubble failure");
        assertEq(returnData.length, 0, "revert data should be empty");
    }

    function _isCallerApproved(address caller) internal view returns (bool) {
        for (uint256 i; i < approvedCallers.length; ++i) {
            if (caller == approvedCallers[i]) {
                return true;
            }
        }
        return false;
    }

    function _callDelegateAs(address caller, bytes memory data) internal {
        vm.prank(caller);
        (bool success, bytes memory returnData) = address(delegateContract).call(data);
        if (!success) {
            assembly ("memory-safe") {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
    }

    function _randomBytesWithLength(uint256 length, bytes32 seed) internal pure returns (bytes memory data) {
        data = new bytes(length);
        for (uint256 i; i < length; ++i) {
            data[i] = bytes1(uint8(uint256(keccak256(abi.encode(seed, i)))));
        }
    }
}
