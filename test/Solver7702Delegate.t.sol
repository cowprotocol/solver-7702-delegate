// SPDX-License-Identifier: MIT OR Apache-2.0
// solhint-disable avoid-low-level-calls, gas-small-strings
pragma solidity ^0.8.34;

import {stdError} from "forge-std/StdError.sol";

import {Solver7702Delegate} from "src/Solver7702Delegate.sol";
import {BaseTest} from "test/BaseTest.t.sol";
import {NonpayableTarget} from "test/mocks/targets/NonpayableTarget.sol";
import {PayableFallbackTarget} from "test/mocks/targets/PayableFallbackTarget.sol";
import {RawRevertTarget} from "test/mocks/targets/RawRevertTarget.sol";
import {RevertingTarget} from "test/mocks/targets/RevertingTarget.sol";

contract Solver7702DelegateTest is BaseTest {
    PayableFallbackTarget internal fallbackTarget;
    NonpayableTarget internal nonpayableTarget;
    RawRevertTarget internal rawRevertTarget;
    RevertingTarget internal revertingTarget;

    address internal unauthorizedCaller;
    address internal targetWithoutCode;

    function setUp() public override {
        super.setUp();

        fallbackTarget = new PayableFallbackTarget();
        nonpayableTarget = new NonpayableTarget();
        rawRevertTarget = new RawRevertTarget();
        revertingTarget = new RevertingTarget();

        unauthorizedCaller = makeAddr("UNAUTHORIZED_CALLER");
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

        uint256 fallbackTargetBalanceBefore = address(fallbackTarget).balance;
        // ~~~~~~~~~~ Call + Assertions ~~~~~~~~~~
        for (uint256 i; i < callers.length; ++i) {
            bytes memory payload = abi.encodePacked("distinct ", i);
            vm.prank(callers[i]);
            (bool success, bytes memory returnData) =
                address(distinctDelegate).call(_packedCalldata(address(fallbackTarget), payload));

            assertTrue(success);
            _assertFallbackReturn(returnData, address(distinctDelegate), 0, payload, fallbackTargetBalanceBefore);
        }

        assertEq(_fallbackCallCount(), callers.length);
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
        uint256 fallbackTargetBalanceBefore = address(fallbackTarget).balance;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(repeatedCaller);
        (bool success, bytes memory returnData) =
            address(duplicateDelegate).call(_packedCalldata(address(fallbackTarget), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        _assertFallbackReturn(returnData, address(duplicateDelegate), 0, payload, fallbackTargetBalanceBefore);
    }

    function test_unit_constructor_success_whenApprovedCallersContainZeroAddress() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[5] memory callers =
            [address(0), approvedCallers.second, address(0), approvedCallers.fourth, approvedCallers.fifth];

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        Solver7702Delegate zeroAddressDelegate = new Solver7702Delegate(callers);
        vm.snapshotGasLastCall("constructor - success - zero address callers");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertGt(address(zeroAddressDelegate).code.length, 0);
    }

    function test_unit_fallback_success_emptyCalldataReceivesEth() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 delegateBalanceBefore = address(delegateContract).balance;
        vm.deal(unauthorizedCaller, MSG_VALUE);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = address(delegateContract).call{value: MSG_VALUE}("");
        vm.snapshotGasLastCall("delegate fallback - success - empty calldata receives ETH");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData.length, 0);
        assertEq(address(delegateContract).balance, delegateBalanceBefore + MSG_VALUE);
        assertEq(_fallbackCallCount(), 0);
    }

    function test_unit_fallback_success_shortCalldataDoesNothing() public {
        // ~~~~~~~~~~ Call + Assertions ~~~~~~~~~~
        for (uint256 length = 1; length < PACKED_TARGET_LENGTH; ++length) {
            bytes memory shortCalldata = _bytesWithLength(length, bytes32(length));

            vm.prank(unauthorizedCaller);
            (bool success, bytes memory returnData) = address(delegateContract).call(shortCalldata);

            assertTrue(success);
            assertEq(returnData.length, 0);
            assertEq(_fallbackCallCount(), 0);
        }
    }

    function test_fuzz_fallback_success_shortCalldataDoesNothing(uint8 length, bytes32 seed) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory shortCalldata = _bytesWithLength(bound(length, 0, PACKED_TARGET_LENGTH - 1), seed);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = address(delegateContract).call(shortCalldata);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData.length, 0);
        assertEq(_fallbackCallCount(), 0);
    }

    function test_unit_fallback_success_forwardsPayloadFromApprovedCallers() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 totalValue;
        uint256 fallbackTargetBalanceBefore = address(fallbackTarget).balance;
        address[5] memory callers = _approvedCallers();

        // ~~~~~~~~~~ Call + Assertions ~~~~~~~~~~
        for (uint256 i; i < callers.length; ++i) {
            bytes memory payload = abi.encodePacked("slot ", i, bytes32(uint256(100 + i)));
            totalValue += MSG_VALUE;
            vm.deal(callers[i], MSG_VALUE);

            vm.prank(callers[i]);
            vm.startSnapshotGas(_packedCalldataGasSnapshotName(i));
            (bool success, bytes memory returnData) =
                address(delegateContract).call{value: MSG_VALUE}(_packedCalldata(address(fallbackTarget), payload));
            vm.stopSnapshotGas();

            assertTrue(success);
            _assertFallbackReturn(
                returnData, address(delegateContract), MSG_VALUE, payload, fallbackTargetBalanceBefore + totalValue
            );
        }

        assertEq(_fallbackCallCount(), callers.length);
        assertEq(address(fallbackTarget).balance, fallbackTargetBalanceBefore + totalValue);
    }

    function test_fuzz_fallback_success_forwardsPayloadFromApprovedCaller(
        uint8 callerIndex,
        bytes memory payload,
        uint96 value
    ) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[5] memory callers = _approvedCallers();
        address caller = callers[uint256(callerIndex) % callers.length];
        bytes memory forwardedPayload = payload.length == 0 ? abi.encodePacked(bytes1(0)) : payload;
        uint256 fallbackTargetBalanceBefore = address(fallbackTarget).balance;
        vm.deal(caller, value);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(caller);
        (bool success, bytes memory returnData) =
            address(delegateContract).call{value: value}(_packedCalldata(address(fallbackTarget), forwardedPayload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        _assertFallbackReturn(
            returnData, address(delegateContract), value, forwardedPayload, fallbackTargetBalanceBefore + value
        );
        assertEq(_fallbackCallCount(), 1);
    }

    function test_unit_fallback_success_forwardsPayload() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodePacked(bytes4(0x12345678), abi.encode(uint256(1), "payload"));
        uint256 fallbackTargetBalanceBefore = address(fallbackTarget).balance;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(fallbackTarget), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        _assertFallbackReturn(returnData, address(delegateContract), 0, payload, fallbackTargetBalanceBefore);
    }

    function test_unit_fallback_success_forwardsZeroMsgValue() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"abcdef";
        uint256 fallbackTargetBalanceBefore = address(fallbackTarget).balance;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(fallbackTarget), payload));
        vm.snapshotGasLastCall("delegate fallback - success - packed calldata forwards zero ETH");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        _assertFallbackReturn(returnData, address(delegateContract), 0, payload, fallbackTargetBalanceBefore);
        assertEq(_fallbackCallCount(), 1);
    }

    function test_unit_fallback_success_forwardsMsgValue() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"abcdef";
        uint256 fallbackTargetBalanceBefore = address(fallbackTarget).balance;
        vm.deal(approvedCallers.first, MSG_VALUE);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call{value: MSG_VALUE}(_packedCalldata(address(fallbackTarget), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        _assertFallbackReturn(
            returnData, address(delegateContract), MSG_VALUE, payload, fallbackTargetBalanceBefore + MSG_VALUE
        );
        assertEq(address(fallbackTarget).balance, fallbackTargetBalanceBefore + MSG_VALUE);
    }

    function test_unit_fallback_success_bubblesExactReturnData() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory expectedReturnData = hex"000102030405deadbeef";
        bytes memory payload = abi.encodeCall(PayableFallbackTarget.returnRaw, (expectedReturnData));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(fallbackTarget), payload));
        vm.snapshotGasLastCall("delegate fallback - success - packed calldata bubbles return data");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData, expectedReturnData);
    }

    function test_fuzz_fallback_success_bubblesReturnData(bytes memory expectedReturnData) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeCall(PayableFallbackTarget.returnRaw, (expectedReturnData));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(fallbackTarget), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData, expectedReturnData);
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
        assertTrue(success);
        assertEq(returnData.length, 0);
    }

    function test_unit_fallback_success_whenTargetIsZeroAddress() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"12345678";

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = address(delegateContract).call(_packedCalldata(address(0), payload));
        vm.snapshotGasLastCall("delegate fallback - success - target is zero address");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData.length, 0);
    }

    // ~~~~~~~~~~~~~~~~~~~~ REVERT CASES ~~~~~~~~~~~~~~~~~~~~

    function test_unit_fallback_revertsWith_Unauthorized_whenCallerNotApproved() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"1234";

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(fallbackTarget), payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - unauthorized caller");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, abi.encodeWithSelector(Solver7702Delegate.Unauthorized.selector, unauthorizedCaller));
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
        assertFalse(success);
        assertEq(returnData, abi.encodeWithSelector(Solver7702Delegate.Unauthorized.selector, caller));
    }

    function test_unit_fallback_revertsWith_NonEmptyRevertData() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory expectedRevertData = abi.encodeWithSelector(RAW_REVERT_SELECTOR, uint256(42), "bad call");
        bytes memory payload = abi.encodeCall(RawRevertTarget.revertRaw, (expectedRevertData));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(rawRevertTarget), payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - non-empty revert data");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, expectedRevertData);
    }

    function test_fuzz_fallback_revertsWith_NonEmptyRevertData(bytes memory expectedRevertData) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeCall(RawRevertTarget.revertRaw, (expectedRevertData));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(rawRevertTarget), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, expectedRevertData);
    }

    function test_fuzz_fallback_revertsWith_ExternalCallReverts(bytes memory expectedRevertData) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeCall(RawRevertTarget.revertRaw, (expectedRevertData));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(rawRevertTarget), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, expectedRevertData);
    }

    function test_unit_fallback_revertsWith_EmptyRevertData() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeCall(RawRevertTarget.revertRaw, (""));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(rawRevertTarget), payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - empty revert data");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData.length, 0);
    }

    function test_unit_fallback_revertsWith_CustomError() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory customPayload = hex"c0ffee";
        bytes memory payload = abi.encodeCall(RevertingTarget.revertWithCustomError, (77, customPayload));
        bytes memory expectedRevertData = abi.encodeWithSelector(
            RevertingTarget.TargetCustomError.selector, address(delegateContract), 77, customPayload
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(revertingTarget), payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - custom error");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, expectedRevertData);
    }

    function test_unit_fallback_revertsWith_StringError() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        string memory reason = "target reverted";
        bytes memory payload = abi.encodeCall(RevertingTarget.revertWithString, (reason));
        bytes memory expectedRevertData = abi.encodeWithSignature("Error(string)", reason);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(revertingTarget), payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - string error");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, expectedRevertData);
    }

    function test_unit_fallback_revertsWith_Panic() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeCall(RevertingTarget.revertWithPanic, ());
        bytes memory expectedRevertData = stdError.arithmeticError;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(revertingTarget), payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - panic");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, expectedRevertData);
    }

    function test_unit_fallback_revertsWith_SendingEthToNonpayableTarget() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"12345678";
        vm.deal(approvedCallers.first, MSG_VALUE);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call{value: MSG_VALUE}(_packedCalldata(address(nonpayableTarget), payload));
        vm.snapshotGasLastCall("delegate fallback - reverts - sending ETH to nonpayable target");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData.length, 0);
    }

    function _fallbackCallCount() internal view returns (uint256) {
        return uint256(vm.load(address(fallbackTarget), bytes32(0)));
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
            return "delegate fallback - approved caller slot 0 forwards payload";
        }
        if (callerIndex == 1) {
            return "delegate fallback - approved caller slot 1 forwards payload";
        }
        if (callerIndex == 2) {
            return "delegate fallback - approved caller slot 2 forwards payload";
        }
        if (callerIndex == 3) {
            return "delegate fallback - approved caller slot 3 forwards payload";
        }
        return "delegate fallback - approved caller slot 4 forwards payload";
    }
}
