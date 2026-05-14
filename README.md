# Contract Template

Template for creating new smart contract projects.

This project is meant to be used as a templated during the creation of new Github repositories (will show in the `Create a new repository > Configuration > Start with a template` selector).

It will contain some useful configuration files and scripts, that can be used also with existing projects (manually copied).

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

```shell
just forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
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
- [ ] Run `just forge install` to install the dependencies. This will create a new `foundry.lock` file which you should commit to the project
- [ ] Set up [Local tooling](#local-tooling) so Solhint and Slither use the pinned project versions
- [ ] Update the project details in `dev/package.json`, including `name` and `description`
- [ ] Make sure you use the [latest version of Solidity](https://github.com/argotorg/solidity/releases) by updating the `solc` version in `foundry.toml`
- [ ] Once all entries in this list are checked, delete this section from the readme
