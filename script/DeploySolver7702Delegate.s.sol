// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

import {Script} from "forge-std/Script.sol";

import {Solver7702Delegate} from "../src/Solver7702Delegate.sol";

/// @title DeploySolver7702Delegate
/// @author CoW Foundation
/// @notice Deploys Solver7702Delegate with five approved caller addresses.
contract DeploySolver7702Delegate is Script {
    /// @notice Foundry's default CREATE2 deployer.
    address internal constant DEFAULT_CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    /// @notice Deploys Solver7702Delegate using approved caller environment variables.
    /// @return solver7702Delegate The deployed Solver7702Delegate contract.
    function run() external returns (Solver7702Delegate solver7702Delegate) {
        address[5] memory approvedCallers = getApprovedCallers();

        vm.startBroadcast();
        if (vm.envExists("SALT")) {
            solver7702Delegate = new Solver7702Delegate{salt: getSalt()}(approvedCallers);
        } else {
            solver7702Delegate = new Solver7702Delegate(approvedCallers);
        }
        vm.stopBroadcast();
    }

    /// @notice Predicts the CREATE2 address using environment variables.
    /// @dev Reads `SALT`, approved callers, and optional `CREATE2_DEPLOYER`.
    /// @return The predicted Solver7702Delegate address.
    function predictAddress() external view returns (address) {
        address deployer =
            vm.envExists("CREATE2_DEPLOYER") ? vm.envAddress("CREATE2_DEPLOYER") : DEFAULT_CREATE2_DEPLOYER;
        address[5] memory approvedCallers = getApprovedCallers();
        bytes32 salt = getSalt();
        bytes memory initCode = abi.encodePacked(type(Solver7702Delegate).creationCode, abi.encode(approvedCallers));
        bytes32 addressHash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(initCode)));

        return address(uint160(uint256(addressHash)));
    }

    /// @notice Reads the approved caller addresses from environment variables.
    /// @return approvedCallers The approved caller addresses.
    function getApprovedCallers() internal view returns (address[5] memory approvedCallers) {
        approvedCallers = [
            vm.envAddress("APPROVED_CALLER_0"),
            vm.envAddress("APPROVED_CALLER_1"),
            vm.envAddress("APPROVED_CALLER_2"),
            vm.envAddress("APPROVED_CALLER_3"),
            vm.envAddress("APPROVED_CALLER_4")
        ];
    }

    /// @notice Reads the CREATE2 salt from the `SALT` environment variable.
    /// @dev Exact `0x`-prefixed 32-byte hex strings are used directly; all other strings are hashed.
    /// @return The CREATE2 salt.
    function getSalt() internal view returns (bytes32) {
        string memory salt = vm.envString("SALT");
        bytes memory saltBytes = bytes(salt);
        if (saltBytes.length == 66 && saltBytes[0] == "0" && (saltBytes[1] == "x" || saltBytes[1] == "X")) {
            return vm.parseBytes32(salt);
        }

        return keccak256(bytes(salt));
    }
}
