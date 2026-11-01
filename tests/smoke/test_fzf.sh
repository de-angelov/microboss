#!/usr/bin/env bash
# Smoke test for the vendored fzf plugin, the Ctrl+P binding, and quick-open
# project listing.
#
# Static checks cover the pinned version, metadata, binding, and the launcher's
# FZF_DEFAULT_COMMAND for both the rg and find paths. The integration check runs
# Micro in a detached tmux session with a temporary HOME, an empty PATH, and a
# copied config, presses Ctrl+P without fzf installed, and asserts that Micro
# reports an actionable error and keeps running. The test never reads or writes
# ~/.config/micro.

set -uo pipefail

REPO_ROOT=$(CDPATH= cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CONFIG="$REPO_ROOT/config"
PLUGIN="$CONFIG/plug/fzf"
BINDINGS="$CONFIG/bindings.json"
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

check_contains() {
    case $2 in
        *"$3"*) ok "$1" ;;
        *) not_ok "$1" "expected [$2] to contain [$3]" ;;
    esac
}

check_prefix() {
    case $2 in
        "$3"*) ok "$1" ;;
        *) not_ok "$1" "expected prefix [$3], got [$2]" ;;
    esac
}

for tool in jq micro tmux; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'missing required test tool: %s\n' "$tool" >&2
        exit 1
    fi
done

# --- Vendored plugin ----------------------------------------------------------

check_true "fzf plugin directory exists" '[ -d "$PLUGIN" ]'
check_eq "vendored fzf VERSION is 1.1.1" \
    "$(cat "$PLUGIN/VERSION" 2>/dev/null)" "1.1.1"
check_true "main.lua reports version 1.1.1" \
    'grep -q "^VERSION = \"1.1.1\"" "$PLUGIN/main.lua"'
check_true "fzf repo.json is valid JSON" \
    'jq empty "$PLUGIN/repo.json" >/dev/null 2>&1'
check_true "fzf repo.json lists version 1.1.1" \
    'jq -e ".[].Versions[] | select(.Version == \"1.1.1\")" "$PLUGIN/repo.json" >/dev/null 2>&1'
check_true "fzf README is present" '[ -s "$PLUGIN/README.md" ]'
check_true "plugin reports a missing fzf binary" \
    'grep -q "fzf not found on PATH" "$PLUGIN/main.lua"'

# --- Binding ------------------------------------------------------------------

check_true "bindings.json is valid JSON" \
    'jq empty "$BINDINGS" >/dev/null 2>&1'
check_eq "CtrlP runs command:fzf" \
    "$(jq -r '.CtrlP' "$BINDINGS" 2>/dev/null)" "command:fzf"

check_true "config does not reference ~/.config/micro" \
    '! grep -Rq --include="*.json" --include="*.lua" --include="*.md" "\.config/micro" "$CONFIG"'

# --- Launcher FZF_DEFAULT_COMMAND --------------------------------------------

