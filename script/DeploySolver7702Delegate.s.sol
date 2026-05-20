// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

import {Script} from "forge-std/Script.sol";

import {Solver7702Delegate} from "../src/Solver7702Delegate.sol";

/// @title DeploySolver7702Delegate
/// @author CoW Foundation
/// @notice Deploys Solver7702Delegate.
contract DeploySolver7702Delegate is Script {
    uint256 internal constant APPROVED_CALLERS_LENGTH = 5;

    error InvalidApprovedCallersLength(uint256 length);

    /// @notice Deploys Solver7702Delegate using approved caller environment variables.
    /// @return solver7702Delegate The deployed Solver7702Delegate contract.
    function run() external returns (Solver7702Delegate solver7702Delegate) {
        vm.startBroadcast();
        solver7702Delegate = new Solver7702Delegate{salt: vm.envOr("SALT", bytes32(0))}(_getApprovedCallers());
        vm.stopBroadcast();
    }

    /// @notice Reads the approved caller addresses from environment variables.
    /// @return approvedCallers The approved caller addresses.
    function _getApprovedCallers() internal view returns (address[APPROVED_CALLERS_LENGTH] memory approvedCallers) {
        address[] memory rawApprovedCallers = vm.envAddress("APPROVED_CALLERS", ",");

        if (rawApprovedCallers.length == 0 || rawApprovedCallers.length > APPROVED_CALLERS_LENGTH) {
            revert InvalidApprovedCallersLength(rawApprovedCallers.length);
        }

        for (uint256 i; i < rawApprovedCallers.length; ++i) {
            approvedCallers[i] = rawApprovedCallers[i];
        }
    }
}
