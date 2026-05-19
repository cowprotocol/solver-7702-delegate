// SPDX-License-Identifier: MIT OR Apache-2.0
// solhint-disable avoid-low-level-calls, gas-small-strings, max-states-count
pragma solidity ^0.8.34;

import {BaseTest} from "test/BaseTest.t.sol";
import {IGPv2Authenticator} from "test/dependencies/settlement/IGPv2Authenticator.sol";
import {IGPv2Settlement} from "test/dependencies/settlement/IGPv2Settlement.sol";

contract Solver7702DelegateForkTest is BaseTest {
    address internal constant GPV2_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address internal constant GPV2_AUTHENTICATOR = 0x2c4c28DDBdAc9C5E7055b4C863b72eA0149D8aFE;

    struct NetworkConfig {
        string name;
        string rpcEnv;
        uint256 forkBlock;
        address settlement;
        address authenticator;
        address usdc;
        address weth;
    }

    struct HistoricalOrder {
        string label;
        bytes orderUid;
        bytes32 txHash;
        uint256 forkBlock;
        uint256 settlementBlock;
        address sellToken;
        address buyToken;
        uint256 sellAmount;
        uint256 buyAmount;
        address owner;
    }

    function setUp() public override {
        // Each test selects its own fork from a real network config.
    }

    // ~~~~~~~~~~~~~~~~~~~~ NETWORK CONFIG TESTS ~~~~~~~~~~~~~~~~~~~~

    function test_fork_submission_attemptsSimpleWethForUsdcOrder_ethereum() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _attemptSimpleWethForUsdcOrder(_ethereumNetworkConfig());
    }

    function test_fork_submission_attemptsSimpleWethForUsdcOrder_arbitrum() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _attemptSimpleWethForUsdcOrder(
            NetworkConfig({
                name: "arbitrum",
                rpcEnv: "ARBITRUM_ONE_RPC_URL",
                forkBlock: 0, // historical blocks not supported in RPC
                settlement: GPV2_SETTLEMENT,
                authenticator: GPV2_AUTHENTICATOR,
                usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
                weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
            })
        );
    }

    function test_fork_submission_attemptsSimpleWethForUsdcOrder_base() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _attemptSimpleWethForUsdcOrder(
            NetworkConfig({
                name: "base",
                rpcEnv: "BASE_RPC_URL",
                forkBlock: 46_025_000,
                settlement: GPV2_SETTLEMENT,
                authenticator: GPV2_AUTHENTICATOR,
                usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
                weth: 0x4200000000000000000000000000000000000006
            })
        );
    }

    function test_fork_submission_attemptsSimpleWethForUsdcOrder_bnb() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _attemptSimpleWethForUsdcOrder(
            NetworkConfig({
                name: "bnb",
                rpcEnv: "BNB_MAINNET_RPC_URL",
                forkBlock: 0, // historical blocks not supported in RPC
                settlement: GPV2_SETTLEMENT,
                authenticator: GPV2_AUTHENTICATOR,
                usdc: 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d,
                weth: 0x2170Ed0880ac9A755fd29B2688956BD959F933F8
            })
        );
    }

    function test_fork_submission_attemptsSimpleWethForUsdcOrder_gnosis() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _attemptSimpleWethForUsdcOrder(
            NetworkConfig({
                name: "gnosis",
                rpcEnv: "GNOSIS_RPC_URL",
                forkBlock: 46_185_000,
                settlement: GPV2_SETTLEMENT,
                authenticator: GPV2_AUTHENTICATOR,
                usdc: 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83,
                weth: 0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1
            })
        );
    }

    function test_fork_submission_attemptsSimpleWethForUsdcOrder_optimism() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _attemptSimpleWethForUsdcOrder(
            NetworkConfig({
                name: "optimism",
                rpcEnv: "OPTIMISM_RPC_URL",
                forkBlock: 151_400_000,
                settlement: GPV2_SETTLEMENT,
                authenticator: GPV2_AUTHENTICATOR,
                usdc: 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85,
                weth: 0x4200000000000000000000000000000000000006
            })
        );
    }

    function test_fork_submission_attemptsSimpleWethForUsdcOrder_polygon() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _attemptSimpleWethForUsdcOrder(
            NetworkConfig({
                name: "polygon",
                rpcEnv: "POLYGON_RPC_URL",
                forkBlock: 0, // historical blocks not supported in RPC
                settlement: GPV2_SETTLEMENT,
                authenticator: GPV2_AUTHENTICATOR,
                usdc: 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359,
                weth: 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619
            })
        );
    }

    function test_fork_submission_attemptsSimpleWethForUsdcOrder_plasma() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _attemptSimpleWethForUsdcOrder(
            NetworkConfig({
                name: "plasma",
                rpcEnv: "PLASMA_RPC_URL",
                forkBlock: 21_916_000,
                settlement: GPV2_SETTLEMENT,
                authenticator: GPV2_AUTHENTICATOR,
                usdc: 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb,
                weth: 0x9895D81bB462A195b4922ED7De0e3ACD007c32CB
            })
        );
    }

    function test_fork_submission_attemptsSimpleWethForUsdcOrder_avalanche() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _attemptSimpleWethForUsdcOrder(
            NetworkConfig({
                name: "avalanche",
                rpcEnv: "AVALANCHE_RPC_URL",
                forkBlock: 0, // historical blocks not supported in RPC
                settlement: GPV2_SETTLEMENT,
                authenticator: GPV2_AUTHENTICATOR,
                usdc: 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E,
                weth: 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB
            })
        );
    }

    function test_fork_submission_attemptsSimpleWethForUsdcOrder_ink() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _attemptSimpleWethForUsdcOrder(
            NetworkConfig({
                name: "ink",
                rpcEnv: "INK_RPC_URL",
                forkBlock: 0, // historical blocks not supported in RPC
                settlement: GPV2_SETTLEMENT,
                authenticator: GPV2_AUTHENTICATOR,
                usdc: 0xF1815bd50389c46847f0Bda824eC8da914045D14,
                weth: 0x4200000000000000000000000000000000000006
            })
        );
    }

    function test_fork_submission_attemptsSimpleWethForUsdcOrder_linea() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _attemptSimpleWethForUsdcOrder(
            NetworkConfig({
                name: "linea",
                rpcEnv: "LINEA_RPC_URL",
                forkBlock: 30_655_000,
                settlement: GPV2_SETTLEMENT,
                authenticator: GPV2_AUTHENTICATOR,
                usdc: 0x176211869cA2b568f2A7D4EE941E073a821EE1ff,
                weth: 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f
            })
        );
    }

    function test_fork_submission_revertsWith_NotSolver_ethereum() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        NetworkConfig memory config = _ethereumNetworkConfig();
        _selectForkAndSetUp(config);

        IGPv2Authenticator authenticator = IGPv2Authenticator(config.authenticator);
        vm.prank(authenticator.manager());
        authenticator.removeSolver(solver);
        assertFalse(authenticator.isSolver(solver));

        bytes memory payload = _realGPv2SettleCalldata(config.usdc, config.weth, address(0));
        bytes memory expectedRevertData = abi.encodeWithSignature("Error(string)", "GPv2: not a solver");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(config.settlement, payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "submission succeeded when not solver");
        assertEq(returnData, expectedRevertData, "revert data mismatch");
    }

    function test_fork_submission_revertsWith_ForbiddenInteraction_ethereum() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        NetworkConfig memory config = _ethereumNetworkConfig();
        _selectForkAndSetUp(config);

        address vaultRelayer = IGPv2Settlement(config.settlement).vaultRelayer();
        bytes memory payload = _realGPv2SettleCalldata(config.usdc, config.weth, vaultRelayer);
        bytes memory expectedRevertData = abi.encodeWithSignature("Error(string)", "GPv2: forbidden interaction");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(approvedCallers.first);
        (bool success, bytes memory returnData) = solver.call(_packedCalldata(config.settlement, payload));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(success, "submission succeeded with forbidden interaction");
        assertEq(returnData, expectedRevertData, "revert data mismatch");
    }

    // ~~~~~~~~~~~~~~~~~~~~ HISTORICAL ORDER TESTS ~~~~~~~~~~~~~~~~~~~~

    // https://explorer.cow.fi/mainnet/orders/0x6c4aa56cadbc45ff53fa35550902a488752218cac1e629ff812d7cb9ff0e1a78b31e6a0bf8d0ad664f58a7374ac0539ec51c3d236a023b7d
    function test_fork_historicalOrder_directVsDelegated_usdcForEura() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _runHistoricalOrder(
            HistoricalOrder({
                label: "USDC -> EURA",
                orderUid: hex"6c4aa56cadbc45ff53fa35550902a488752218cac1e629ff812d7cb9ff0e1a78b31e6a0bf8d0ad664f58a7374ac0539ec51c3d236a023b7d",
                txHash: 0x8db7514f572db097bc1dce61402f347c1ace164a9e2de7f0dd0f32443f2e9d7f,
                forkBlock: 25_074_097,
                settlementBlock: 25_074_098,
                sellToken: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                buyToken: 0x57e114B691Db790C35207b2e685D4A43181e6061,
                sellAmount: 489_089_774,
                buyAmount: 3_742_033_366_022_621_078_227,
                owner: 0xb31E6A0bf8d0Ad664f58A7374ac0539eC51c3D23
            })
        );
    }

    // https://explorer.cow.fi/mainnet/orders/0x391884a8e90bf92e99cfdd9ce97959214e9b13da7022b95d8a797c71caeb4cd2ba3cb449bd2b4adddbc894d8697f5170800eadecffffffff
    function test_fork_historicalOrder_directVsDelegated_wethForUsdc() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _runHistoricalOrder(
            HistoricalOrder({
                label: "WETH -> USDC",
                orderUid: hex"391884a8e90bf92e99cfdd9ce97959214e9b13da7022b95d8a797c71caeb4cd2ba3cb449bd2b4adddbc894d8697f5170800eadecffffffff",
                txHash: 0x80a37a1af03bd0c3d8030c764b66c332d580d497a04e3e00c9746de49e47cf4e,
                forkBlock: 25_099_780,
                settlementBlock: 25_099_781,
                sellToken: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                buyToken: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                sellAmount: 3_860_000_000_000_000_000,
                buyAmount: 8_692_179_691,
                owner: 0xbA3cB449bD2B4ADddBc894D8697F5170800EAdeC
            })
        );
    }

    // https://explorer.cow.fi/mainnet/orders/0xde339bcddeadcb054d7cf6a8421ed059ba19ce50d9aa8fedc348c041cb0302d8a5f84b556d5fd8959165eff0324dcfea164fa0896a06f646
    function test_fork_historicalOrder_directVsDelegated_yfiForUsdc() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _runHistoricalOrder(
            HistoricalOrder({
                label: "YFI -> USDC",
                orderUid: hex"de339bcddeadcb054d7cf6a8421ed059ba19ce50d9aa8fedc348c041cb0302d8a5f84b556d5fd8959165eff0324dcfea164fa0896a06f646",
                txHash: 0x38793b2b90a472f43ebe9ff35105132cb4e2be906a89f4bb0017bdedf29b8f53,
                forkBlock: 25_099_837,
                settlementBlock: 25_099_838,
                sellToken: 0x4d1C297d39C5c1277964D0E3f8Aa901493664530,
                buyToken: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                sellAmount: 86_957_000_000_000_000_000_000,
                buyAmount: 2_351_389_220,
                owner: 0xa5F84b556d5FD8959165Eff0324DCFEa164fA089
            })
        );
    }

    // https://explorer.cow.fi/mainnet/orders/0xe4a4cb076fcabe07910b078ff008c53780566a323294aabf7de07048a27e0d9bbb08a33f8829c7f8f3684f67723326b2ebf5a86c6a06f55c
    function test_fork_historicalOrder_directVsDelegated_usdtForAave() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _runHistoricalOrder(
            HistoricalOrder({
                label: "USDT -> AAVE",
                orderUid: hex"e4a4cb076fcabe07910b078ff008c53780566a323294aabf7de07048a27e0d9bbb08a33f8829c7f8f3684f67723326b2ebf5a86c6a06f55c",
                txHash: 0x67ffdb1c1afb013b3c848a891fca0b6924bd9584be9ee7776d09b772dcb6739a,
                forkBlock: 25_099_804,
                settlementBlock: 25_099_805,
                sellToken: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
                buyToken: 0xe76C6c83af64e4C60245D8C7dE953DF673a7A33D,
                sellAmount: 16_693_724_350,
                buyAmount: 9_699_459_097_528_824_221_061,
                owner: 0xbb08A33f8829C7f8F3684f67723326B2EbF5a86c
            })
        );
    }

    // https://explorer.cow.fi/mainnet/orders/0x1abdbe80040b0e51ed87b12c7a18f46dcf72141b5e3ff011eb94fa382f65bbab55bc5e6ad29da823854822749fd2eda2775c78bd6a06f48c
    function test_fork_historicalOrder_directVsDelegated_usdcPermitForMog() public {
        // ~~~~~~~~~~ Setup / Call / Assertions ~~~~~~~~~~
        _runHistoricalOrder(
            HistoricalOrder({
                label: "USDC permit -> MOG",
                orderUid: hex"1abdbe80040b0e51ed87b12c7a18f46dcf72141b5e3ff011eb94fa382f65bbab55bc5e6ad29da823854822749fd2eda2775c78bd6a06f48c",
                txHash: 0xc157c9b4214a1c901ad25c1da17be6094490971bae4475ff55971d309f463702,
                forkBlock: 25_099_786,
                settlementBlock: 25_099_787,
                sellToken: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                buyToken: 0x1Aad217B8F78dbA5E6693460e8470F8b1A3977f3,
                sellAmount: 2_452_152_963,
                buyAmount: 24_674_903_497_290_529_676,
                owner: 0x55BC5E6Ad29DA823854822749FD2Eda2775C78bd
            })
        );
    }

    function _attemptSimpleWethForUsdcOrder(NetworkConfig memory config) internal {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _selectForkAndSetUp(config);
        bytes memory payload = _realGPv2WethForUsdcOrderCalldata(config.usdc, config.weth, solver);
        bytes memory delegatedCalldata = _packedCalldata(config.settlement, payload);
        _assertPayloadSelector(payload, IGPv2Settlement.settle.selector);

        uint256 snapshot = vm.snapshotState();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(solver);
        vm.startSnapshotGas(string.concat(config.name, " - direct call - simple WETH -> USDC order attempt"));
        (bool directSuccess, bytes memory directReturnData) = config.settlement.call(payload);
        vm.stopSnapshotGas();

        vm.revertToState(snapshot);

        vm.prank(approvedCallers.first);
        vm.startSnapshotGas(string.concat(config.name, " - delegated call - simple WETH -> USDC order attempt"));
        (bool delegatedSuccess, bytes memory delegatedReturnData) = solver.call(delegatedCalldata);
        vm.stopSnapshotGas();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(directSuccess, "direct simple order attempt unexpectedly succeeded");
        assertFalse(delegatedSuccess, "delegated simple order attempt unexpectedly succeeded");
        assertEq(delegatedSuccess, directSuccess, "success mismatch");
        assertEq(keccak256(delegatedReturnData), keccak256(directReturnData), "return data mismatch");
        assertFalse(
            keccak256(directReturnData) == keccak256(abi.encodeWithSignature("Error(string)", "GPv2: not a solver")),
            "direct solver was not allowlisted"
        );
        assertFalse(
            keccak256(delegatedReturnData) == keccak256(abi.encodeWithSignature("Error(string)", "GPv2: not a solver")),
            "delegated solver was not allowlisted"
        );
    }

    function _runHistoricalOrder(HistoricalOrder memory order) internal {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        NetworkConfig memory config = _ethereumNetworkConfig();
        config.forkBlock = order.forkBlock;
        _selectForkAndSetUp(config);

        bytes memory payload = _historicalSettlementCalldata(config, order.txHash);
        bytes memory delegatedCalldata = _packedCalldata(config.settlement, payload);
        assertGt(payload.length, 4, "missing historical calldata");
        _assertPayloadSelector(payload, IGPv2Settlement.settle.selector);

        uint256 snapshot = vm.snapshotState();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(solver);
        vm.startSnapshotGas(string.concat("historical order - ", order.label, " - direct call"));
        (bool directSuccess, bytes memory directReturnData) = config.settlement.call(payload);
        vm.stopSnapshotGas();

        vm.revertToState(snapshot);

        vm.prank(approvedCallers.first);
        vm.startSnapshotGas(string.concat("historical order - ", order.label, " - delegated call"));
        (bool delegatedSuccess, bytes memory delegatedReturnData) = solver.call(delegatedCalldata);
        vm.stopSnapshotGas();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(directSuccess, "direct submission failed");
        assertTrue(delegatedSuccess, "delegated submission failed");
        assertEq(delegatedSuccess, directSuccess, "success mismatch");
        assertEq(keccak256(delegatedReturnData), keccak256(directReturnData), "return data mismatch");
        assertEq(directReturnData.length, 0, "direct return data must be empty");
        assertEq(delegatedReturnData.length, 0, "delegated return data must be empty");
        assertEq(order.settlementBlock - 1, order.forkBlock, "fork must be before settlement");
    }

    function _assertPayloadSelector(bytes memory payload, bytes4 expectedSelector) internal pure {
        assertGt(payload.length, 4, "missing calldata selector");
        // casting to bytes4 is safe because the length is checked just above.
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(bytes4(payload), expectedSelector, "calldata selector mismatch");
    }

    function _realGPv2SettleCalldata(address usdc, address weth, address forbiddenTarget)
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

    function _realGPv2WethForUsdcOrderCalldata(address usdc, address weth, address owner)
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

    function _historicalSettlementCalldata(NetworkConfig memory config, bytes32 txHash)
        internal
        returns (bytes memory payload)
    {
        (, address target, bytes memory transactionPayload) = _historicalTargetAndCalldata(txHash);
        if (target == config.settlement && _hasSelector(transactionPayload, IGPv2Settlement.settle.selector)) {
            return transactionPayload;
        }

        payload = _extractNestedCall(transactionPayload, IGPv2Settlement.settle.selector);
        assertGt(payload.length, 4, "missing nested settlement calldata");
    }

    function _hasSelector(bytes memory payload, bytes4 selector) internal pure returns (bool) {
        if (payload.length < 4) {
            return false;
        }
        return payload[0] == selector[0] && payload[1] == selector[1] && payload[2] == selector[2]
            && payload[3] == selector[3];
    }

    function _extractNestedCall(bytes memory payload, bytes4 selector) internal pure returns (bytes memory nestedCall) {
        uint256 selectorOffset = _findSelector(payload, selector);
        if (selectorOffset == type(uint256).max) {
            return nestedCall;
        }

        uint256 nestedLength = payload.length - selectorOffset;
        if (selectorOffset >= 32) {
            uint256 encodedLength = _readUint(payload, selectorOffset - 32);
            if (encodedLength >= 4 && selectorOffset + encodedLength <= payload.length) {
                nestedLength = encodedLength;
            }
        }

        nestedCall = new bytes(nestedLength);
        for (uint256 i; i < nestedLength; ++i) {
            nestedCall[i] = payload[selectorOffset + i];
        }
    }

    function _findSelector(bytes memory payload, bytes4 selector) internal pure returns (uint256 offset) {
        if (payload.length < 4) {
            return type(uint256).max;
        }
        for (uint256 i; i <= payload.length - 4; ++i) {
            if (
                payload[i] == selector[0] && payload[i + 1] == selector[1] && payload[i + 2] == selector[2]
                    && payload[i + 3] == selector[3]
            ) {
                return i;
            }
        }
        return type(uint256).max;
    }

    function _selectForkAndSetUp(NetworkConfig memory config) internal {
        string memory rpcUrl = vm.envOr(config.rpcEnv, string(""));
        if (bytes(rpcUrl).length == 0 && keccak256(bytes(config.rpcEnv)) == keccak256(bytes("ETH_MAINNET_RPC_URL"))) {
            rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        }
        vm.skip(bytes(rpcUrl).length == 0, string.concat("missing ", config.rpcEnv));
        if (config.forkBlock == 0) {
            vm.createSelectFork(rpcUrl);
        } else {
            vm.createSelectFork(rpcUrl, config.forkBlock);
        }

        super.setUp();
        assertEq(address(IGPv2Settlement(config.settlement).authenticator()), config.authenticator);

        IGPv2Authenticator authenticator = IGPv2Authenticator(config.authenticator);
        vm.prank(authenticator.manager());
        authenticator.addSolver(solver);
        assertTrue(authenticator.isSolver(solver));

        _attachDelegation(SOLVER_PRIVATE_KEY);
    }

    function _historicalTargetAndCalldata(bytes32 txHash)
        internal
        returns (address from, address to, bytes memory input)
    {
        bytes memory data = vm.rpc("eth_getTransactionByHash", string.concat("[\"", vm.toString(txHash), "\"]"));
        uint256 tupleStart = _readUint(data, 0);
        uint256 fromOffset = 0x80;
        uint256 toOffset = 0x1c0;
        uint256 inputOffsetOffset = 0x100;

        from = _readAddress(data, tupleStart + fromOffset);
        if (from == address(0)) {
            fromOffset = 0xa0;
            toOffset = 0x1e0;
            inputOffsetOffset = 0x120;
            from = _readAddress(data, tupleStart + fromOffset);
        }

        to = _readAddress(data, tupleStart + toOffset);
        uint256 inputOffset = _readUint(data, tupleStart + inputOffsetOffset);
        uint256 inputStart = tupleStart + inputOffset;
        input = _readBytes(data, inputStart);
    }

    function _readAddress(bytes memory data, uint256 offset) internal pure returns (address value) {
        value = address(uint160(_readUint(data, offset)));
    }

    function _readUint(bytes memory data, uint256 offset) internal pure returns (uint256 value) {
        for (uint256 i; i < 32; ++i) {
            value = (value << 8) | uint8(data[offset + i]);
        }
    }

    function _readBytes(bytes memory data, uint256 offset) internal pure returns (bytes memory value) {
        uint256 length = _readUint(data, offset);
        value = new bytes(length);
        for (uint256 i; i < length; ++i) {
            value[i] = data[offset + 32 + i];
        }
    }

    function _ethereumNetworkConfig() internal pure returns (NetworkConfig memory config) {
        config = NetworkConfig({
            name: "ethereum",
            rpcEnv: "ETH_MAINNET_RPC_URL",
            forkBlock: 25_099_000,
            settlement: GPV2_SETTLEMENT,
            authenticator: GPV2_AUTHENTICATOR,
            usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        });
    }
}
