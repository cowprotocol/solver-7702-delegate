// SPDX-License-Identifier: MIT OR Apache-2.0
// solhint-disable avoid-low-level-calls, gas-small-strings
pragma solidity ^0.8.34;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Solver7702Delegate} from "src/Solver7702Delegate.sol";
import {BaseTest} from "test/BaseTest.t.sol";
import {IGPv2Authenticator} from "test/dependencies/settlement/IGPv2Authenticator.sol";
import {IGPv2Settlement} from "test/dependencies/settlement/IGPv2Settlement.sol";
import {MockSettlement} from "test/mocks/MockSettlement.sol";
import {FallbackTarget} from "test/mocks/targets/FallbackTarget.sol";
import {SettlementUtils} from "test/utils/SettlementUtils.sol";

contract Solver7702DelegateForkTest is BaseTest {
    uint256 internal constant MAINNET_FORK_BLOCK = 25_093_000;
    uint256 internal constant LARGE_GPV2_TOKEN_COUNT = 24;
    IGPv2Settlement internal constant REAL_GPV2_SETTLEMENT =
        IGPv2Settlement(0x9008D19f58AAbD9eD0D60971565AA8510560ab41);

    function setUp() public override {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), MAINNET_FORK_BLOCK);
        super.setUp();

        IGPv2Authenticator authenticator = REAL_GPV2_SETTLEMENT.authenticator();
        vm.prank(authenticator.manager());
        authenticator.addSolver(solver);
        assertTrue(authenticator.isSolver(solver));

        _attachDelegation(SOLVER_PRIVATE_KEY);
    }

    function test_fork_7702Submission_success_settlementSeesSolverEoa() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockSettlement settlement = new MockSettlement();
        bytes memory payload = abi.encodeCall(MockSettlement.settle, (TEST_ORDER_UID, TEST_AMOUNT));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(settlement), payload));
        vm.snapshotGasLastCall("fork simple 7702 delegation - success - mock settlement sees solver EOA");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(abi.decode(returnData, (bytes32)), TEST_ORDER_UID);
        assertEq(settlement.lastSender(), solver);
    }

    function test_fork_7702Submission_revertsWith_Unauthorized_whenCallerNotApproved() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockSettlement settlement = new MockSettlement();
        address unauthorizedCaller = makeAddr("FORK_UNAUTHORIZED_CALLER");
        bytes memory payload = abi.encodeCall(MockSettlement.settle, (TEST_ORDER_UID, TEST_AMOUNT));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorizedCaller);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(settlement), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, abi.encodeWithSelector(Solver7702Delegate.Unauthorized.selector, unauthorizedCaller));
    }

    function test_fork_7702Submission_success_sendsEthToPayableTarget() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        FallbackTarget target = new FallbackTarget();
        bytes memory payload = hex"abcdef";
        uint256 targetBalanceBefore = address(target).balance;
        vm.deal(approvedCallers.first, MSG_VALUE);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) =
            solver.call{value: MSG_VALUE}(_packedCalldata(address(target), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        _assertFallbackReturn(returnData, solver, MSG_VALUE, payload, targetBalanceBefore + MSG_VALUE);
        assertEq(address(target).balance, targetBalanceBefore + MSG_VALUE);
    }

    function test_fork_7702Submission_success_transfersErc20FromSolver() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        ERC20Mock token = new ERC20Mock();
        address recipient = makeAddr("FORK_RECIPIENT");
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

    function test_fork_7702Submission_success_submitsSmallGPv2SettlementAsAllowlistedSolver() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = SettlementUtils.realGPv2SettleCalldata(0, address(0));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.expectEmit(address(REAL_GPV2_SETTLEMENT));
        emit IGPv2Settlement.Settlement(solver);
        vm.prank(approvedCallers.first);
        uint256 gasBefore = gasleft();
        (bool success,) = solver.call(_packedCalldata(address(REAL_GPV2_SETTLEMENT), payload));
        uint256 delegatedGas = gasBefore - gasleft();
        vm.snapshotValue("real GPv2Settlement 7702 delegation - success - empty settlement", delegatedGas);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
    }

    function test_fork_7702Submission_success_submitsLargeGPv2SettlementAsAllowlistedSolver() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = SettlementUtils.realGPv2SettleCalldata(LARGE_GPV2_TOKEN_COUNT, address(0));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.expectEmit(address(REAL_GPV2_SETTLEMENT));
        emit IGPv2Settlement.Settlement(solver);
        vm.prank(approvedCallers.first);
        uint256 gasBefore = gasleft();
        (bool success,) = solver.call(_packedCalldata(address(REAL_GPV2_SETTLEMENT), payload));
        uint256 delegatedGas = gasBefore - gasleft();
        vm.snapshotValue("real GPv2Settlement 7702 delegation - success - 24-token settlement", delegatedGas);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
    }

    function test_fork_7702Submission_revertsWith_TargetRevertData_whenGPv2SettlementRejectsCaller() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IGPv2Authenticator authenticator = REAL_GPV2_SETTLEMENT.authenticator();
        vm.prank(authenticator.manager());
        authenticator.removeSolver(solver);
        assertFalse(authenticator.isSolver(solver));
        bytes memory payload = SettlementUtils.realGPv2SettleCalldata(0, address(0));
        bytes memory expectedRevertData = abi.encodeWithSignature("Error(string)", "GPv2: not a solver");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(REAL_GPV2_SETTLEMENT), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, expectedRevertData);
    }

    function test_fork_7702Submission_revertsWith_TargetRevertData_whenGPv2SettlementBatchInvalid() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = SettlementUtils.realGPv2SettleCalldata(0, REAL_GPV2_SETTLEMENT.vaultRelayer());
        bytes memory expectedRevertData = abi.encodeWithSignature("Error(string)", "GPv2: forbidden interaction");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(REAL_GPV2_SETTLEMENT), payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success);
        assertEq(returnData, expectedRevertData);
    }
}
