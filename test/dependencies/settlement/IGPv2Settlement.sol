// SPDX-License-Identifier: MIT OR Apache-2.0
// solhint-disable gas-struct-packing
pragma solidity ^0.8.34;

import {IGPv2Authenticator} from "test/dependencies/settlement/IGPv2Authenticator.sol";

interface IGPv2Settlement {
    struct Trade {
        uint256 sellTokenIndex;
        uint256 buyTokenIndex;
        address receiver;
        uint256 sellAmount;
        uint256 buyAmount;
        uint32 validTo;
        bytes32 appData;
        uint256 feeAmount;
        uint256 flags;
        uint256 executedAmount;
        bytes signature;
    }

    struct Interaction {
        address target;
        uint256 value;
        bytes callData;
    }

    event Settlement(address indexed solver);

    function authenticator() external view returns (IGPv2Authenticator);

    function vaultRelayer() external view returns (address);

    function settle(
        address[] calldata tokens,
        uint256[] calldata clearingPrices,
        Trade[] calldata trades,
        Interaction[][3] calldata interactions
    ) external;
}