TMP=$(mktemp -d "${TMPDIR:-/tmp}/microboss-fzf.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT

TEST_HOME="$TMP/home"
FAKE_RG="$TMP/bin-rg"
FAKE_NO_RG="$TMP/bin-no-rg"
ENV_LOG="$TMP/fzf.env"
STATUS=0

mkdir -p "$TEST_HOME" "$FAKE_RG" "$FAKE_NO_RG"

cat > "$FAKE_RG/micro" <<'FAKE'
#!/bin/sh
printf '%s\n' "${FZF_DEFAULT_COMMAND-}" > "${MICROBOSS_TEST_LOG:?MICROBOSS_TEST_LOG is not set}"
FAKE
chmod +x "$FAKE_RG/micro"

for tool in dirname readlink; do
    tool_path=$(command -v "$tool") || {
        printf 'missing required test tool: %s\n' "$tool" >&2
        exit 1
    }
    ln -s "$tool_path" "$FAKE_RG/$tool"
    ln -s "$tool_path" "$FAKE_NO_RG/$tool"
done
cp "$FAKE_RG/micro" "$FAKE_NO_RG/micro"

# The launcher only probes for rg on PATH, so a stub is enough to exercise the
# rg branch on hosts that do not have ripgrep installed.
printf '#!/bin/sh\nexit 0\n' > "$FAKE_RG/rg"
chmod +x "$FAKE_RG/rg"

run_launcher() {
    local path=$1
    : > "$ENV_LOG"
    env -u MICROBOSS_CONFIG -u MICROBOSS_DATA -u MICROBOSS_CACHE \
        -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME \
        -u FZF_DEFAULT_COMMAND \
        HOME="$TEST_HOME" PATH="$path" MICROBOSS_TEST_LOG="$ENV_LOG" \
        "$LAUNCHER" "file.txt" >/dev/null 2>"$TMP/stderr"
    STATUS=$?
}

run_launcher "$FAKE_RG"
FZF_CMD=$(cat "$ENV_LOG" 2>/dev/null)
check_eq "launcher exits 0 with rg on PATH" "$STATUS" "0"
check_prefix "FZF_DEFAULT_COMMAND uses rg --files" "$FZF_CMD" "rg --files"
for entry in .git node_modules dist coverage; do
    check_contains "rg listing excludes $entry" "$FZF_CMD" "$entry"
done
check_contains "rg listing includes hidden files explicitly" "$FZF_CMD" "--hidden"

run_launcher "$FAKE_NO_RG"
FZF_CMD=$(cat "$ENV_LOG" 2>/dev/null)
check_eq "launcher exits 0 without rg on PATH" "$STATUS" "0"
check_contains "FZF_DEFAULT_COMMAND falls back to find" "$FZF_CMD" "find . -type d"
for entry in .git node_modules dist coverage; do
    check_contains "find listing prunes $entry" "$FZF_CMD" "$entry"
done
check_contains "find fallback keeps the output relative" "$FZF_CMD" "sed 's|^\\./||'"

# --- Integration fixture ------------------------------------------------------

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/microboss-fzf-run.XXXXXX") || exit 1
SOCKET="microboss-fzf-$$"
SESSION="mb-fzf-$$"
LOG="$TMP_ROOT/log.txt"
MICRO_OUT="$TMP_ROOT/micro.out"
PROJECT="$TMP_ROOT/project"
FIXTURE="$PROJECT/fixture.txt"
EMPTY_BIN="$TMP_ROOT/emptybin"
MICRO_BIN=$(command -v micro)

cleanup() {
    tmux -L "$SOCKET" kill-server >/dev/null 2>&1 || true
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

export HOME="$TMP_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
mkdir -p "$HOME" "$PROJECT" "$EMPTY_BIN"

cp -a "$CONFIG" "$TMP_ROOT/config"
printf 'fixture\n' > "$FIXTURE"

session_alive() {
    tmux -L "$SOCKET" has-session -t "$SESSION" >/dev/null 2>&1
}

wait_for_log() {
    local pattern=$1
    local i=0
    while [ "$i" -lt 60 ]; do
        if grep -q "$pattern" "$LOG" 2>/dev/null; then
            return 0
        fi
        session_alive || return 1
        i=$((i + 1))
        sleep 0.1
    done
    return 1
}

wait_for_screen() {
    local pattern=$1
    local i=0
    while [ "$i" -lt 60 ]; do
        if tmux -L "$SOCKET" capture-pane -p -t "$SESSION" 2>/dev/null |
            grep -qi "$pattern"; then
            return 0
        fi
        session_alive || return 1
        i=$((i + 1))
        sleep 0.1
    done
    return 1
}

tmux -L "$SOCKET" new-session -d -s "$SESSION" -x 120 -y 40 \
    "cd '$TMP_ROOT' && HOME='$HOME' XDG_CONFIG_HOME='$XDG_CONFIG_HOME' XDG_CACHE_HOME='$XDG_CACHE_HOME' XDG_DATA_HOME='$XDG_DATA_HOME' PATH='$EMPTY_BIN' '$MICRO_BIN' -config-dir '$TMP_ROOT/config' -debug '$FIXTURE' >'$MICRO_OUT' 2>&1"

if wait_for_log "Micro started"; then
    ok "Micro started in a temporary fixture"
else
    not_ok "Micro started in a temporary fixture" "$(tail -n 3 "$MICRO_OUT" 2>/dev/null)"
fi

tmux -L "$SOCKET" send-keys -t "$SESSION" C-p >/dev/null 2>&1
if wait_for_screen "fzf not found"; then
    ok "Ctrl+P reports a missing fzf binary in the info bar"
else
    not_ok "Ctrl+P reports a missing fzf binary in the info bar" \
        "$(tmux -L "$SOCKET" capture-pane -p -t "$SESSION" 2>/dev/null | tail -n 2)"
fi

sleep 0.2
check_true "Micro stays alive after the missing fzf error" 'session_alive'
check_true "the editor buffer remains visible after the error" \
    'tmux -L "$SOCKET" capture-pane -p -t "$SESSION" 2>/dev/null | grep -q "fixture"'
check_true "Micro did not create ~/.config/micro under the test HOME" \
    '[ ! -e "$HOME/.config/micro" ]'

# --- Summary -----------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
