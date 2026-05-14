// SPDX-License-Identifier: MIT OR Apache-2.0
// solhint-disable avoid-low-level-calls, gas-small-strings
pragma solidity ^0.8.34;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Solver7702Delegate} from "src/Solver7702Delegate.sol";
import {BaseTest} from "test/BaseTest.t.sol";
import {MockGPv2Authenticator} from "test/mocks/MockGPv2Authenticator.sol";
import {MockGPv2Settlement} from "test/mocks/MockGPv2Settlement.sol";
import {MockSettlement} from "test/mocks/MockSettlement.sol";
import {FallbackTarget} from "test/mocks/targets/FallbackTarget.sol";
import {RawRevertTarget} from "test/mocks/targets/RawRevertTarget.sol";
import {MathUtils} from "test/utils/MathUtils.sol";
import {SettlementUtils} from "test/utils/SettlementUtils.sol";

contract Solver7702DelegateIntegrationTest is BaseTest {
    uint256 internal constant SMALL_SETTLEMENT_PAYLOAD_WORDS = 1;
    uint256 internal constant LARGE_SETTLEMENT_PAYLOAD_WORDS = 64;

    uint256 internal constant SMALL_GPV2_TOKEN_COUNT = 2;
    uint256 internal constant SMALL_GPV2_TRADE_COUNT = 1;
    uint256 internal constant SMALL_GPV2_INTERACTION_COUNT = 0;

    uint256 internal constant LARGE_GPV2_TOKEN_COUNT = 8;
    uint256 internal constant LARGE_GPV2_TRADE_COUNT = 16;
    uint256 internal constant LARGE_GPV2_INTERACTION_COUNT = 6;

    uint256 internal constant REVERTING_GPV2_TOKEN_COUNT = 2;
    uint256 internal constant REVERTING_GPV2_TRADE_COUNT = 1;
    uint256 internal constant REVERTING_GPV2_INTERACTION_COUNT = 1;

    MockSettlement internal settlement;
    MockGPv2Authenticator internal authenticator;
    MockGPv2Settlement internal gpv2Settlement;
    ERC20Mock internal token;
    FallbackTarget internal fallbackTarget;
    RawRevertTarget internal rawRevertTarget;

    address internal recipient;
    address internal spender;
    address internal unauthorizedCaller;

    function setUp() public override {
        super.setUp();

        settlement = new MockSettlement();
        authenticator = new MockGPv2Authenticator(address(this));
        authenticator.addSolver(solver);
        gpv2Settlement = new MockGPv2Settlement(authenticator, makeAddr("VAULT_RELAYER"));
        token = new ERC20Mock();
        fallbackTarget = new FallbackTarget();
        rawRevertTarget = new RawRevertTarget();
        recipient = makeAddr("RECIPIENT");
        spender = makeAddr("SPENDER");
        unauthorizedCaller = makeAddr("UNAUTHORIZED_CALLER");

        _attachDelegation(SOLVER_PRIVATE_KEY);
    }

    function test_integration_7702Submission_success_settlementSeesSolverEoa() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeCall(MockSettlement.settle, (TEST_ORDER_UID, TEST_AMOUNT));
        uint256 settlementBalanceBefore = address(settlement).balance;
        vm.deal(approvedCallers.first, MSG_VALUE);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            solver.call{value: MSG_VALUE}(_packedCalldata(address(settlement), payload));
        vm.snapshotGasLastCall("simple 7702 delegation - success - mock settlement forwards ETH");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(abi.decode(returnData, (bytes32)), TEST_ORDER_UID);
        assertEq(settlement.lastSender(), solver);
        assertEq(settlement.lastValue(), MSG_VALUE);
        assertEq(settlement.lastOrderUid(), TEST_ORDER_UID);
        assertEq(settlement.lastAmount(), TEST_AMOUNT);
        assertEq(address(settlement).balance, settlementBalanceBefore + MSG_VALUE);
    }

    function test_integration_7702Submission_success_forwardsMsgValue() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"abcdef";
        uint256 fallbackTargetBalanceBefore = address(fallbackTarget).balance;
        vm.deal(approvedCallers.first, MSG_VALUE);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            solver.call{value: MSG_VALUE}(_packedCalldata(address(fallbackTarget), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        _assertFallbackReturn(returnData, solver, MSG_VALUE, payload, fallbackTargetBalanceBefore + MSG_VALUE);
        assertEq(address(fallbackTarget).balance, fallbackTargetBalanceBefore + MSG_VALUE);
    }

    function test_integration_7702Submission_success_forwardsSmallSettlementPayload() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory settlementPayload = SettlementUtils.settlementPayload(SMALL_SETTLEMENT_PAYLOAD_WORDS);
        bytes memory payload = abi.encodeCall(MockSettlement.settlePayload, (settlementPayload));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(settlement), payload));
        vm.snapshotGasLastCall("simple 7702 delegation - success - small mock settlement payload");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(abi.decode(returnData, (bytes32)), keccak256(settlementPayload));
        assertEq(settlement.lastSender(), solver);
        assertEq(settlement.lastPayloadHash(), keccak256(settlementPayload));
        assertEq(settlement.lastPayloadLength(), settlementPayload.length);
    }

    function test_integration_7702Submission_success_forwardsLargeSettlementPayload() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory settlementPayload = SettlementUtils.settlementPayload(LARGE_SETTLEMENT_PAYLOAD_WORDS);
        bytes memory payload = abi.encodeCall(MockSettlement.settlePayload, (settlementPayload));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(settlement), payload));
        vm.snapshotGasLastCall("simple 7702 delegation - success - large mock settlement payload");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(abi.decode(returnData, (bytes32)), keccak256(settlementPayload));
        assertEq(settlement.lastSender(), solver);
        assertEq(settlement.lastPayloadHash(), keccak256(settlementPayload));
        assertEq(settlement.lastPayloadLength(), settlementPayload.length);
    }

    function test_integration_7702Submission_revertsWith_Unauthorized_whenCallerNotApproved() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeCall(MockSettlement.settle, (TEST_ORDER_UID, TEST_AMOUNT));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(settlement), payload));
        vm.snapshotGasLastCall("simple 7702 delegation - reverts - unauthorized caller");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, abi.encodeWithSelector(Solver7702Delegate.Unauthorized.selector, unauthorizedCaller));
    }

    function test_integration_7702Submission_success_whenCalldataShorterThanTargetLength() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory shortCalldata = hex"010203040506070809";

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = solver.call(shortCalldata);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData.length, 0);
    }

    function test_integration_7702Submission_success_receivesEthWithEmptyCalldata() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 solverBalanceBefore = solver.balance;
        vm.deal(unauthorizedCaller, MSG_VALUE);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = solver.call{value: MSG_VALUE}("");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData.length, 0);
        assertEq(solver.balance, solverBalanceBefore + MSG_VALUE);
    }

    function test_integration_7702Submission_success_receivesEthWithShortCalldata() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory shortCalldata = hex"010203";
        uint256 solverBalanceBefore = solver.balance;
        vm.deal(unauthorizedCaller, MSG_VALUE);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = solver.call{value: MSG_VALUE}(shortCalldata);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData.length, 0);
        assertEq(solver.balance, solverBalanceBefore + MSG_VALUE);
    }

    function test_integration_7702Submission_success_sendsEthToPayableTarget() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = hex"112233";
        uint256 fallbackTargetBalanceBefore = address(fallbackTarget).balance;
        vm.deal(approvedCallers.first, MSG_VALUE);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            solver.call{value: MSG_VALUE}(_packedCalldata(address(fallbackTarget), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        _assertFallbackReturn(returnData, solver, MSG_VALUE, payload, fallbackTargetBalanceBefore + MSG_VALUE);
        assertEq(address(fallbackTarget).balance, fallbackTargetBalanceBefore + MSG_VALUE);
    }

    function test_integration_7702Submission_revertsWith_TargetRevertData_whenEthTargetReverts() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory expectedRevertData = abi.encodeWithSelector(RAW_REVERT_SELECTOR, uint256(7), "eth failed");
        bytes memory payload = abi.encodeCall(RawRevertTarget.revertRaw, (expectedRevertData));
        uint256 rawRevertTargetBalanceBefore = address(rawRevertTarget).balance;
        vm.deal(approvedCallers.first, MSG_VALUE);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            solver.call{value: MSG_VALUE}(_packedCalldata(address(rawRevertTarget), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, expectedRevertData);
        assertEq(address(rawRevertTarget).balance, rawRevertTargetBalanceBefore);
    }

    function test_integration_7702Submission_success_transfersErc20FromSolver() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        token.mint(solver, TEST_AMOUNT);
        bytes memory payload = abi.encodeWithSelector(IERC20.transfer.selector, recipient, TEST_AMOUNT);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(token), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(abi.decode(returnData, (bool)), true);
        assertEq(token.balanceOf(solver), 0);
        assertEq(token.balanceOf(recipient), TEST_AMOUNT);
    }

    function test_integration_7702Submission_revertsWith_TargetRevertData_whenErc20TransferFails() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amountTooHigh = TEST_AMOUNT + 1;
        token.mint(solver, TEST_AMOUNT);
        bytes memory payload = abi.encodeWithSelector(IERC20.transfer.selector, recipient, amountTooHigh);
        bytes memory expectedRevertData =
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, solver, TEST_AMOUNT, amountTooHigh);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(token), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, expectedRevertData);
        assertEq(token.balanceOf(solver), TEST_AMOUNT);
        assertEq(token.balanceOf(recipient), 0);
    }

    function test_integration_7702Submission_success_approvesErc20FromSolver() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encodeWithSelector(IERC20.approve.selector, spender, TEST_AMOUNT);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(token), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(abi.decode(returnData, (bool)), true);
        assertEq(token.allowance(solver, spender), TEST_AMOUNT);
    }

    function test_integration_7702Submission_success_submitsSmallSettlementAsSolver() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        (bytes memory payload, bytes32 expectedPayloadHash) = SettlementUtils.gpv2SettlementCalldata(
            SMALL_GPV2_TOKEN_COUNT,
            SMALL_GPV2_TRADE_COUNT,
            SMALL_GPV2_INTERACTION_COUNT,
            recipient,
            address(fallbackTarget)
        );
        uint256 directGas =
            _snapshotDirectSettlementGas(payload, "GPv2Settlement direct call - success - small settlement");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        uint256 gasBefore = gasleft();
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(gpv2Settlement), payload));
        uint256 delegatedGas = gasBefore - gasleft();
        vm.snapshotValue("GPv2Settlement 7702 delegation - success - small settlement", delegatedGas);
        vm.snapshotValue(
            "GPv2Settlement 7702 overhead - success - small settlement",
            MathUtils.nonNegativeDelta(delegatedGas, directGas)
        );

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData.length, 0);
        assertEq(gpv2Settlement.lastSender(), solver);
        assertEq(gpv2Settlement.lastPayloadHash(), expectedPayloadHash);
        assertEq(gpv2Settlement.lastTokenCount(), SMALL_GPV2_TOKEN_COUNT);
        assertEq(gpv2Settlement.lastTradeCount(), SMALL_GPV2_TRADE_COUNT);
    }

    function test_integration_7702Submission_success_submitsLargeSettlementAsSolver() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        (bytes memory payload, bytes32 expectedPayloadHash) = SettlementUtils.gpv2SettlementCalldata(
            LARGE_GPV2_TOKEN_COUNT,
            LARGE_GPV2_TRADE_COUNT,
            LARGE_GPV2_INTERACTION_COUNT,
            recipient,
            address(fallbackTarget)
        );
        uint256 directGas = _snapshotDirectSettlementGas(
            payload, "GPv2Settlement direct call - success - large settlement with 6 interactions"
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        uint256 gasBefore = gasleft();
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(gpv2Settlement), payload));
        uint256 delegatedGas = gasBefore - gasleft();
        vm.snapshotValue(
            "GPv2Settlement 7702 delegation - success - large settlement with 6 interactions", delegatedGas
        );
        vm.snapshotValue(
            "GPv2Settlement 7702 overhead - success - large settlement with 6 interactions",
            MathUtils.nonNegativeDelta(delegatedGas, directGas)
        );

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(returnData.length, 0);
        assertEq(gpv2Settlement.lastSender(), solver);
        assertEq(gpv2Settlement.lastPayloadHash(), expectedPayloadHash);
        assertEq(gpv2Settlement.lastTokenCount(), LARGE_GPV2_TOKEN_COUNT);
        assertEq(gpv2Settlement.lastTradeCount(), LARGE_GPV2_TRADE_COUNT);
        assertEq(gpv2Settlement.lastInteractionCount(), LARGE_GPV2_INTERACTION_COUNT);
    }

    function test_integration_7702Submission_revertsWith_TargetRevertData_whenSettlementRejectsSolver() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        (bytes memory payload,) = SettlementUtils.gpv2SettlementCalldata(
            SMALL_GPV2_TOKEN_COUNT,
            SMALL_GPV2_TRADE_COUNT,
            SMALL_GPV2_INTERACTION_COUNT,
            recipient,
            address(fallbackTarget)
        );
        bytes memory expectedRevertData = abi.encodeWithSelector(MockGPv2Settlement.NotSolver.selector, solver);
        authenticator.removeSolver(solver);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(gpv2Settlement), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, expectedRevertData);
    }

    function test_integration_7702Submission_revertsWith_TargetRevertData_whenSettlementInteractionReverts() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory interactionRevertData = abi.encodeWithSelector(RAW_REVERT_SELECTOR, uint256(9), "interaction");
        (bytes memory payload,) = SettlementUtils.gpv2SettlementCalldata(
            REVERTING_GPV2_TOKEN_COUNT,
            REVERTING_GPV2_TRADE_COUNT,
            REVERTING_GPV2_INTERACTION_COUNT,
            recipient,
            address(fallbackTarget),
            address(rawRevertTarget),
            interactionRevertData
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(gpv2Settlement), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, interactionRevertData);
    }

    function _snapshotDirectSettlementGas(bytes memory payload, string memory label)
        internal
        returns (uint256 gasUsed)
    {
        MockGPv2Authenticator directAuthenticator = new MockGPv2Authenticator(address(this));
        directAuthenticator.addSolver(solver);
        MockGPv2Settlement directSettlement =
            new MockGPv2Settlement(directAuthenticator, makeAddr("DIRECT_VAULT_RELAYER"));

        vm.prank(solver);
        uint256 gasBefore = gasleft();
        (bool success,) = address(directSettlement).call(payload);
        gasUsed = gasBefore - gasleft();

        assertTrue(success);
        vm.snapshotValue(label, gasUsed);
    }
}
