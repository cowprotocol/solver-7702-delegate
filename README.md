# Solver7702Delegate

`Solver7702Delegate` is a minimal ERC-7702 delegation target for CoW Protocol solvers. It lets a solver keep using its existing solver EOA while allowing a fixed set of auxiliary EOAs to submit transactions through that solver EOA. The main benefit is parallel settlement submission: auxiliary EOAs provide independent nonce lanes, while downstream contracts still see the solver EOA as `msg.sender`, which keeps the authorization clean.

Read more about the initiative [here](https://www.notion.so/cownation/Solver7702Delegate-Design-Doc-3588da5f04ca80a1b521c436abf17724).

## Usage

### Just commands

Install `just` on your machine, then run `just help` to see the available commands.

### Build

```shell
just build
```

Project contracts should keep simple caret pragmas like `^0.8` so downstream projects can import them with older compatible Solidity 0.8 compilers.

If specific features are needed (like PUSH0 in 0.8.20 for gas optimizations or transient storage/better `via-ir` in 0.8.34), you can use it but make sure to keep the caret (`^`).

### Test

```shell
just test
```

#### Replaying Your Own Historical Transactions

The fork test `test_fork_historicalTransaction_directVsDelegated_userSuppliedTxHashes` lets you replay your own batch transactions through the delegate.

Set:

- `ETH_MAINNET_RPC_URL` to the RPC URL you want Foundry to fork from.
- `COW_HISTORICAL_TX_HASHES` to a comma-separated list of transaction hashes.

Despite the env var name, `ETH_MAINNET_RPC_URL` can point at another network RPC URL. The supplied transaction hashes just need to exist on that network, and the RPC must support the historical state needed by `vm.rollFork(txHash)`.

Example:

```shell
ETH_MAINNET_RPC_URL=<your_rpc_url> \
COW_HISTORICAL_TX_HASHES=0xabc...,0xdef... \
just test --match-test test_fork_historicalTransaction_directVsDelegated_userSuppliedTxHashes
```

### Format

```shell
just fmt
```

### Local tooling

Foundry should be installed locally and pinned to `v1.7.1`.
CI uses the same Foundry version.

Install Foundry with:

```shell
foundryup --install v1.7.1
```

Check that the expected version is active with:

```shell
forge --version
```

The output should end in `v1.7.1`.

Solhint and Slither are pinned as local development dependencies under `dev/`.

The pnpm and uv setups wait 7 days before installing newly released packages, matching CoW repos and giving more review time than a 2-day delay.

Install them with:

```shell
pnpm --dir dev install --frozen-lockfile
uv sync --project dev --locked
```

Run the pinned local tools through `just`. `just lint` checks Forge formatting and Solhint, and `just slither` checks contracts under `src`.

```shell
just lint
just slither
```

### Pre-commit hooks

Install the hooks with:

```shell
just register-hooks
```

The pre-push hooks run `just lint`, `just slither`, and `just coverage-check`.
You can bypass hooks with `--no-verify`, but CI remains the source of truth.

The root config applies to all Solidity files.
The `script/` and `test/` folders have a small override config for their own style.

### Gas Snapshots

```shell
just snapshot
```

### Deploy

The deploy script reads up to five approved caller addresses from `APPROVED_CALLERS`.
If fewer than five addresses are needed, omit the rest.

```shell
export APPROVED_CALLERS=<approved_caller_0>,<approved_caller_1>

just forge script script/DeploySolver7702Delegate.s.sol:DeploySolver7702Delegate \
  --rpc-url <your_rpc_url> \
  --private-key <your_private_key> \
  --broadcast
```

Deployments use `CREATE2` with a zero salt by default. To use a different salt, pass a `bytes32` value:

```shell
export SALT=<bytes32_salt>

just forge script script/DeploySolver7702Delegate.s.sol:DeploySolver7702Delegate \
  --rpc-url <your_rpc_url> \
  --private-key <your_private_key> \
  --broadcast
```

To simulate the deployment and inspect the computed address, run the same command without `--broadcast`:

```shell
just forge script script/DeploySolver7702Delegate.s.sol:DeploySolver7702Delegate \
  --rpc-url <your_rpc_url> \
  --private-key <your_private_key>
```

## New project creation checklist

The following operations need to be performed after this repository has been created.

- [ ] Discuss and confirm the project license with the team lead before starting implementation work. You must set this up before writing project code.
  - [ ] The license is very likely going to be one of the following:
    - [ ] `MIT OR Apache-2.0` for projects with low strategic relevance (included by default in the template).
    - [ ] `LGPL-3.0-or-later` for projects with high strategic relevance.
    - [ ] In some cases, a different license may be needed.
  - [ ] If it's `MIT OR Apache-2.0`, the license is already included. Otherwise, remove the existing license files and add the selected license as a file in the repository root.
  - [ ] Update `dev/package.json` with the selected license.
  - [ ] Update each Solidity smart contract's `SPDX-License-Identifier` with the selected license.
- [ ] In GitHub repo settings:
  - [ ] Add a new ruleset called "Protected branches" and include the following changes:
    - Enforcement status: active
    - Target branches: Include default branch
    - Require linear history
    - Require a pull request before merging
      - Required approvals: 1
      - Allowed merge methods: Squash
    - Block force pushes
  - [ ] In General → Features → Pull requests:
    - Select "Pull request title and description" in "Default commit message" option
    - Unckeck "Allow merge commits" option
    - Check "Allow auto-merge" option
- [ ] Run `forge install` to install the dependencies. This will create a new `foundry.lock` file which you should commit to the project
- [ ] Set up [Local tooling](#local-tooling) so Solhint and Slither use the pinned project versions
- [ ] Update the project details in `dev/package.json`, including `name` and `description`
- [ ] Make sure you use the [latest version of Solidity](https://github.com/argotorg/solidity/releases) by updating the `solc` version in `foundry.toml`
- [ ] Once all entries in this list are checked, delete this section from the readme