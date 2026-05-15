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

### Format

```shell
just fmt
```

### Local tooling

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

Foundry commands can be run through `just`, so they use the pinned local executables:

```shell
just forge --version
just anvil --version
just cast --version
just chisel --version
```

Compare the printed versions with `dev/package.json` and `dev/pnpm-lock.yaml`.
For example, if `@foundry-rs/forge` resolves to `1.7.0`, `just forge --version` should print a version ending in `v1.7.0`.

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

The deploy script reads the five approved caller addresses from environment variables:

```shell
export APPROVED_CALLER_0=<approved_caller_0>
export APPROVED_CALLER_1=<approved_caller_1>
export APPROVED_CALLER_2=<approved_caller_2>
export APPROVED_CALLER_3=<approved_caller_3>
export APPROVED_CALLER_4=<approved_caller_4>

just forge script script/DeploySolver7702Delegate.s.sol:DeploySolver7702Delegate \
  --rpc-url <your_rpc_url> \
  --private-key <your_private_key> \
  --broadcast
```

This deploys without `CREATE2`.

To deploy with `CREATE2`, set `SALT`. Exact `0x`-prefixed 32-byte hex values are used directly as the `CREATE2` salt. Any other value is treated as a string and hashed as `keccak256(bytes(SALT))`:

```shell
export SALT=<salt>

just forge script script/DeploySolver7702Delegate.s.sol:DeploySolver7702Delegate \
  --rpc-url <your_rpc_url> \
  --private-key <your_private_key> \
  --broadcast
```

When `SALT` is set, Foundry uses the canonical `CREATE2` deployer `0x4e59b44847b379578588920cA78FbF26c0B4956C`, unless a different address is passed with `--create2-deployer`.
The `CREATE2` address is deterministic. To get the same address across networks, use the same `CREATE2` deployer address, salt, bytecode, and approved caller addresses.

To compute the `CREATE2` address before deployment with the approved caller addresses from the same environment variables:

```shell
just forge script script/DeploySolver7702Delegate.s.sol:DeploySolver7702Delegate --sig predictAddress
```

Set `CREATE2_DEPLOYER` to the address passed with `--create2-deployer` if you override Foundry's default:

```shell
export CREATE2_DEPLOYER=<create2_deployer>
```
