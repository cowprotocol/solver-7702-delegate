// SPDX-License-Identifier: MIT OR Apache-2.0
// solhint-disable avoid-low-level-calls, gas-small-strings
pragma solidity ^0.8.34;

import {Solver7702Delegate} from "src/Solver7702Delegate.sol";
import {BaseTest} from "test/BaseTest.t.sol";
import {MockSettlement} from "test/mocks/MockSettlement.sol";

contract Solver7702DelegateIntegrationTest is BaseTest {
    uint256 internal constant SETTLEMENT_AMOUNT = 12.34 ether;
    uint256 internal constant SMALL_SETTLEMENT_WORDS = 1;
    uint256 internal constant LARGE_SETTLEMENT_WORDS = 64;
    bytes32 internal constant ORDER_UID = keccak256("order");

    MockSettlement internal settlement;
    address internal unauthorizedCaller;

    function setUp() public override {
        super.setUp();

        settlement = new MockSettlement();
        unauthorizedCaller = makeAddr("UNAUTHORIZED_CALLER");
    }

    function test_integration_7702Submission_success_settlementSeesSolverEoa() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeCall(MockSettlement.settle, (ORDER_UID, SETTLEMENT_AMOUNT));
        vm.deal(approvedCallers.first, MSG_VALUE);
        vm.signAndAttachDelegation(address(delegateContract), SOLVER_PRIVATE_KEY);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            solver.call{value: MSG_VALUE}(_packedCalldata(address(settlement), payload));
        vm.snapshotGasLastCall("7702 submission - success - settlement sees solver eoa");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(abi.decode(returnData, (bytes32)), ORDER_UID);
        assertEq(settlement.lastSender(), solver);
        assertEq(settlement.lastValue(), MSG_VALUE);
        assertEq(settlement.lastOrderUid(), ORDER_UID);
        assertEq(settlement.lastAmount(), SETTLEMENT_AMOUNT);
        assertEq(address(settlement).balance, MSG_VALUE);
    }

    function test_integration_7702Submission_success_forwardsSmallSettlementPayload() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory settlementPayload = _settlementPayload(SMALL_SETTLEMENT_WORDS);
        bytes memory payload = abi.encodeCall(MockSettlement.settlePayload, (settlementPayload));
        vm.signAndAttachDelegation(address(delegateContract), SOLVER_PRIVATE_KEY);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(settlement), payload));
        vm.snapshotGasLastCall("7702 submission - success - forwards small settlement payload");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(abi.decode(returnData, (bytes32)), keccak256(settlementPayload));
        assertEq(settlement.lastSender(), solver);
        assertEq(settlement.lastPayloadHash(), keccak256(settlementPayload));
        assertEq(settlement.lastPayloadLength(), settlementPayload.length);
    }

    function test_integration_7702Submission_success_forwardsLargeSettlementPayload() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory settlementPayload = _settlementPayload(LARGE_SETTLEMENT_WORDS);
        bytes memory payload = abi.encodeCall(MockSettlement.settlePayload, (settlementPayload));
        vm.signAndAttachDelegation(address(delegateContract), SOLVER_PRIVATE_KEY);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(settlement), payload));
        vm.snapshotGasLastCall("7702 submission - success - forwards large settlement payload");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(abi.decode(returnData, (bytes32)), keccak256(settlementPayload));
        assertEq(settlement.lastSender(), solver);
        assertEq(settlement.lastPayloadHash(), keccak256(settlementPayload));
        assertEq(settlement.lastPayloadLength(), settlementPayload.length);
    }

    function test_integration_7702Submission_revertsWhen_callerUnauthorized_UnauthorizedErrorWhenRevert() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeCall(MockSettlement.settle, (ORDER_UID, SETTLEMENT_AMOUNT));
        vm.signAndAttachDelegation(address(delegateContract), SOLVER_PRIVATE_KEY);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(settlement), payload));
        vm.snapshotGasLastCall("7702 submission - reverts when - unauthorized error when revert");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, abi.encodeWithSelector(Solver7702Delegate.Unauthorized.selector, unauthorizedCaller));
    }

    function _settlementPayload(uint256 words) internal pure returns (bytes memory payload) {
        payload = new bytes(words * 32);
        for (uint256 i; i < words; ++i) {
            bytes32 word = keccak256(abi.encode(i));
            assembly {
                mstore(add(add(payload, 0x20), mul(i, 0x20)), word)
            }
        }
    }
}
