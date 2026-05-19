// SPDX-License-Identifier: MIT OR Apache-2.0
// solhint-disable avoid-low-level-calls, gas-small-strings
pragma solidity ^0.8.34;

import {stdError} from "forge-std/StdError.sol";

import {Solver7702Delegate} from "src/Solver7702Delegate.sol";
import {BaseTest} from "test/BaseTest.t.sol";

contract Solver7702DelegateTest is BaseTest {
    error TargetCustomError(address sender, uint256 value, bytes payload);

    address internal fallbackTarget;
    address internal rawRevertTarget;
    address internal revertingTarget;
    address internal nonpayableTarget;
    address internal targetWithoutCode;

    function setUp() public override {
        super.setUp();

        fallbackTarget = makeAddr("FALLBACK_TARGET");
        rawRevertTarget = makeAddr("RAW_REVERT_TARGET");
        revertingTarget = makeAddr("REVERTING_TARGET");
        nonpayableTarget = makeAddr("NONPAYABLE_TARGET");
        targetWithoutCode = makeAddr("TARGET_WITHOUT_CODE");
    }

    // ~~~~~~~~~~~~~~~~~~~~ SUCCESS CASES ~~~~~~~~~~~~~~~~~~~~

    function test_unit_constructor_success_whenApprovedCallersAreDistinct() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[5] memory callers = [
            makeAddr("DISTINCT_CALLER_0"),
            makeAddr("DISTINCT_CALLER_1"),
            makeAddr("DISTINCT_CALLER_2"),
            makeAddr("DISTINCT_CALLER_3"),
            makeAddr("DISTINCT_CALLER_4")
        ];
        Solver7702Delegate distinctDelegate = new Solver7702Delegate(callers);
        vm.snapshotGasLastCall("constructor - success - distinct callers");

        // ~~~~~~~~~~ Call + Assertions ~~~~~~~~~~
        for (uint256 i; i < callers.length; ++i) {
            bytes memory payload = abi.encodePacked("distinct ", i);
            bytes memory expectedReturnData =
                _mockFallbackReturn(address(distinctDelegate), 0, payload, fallbackTarget.balance);

            vm.prank(callers[i]);
            (bool success, bytes memory returnData) =
                address(distinctDelegate).call(_packedCalldata(fallbackTarget, payload));

            assertTrue(success, "distinct approved caller should forward");
            assertEq(returnData, expectedReturnData, "target return data should bubble");
        }
    }

    function test_unit_constructor_success_whenApprovedCallersContainDuplicates() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address repeatedCaller = makeAddr("REPEATED_CALLER");
        address[5] memory callers = [
            repeatedCaller,
            repeatedCaller,
            makeAddr("DUPLICATE_CALLER_2"),
            repeatedCaller,
            makeAddr("DUPLICATE_CALLER_4")
        ];
        Solver7702Delegate duplicateDelegate = new Solver7702Delegate(callers);
        vm.snapshotGasLastCall("constructor - success - duplicate callers");

        bytes memory payload = hex"123456";
        bytes memory expectedReturnData =
            _mockFallbackReturn(address(duplicateDelegate), 0, payload, fallbackTarget.balance);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(repeatedCaller);
        (bool success, bytes memory returnData) =
            address(duplicateDelegate).call(_packedCalldata(fallbackTarget, payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success, "duplicate approved caller should forward");
        assertEq(returnData, expectedReturnData, "target return data should bubble");
    }

    function test_unit_constructor_success_whenApprovedCallersContainZeroAddress() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[5] memory callers =
            [address(0), approvedCallers.second, address(0), approvedCallers.fourth, approvedCallers.fifth];

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        Solver7702Delegate zeroAddressDelegate = new Solver7702Delegate(callers);
        vm.snapshotGasLastCall("constructor - success - zero address callers");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertGt(address(zeroAddressDelegate).code.length, 0, "delegate should deploy with zero-address callers");
    }

    function test_unit_fallback_success_emptyCalldataReceivesEth() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 delegateBalanceBefore = address(delegateContract).balance;
        vm.deal(unauthorizedCaller, MSG_VALUE);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = address(delegateContract).call{value: MSG_VALUE}("");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success, "empty calldata ETH transfer should succeed");
        assertEq(returnData.length, 0, "empty calldata should return no data");
        assertEq(
            address(delegateContract).balance,
            delegateBalanceBefore + MSG_VALUE,
            "delegate should receive forwarded ETH"
        );
    }

    function test_unit_fallback_success_shortCalldataDoesNothing() public {
        // ~~~~~~~~~~ Call + Assertions ~~~~~~~~~~
        for (uint256 length = 1; length < PACKED_TARGET_LENGTH; ++length) {
            bytes memory shortCalldata = _bytesWithLength(length, bytes32(length));

            vm.prank(unauthorizedCaller);
            (bool success, bytes memory returnData) = address(delegateContract).call(shortCalldata);

            assertTrue(success, "short calldata should succeed");
            assertEq(returnData.length, 0, "short calldata should return no data");
        }
    }

    function test_fuzz_fallback_success_shortCalldataDoesNothing(uint8 length, bytes32 seed) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory shortCalldata = _bytesWithLength(bound(length, 0, PACKED_TARGET_LENGTH - 1), seed);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = address(delegateContract).call(shortCalldata);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success, "fuzzed short calldata should succeed");
        assertEq(returnData.length, 0, "fuzzed short calldata should return no data");
    }

    function test_unit_fallback_success_forwardsPayloadFromApprovedCallers() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 totalValue;
        address[5] memory callers = _approvedCallers();

        // Warm up every forwarding path before measuring so snapshots compare branch cost.
        for (uint256 i; i < callers.length; ++i) {
            bytes memory warmupPayload = abi.encodePacked("warmup ", i);
            vm.deal(callers[i], MSG_VALUE);
            bytes memory warmupExpectedReturnData =
                _mockFallbackReturn(address(delegateContract), MSG_VALUE, warmupPayload, 0);
            vm.expectCall(fallbackTarget, MSG_VALUE, warmupPayload);

            vm.prank(callers[i]);
            (bool warmupSuccess, bytes memory warmupReturnData) =
                address(delegateContract).call{value: MSG_VALUE}(_packedCalldata(fallbackTarget, warmupPayload));

            assertTrue(warmupSuccess, "warmup call should forward payload");
            assertEq(warmupReturnData, warmupExpectedReturnData, "warmup return data should bubble");
        }

        // ~~~~~~~~~~ Call + Assertions ~~~~~~~~~~
        for (uint256 i; i < callers.length; ++i) {
            bytes memory payload = abi.encodePacked("slot ", i, bytes32(uint256(100 + i)));
            totalValue += MSG_VALUE;
            vm.deal(callers[i], MSG_VALUE);
            bytes memory expectedReturnData = _mockFallbackReturn(address(delegateContract), MSG_VALUE, payload, 0);
            vm.expectCall(fallbackTarget, MSG_VALUE, payload);

            vm.prank(callers[i]);
            vm.startSnapshotGas(_packedCalldataGasSnapshotName(i));
            (bool success, bytes memory returnData) =
                address(delegateContract).call{value: MSG_VALUE}(_packedCalldata(fallbackTarget, payload));
            vm.stopSnapshotGas();

            assertTrue(success, "approved caller should forward payload");
            assertEq(returnData, expectedReturnData, "target return data should bubble");
        }
        assertEq(totalValue, MSG_VALUE * callers.length, "test should forward ETH from every approved caller");
    }

    function test_fuzz_fallback_success_forwardsPayloadFromApprovedCaller(
        uint8 callerIndex,
        bytes memory payload,
        uint96 value
    ) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[5] memory callers = _approvedCallers();
        address caller = callers[uint256(callerIndex) % callers.length];
        vm.deal(caller, value);
        bytes memory expectedReturnData;
        if (payload.length == 0) {
            vm.mockCall(fallbackTarget, value, payload, "");
        } else {
            expectedReturnData = _mockFallbackReturn(address(delegateContract), value, payload, 0);
        }
        vm.expectCall(fallbackTarget, value, payload);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(caller);
        (bool success, bytes memory returnData) =
            address(delegateContract).call{value: value}(_packedCalldata(fallbackTarget, payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success, "fuzzed approved caller should forward payload");
        if (payload.length == 0) {
            assertEq(returnData.length, 0, "empty payload should return no data");
            return;
        }
        assertEq(returnData, expectedReturnData, "target return data should bubble");
    }

    function test_unit_fallback_success_forwardsPayload() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodePacked(bytes4(0x12345678), abi.encode(uint256(1), "payload"));
        bytes memory expectedReturnData =
            _mockFallbackReturn(address(delegateContract), 0, payload, fallbackTarget.balance);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(fallbackTarget, payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success, "approved caller should forward payload");
        assertEq(returnData, expectedReturnData, "target return data should bubble");
    }

    function test_unit_fallback_success_forwardsZeroMsgValue() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"abcdef";
        bytes memory expectedReturnData =
            _mockFallbackReturn(address(delegateContract), 0, payload, fallbackTarget.balance);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(fallbackTarget, payload));
        vm.snapshotGasLastCall("delegate fallback - success - packed calldata forwards zero ETH");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success, "zero-value call should forward");
        assertEq(returnData, expectedReturnData, "target return data should bubble");
    }

    function test_unit_fallback_success_forwardsMsgValue() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"abcdef";
        vm.deal(approvedCallers.first, MSG_VALUE);
        bytes memory expectedReturnData = _mockFallbackReturn(address(delegateContract), MSG_VALUE, payload, 0);
        vm.expectCall(fallbackTarget, MSG_VALUE, payload);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call{value: MSG_VALUE}(_packedCalldata(fallbackTarget, payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success, "ETH call should forward");
        assertEq(returnData, expectedReturnData, "target return data should bubble");
    }

    function test_unit_fallback_success_bubblesExactReturnData() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory expectedReturnData = hex"000102030405deadbeef";
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("returnRaw(bytes)")), expectedReturnData);
        vm.mockCall(fallbackTarget, payload, expectedReturnData);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(fallbackTarget, payload));
        vm.snapshotGasLastCall("delegate fallback - success - packed calldata bubbles return data");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success, "call should bubble exact return data");
        assertEq(returnData, expectedReturnData, "return data should match target output");
    }

    function test_fuzz_fallback_success_bubblesReturnData(bytes memory expectedReturnData) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("returnRaw(bytes)")), expectedReturnData);
        vm.mockCall(fallbackTarget, payload, expectedReturnData);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(fallbackTarget, payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success, "fuzzed call should bubble return data");
        assertEq(returnData, expectedReturnData, "fuzzed return data should match target output");
    }

    function test_unit_fallback_success_whenTargetHasNoCode() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"12345678";

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(targetWithoutCode, payload));
        vm.snapshotGasLastCall("delegate fallback - success - target has no code");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success, "call to target without code should succeed");
        assertEq(returnData.length, 0, "target without code should return no data");
    }

    function test_unit_fallback_success_whenTargetIsZeroAddress() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"12345678";

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = address(delegateContract).call(_packedCalldata(address(0), payload));
        vm.snapshotGasLastCall("delegate fallback - success - target is zero address");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success, "call to zero address should succeed");
        assertEq(returnData.length, 0, "zero address target should return no data");
    }

    // ~~~~~~~~~~~~~~~~~~~~ REVERT CASES ~~~~~~~~~~~~~~~~~~~~

    function test_unit_fallback_revertsWith_Unauthorized_whenCallerNotApproved() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"1234";

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(fallbackTarget, payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - unauthorized caller");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "unauthorized caller should revert");
        assertEq(
            returnData,
            abi.encodeWithSelector(Solver7702Delegate.Unauthorized.selector, unauthorizedCaller),
            "unauthorized caller should return Unauthorized error"
        );
    }

    function test_fuzz_fallback_revertsWith_UnauthorizedCaller(
        uint256 callerPrivateKey,
        bytes20 rawTarget,
        bytes memory payload
    ) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        callerPrivateKey = bound(callerPrivateKey, 1, type(uint128).max);
        address caller = vm.addr(callerPrivateKey);
        vm.assume(!_isCallerApproved(caller));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(caller);
        (bool success, bytes memory returnData) = address(delegateContract).call(abi.encodePacked(rawTarget, payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "fuzzed unauthorized caller should revert");
        assertEq(
            returnData,
            abi.encodeWithSelector(Solver7702Delegate.Unauthorized.selector, caller),
            "fuzzed unauthorized caller should return Unauthorized error"
        );
    }

    function test_unit_fallback_revertsWith_NonEmptyRevertData() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory expectedRevertData = abi.encodeWithSelector(RAW_REVERT_SELECTOR, uint256(42), "bad call");
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("revertRaw(bytes)")), expectedRevertData);
        vm.mockCallRevert(rawRevertTarget, payload, expectedRevertData);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(rawRevertTarget, payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - non-empty revert data");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "target revert should bubble failure");
        assertEq(returnData, expectedRevertData, "non-empty revert data should match target revert");
    }

    function test_fuzz_fallback_revertsWith_NonEmptyRevertData(bytes memory expectedRevertData) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("revertRaw(bytes)")), expectedRevertData);
        vm.mockCallRevert(rawRevertTarget, payload, expectedRevertData);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(rawRevertTarget, payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "fuzzed target revert should bubble failure");
        assertEq(returnData, expectedRevertData, "fuzzed revert data should match target revert");
    }

    function test_unit_fallback_revertsWith_EmptyRevertData() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("revertRaw(bytes)")), "");
        vm.mockCallRevert(rawRevertTarget, payload, "");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(rawRevertTarget, payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - empty revert data");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "empty target revert should fail");
        assertEq(returnData.length, 0, "empty target revert should return no data");
    }

    function test_unit_fallback_revertsWith_CustomError() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory customPayload = hex"c0ffee";
        bytes memory payload =
            abi.encodeWithSelector(bytes4(keccak256("revertWithCustomError(uint256,bytes)")), 77, customPayload);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bytes memory expectedRevertData =
            abi.encodeWithSelector(TargetCustomError.selector, address(delegateContract), 77, customPayload);
        vm.mockCallRevert(revertingTarget, payload, expectedRevertData);
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(revertingTarget, payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - custom error");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "custom error should bubble failure");
        assertEq(returnData, expectedRevertData, "custom error data should match target revert");
    }

    function test_unit_fallback_revertsWith_StringError() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        string memory reason = "target reverted";
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("revertWithString(string)")), reason);
        bytes memory expectedRevertData = abi.encodeWithSignature("Error(string)", reason);
        vm.mockCallRevert(revertingTarget, payload, expectedRevertData);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(revertingTarget, payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - string error");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "string error should bubble failure");
        assertEq(returnData, expectedRevertData, "string error data should match target revert");
    }

    function test_unit_fallback_revertsWith_Panic() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeWithSelector(bytes4(keccak256("revertWithPanic()")));
        bytes memory expectedRevertData = stdError.arithmeticError;
        vm.mockCallRevert(revertingTarget, payload, expectedRevertData);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(revertingTarget, payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - panic");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "panic should bubble failure");
        assertEq(returnData, expectedRevertData, "panic data should match target revert");
    }

    function test_unit_fallback_revertsWith_SendingEthToNonpayableTarget() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"12345678";
        vm.deal(approvedCallers.first, MSG_VALUE);
        vm.mockCallRevert(nonpayableTarget, MSG_VALUE, payload, "");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call{value: MSG_VALUE}(_packedCalldata(nonpayableTarget, payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - sending ETH to nonpayable target");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "nonpayable target should reject ETH");
        assertEq(returnData.length, 0, "nonpayable target revert should return no data");
    }

    function _isCallerApproved(address caller) internal view returns (bool) {
        return caller == approvedCallers.first || caller == approvedCallers.second || caller == approvedCallers.third
            || caller == approvedCallers.fourth || caller == approvedCallers.fifth;
    }

    function _approvedCallers() internal view returns (address[5] memory callers) {
        callers = [
            approvedCallers.first,
            approvedCallers.second,
            approvedCallers.third,
            approvedCallers.fourth,
            approvedCallers.fifth
        ];
    }

    function _bytesWithLength(uint256 length, bytes32 seed) internal pure returns (bytes memory data) {
        data = new bytes(length);
        for (uint256 i; i < length; ++i) {
            data[i] = bytes1(uint8(uint256(keccak256(abi.encode(seed, i)))));
        }
    }

    function _packedCalldataGasSnapshotName(uint256 callerIndex) internal pure returns (string memory) {
        if (callerIndex == 0) {
            return "delegate fallback - success - approved caller slot 0 forwards payload";
        }
        if (callerIndex == 1) {
            return "delegate fallback - success - approved caller slot 1 forwards payload";
        }
        if (callerIndex == 2) {
            return "delegate fallback - success - approved caller slot 2 forwards payload";
        }
        if (callerIndex == 3) {
            return "delegate fallback - success - approved caller slot 3 forwards payload";
        }
        return "delegate fallback - success - approved caller slot 4 forwards payload";
    }

    function _mockFallbackReturn(
        address expectedSender,
        uint256 expectedValue,
        bytes memory expectedPayload,
        uint256 expectedBalance
    ) internal returns (bytes memory returnData) {
        returnData = abi.encode(expectedSender, expectedValue, expectedPayload, expectedBalance);
        if (expectedValue == 0) {
            vm.mockCall(fallbackTarget, expectedPayload, returnData);
        } else {
            vm.mockCall(fallbackTarget, expectedValue, expectedPayload, returnData);
        }
    }
}
