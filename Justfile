set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set quiet # Doesn't print the command that is being run

COVERAGE_MIN := env_var_or_default("COVERAGE_MIN", "100")
SOLHINT := "dev/node_modules/.bin/solhint" # Binary path for local Solhint installation
FORGE := "dev/node_modules/.bin/forge" # Binary path for local Forge installation
ANVIL := "dev/node_modules/.bin/anvil" # Binary path for local Anvil installation
CAST := "dev/node_modules/.bin/cast" # Binary path for local Cast installation
CHISEL := "dev/node_modules/.bin/chisel" # Binary path for local Chisel installation
NPM_BIN := "dev/node_modules/.bin" # Directory containing the local NPM binaries
JUST := just_executable()

# Runs `just help`
default: help

# Register pre-push hooks
register-hooks:
    uv run --project dev pre-commit install --hook-type pre-push

# Show available recipes
help:
    {{JUST}} --list

# Run the local Forge binary
forge *args:
    {{FORGE}} {{args}}

# Run the local Anvil binary
anvil *args:
    {{ANVIL}} {{args}}

# Run the local Cast binary
cast *args:
    {{CAST}} {{args}}

# Run the local Chisel binary
chisel *args:
    {{CHISEL}} {{args}}

# Compile contracts
build:
    {{FORGE}} build

# Compile all contracts
build-all:
    {{FORGE}} build --force

# Format Solidity sources
fmt:
    {{FORGE}} fmt

# Check formatting and run `solhint` on `src`/`script`/`test`
lint:
    {{FORGE}} fmt --check
    {{SOLHINT}} --max-warnings 0 '**/*.sol'

# Run Slither static analysis on `src`
slither:
    PATH="$PWD/{{NPM_BIN}}:$PATH" uv run --project dev slither src --config-file slither.config.json

# Run tests
test:
    {{FORGE}} test -vvv --show-progress --gas-snapshot-check true

# Print coverage summary
coverage-summary:
    {{FORGE}} coverage --no-match-coverage "^(test|script)/" --report summary

# Generate lcov coverage report
coverage-lcov:
    {{FORGE}} coverage --no-match-coverage "^(test|script)/" --report lcov

# Fail if the minimum of all four coverage metrics (lines/statements/branches/funcs) on the `Total` row is below `COVERAGE_MIN` (default `100`)
coverage-check:
    @{{JUST}} coverage-summary > coverage.txt
    cat coverage.txt
    # Fields on the `| Total | ... |` row are: $4=lines, $7=statements, $10=branches, $13=funcs (whitespace-split, `%` stripped)
    awk -v threshold={{COVERAGE_MIN}} '\
        BEGIN { labels[4]="lines"; labels[7]="statements"; labels[10]="branches"; labels[13]="funcs"; min=100; below="" } \
        /^\| Total/ { \
            found=1; \
            for (i=4; i<=13; i+=3) { \
                gsub(/%/, "", $i); \
                v=$i+0; \
                if (v < min) min=v; \
                if (v < threshold) below = below sprintf("  %-12s %s%%\n", labels[i] ":", $i); \
            } \
        } \
        END { \
            if (!found) { print "Failed to extract coverage percentage."; exit 1 } \
            if (min < threshold) { printf "\nMetrics below minimum threshold of %s%%:\n%s\n", threshold, below; exit 1 } \
        }' coverage.txt
    rm coverage.txt

# Generate gas snapshots
snapshot:
    {{FORGE}} snapshot --desc --show-progress

# Run build, lint, slither, coverage-check, snapshot
all: build lint slither coverage-check snapshot
