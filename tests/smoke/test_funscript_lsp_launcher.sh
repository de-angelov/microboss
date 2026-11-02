#!/usr/bin/env bash
# Smoke test for scripts/funscript-lsp.sh: executable resolution and stdio.
#
# Uses temporary projects and fake `funscript` executables, so no real FunScript
# install is required and no machine-specific path is assumed.

set -uo pipefail

REPO_ROOT=$(CDPATH= cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
LAUNCHER="$REPO_ROOT/scripts/funscript-lsp.sh"

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

TMP=$(mktemp -d "${TMPDIR:-/tmp}/microboss-funscript-lsp.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

TEST_HOME="$TMP/home"
FAKEBIN="$TMP/pathbin"
PROJECT="$TMP/project"
EMPTYBIN="$TMP/emptybin"
LOG="$TMP/funscript.log"
OUT="$TMP/stdout"
ERR="$TMP/stderr"
STATUS=0

mkdir -p "$TEST_HOME" "$FAKEBIN" "$PROJECT" "$EMPTYBIN"
FAKEBIN=$(CDPATH= cd -P "$FAKEBIN" && pwd)
PROJECT=$(CDPATH= cd -P "$PROJECT" && pwd)
EMPTYBIN=$(CDPATH= cd -P "$EMPTYBIN" && pwd)

# Fake server: record argv and stdin in the log, then emit a marker on each
# protocol stream. It never writes diagnostics to stdout or stderr.
make_fake() {
    mkdir -p "$(dirname "$1")"
    cat > "$1" <<'FAKE'
#!/bin/sh
{
    printf 'argv0=%s\n' "$0"
    printf 'argc=%s\n' "$#"
    i=0
    for arg in "$@"; do
        i=$((i + 1))
        printf 'arg%s=%s\n' "$i" "$arg"
    done
    if IFS= read -r line; then
        printf 'stdin=%s\n' "$line"
    else
        printf 'stdin=EOF\n'
    fi
} > "${MICROBOSS_TEST_LOG:?MICROBOSS_TEST_LOG is not set}"
printf 'fake-lsp-ready\n'
printf 'fake-lsp-stderr\n' >&2
FAKE
    chmod +x "$1"
}

make_fake "$FAKEBIN/funscript"
make_fake "$PROJECT/node_modules/.bin/funscript"

log_value() {
    sed -n "s/^$1=//p" "$LOG" | head -n 1
}

check_arg() {
    check_eq "$1" "$(log_value "arg$2")" "$3"
}

# run_launcher <working-directory> <search-path> [args...]
# Feeds one protocol line on stdin and captures stdout and stderr separately.
run_launcher() {
    local dir=$1
    local search_path=$2
    shift 2

    : > "$LOG"
    : > "$OUT"
    : > "$ERR"
    printf 'initialize\n' | (
        cd "$dir" || exit 1
        env HOME="$TEST_HOME" PATH="$search_path" MICROBOSS_TEST_LOG="$LOG" \
            "$LAUNCHER" "$@" > "$OUT" 2> "$ERR"
    )
    STATUS=$?
}

# --- Syntax and executable bit ------------------------------------------------

if bash -n "$LAUNCHER"; then
    ok "bash -n accepts scripts/funscript-lsp.sh"
else
    not_ok "bash -n accepts scripts/funscript-lsp.sh"
fi

check_true "scripts/funscript-lsp.sh is executable" '[ -x "$LAUNCHER" ]'

# --- Project-local executable wins over PATH ----------------------------------

run_launcher "$PROJECT" "$FAKEBIN"
check_eq "project-local run exits 0" "$STATUS" "0"
check_eq "project-local executable is selected" "$(log_value argv0)" \
    "$PROJECT/node_modules/.bin/funscript"
check_eq "project-local run forwards lsp" "$(log_value arg1)" "lsp"
check_eq "project-local run forwards --stdio" "$(log_value arg2)" "--stdio"
check_eq "project-local run forwards exactly two arguments" \
    "$(log_value argc)" "2"
check_eq "project-local run forwards stdin" "$(log_value stdin)" "initialize"
check_eq "project-local run preserves stdout for protocol traffic" \
    "$(cat "$OUT")" "fake-lsp-ready"
check_eq "project-local run preserves stderr" "$(cat "$ERR")" "fake-lsp-stderr"

# --- PATH fallback ------------------------------------------------------------

rm -rf "$PROJECT/node_modules"
run_launcher "$PROJECT" "$FAKEBIN"
check_eq "PATH-installed run exits 0" "$STATUS" "0"
check_eq "PATH-installed executable is selected" "$(log_value argv0)" \
    "$FAKEBIN/funscript"
check_eq "PATH-installed run forwards lsp" "$(log_value arg1)" "lsp"
check_eq "PATH-installed run forwards --stdio" "$(log_value arg2)" "--stdio"
check_eq "PATH-installed run forwards stdin" "$(log_value stdin)" "initialize"
check_eq "PATH-installed run preserves stdout" "$(cat "$OUT")" \
    "fake-lsp-ready"

# A non-executable project-local entry falls back to PATH instead of failing.
mkdir -p "$PROJECT/node_modules/.bin"
cp "$FAKEBIN/funscript" "$PROJECT/node_modules/.bin/funscript"
chmod -x "$PROJECT/node_modules/.bin/funscript"
run_launcher "$PROJECT" "$FAKEBIN"
check_eq "non-executable project-local entry: run exits 0" "$STATUS" "0"
check_eq "non-executable project-local entry falls back to PATH" \
    "$(log_value argv0)" "$FAKEBIN/funscript"
rm -rf "$PROJECT/node_modules"

# --- Missing executable -------------------------------------------------------

: > "$LOG"
: > "$OUT"
: > "$ERR"
(
    cd "$PROJECT" || exit 1
    env HOME="$TEST_HOME" PATH="$EMPTYBIN" MICROBOSS_TEST_LOG="$LOG" \
        "$LAUNCHER" > "$OUT" 2> "$ERR"
)
STATUS=$?
check_true "missing FunScript fails with a non-zero status" \
    '[ "$STATUS" -ne 0 ]'
check_true "missing FunScript error names the executable and both locations" \
    'grep -q "node_modules/.bin/funscript" "$ERR" && grep -q "PATH" "$ERR"'
check_true "missing FunScript error includes the installation prerequisites" \
    'grep -q "npm install --save-dev funscript" "$ERR" &&
        grep -q "github.com/de-angelov/funscript" "$ERR"'
check_true "missing FunScript writes nothing to stdout" '[ ! -s "$OUT" ]'
check_true "missing FunScript does not start a server" '[ ! -s "$LOG" ]'

# --- Summary ------------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
