// SPDX-License-Identifier: MIT OR Apache-2.0
// solhint-disable avoid-low-level-calls
pragma solidity ^0.8.34;

import {IGPv2Authenticator} from "test/dependencies/settlement/IGPv2Authenticator.sol";
import {IGPv2Settlement} from "test/dependencies/settlement/IGPv2Settlement.sol";

/// @notice Minimal GPv2 settlement target for integration tests.
/// @dev Checks the solver allowlist, records settlement shape, and executes interactions so delegate tests cover
/// settlement-style payloads without depending on the real mainnet contract.
contract MockGPv2Settlement is IGPv2Settlement {
    error ClearingPriceLengthMismatch();
    error NotSolver(address sender);

    IGPv2Authenticator public immutable AUTHENTICATOR;
    address public immutable VAULT_RELAYER;

    address public lastSender;
    uint256 public lastValue;
    bytes32 public lastPayloadHash;
    uint256 public lastTokenCount;
    uint256 public lastTradeCount;
    uint256 public lastInteractionCount;

    constructor(IGPv2Authenticator authenticator_, address vaultRelayer_) {
        AUTHENTICATOR = authenticator_;
        VAULT_RELAYER = vaultRelayer_;
    }

    /// @notice Accepts ETH so value-forwarding tests can use this mock as a payable target.
    receive() external payable {}

    /// @notice Records a settlement submission from an allowlisted solver.
    /// @dev Reverts with interaction returndata unchanged to match the production bubbling behavior tests need.
    function settle(
        address[] calldata tokens,
        uint256[] calldata clearingPrices,
        Trade[] calldata trades,
        Interaction[][3] calldata interactions
    ) external {
        if (!AUTHENTICATOR.isSolver(msg.sender)) {
            revert NotSolver(msg.sender);
        }
        if (tokens.length != clearingPrices.length) {
            revert ClearingPriceLengthMismatch();
        }

        uint256 interactionCount;
        for (uint256 phase; phase < interactions.length; ++phase) {
            interactionCount += interactions[phase].length;
            for (uint256 i; i < interactions[phase].length; ++i) {
                Interaction calldata interaction = interactions[phase][i];
                (bool success, bytes memory returnData) =
                    interaction.target.call{value: interaction.value}(interaction.callData);
                if (!success) {
                    assembly {
                        revert(add(returnData, 0x20), mload(returnData))
                    }
                }
            }
        }

        lastSender = msg.sender;
        lastValue = 0;
        lastPayloadHash = keccak256(abi.encode(tokens, clearingPrices, trades, interactions));
        lastTokenCount = tokens.length;
        lastTradeCount = trades.length;
        lastInteractionCount = interactionCount;

        emit Settlement(msg.sender);
    }

    /// @notice Returns the authenticator used to decide whether `msg.sender` is a solver.
    function authenticator() external view returns (IGPv2Authenticator) {
        return AUTHENTICATOR;
    }

    /// @notice Returns the vault relayer address used by GPv2 forbidden-interaction tests.
    function vaultRelayer() external view returns (address) {
        return VAULT_RELAYER;
    }
}
