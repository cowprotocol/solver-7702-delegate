// SPDX-License-Identifier: MIT OR Apache-2.0
// solhint-disable avoid-low-level-calls, gas-small-strings
pragma solidity ^0.8.34;

import {BaseTest} from "test/BaseTest.t.sol";
import {MockSettlement} from "test/mocks/MockSettlement.sol";

contract Solver7702DelegateForkTest is BaseTest {
    uint256 internal constant SETTLEMENT_AMOUNT = 12.34 ether;
    bytes32 internal constant FORK_ORDER_UID = keccak256("fork order");

    function test_fork_7702Submission_success_settlementSeesSolverEoa() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        string memory mainnetRpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(mainnetRpcUrl).length == 0) {
            vm.skip(true, "MAINNET_RPC_URL not set");
        }

        vm.createSelectFork(mainnetRpcUrl);
        MockSettlement settlement = new MockSettlement();
        bytes memory payload = abi.encodeCall(MockSettlement.settle, (FORK_ORDER_UID, SETTLEMENT_AMOUNT));
        vm.signAndAttachDelegation(address(delegateContract), SOLVER_PRIVATE_KEY);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(address(settlement), payload));
        vm.snapshotGasLastCall("7702 submission - success - settlement sees solver eoa on fork");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(success);
        assertEq(abi.decode(returnData, (bytes32)), FORK_ORDER_UID);
        assertEq(settlement.lastSender(), solver);
    }
}
