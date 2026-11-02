#!/usr/bin/env bash
# Smoke test for FunScript file detection and syntax highlighting.
#
# Static checks cover the syntax definition and fixtures. The integration check
# drives Micro 2.0.13 in detached tmux sessions with a temporary HOME and config
# directory, opens both .fun and .funx fixtures, and asserts that Micro detects
# the funscript filetype. The test never reads or writes ~/.config/micro.

set -uo pipefail

REPO_ROOT=$(CDPATH= cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CONFIG="$REPO_ROOT/config"
SYNTAX="$CONFIG/syntax/funscript.yaml"
FIXTURES="$REPO_ROOT/tests/fixtures/funscript"

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

for tool in jq micro tmux; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'missing required test tool: %s\n' "$tool" >&2
        exit 1
    fi
done

# --- Syntax definition --------------------------------------------------------

check_true "funscript syntax file exists" '[ -s "$SYNTAX" ]'
check_true "funscript syntax declares the filetype" \
    'grep -q "^filetype: funscript$" "$SYNTAX"'
check_true "funscript syntax detects .fun and .funx" \
    'grep -q "funx?" "$SYNTAX"'

check_true "funscript syntax highlights comments" \
    'grep -q "comment:" "$SYNTAX"'
check_true "funscript syntax highlights strings" \
    'grep -q "constant.string:" "$SYNTAX"'
check_true "funscript syntax highlights operators" \
    'grep -q "symbol.operator:" "$SYNTAX"'
check_true "funscript syntax highlights keywords" \
    'grep -qF "match|when|effect" "$SYNTAX" && grep -qF "schema|service|error" "$SYNTAX" && grep -qF "import|export|from" "$SYNTAX"'
check_true "funscript syntax highlights booleans and numbers" \
    'grep -q "constant.bool:" "$SYNTAX" && grep -q "constant.number:" "$SYNTAX"'

check_true ".fun fixture exists" '[ -s "$FIXTURES/sample.fun" ]'
check_true ".funx fixture exists" '[ -s "$FIXTURES/sample.funx" ]'
check_true "fixtures cover schemas, matching, effects, and pipelines" \
    'grep -q "schema" "$FIXTURES/sample.fun" && grep -q "match" "$FIXTURES/sample.fun" && grep -q "effect" "$FIXTURES/sample.fun" && grep -q "|>" "$FIXTURES/sample.fun"'
if grep -q "<div" "$FIXTURES/sample.funx" \
    && grep -qF 'variant-${props.variant}' "$FIXTURES/sample.funx"; then
    ok ".funx fixture covers JSX and interpolated strings"
else
    not_ok ".funx fixture covers JSX and interpolated strings"
fi

# --- Integration fixture ------------------------------------------------------

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/microboss-funscript.XXXXXX") || exit 1
SOCKET="microboss-fs-$$"
SESSION="mb-fs-$$"

cleanup() {
    tmux -L "$SOCKET" kill-server >/dev/null 2>&1 || true
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

export HOME="$TMP_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
mkdir -p "$HOME"

cp -a "$CONFIG" "$TMP_ROOT/config"
mkdir -p "$TMP_ROOT/config/plug/syntaxprobe"
cat > "$TMP_ROOT/config/plug/syntaxprobe/syntaxprobe.lua" <<'PROBE'
local micro = import("micro")
local config = import("micro/config")

function dump()
    local buf = micro.CurPane().Buf
    micro.Log("PROBE filetype=" .. tostring(buf:FileType()) ..
        " syntax=" .. tostring(buf.Settings["syntax"]))
end

function init()
    config.MakeCommand("probe", dump, config.NoComplete)
end
PROBE

jq '. + {"F9": "lua:syntaxprobe.dump"}' "$TMP_ROOT/config/bindings.json" \
    > "$TMP_ROOT/config/bindings.json.tmp" \
    && mv "$TMP_ROOT/config/bindings.json.tmp" "$TMP_ROOT/config/bindings.json"

session_alive() {
    tmux -L "$SOCKET" has-session -t "$SESSION" >/dev/null 2>&1
}

wait_for_log() {
    local log=$1
    local pattern=$2
    local i=0
    while [ "$i" -lt 60 ]; do
        if grep -q "$pattern" "$log" 2>/dev/null; then
            return 0
        fi
        session_alive || return 1
        i=$((i + 1))
        sleep 0.1
    done
    return 1
}

probe_count() {
    grep -c 'PROBE ' "$LOG" 2>/dev/null || true
}

probe_line() {
    grep 'PROBE ' "$LOG" 2>/dev/null | tail -n 1 | sed 's/.*PROBE //'
}

wait_for_probe() {
    local want=$1
    local i=0
    while [ "$i" -lt 60 ]; do
        if [ "$(probe_count)" -ge "$want" ]; then
            return 0
        fi
        session_alive || return 1
        i=$((i + 1))
        sleep 0.1
    done
    return 1
}

detect_filetype() {
    local label=$1
    local file=$2
    local dir=$3

    mkdir -p "$dir"
    LOG="$dir/log.txt"
    local out="$dir/micro.out"

    tmux -L "$SOCKET" new-session -d -s "$SESSION" -x 120 -y 40 \
        "cd '$dir' && HOME='$HOME' XDG_CONFIG_HOME='$XDG_CONFIG_HOME' XDG_CACHE_HOME='$XDG_CACHE_HOME' XDG_DATA_HOME='$XDG_DATA_HOME' micro -config-dir '$TMP_ROOT/config' -debug '$file' >'$out' 2>&1"

    if wait_for_log "$LOG" "Micro started"; then
        ok "Micro starts with $label"
    else
        not_ok "Micro starts with $label" "$(tail -n 3 "$out" 2>/dev/null)"
    fi

    tmux -L "$SOCKET" send-keys -t "$SESSION" F9 >/dev/null 2>&1
    if wait_for_probe 1; then
        check_eq "Micro detects $label as funscript" \
            "$(probe_line)" "filetype=funscript syntax=true"
    else
        not_ok "Micro detects $label as funscript" \
            "last probe: $(probe_line); $(tail -n 3 "$out" 2>/dev/null)"
    fi

    tmux -L "$SOCKET" kill-session -t "$SESSION" >/dev/null 2>&1 || true
}

cp "$FIXTURES/sample.fun" "$TMP_ROOT/sample.fun"
cp "$FIXTURES/sample.funx" "$TMP_ROOT/sample.funx"

detect_filetype ".fun" "$TMP_ROOT/sample.fun" "$TMP_ROOT/case-fun"
detect_filetype ".funx" "$TMP_ROOT/sample.funx" "$TMP_ROOT/case-funx"

if grep -RqiE "Error (parsing|loading) (syntax|header) file.*funscript" "$TMP_ROOT" 2>/dev/null; then
    not_ok "Micro reports no funscript syntax errors" \
        "$(grep -RhiE "Error (parsing|loading) (syntax|header) file.*funscript" "$TMP_ROOT" 2>/dev/null | head -n 3)"
else
    ok "Micro reports no funscript syntax errors"
fi

check_true "Micro did not create ~/.config/micro under the test HOME" \
    '[ ! -e "$HOME/.config/micro" ]'

# --- Summary -----------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
