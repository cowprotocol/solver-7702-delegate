// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.34;

import {IGPv2Settlement} from "test/dependencies/settlement/IGPv2Settlement.sol";

/// @notice Helpers for building mock and real GPv2 settlement calldata in tests.
library SettlementUtils {
    /// @notice Selector for MockInteraction(uint256).
    bytes4 private constant MOCK_INTERACTION_SELECTOR = bytes4(keccak256("mockInteraction(uint256)"));

    /// @notice Builds calldata for a mock GPv2 settlement with the given shape.
    function gpv2SettlementCalldata(
        uint256 tokenCount,
        uint256 tradeCount,
        uint256 interactionCount,
        address recipient,
        address fallbackTarget
    ) internal pure returns (bytes memory payload, bytes32 payloadHash) {
        return gpv2SettlementCalldata(
            tokenCount, tradeCount, [interactionCount, uint256(0), uint256(0)], recipient, fallbackTarget
        );
    }

    /// @notice Builds calldata for a mock GPv2 settlement with interactions split by phase.
    function gpv2SettlementCalldata(
        uint256 tokenCount,
        uint256 tradeCount,
        uint256[3] memory interactionCounts,
        address recipient,
        address fallbackTarget
    ) internal pure returns (bytes memory payload, bytes32 payloadHash) {
        (
            address[] memory tokens,
            uint256[] memory clearingPrices,
            IGPv2Settlement.Trade[] memory trades,
            IGPv2Settlement.Interaction[][3] memory interactions
        ) = gpv2SettlementData(tokenCount, tradeCount, interactionCounts, recipient, fallbackTarget);

        payload = abi.encodeCall(IGPv2Settlement.settle, (tokens, clearingPrices, trades, interactions));
        payloadHash = keccak256(abi.encode(tokens, clearingPrices, trades, interactions));
    }

    /// @notice Builds malformed calldata with one fewer clearing price than token.
    function gpv2SettlementCalldataWithMissingClearingPrice(
        uint256 tokenCount,
        uint256 tradeCount,
        address recipient,
        address fallbackTarget
    ) internal pure returns (bytes memory payload) {
        uint256 clearingPriceCount = tokenCount == 0 ? 0 : tokenCount - 1;
        (address[] memory tokens,) = gpv2Tokens(tokenCount);
        (, uint256[] memory clearingPrices) = gpv2Tokens(clearingPriceCount);
        IGPv2Settlement.Trade[] memory trades = gpv2Trades(tradeCount, tokenCount, recipient);
        IGPv2Settlement.Interaction[][3] memory interactions =
            gpv2Interactions([uint256(0), uint256(0), uint256(0)], fallbackTarget);

        payload = abi.encodeCall(IGPv2Settlement.settle, (tokens, clearingPrices, trades, interactions));
    }

    /// @notice Builds fork-test calldata for the real GPv2 settlement contract using the configured token pair.
    function realGPv2SettleCalldata(address usdc, address weth, address forbiddenTarget)
        internal
        pure
        returns (bytes memory)
    {
        address[] memory tokens = new address[](2);
        uint256[] memory clearingPrices = new uint256[](2);
        IGPv2Settlement.Trade[] memory trades = new IGPv2Settlement.Trade[](0);
        IGPv2Settlement.Interaction[][3] memory interactions;

        tokens[0] = usdc;
        tokens[1] = weth;
        clearingPrices[0] = 1 ether;
        clearingPrices[1] = 1 ether;

        if (forbiddenTarget == address(0)) {
            interactions[0] = new IGPv2Settlement.Interaction[](0);
        } else {
            interactions[0] = new IGPv2Settlement.Interaction[](1);
            interactions[0][0] = IGPv2Settlement.Interaction({target: forbiddenTarget, value: 0, callData: ""});
        }
        interactions[1] = new IGPv2Settlement.Interaction[](0);
        interactions[2] = new IGPv2Settlement.Interaction[](0);

        return abi.encodeCall(IGPv2Settlement.settle, (tokens, clearingPrices, trades, interactions));
    }

    /// @notice Builds fork-test calldata for a simple WETH -> USDC trade attempt on the real GPv2 settlement.
    function realGPv2WethForUsdcOrderCalldata(address usdc, address weth, address owner)
        internal
        pure
        returns (bytes memory)
    {
        address[] memory tokens = new address[](2);
        uint256[] memory clearingPrices = new uint256[](2);
        IGPv2Settlement.Trade[] memory trades = new IGPv2Settlement.Trade[](1);
        IGPv2Settlement.Interaction[][3] memory interactions;

        tokens[0] = weth;
        tokens[1] = usdc;
        clearingPrices[0] = 1 ether;
        clearingPrices[1] = 3000 * 1 ether;

        trades[0] = IGPv2Settlement.Trade({
            sellTokenIndex: 0,
            buyTokenIndex: 1,
            receiver: owner,
            sellAmount: 1 ether,
            buyAmount: 3000e6,
            validTo: 4_102_444_800,
            appData: bytes32(0),
            feeAmount: 0,
            flags: 0,
            executedAmount: 1 ether,
            signature: abi.encodePacked(owner)
        });

        interactions[0] = new IGPv2Settlement.Interaction[](0);
        interactions[1] = new IGPv2Settlement.Interaction[](0);
        interactions[2] = new IGPv2Settlement.Interaction[](0);

        return abi.encodeCall(IGPv2Settlement.settle, (tokens, clearingPrices, trades, interactions));
    }

    /// @notice Builds the mock GPv2 settlement data tuple.
    function gpv2SettlementData(
        uint256 tokenCount,
        uint256 tradeCount,
        uint256[3] memory interactionCounts,
        address recipient,
        address fallbackTarget
    )
        private
        pure
        returns (
            address[] memory tokens,
            uint256[] memory clearingPrices,
            IGPv2Settlement.Trade[] memory trades,
            IGPv2Settlement.Interaction[][3] memory interactions
        )
    {
        (tokens, clearingPrices) = gpv2Tokens(tokenCount);
        trades = gpv2Trades(tradeCount, tokenCount, recipient);
        interactions = gpv2Interactions(interactionCounts, fallbackTarget);
    }

    /// @notice Builds deterministic mock token addresses and clearing prices.
    function gpv2Tokens(uint256 tokenCount)
        private
        pure
        returns (address[] memory tokens, uint256[] memory clearingPrices)
    {
        tokens = new address[](tokenCount);
        clearingPrices = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; ++i) {
            tokens[i] = address(uint160(uint256(keccak256(abi.encode("token", i)))));
            clearingPrices[i] = 1 ether + i;
        }
    }

    /// @notice Builds deterministic mock trades.
    function gpv2Trades(uint256 tradeCount, uint256 tokenCount, address recipient)
        private
        pure
        returns (IGPv2Settlement.Trade[] memory trades)
    {
        trades = new IGPv2Settlement.Trade[](tradeCount);
        for (uint256 i; i < tradeCount; ++i) {
            trades[i] = IGPv2Settlement.Trade({
                sellTokenIndex: i % tokenCount,
                buyTokenIndex: (i + 1) % tokenCount,
                receiver: recipient,
                sellAmount: 10 ether + i,
                buyAmount: 9 ether + i,
                validTo: 4_102_444_800,
                appData: keccak256(abi.encode("appData", i)),
                feeAmount: i,
                flags: 0,
                executedAmount: 0,
                signature: abi.encodePacked(bytes32(i))
            });
        }
    }

    /// @notice Builds the pre, intra, and post settlement interaction lists.
    function gpv2Interactions(uint256[3] memory interactionCounts, address fallbackTarget)
        private
        pure
        returns (IGPv2Settlement.Interaction[][3] memory interactions)
    {
        uint256 interactionIndex;
        for (uint256 phase; phase < interactions.length; ++phase) {
            interactions[phase] = new IGPv2Settlement.Interaction[](interactionCounts[phase]);
            for (uint256 i; i < interactionCounts[phase]; ++i) {
                interactions[phase][i] = gpv2Interaction(interactionIndex, fallbackTarget);
                ++interactionIndex;
            }
        }
    }

    /// @notice Builds one mock GPv2 interaction.
    function gpv2Interaction(uint256 index, address fallbackTarget)
        private
        pure
        returns (IGPv2Settlement.Interaction memory interaction)
    {
        interaction = IGPv2Settlement.Interaction({
            target: fallbackTarget, value: 0, callData: abi.encodeWithSelector(MOCK_INTERACTION_SELECTOR, index)
        });
    }
}
