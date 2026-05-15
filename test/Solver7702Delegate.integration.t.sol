// SPDX-License-Identifier: MIT OR Apache-2.0
// solhint-disable avoid-low-level-calls, gas-small-strings
pragma solidity ^0.8.34;

import {Solver7702Delegate} from "src/Solver7702Delegate.sol";
import {BaseTest} from "test/BaseTest.t.sol";
import {MockGPv2Authenticator} from "test/mocks/MockGPv2Authenticator.sol";
import {MockGPv2Settlement} from "test/mocks/MockGPv2Settlement.sol";
import {SettlementUtils} from "test/utils/SettlementUtils.sol";

contract Solver7702DelegateIntegrationTest is BaseTest {
    uint256 internal constant SMALL_GPV2_TOKEN_COUNT = 2;
    uint256 internal constant SMALL_GPV2_TRADE_COUNT = 1;
    uint256 internal constant SMALL_GPV2_INTERACTION_COUNT = 0;

    uint256 internal constant LARGE_GPV2_TOKEN_COUNT = 8;
    uint256 internal constant LARGE_GPV2_TRADE_COUNT = 16;
    uint256 internal constant LARGE_GPV2_INTERACTION_COUNT = 6;

    MockGPv2Authenticator internal authenticator;
    MockGPv2Settlement internal gpv2Settlement;

    function setUp() public override {
        super.setUp();

        authenticator = new MockGPv2Authenticator(address(this));
        authenticator.addSolver(solver);
        gpv2Settlement = new MockGPv2Settlement(authenticator, makeAddr("VAULT_RELAYER"));

        _attachDelegation(SOLVER_PRIVATE_KEY);
    }

    // ~~~~~~~~~~~~~~~~~~~~ SUCCESS CASES ~~~~~~~~~~~~~~~~~~~~

    function test_integration_submission_success_smallSettlement() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        (bytes memory payload, bytes32 expectedPayloadHash) = SettlementUtils.gpv2SettlementCalldata(
            SMALL_GPV2_TOKEN_COUNT, SMALL_GPV2_TRADE_COUNT, SMALL_GPV2_INTERACTION_COUNT, recipient, address(0)
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(solver);
        vm.startSnapshotGas("direct submission - success - small settlement");
        (bool directSuccess,) = address(gpv2Settlement).call(payload);
        vm.stopSnapshotGas();

        vm.prank(approvedCallers.first);
        vm.startSnapshotGas("delegated submission - success - small settlement");
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(gpv2Settlement), payload));
        vm.stopSnapshotGas();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(directSuccess, "direct submission failed");
        assertTrue(success, "delegated submission failed");
        assertEq(returnData.length, 0, "return data length mismatch");
        assertEq(gpv2Settlement.lastSender(), solver, "sender mismatch");
        assertEq(gpv2Settlement.lastPayloadHash(), expectedPayloadHash, "payload hash mismatch");
        assertEq(gpv2Settlement.lastTokenCount(), SMALL_GPV2_TOKEN_COUNT, "token count mismatch");
        assertEq(gpv2Settlement.lastTradeCount(), SMALL_GPV2_TRADE_COUNT, "trade count mismatch");
    }

    function test_integration_submission_success_largeSettlementWithInteractions() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        (bytes memory payload, bytes32 expectedPayloadHash) = SettlementUtils.gpv2SettlementCalldata(
            LARGE_GPV2_TOKEN_COUNT, LARGE_GPV2_TRADE_COUNT, LARGE_GPV2_INTERACTION_COUNT, recipient, address(0)
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(solver);
        vm.startSnapshotGas("direct submission - success - large settlement with interactions");
        (bool directSuccess,) = address(gpv2Settlement).call(payload);
        vm.stopSnapshotGas();

        vm.prank(approvedCallers.first);
        vm.startSnapshotGas("delegated submission - success - large settlement with interactions");
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(gpv2Settlement), payload));
        vm.stopSnapshotGas();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(directSuccess, "direct submission failed");
        assertTrue(success, "delegated submission failed");
        assertEq(returnData.length, 0, "return data length mismatch");
        assertEq(gpv2Settlement.lastSender(), solver, "sender mismatch");
        assertEq(gpv2Settlement.lastPayloadHash(), expectedPayloadHash, "payload hash mismatch");
        assertEq(gpv2Settlement.lastTokenCount(), LARGE_GPV2_TOKEN_COUNT, "token count mismatch");
        assertEq(gpv2Settlement.lastTradeCount(), LARGE_GPV2_TRADE_COUNT, "trade count mismatch");
        assertEq(gpv2Settlement.lastInteractionCount(), LARGE_GPV2_INTERACTION_COUNT, "interaction count mismatch");
    }

    function test_integration_submission_success_interactionsAcrossPhases() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256[3] memory interactionCounts = [uint256(2), uint256(3), uint256(1)];
        uint256 totalInteractions = interactionCounts[0] + interactionCounts[1] + interactionCounts[2];
        (bytes memory payload, bytes32 expectedPayloadHash) = SettlementUtils.gpv2SettlementCalldata(
            SMALL_GPV2_TOKEN_COUNT, SMALL_GPV2_TRADE_COUNT, interactionCounts, recipient, address(0)
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(solver);
        vm.startSnapshotGas("direct submission - success - interactions across phases");
        (bool directSuccess,) = address(gpv2Settlement).call(payload);
        vm.stopSnapshotGas();

        vm.prank(approvedCallers.first);
        vm.startSnapshotGas("delegated submission - success - interactions across phases");
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(gpv2Settlement), payload));
        vm.stopSnapshotGas();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(directSuccess, "direct submission failed");
        assertTrue(success, "delegated submission failed");
        assertEq(returnData.length, 0, "return data length mismatch");
        assertEq(gpv2Settlement.lastSender(), solver, "sender mismatch");
        assertEq(gpv2Settlement.lastPayloadHash(), expectedPayloadHash, "payload hash mismatch");
        assertEq(gpv2Settlement.lastInteractionCount(), totalInteractions, "interaction count mismatch");
    }

    // ~~~~~~~~~~~~~~~~~~~~ REVERT CASES ~~~~~~~~~~~~~~~~~~~~

    function test_integration_submission_revertsWith_UnauthorizedCaller() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        (bytes memory payload,) = SettlementUtils.gpv2SettlementCalldata(
            SMALL_GPV2_TOKEN_COUNT, SMALL_GPV2_TRADE_COUNT, SMALL_GPV2_INTERACTION_COUNT, recipient, address(0)
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(gpv2Settlement), payload));
        vm.snapshotGasLastCall("delegated submission - reverts - UnauthorizedCaller");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "submission succeeded when unauthorized caller");
        assertEq(
            returnData,
            abi.encodeWithSelector(Solver7702Delegate.Unauthorized.selector, unauthorizedCaller),
            "revert data mismatch"
        );
    }

    function test_integration_submission_revertsWith_NotSolver() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        (bytes memory payload,) = SettlementUtils.gpv2SettlementCalldata(
            SMALL_GPV2_TOKEN_COUNT, SMALL_GPV2_TRADE_COUNT, SMALL_GPV2_INTERACTION_COUNT, recipient, address(0)
        );
        authenticator.removeSolver(solver);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bytes memory expectedRevertData = abi.encodeWithSelector(MockGPv2Settlement.NotSolver.selector, solver);
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(gpv2Settlement), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "submission succeeded when not solver");
        assertEq(returnData, expectedRevertData, "revert data mismatch");
    }

    function test_integration_submission_revertsWith_ClearingPriceLengthMismatch() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = SettlementUtils.gpv2SettlementCalldataWithMissingClearingPrice(
            SMALL_GPV2_TOKEN_COUNT, SMALL_GPV2_TRADE_COUNT, recipient, address(0)
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bytes memory expectedRevertData =
            abi.encodeWithSelector(MockGPv2Settlement.ClearingPriceLengthMismatch.selector);
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(gpv2Settlement), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "submission succeeded when clearing price length mismatch");
        assertEq(returnData, expectedRevertData, "revert data mismatch");
    }
}
