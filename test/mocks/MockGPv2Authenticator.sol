// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

import {IGPv2Authenticator} from "test/dependencies/settlement/IGPv2Authenticator.sol";

/// @notice Minimal GPv2 authenticator for tests.
/// @dev Lets tests add or remove solver addresses without pulling in the production authenticator.
contract MockGPv2Authenticator is IGPv2Authenticator {
    address public immutable MANAGER;

    mapping(address solver => bool allowed) public solvers;

    constructor(address manager_) {
        MANAGER = manager_;
    }

    /// @notice Marks `solver` as allowed to submit settlements.
    function addSolver(address solver) external {
        solvers[solver] = true;
    }

    /// @notice Removes `solver` from the allowlist.
    function removeSolver(address solver) external {
        solvers[solver] = false;
    }

    /// @notice Returns whether `prospectiveSolver` is currently allowed.
    function isSolver(address prospectiveSolver) external view returns (bool) {
        return solvers[prospectiveSolver];
    }

    /// @notice Returns the mock manager address used by fork tests.
    function manager() external view returns (address) {
        return MANAGER;
    }
}
