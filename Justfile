set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set quiet # Doesn't print the command that is being run

COVERAGE_MIN := env_var_or_default("COVERAGE_MIN", "100")
SOLHINT := "dev/node_modules/.bin/solhint" # Binary path for local Solhint installation
JUST := just_executable()

# Runs `just help`
default: help

# Register pre-push hooks
register-hooks:
    uv run --project dev pre-commit install --hook-type pre-push

# Show available recipes
help:
    {{JUST}} --list

# Compile contracts
build:
    forge build

# Compile all contracts
build-all:
    forge build --force

# Format Solidity sources
fmt:
    forge fmt

# Check formatting and run `solhint` on `src`/`script`/`test`
lint:
    forge fmt --check
    {{SOLHINT}} --max-warnings 0 '**/*.sol'

# Run Slither static analysis on `src`
slither:
    uv run --project dev slither src --config-file slither.config.json

# Run tests
test:
    FOUNDRY_PROFILE=test forge test -vvv --show-progress

# Print coverage summary
coverage-summary:
    FOUNDRY_PROFILE=test forge coverage --no-match-coverage "^(test|script)/" --report summary

# Generate lcov coverage report
coverage-lcov:
    FOUNDRY_PROFILE=test forge coverage --no-match-coverage "^(test|script)/" --report lcov

# Fail if the minimum of all four coverage metrics (lines/statements/branches/funcs) on the `Total` row is below `COVERAGE_MIN` (default `100`)
coverage-check:
    # Fields on the `| Total | ... |` row are: $4=lines, $7=statements, $10=branches, $13=funcs (whitespace-split, `%` stripped)
    @tmp_dir="$(mktemp -d)"; \
    snapshot_patch="$tmp_dir/snapshots.patch"; \
    git diff --binary -- snapshots > "$snapshot_patch"; \
    cleanup() { git restore --worktree snapshots; if [ -s "$snapshot_patch" ]; then git apply "$snapshot_patch"; fi; rm -rf "$tmp_dir"; rm -f coverage.txt; }; \
    trap cleanup EXIT; \
    if ! {{JUST}} coverage-summary > coverage.txt 2>&1; then \
        cat coverage.txt; \
        exit 1; \
    fi; \
    cat coverage.txt; \
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

# Generate gas snapshots
snapshot:
    FOUNDRY_PROFILE=test forge snapshot --desc --show-progress

# Run build, lint, slither, coverage-check, snapshot
all: build lint slither coverage-check snapshot
