// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

import {Solver7702Delegate} from "src/Solver7702Delegate.sol";
import {BaseTest} from "test/BaseTest.t.sol";

contract Solver7702DelegateForkTest is BaseTest {
    string internal constant MAINNET_RPC_ENV = "ETH_MAINNET_RPC_URL";
    bytes internal constant EIP7702_DELEGATION_PREFIX = hex"ef0100";

    Solver7702Delegate internal delegateContract;

    struct HistoricalTransaction {
        string label;
        bytes32 txHash;
    }

    struct HistoricalCall {
        address originalSolver;
        address target;
        uint256 value;
        bytes payload;
    }

    function test_fork_historicalTransaction_directVsDelegated_usdcForEura() public {
        _runHistoricalTransaction(
            HistoricalTransaction({
                label: "USDC to EURA", txHash: 0x8db7514f572db097bc1dce61402f347c1ace164a9e2de7f0dd0f32443f2e9d7f
            }),
            true
        );
    }

    function test_fork_historicalTransaction_directVsDelegated_wethForUsdc() public {
        _runHistoricalTransaction(
            HistoricalTransaction({
                label: "WETH to USDC", txHash: 0x80a37a1af03bd0c3d8030c764b66c332d580d497a04e3e00c9746de49e47cf4e
            }),
            true
        );
    }

    function test_fork_historicalTransaction_directVsDelegated_yfiForUsdc() public {
        _runHistoricalTransaction(
            HistoricalTransaction({
                label: "YFI to USDC", txHash: 0x38793b2b90a472f43ebe9ff35105132cb4e2be906a89f4bb0017bdedf29b8f53
            }),
            true
        );
    }

    function test_fork_historicalTransaction_directVsDelegated_usdtForAave() public {
        _runHistoricalTransaction(
            HistoricalTransaction({
                label: "USDT to AAVE", txHash: 0x67ffdb1c1afb013b3c848a891fca0b6924bd9584be9ee7776d09b772dcb6739a
            }),
            true
        );
    }

    function test_fork_historicalTransaction_directVsDelegated_usdcPermitForMog() public {
        _runHistoricalTransaction(
            HistoricalTransaction({
                label: "USDC permit to MOG", txHash: 0xc157c9b4214a1c901ad25c1da17be6094490971bae4475ff55971d309f463702
            }),
            true
        );
    }

    function test_fork_historicalTransaction_directVsDelegated_userSuppliedTxHashes() public {
        string memory rawTxHashes = vm.envOr("COW_HISTORICAL_TX_HASHES", string(""));
        if (bytes(rawTxHashes).length == 0) {
            return;
        }

        string[] memory txHashes = vm.split(rawTxHashes, ",");
        for (uint256 i; i < txHashes.length; ++i) {
            _runHistoricalTransaction(HistoricalTransaction({label: "", txHash: vm.parseBytes32(txHashes[i])}), false);
        }
    }

    function _runHistoricalTransaction(HistoricalTransaction memory txn, bool snapshotGas) internal {
        // 1. Create a fork and roll to the transaction block.
        vm.createSelectFork(vm.envString(MAINNET_RPC_ENV));
        vm.rollFork(txn.txHash);
        HistoricalCall memory hc = _historicalTargetAndCalldata(txn.txHash);
        assertTrue(hc.target != address(0), "historical transaction target missing");
        assertGt(hc.payload.length, 0, "historical transaction calldata missing");

        // 2. Take a snapshot of the state.
        uint256 snapshot = vm.snapshotState();

        bool directSuccess;
        bytes memory directReturnData;
        bool delegatedSuccess;
        bytes memory delegatedReturnData;

        // 3. Call the target directly and snapshot the gas if requested.
        vm.prank(hc.originalSolver);
        (directSuccess, directReturnData) = hc.target.call{value: hc.value}(hc.payload);
        if (snapshotGas) {
            vm.snapshotGasLastCall(string.concat("historical tx - ", txn.label, " - direct call"));
        }

        // 4. Call the target through delegation and snapshot the gas if requested.
        (delegatedSuccess, delegatedReturnData) = _runHistoricalTransactionDelegated(txn, hc, snapshot, snapshotGas);

        // 5. Assert the results.
        assertTrue(directSuccess, "direct replay failed");
        assertTrue(delegatedSuccess, "delegated replay failed");
        assertEq(delegatedSuccess, directSuccess, "success mismatch");
        assertEq(keccak256(delegatedReturnData), keccak256(directReturnData), "return data mismatch");
    }

    function _runHistoricalTransactionDelegated(
        HistoricalTransaction memory txn,
        HistoricalCall memory hc,
        uint256 snapshot,
        bool snapshotGas
    ) internal returns (bool delegatedSuccess, bytes memory delegatedReturnData) {
        // Revert to the snapshot before the direct call.
        vm.revertToState(snapshot);

        // Set up the delegate contract.
        super.setUp();
        delegateContract = new Solver7702Delegate(approvedCallers);

        // Set the original solver to delegate to the new delegate contract.
        vm.etch(hc.originalSolver, abi.encodePacked(EIP7702_DELEGATION_PREFIX, address(delegateContract)));

        vm.deal(approvedCallers[0], hc.value);
        vm.prank(approvedCallers[0]);
        (delegatedSuccess, delegatedReturnData) =
            hc.originalSolver.call{value: hc.value}(_packedCalldata(hc.target, hc.payload));
        if (snapshotGas) {
            vm.snapshotGasLastCall(string.concat("historical tx - ", txn.label, " - delegated call"));
        }
    }

    function _historicalTargetAndCalldata(bytes32 txHash) internal returns (HistoricalCall memory hc) {
        bytes memory data = vm.rpc("eth_getTransactionByHash", string.concat("[\"", vm.toString(txHash), "\"]"));
        uint256 tupleStart = _readUint(data, 0);
        uint256 fromOffset = 0x80;
        uint256 toOffset = 0x1c0;
        uint256 valueOffset = 0x240;
        uint256 inputOffsetOffset = 0x100;

        hc.originalSolver = _readAddress(data, tupleStart + fromOffset);
        if (hc.originalSolver == address(0)) {
            fromOffset = 0xa0;
            toOffset = 0x1e0;
            valueOffset = 0x260;
            inputOffsetOffset = 0x120;
            hc.originalSolver = _readAddress(data, tupleStart + fromOffset);
        }

        hc.target = _readAddress(data, tupleStart + toOffset);
        hc.value = _readDynamicUint(data, tupleStart, valueOffset);
        uint256 inputOffset = _readUint(data, tupleStart + inputOffsetOffset);
        uint256 inputStart = tupleStart + inputOffset;
        hc.payload = _readBytes(data, inputStart);
    }

    function _readAddress(bytes memory data, uint256 offset) internal pure returns (address value) {
        value = address(uint160(_readUint(data, offset)));
    }

    function _readUint(bytes memory data, uint256 offset) internal pure returns (uint256 value) {
        for (uint256 i; i < 32; ++i) {
            value = (value << 8) | uint8(data[offset + i]);
        }
    }

    function _readDynamicUint(bytes memory data, uint256 tupleStart, uint256 offset)
        internal
        pure
        returns (uint256 value)
    {
        uint256 valueStart = tupleStart + _readUint(data, tupleStart + offset);
        uint256 length = _readUint(data, valueStart);
        for (uint256 i; i < length; ++i) {
            value = (value << 8) | uint8(data[valueStart + 32 + i]);
        }
    }

    function _readBytes(bytes memory data, uint256 offset) internal pure returns (bytes memory value) {
        uint256 length = _readUint(data, offset);
        value = new bytes(length);
        for (uint256 i; i < length; ++i) {
            value[i] = data[offset + 32 + i];
        }
    }
}
