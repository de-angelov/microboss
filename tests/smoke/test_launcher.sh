#!/usr/bin/env bash
# Smoke test for bin/microboss: config isolation and argument passthrough.
#
# Runs the launcher with a temporary HOME and a fake `micro` on PATH, so the
# real Micro binary and the user's real configuration are never touched.

set -uo pipefail

REPO_ROOT=$(CDPATH= cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
LAUNCHER="$REPO_ROOT/bin/microboss"

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

TMP=$(mktemp -d "${TMPDIR:-/tmp}/microboss-launcher.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

TEST_HOME="$TMP/home"
FAKEBIN="$TMP/fakebin"
LOG="$TMP/micro.log"
OUT="$TMP/stdout"
ERR="$TMP/stderr"
STATUS=0

mkdir -p "$TEST_HOME" "$FAKEBIN"

# Fake micro: record argv and the microboss environment, then exit 0.
cat > "$FAKEBIN/micro" <<'FAKE'
#!/bin/sh
{
    printf 'argc=%s\n' "$#"
    i=0
    for arg in "$@"; do
        i=$((i + 1))
        printf 'arg%s=%s\n' "$i" "$arg"
    done
    printf 'env_config=%s\n' "${MICROBOSS_CONFIG-}"
    printf 'env_data=%s\n' "${MICROBOSS_DATA-}"
    printf 'env_cache=%s\n' "${MICROBOSS_CACHE-}"
    printf 'env_root=%s\n' "${MICROBOSS_ROOT-}"
} > "${MICROBOSS_TEST_LOG:?MICROBOSS_TEST_LOG is not set}"
FAKE
chmod +x "$FAKEBIN/micro"

# run_launcher <launcher-path> [args...]
# Uses a clean microboss environment; tests add overrides with run_launcher_env.
run_launcher() {
    local launcher=$1
    shift
    : > "$LOG"
    : > "$OUT"
    : > "$ERR"
    env -u MICROBOSS_CONFIG -u MICROBOSS_DATA -u MICROBOSS_CACHE \
        -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME \
        HOME="$TEST_HOME" PATH="$FAKEBIN:/usr/bin:/bin" \
        MICROBOSS_TEST_LOG="$LOG" \
        "$launcher" "$@" > "$OUT" 2> "$ERR"
    STATUS=$?
}

# run_launcher_env <launcher-path> <VAR=value>... -- [args...]
run_launcher_env() {
    local launcher=$1
    shift
    local overrides=()
    while [ $# -gt 0 ] && [ "$1" != "--" ]; do
        overrides+=("$1")
        shift
    done
    [ $# -gt 0 ] && shift

    : > "$LOG"
    : > "$OUT"
    : > "$ERR"
    env -u MICROBOSS_CONFIG -u MICROBOSS_DATA -u MICROBOSS_CACHE \
        -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME \
        HOME="$TEST_HOME" PATH="$FAKEBIN:/usr/bin:/bin" \
        MICROBOSS_TEST_LOG="$LOG" "${overrides[@]}" \
        "$launcher" "$@" > "$OUT" 2> "$ERR"
    STATUS=$?
}

log_value() {
    sed -n "s/^$1=//p" "$LOG" | head -n 1
}

check_arg() {
    check_eq "$1" "$(log_value "arg$2")" "$3"
}

# --- Syntax and executable bit ------------------------------------------------

if bash -n "$LAUNCHER"; then
    ok "bash -n accepts bin/microboss"
else
    not_ok "bash -n accepts bin/microboss"
fi

check_true "bin/microboss is executable" '[ -x "$LAUNCHER" ]'

# --- Default run: isolated config, args passed through -----------------------

mkdir -p "$TMP/work"
(
    cd "$TMP/work" || exit 1
    run_launcher "$LAUNCHER" "file.txt" "+3:4" "--"
    exit $STATUS
)
check_eq "launcher exits 0" "$STATUS" "0"
check_eq "micro receives -config-dir first" "$(log_value arg1)" "-config-dir"
check_eq "micro receives the default isolated config dir" \
    "$(log_value arg2)" "$TEST_HOME/.config/microboss"
check_eq "micro receives the file argument" "$(log_value arg3)" "file.txt"
check_eq "micro receives +LINE:COL unchanged" "$(log_value arg4)" "+3:4"
check_eq "micro receives -- unchanged" "$(log_value arg5)" "--"
check_eq "argument count is 5" "$(log_value argc)" "5"
check_eq "MICROBOSS_CONFIG is exported" "$(log_value env_config)" \
    "$TEST_HOME/.config/microboss"
check_eq "MICROBOSS_DATA defaults under HOME" "$(log_value env_data)" \
    "$TEST_HOME/.local/share/microboss"
check_eq "MICROBOSS_CACHE defaults under HOME" "$(log_value env_cache)" \
    "$TEST_HOME/.cache/microboss"
check_eq "MICROBOSS_ROOT points at the distribution root" \
    "$(log_value env_root)" "$REPO_ROOT"

check_true "default run does not create ~/.config/micro" \
    '[ ! -e "$TEST_HOME/.config/micro" ]'

# --- Environment overrides ----------------------------------------------------

mkdir -p "$TMP/alt-config" "$TMP/alt-data" "$TMP/alt-cache"
run_launcher_env "$LAUNCHER" \
    "MICROBOSS_CONFIG=$TMP/alt-config" \
    "MICROBOSS_DATA=$TMP/alt-data" \
    "MICROBOSS_CACHE=$TMP/alt-cache" \
    -- "notes.md"
check_eq "overrides: launcher exits 0" "$STATUS" "0"
check_eq "MICROBOSS_CONFIG override reaches micro" "$(log_value arg2)" \
    "$TMP/alt-config"
check_eq "MICROBOSS_DATA override is exported" "$(log_value env_data)" \
    "$TMP/alt-data"
check_eq "MICROBOSS_CACHE override is exported" "$(log_value env_cache)" \
    "$TMP/alt-cache"
check_eq "overrides: user arguments still pass through" "$(log_value arg3)" \
    "notes.md"

# --- XDG base directories -----------------------------------------------------

mkdir -p "$TMP/xdg/config" "$TMP/xdg/data" "$TMP/xdg/cache"
run_launcher_env "$LAUNCHER" \
    "XDG_CONFIG_HOME=$TMP/xdg/config" \
    "XDG_DATA_HOME=$TMP/xdg/data" \
    "XDG_CACHE_HOME=$TMP/xdg/cache" \
    -- "xdg.txt"
check_eq "XDG_CONFIG_HOME is honoured" "$(log_value arg2)" \
    "$TMP/xdg/config/microboss"
check_eq "XDG_DATA_HOME is honoured" "$(log_value env_data)" \
    "$TMP/xdg/data/microboss"
check_eq "XDG_CACHE_HOME is honoured" "$(log_value env_cache)" \
    "$TMP/xdg/cache/microboss"

# --- POSIX sh invocation ------------------------------------------------------

: > "$LOG"
: > "$OUT"
: > "$ERR"
env -u MICROBOSS_CONFIG -u MICROBOSS_DATA -u MICROBOSS_CACHE \
    -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME \
    HOME="$TEST_HOME" PATH="$FAKEBIN:/usr/bin:/bin" MICROBOSS_TEST_LOG="$LOG" \
    sh "$LAUNCHER" "posix.txt" > "$OUT" 2> "$ERR"
STATUS=$?
check_eq "launcher runs under POSIX sh" "$STATUS" "0"
check_eq "sh run keeps the isolated config dir" "$(log_value arg2)" \
    "$TEST_HOME/.config/microboss"

# --- Existing ~/.config/micro is left untouched ------------------------------

mkdir -p "$TEST_HOME/.config/micro"
printf 'user-owned\n' > "$TEST_HOME/.config/micro/settings.json"
printf 'buffer\n' > "$TEST_HOME/.config/micro/buffers"
MICRO_BEFORE=$(cd "$TEST_HOME/.config/micro" && ls -A | sort && cat settings.json buffers)

run_launcher "$LAUNCHER" "again.txt"
check_eq "run with existing ~/.config/micro exits 0" "$STATUS" "0"
MICRO_AFTER=$(cd "$TEST_HOME/.config/micro" && ls -A | sort && cat settings.json buffers)
check_eq "existing ~/.config/micro is not modified" "$MICRO_AFTER" "$MICRO_BEFORE"

# --- Symlinked launcher -------------------------------------------------------

mkdir -p "$TMP/pathbin"
ln -s "$LAUNCHER" "$TMP/pathbin/microboss"
(
    cd "$TMP/work" || exit 1
    run_launcher "$TMP/pathbin/microboss" "linked.txt"
    exit $STATUS
)
check_eq "symlinked launcher exits 0" "$STATUS" "0"
check_eq "symlinked launcher keeps the isolated config dir" \
    "$(log_value arg2)" "$TEST_HOME/.config/microboss"
check_eq "symlinked launcher passes arguments through" "$(log_value arg3)" \
    "linked.txt"
check_eq "symlinked launcher resolves the distribution root" \
    "$(log_value env_root)" "$REPO_ROOT"

# --- Missing micro ------------------------------------------------------------

mkdir -p "$TMP/nobin"
for tool in dirname readlink; do
    tool_path=$(command -v "$tool") || {
        printf 'missing required test tool: %s\n' "$tool" >&2
        exit 1
    }
    ln -s "$tool_path" "$TMP/nobin/$tool"
done

: > "$LOG"
env -u MICROBOSS_CONFIG -u MICROBOSS_DATA -u MICROBOSS_CACHE \
    -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME \
    HOME="$TEST_HOME" PATH="$TMP/nobin" MICROBOSS_TEST_LOG="$LOG" \
    "$LAUNCHER" "x.txt" > "$OUT" 2> "$ERR"
STATUS=$?
check_true "missing micro fails with a non-zero status" '[ "$STATUS" -ne 0 ]'
check_true "missing micro error names micro and PATH" \
    'grep -qi "micro" "$ERR" && grep -qi "PATH" "$ERR"'
check_true "missing micro does not run a fake micro" '[ ! -s "$LOG" ]'

# --- Summary ------------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
