// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";

import {Solver7702Delegate} from "src/Solver7702Delegate.sol";

struct ApprovedCallers {
    /// @notice First approved caller slot.
    address first;
    /// @notice Second approved caller slot.
    address second;
    /// @notice Third approved caller slot.
    address third;
    /// @notice Fourth approved caller slot.
    address fourth;
    /// @notice Fifth approved caller slot.
    address fifth;
}

/// @notice Shared setup and helpers for Solver7702Delegate tests.
abstract contract BaseTest is Test {
    /// @notice Private key for the EOA that gets EIP-7702 delegation attached.
    uint256 internal constant SOLVER_PRIVATE_KEY = uint256(keccak256("SOLVER_PRIVATE_KEY"));
    /// @notice ETH value used by tests that forward native token value.
    uint256 internal constant MSG_VALUE = 1 ether;
    /// @notice Number of bytes used to encode the packed target address.
    uint256 internal constant PACKED_TARGET_LENGTH = 20;
    /// @notice Shared token and mock settlement amount.
    uint256 internal constant TEST_AMOUNT = 100 ether;
    /// @notice Shared order UID used by mock settlement tests.
    bytes32 internal constant TEST_ORDER_UID = keccak256("TEST_ORDER_UID");
    /// @notice Selector for RawRevert(uint256,string).
    bytes4 internal constant RAW_REVERT_SELECTOR = bytes4(keccak256("RawRevert(uint256,string)"));

    Solver7702Delegate internal delegateContract;

    address internal solver;
    ApprovedCallers internal approvedCallers;

    /// @notice Creates the default solver, approved callers, and delegate contract.
    function setUp() public virtual {
        solver = vm.addr(SOLVER_PRIVATE_KEY);
        approvedCallers = ApprovedCallers({
            first: makeAddr("APPROVED_CALLER_0"),
            second: makeAddr("APPROVED_CALLER_1"),
            third: makeAddr("APPROVED_CALLER_2"),
            fourth: makeAddr("APPROVED_CALLER_3"),
            fifth: makeAddr("APPROVED_CALLER_4")
        });

        delegateContract = new Solver7702Delegate(
            [
                approvedCallers.first,
                approvedCallers.second,
                approvedCallers.third,
                approvedCallers.fourth,
                approvedCallers.fifth
            ]
        );
    }

    /// @notice Encodes the delegate fallback calldata as a 20-byte target followed by payload.
    function _packedCalldata(address target, bytes memory payload) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes20(target), payload);
    }

    /// @notice Attaches the delegate code to the solver EOA.
    function _attachDelegation(uint256 solverPrivateKey) internal {
        vm.signAndAttachDelegation(address(delegateContract), solverPrivateKey);
    }

    /// @notice Decodes and checks the return data from FallbackTarget.
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
