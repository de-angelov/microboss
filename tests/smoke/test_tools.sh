#!/usr/bin/env bash
# Smoke test for the pinned language-server toolchain.
#
# Verifies that tools/package.json and tools/package-lock.json pin the exact
# server and TypeScript versions, then reproduces the install with `npm ci`
# using temporary cache and log directories under tests/tmp so the test never
# writes to ~/.npm or the user's other files.

set -uo pipefail

REPO_ROOT=$(CDPATH= cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TOOLS="$REPO_ROOT/tools"
MANIFEST="$TOOLS/package.json"
LOCKFILE="$TOOLS/package-lock.json"

PASS=0
FAIL=0

ok() {
    PASS=$((PASS + 1))
    printf 'ok %d - %s\n' "$((PASS + FAIL))" "$1"
}

not_ok() {
    FAIL=$((FAIL + 1))
    printf 'not ok %d - %s\n' "$((PASS + FAIL))" "$1"
    if [ $# -gt 1 ]; then
        printf '# %s\n' "$2"
    fi
}

check_eq() {
    if [ "$2" = "$3" ]; then
        ok "$1"
    else
        not_ok "$1" "expected [$3], got [$2]"
    fi
}

check_true() {
    if eval "$2"; then
        ok "$1"
    else
        not_ok "$1" "failed: $2"
    fi
}

for tool in npm jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'missing required test tool: %s\n' "$tool" >&2
        exit 1
    fi
done

# --- Manifest pins ------------------------------------------------------------

check_true "tools/package.json exists" '[ -s "$MANIFEST" ]'
check_true "tools/package.json is valid JSON" 'jq empty "$MANIFEST" >/dev/null 2>&1'
check_true "tools/package-lock.json exists" '[ -s "$LOCKFILE" ]'
check_true "tools/package-lock.json is valid JSON" 'jq empty "$LOCKFILE" >/dev/null 2>&1'

PINS=(
    "typescript 5.9.3"
    "typescript-language-server 5.3.0"
    "vscode-langservers-extracted 4.10.0"
    "@angular/language-server 21.2.25"
)

for pin in "${PINS[@]}"; do
    package=${pin% *}
    version=${pin#* }
    check_eq "package.json pins $package@$version" \
        "$(jq -r --arg p "$package" '.dependencies[$p] // ""' "$MANIFEST")" \
        "$version"
    check_eq "package.json root pins $package@$version" \
        "$(jq -r --arg p "$package" '.packages[""].dependencies[$p] // ""' "$LOCKFILE")" \
        "$version"
    check_eq "package-lock.json locks $package@$version" \
        "$(jq -r --arg p "node_modules/$package" '.packages[$p].version // ""' "$LOCKFILE")" \
        "$version"
done

# --- Reproducible install -----------------------------------------------------

mkdir -p "$REPO_ROOT/tests/tmp"
TMP=$(mktemp -d "$REPO_ROOT/tests/tmp/tools.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
STATUS=0

npm_config_cache="$TMP/cache" \
npm_config_logs_dir="$TMP/logs" \
npm_config_update_notifier=false \
npm_config_fund=false \
npm_config_audit=false \
    npm ci --prefix "$TOOLS" --ignore-scripts --no-audit --no-fund \
    >"$TMP/npm-ci.log" 2>&1
STATUS=$?

if [ "$STATUS" -eq 0 ]; then
    ok "npm ci --prefix tools --ignore-scripts succeeds"
else
    not_ok "npm ci --prefix tools --ignore-scripts succeeds" \
        "$(tail -n 5 "$TMP/npm-ci.log" 2>/dev/null)"
fi

check_true "installed TypeScript provides lib/tsserver.js" \
    '[ -f "$TOOLS/node_modules/typescript/lib/tsserver.js" ]'

for pin in "${PINS[@]}"; do
    package=${pin% *}
    version=${pin#* }
    check_eq "npm ls reports $package@$version" \
        "$(npm ls --prefix "$TOOLS" --depth=0 --json 2>/dev/null |
            jq -r --arg p "$package" '.dependencies[$p].version // ""')" \
        "$version"
done

check_true "the install leaves no cache or logs beside the manifest" \
    '[ ! -e "$TOOLS/cache" ] && [ ! -e "$TOOLS/logs" ]'

# --- Summary -----------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
