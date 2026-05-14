// SPDX-License-Identifier: MIT OR Apache-2.0
// solhint-disable avoid-low-level-calls, gas-small-strings
pragma solidity ^0.8.34;

import {Solver7702Delegate} from "src/Solver7702Delegate.sol";
import {BaseTest} from "test/BaseTest.t.sol";
import {FallbackTarget} from "test/mocks/targets/FallbackTarget.sol";
import {RawReturnTarget} from "test/mocks/targets/RawReturnTarget.sol";
import {RawRevertTarget} from "test/mocks/targets/RawRevertTarget.sol";

contract Solver7702DelegateTest is BaseTest {
    bytes4 internal constant RAW_REVERT_SELECTOR = bytes4(0x12345678);

    FallbackTarget internal fallbackTarget;
    RawReturnTarget internal rawReturnTarget;
    RawRevertTarget internal rawRevertTarget;
    address internal unauthorizedCaller;
    address internal targetWithoutCode;

    function setUp() public override {
        super.setUp();

        fallbackTarget = new FallbackTarget();
        rawReturnTarget = new RawReturnTarget();
        rawRevertTarget = new RawRevertTarget();
        unauthorizedCaller = makeAddr("UNAUTHORIZED_CALLER");
        targetWithoutCode = makeAddr("TARGET_WITHOUT_CODE");
    }

    function test_unit_emptyCalldata_success_receivesEthFromAnyCaller() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.deal(unauthorizedCaller, MSG_VALUE);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = address(delegateContract).call{value: MSG_VALUE}("");
        vm.snapshotGasLastCall("empty calldata - success - receives eth from any caller");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData.length, 0);
        assertEq(address(delegateContract).balance, MSG_VALUE);
        assertEq(_fallbackCallCount(), 0);
    }

    function test_unit_packedCalldata_success_forwardsThroughAllApprovedCallerSlots() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 totalValue;
        address[5] memory callers = _approvedCallers();

        for (uint256 i; i < callers.length; ++i) {
            bytes memory payload = abi.encodePacked("slot ", i, bytes32(uint256(100 + i)));
            totalValue += MSG_VALUE;
            vm.deal(callers[i], MSG_VALUE);

            // ~~~~~~~~~~ Call ~~~~~~~~~~
            vm.prank(callers[i]);
            uint256 gasBefore = gasleft();
            (bool success, bytes memory returnData) =
                address(delegateContract).call{value: MSG_VALUE}(_packedCalldata(address(fallbackTarget), payload));
            uint256 gasUsed = gasBefore - gasleft();
            _snapshotPackedCalldataGas(callers[i], gasUsed);

            // ~~~~~~~~~~ Assertions ~~~~~~~~~~
            assertTrue(success);
            _assertFallbackReturn(returnData, address(delegateContract), MSG_VALUE, payload, totalValue);
        }

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(_fallbackCallCount(), callers.length);
        assertEq(address(fallbackTarget).balance, totalValue);
    }

    function test_unit_packedCalldata_success_callsTargetWithEmptyPayload() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory calldataWithOnlyTarget = _packedCalldata(address(fallbackTarget), "");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = address(delegateContract).call(calldataWithOnlyTarget);
        vm.snapshotGasLastCall("packed calldata - success - calls target with empty payload");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData.length, 0);
        assertEq(_fallbackCallCount(), 1);
    }

    function test_unit_packedCalldata_success_returnsEmptyDataFromNoCodeTarget() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"12345678";

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(targetWithoutCode, payload));
        vm.snapshotGasLastCall("packed calldata no code target - success - returns empty data");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData.length, 0);
    }

    function test_unit_packedCalldata_success_forwardsZeroMsgValue() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"abcdef";

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(fallbackTarget), payload));
        vm.snapshotGasLastCall("packed calldata zero msg value - success - forwards calldata");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        _assertFallbackReturn(returnData, address(delegateContract), 0, payload, 0);
        assertEq(_fallbackCallCount(), 1);
    }

    function test_unit_packedCalldata_revertsWhen_callerUnauthorized_UnauthorizedErrorWhenRevert() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"1234";

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(fallbackTarget), payload));
        vm.snapshotGasLastCall("packed calldata - reverts when - unauthorized error when revert");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, abi.encodeWithSelector(Solver7702Delegate.Unauthorized.selector, unauthorizedCaller));
    }

    function test_unit_packedCalldata_success_bubblesExactReturnData() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory expectedReturnData = hex"000102030405deadbeef";
        bytes memory payload = abi.encodeCall(RawReturnTarget.returnRaw, (expectedReturnData));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(rawReturnTarget), payload));
        vm.snapshotGasLastCall("packed calldata return data - success - bubbles exact return data");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData, expectedReturnData);
    }

    function test_unit_packedCalldata_revertsWhen_targetReverts_ExtraDataWhenRevert() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory expectedRevertData = abi.encodeWithSelector(RAW_REVERT_SELECTOR, uint256(42), "bad call");
        bytes memory payload = abi.encodeCall(RawRevertTarget.revertRaw, (expectedRevertData));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(rawRevertTarget), payload));
        vm.snapshotGasLastCall("packed calldata - reverts when - target revert data when revert");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, expectedRevertData);
    }

    function test_unit_packedCalldata_revertsWhen_targetRevertsWithoutData_EmptyDataWhenRevert() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeCall(RawRevertTarget.revertRaw, (""));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            address(delegateContract).call(_packedCalldata(address(rawRevertTarget), payload));
        vm.snapshotGasLastCall("packed calldata - reverts when - target empty data when revert");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData.length, 0);
    }

    function test_unit_abiEncodedEnvelope_success_doesNotReachIntendedTarget() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory targetPayload = hex"12345678";
        bytes memory wrongEnvelope = abi.encode(address(fallbackTarget), targetPayload);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = address(delegateContract).call(wrongEnvelope);
        vm.snapshotGasLastCall("abi encoded envelope - success - does not reach intended target");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData.length, 0);
        assertEq(_fallbackCallCount(), 0);
        assertEq(address(fallbackTarget).balance, 0);
    }

    function test_fuzz_packedCalldata_success_forwardsFromApprovedCaller(
        uint8 callerIndex,
        bytes memory payload,
        uint96 value
    ) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[5] memory callers = _approvedCallers();
        address caller = callers[uint256(callerIndex) % callers.length];
        bytes memory forwardedPayload = payload.length == 0 ? abi.encodePacked(bytes1(0)) : payload;
        vm.deal(caller, value);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(caller);
        (bool success, bytes memory returnData) =
            address(delegateContract).call{value: value}(_packedCalldata(address(fallbackTarget), forwardedPayload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        _assertFallbackReturn(returnData, address(delegateContract), value, forwardedPayload, value);
        assertEq(_fallbackCallCount(), 1);
    }

    function test_fuzz_packedCalldata_revertsWhen_callerUnauthorized_UnauthorizedErrorWhenRevert(
        address caller,
        bytes20 rawTarget,
        bytes memory payload
    ) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(!_isCallerApproved(caller));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(caller);
        (bool success, bytes memory returnData) = address(delegateContract).call(abi.encodePacked(rawTarget, payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, abi.encodeWithSelector(Solver7702Delegate.Unauthorized.selector, caller));
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

    function _snapshotPackedCalldataGas(address caller, uint256 gasUsed) internal {
        if (caller == approvedCallers.first) {
            vm.snapshotValue("packed calldata approved caller 0 - success - first target call gas only", gasUsed);
        }
        if (caller == approvedCallers.second) {
            vm.snapshotValue("packed calldata approved caller 1 - success - repeat target call gas only", gasUsed);
        }
        if (caller == approvedCallers.third) {
            vm.snapshotValue("packed calldata approved caller 2 - success - repeat target call gas only", gasUsed);
        }
        if (caller == approvedCallers.fourth) {
            vm.snapshotValue("packed calldata approved caller 3 - success - repeat target call gas only", gasUsed);
        }
        if (caller == approvedCallers.fifth) {
            vm.snapshotValue("packed calldata approved caller 4 - success - repeat target call gas only", gasUsed);
        }
    }

    function _assertFallbackReturn(
        bytes memory returnData,
        address expectedSender,
        uint256 expectedValue,
        bytes memory expectedPayload,
        uint256 expectedBalance
    ) internal pure {
        (address sender, uint256 value, bytes memory payload, uint256 balance) =
            abi.decode(returnData, (address, uint256, bytes, uint256));

        assertEq(sender, expectedSender);
        assertEq(value, expectedValue);
        assertEq(payload, expectedPayload);
        assertEq(balance, expectedBalance);
    }
}
