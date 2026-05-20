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

    function test_unit_fallback_success_shortCalldataReceivesEthFromAnyCaller() public {
        address[2] memory callers = [unauthorizedCaller, approvedCallers[0]];
        uint256 delegateBalanceBefore = address(delegateContract).balance;

        for (uint256 i; i < callers.length; ++i) {
            for (uint256 length; length < 20; ++length) {
                bytes memory shortCalldata = _randomBytesWithLength(length, bytes32(length));
                vm.deal(callers[i], MSG_VALUE);

                vm.prank(callers[i]);
                (bool success, bytes memory returnData) =
                    address(delegateContract).call{value: MSG_VALUE}(shortCalldata);

                assertTrue(success, "short calldata ETH transfer should succeed");
                assertEq(returnData.length, 0, "short calldata should return no data");
            }
        }
        assertEq(
            address(delegateContract).balance,
            delegateBalanceBefore + MSG_VALUE * callers.length * 20,
            "delegate should receive forwarded ETH"
        );
    }

    function test_unit_fallback_success_forwardsEmptyPayload() public {
        bytes memory emptyPayload;
        vm.mockCall(fallbackTarget, uint256(0), emptyPayload, "");
        vm.expectCall(fallbackTarget, uint256(0), emptyPayload);

        vm.prank(approvedCallers[0]);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(fallbackTarget, emptyPayload));

        assertTrue(success, "empty target payload should forward");
        assertEq(returnData.length, 0, "empty target payload should return no data");
    }

    function test_unit_fallback_success_forwardsPayloadFromApprovedCallers() public {
        for (uint256 i; i < approvedCallers.length; ++i) {
            bytes memory warmupPayload = abi.encodePacked("warmup ", i);
            vm.deal(approvedCallers[i], MSG_VALUE);
            vm.mockCall(fallbackTarget, MSG_VALUE, warmupPayload, "");
            vm.expectCall(fallbackTarget, MSG_VALUE, warmupPayload);

            vm.prank(approvedCallers[i]);
            (bool warmupSuccess, bytes memory warmupReturnData) =
                address(delegateContract).call{value: MSG_VALUE}(_packedCalldata(fallbackTarget, warmupPayload));

            assertTrue(warmupSuccess, "warmup call should forward payload");
            assertEq(warmupReturnData.length, 0, "warmup return data should be empty");
        }

        for (uint256 i; i < approvedCallers.length; ++i) {
            bytes memory payload = abi.encodePacked("slot ", i, bytes32(uint256(100 + i)));
            vm.deal(approvedCallers[i], MSG_VALUE);
            vm.mockCall(fallbackTarget, MSG_VALUE, payload, "");
            vm.expectCall(fallbackTarget, MSG_VALUE, payload);

            vm.prank(approvedCallers[i]);
            (bool success, bytes memory returnData) =
                address(delegateContract).call{value: MSG_VALUE}(_packedCalldata(fallbackTarget, payload));
            vm.snapshotGasLastCall(_packedCalldataGasSnapshotName(i));

            assertTrue(success, "approved caller should forward payload");
            assertEq(returnData.length, 0, "target return data should be empty");
        }
    }

    function test_fuzz_fallback_success_forwardsPayloadFromApprovedCaller(
        uint8 callerIndex,
        bytes memory payload,
        uint96 value
    ) public {
        address caller = approvedCallers[uint256(callerIndex) % approvedCallers.length];
        vm.deal(caller, value);
        bytes memory expectedReturnData;
        if (payload.length == 0) {
            vm.mockCall(fallbackTarget, value, payload, "");
        } else {
            expectedReturnData = _mockFallbackReturn(address(delegateContract), value, payload, 0);
        }
        vm.expectCall(fallbackTarget, value, payload);

        vm.prank(caller);
        (bool success, bytes memory returnData) =
            address(delegateContract).call{value: value}(_packedCalldata(fallbackTarget, payload));

        assertTrue(success, "fuzzed approved caller should forward payload");
        if (payload.length == 0) {
            assertEq(returnData.length, 0, "empty payload should return no data");
            return;
        }
        assertEq(returnData, expectedReturnData, "target return data should bubble");
    }

    function test_unit_fallback_success_forwardsZeroMsgValue() public {
        bytes memory payload = hex"abcdef";
        bytes memory expectedReturnData =
            _mockFallbackReturn(address(delegateContract), 0, payload, fallbackTarget.balance);
        vm.expectCall(fallbackTarget, uint256(0), payload);

        vm.prank(approvedCallers[0]);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(fallbackTarget, payload));
        vm.snapshotGasLastCall("delegate fallback - success - packed calldata forwards zero ETH");

        assertTrue(success, "zero-value call should forward");
        assertEq(returnData, expectedReturnData, "target return data should bubble");
    }

    function test_fuzz_fallback_success_bubblesReturnData(bytes memory expectedReturnData) public {
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("returnRaw(bytes)")), expectedReturnData);
        vm.mockCall(fallbackTarget, uint256(0), payload, expectedReturnData);

        vm.prank(approvedCallers[0]);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(fallbackTarget, payload));

        assertTrue(success, "fuzzed call should bubble return data");
        assertEq(returnData, expectedReturnData, "fuzzed return data should match target output");
    }

    function test_fuzz_fallback_revertsWith_UnauthorizedCaller(
        uint256 callerPrivateKey,
        bytes20 rawTarget,
        bytes memory payload
    ) public {
        callerPrivateKey = bound(callerPrivateKey, 1, type(uint128).max);
        address caller = vm.addr(callerPrivateKey);
        vm.assume(!_isCallerApproved(caller));

        vm.expectRevert(abi.encodeWithSelector(Solver7702Delegate.Unauthorized.selector, caller));
        _callDelegateAs(caller, abi.encodePacked(rawTarget, payload));
    }

    function test_unit_fallback_revertsWith_NonEmptyRevertData() public {
        bytes memory expectedRevertData =
            abi.encodeWithSelector(bytes4(keccak256("RawRevert(uint256,string)")), uint256(42), "bad call");
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("revertRaw(bytes)")), expectedRevertData);
        vm.mockCallRevert(rawRevertTarget, payload, expectedRevertData);

        vm.expectRevert(expectedRevertData);
        _callDelegateAs(approvedCallers[0], _packedCalldata(rawRevertTarget, payload));
    }

    function test_fuzz_fallback_revertsWith_NonEmptyRevertData(bytes memory expectedRevertData) public {
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("revertRaw(bytes)")), expectedRevertData);
        vm.mockCallRevert(rawRevertTarget, payload, expectedRevertData);

        vm.expectRevert(expectedRevertData);
        _callDelegateAs(approvedCallers[0], _packedCalldata(rawRevertTarget, payload));
    }

    function test_unit_fallback_revertsWith_EmptyRevertData() public {
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("revertRaw(bytes)")), "");
        vm.mockCallRevert(rawRevertTarget, payload, "");

        vm.expectRevert(bytes(""));
        _callDelegateAs(approvedCallers[0], _packedCalldata(rawRevertTarget, payload));
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

    function _packedCalldataGasSnapshotName(uint256 callerIndex) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "delegate fallback - success - approved caller slot ", vm.toString(callerIndex), " forwards payload"
            )
        );
    }

    function _mockFallbackReturn(
        address expectedSender,
        uint256 expectedValue,
        bytes memory expectedPayload,
        uint256 expectedBalance
    ) internal returns (bytes memory returnData) {
        returnData = abi.encode(expectedSender, expectedValue, expectedPayload, expectedBalance);
        vm.mockCall(fallbackTarget, expectedValue, expectedPayload, returnData);
    }
}
