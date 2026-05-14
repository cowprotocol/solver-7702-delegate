// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";

import {Solver7702Delegate} from "src/Solver7702Delegate.sol";

struct ApprovedCallers {
    address first;
    address second;
    address third;
    address fourth;
    address fifth;
}

abstract contract BaseTest is Test {
    uint256 internal constant SOLVER_PRIVATE_KEY = uint256(keccak256("SOLVER_PRIVATE_KEY"));
    uint256 internal constant MSG_VALUE = 1 ether;

    Solver7702Delegate internal delegateContract;

    address internal solver;
    ApprovedCallers internal approvedCallers;

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

    function _packedCalldata(address target, bytes memory payload) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes20(target), payload);
    }
}
