// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

interface IGPv2Authenticator {
    function manager() external view returns (address);

    function addSolver(address solver) external;

    function removeSolver(address solver) external;

    function isSolver(address prospectiveSolver) external view returns (bool);
}
