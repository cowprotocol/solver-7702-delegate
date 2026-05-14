// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8;

import {Counter} from "../src/Counter.sol";
import {Script} from "forge-std/Script.sol";

/// @title CounterScript
/// @author CoW DAO Developers
/// @notice Script to deploy the Counter contract
contract CounterScript is Script {
    /// @notice The deployed Counter contract
    Counter public counter;

    /// @notice Run the script
    function run() public {
        vm.startBroadcast();
        counter = new Counter();
        vm.stopBroadcast();
    }
}
