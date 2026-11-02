#!/usr/bin/env bash
# Smoke test for loading the vendored lsp plugin in Micro without Lua errors.

set -uo pipefail

REPO_ROOT=$(CDPATH= cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CONFIG="$REPO_ROOT/config"
PLUGIN="$CONFIG/plug/lsp"

PASS=0
FAIL=0

ok() {
    PASS=$((PASS + 1))
    printf 'ok %d - %s\n' "$((PASS + FAIL))" "$1"
}

not_ok() {
    FAIL=$((FAIL + 1))
    printf 'not ok %d - %s\n' "$((PASS + FAIL))" "$1"
    if [ "$#" -gt 1 ]; then
        printf '# %s\n' "$2"
    fi
}

for tool in jq micro tmux; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'missing required test tool: %s\n' "$tool" >&2
        exit 1
    fi
done

# --- Vendored plugin metadata -------------------------------------------------

if [ -d "$PLUGIN" ]; then
    ok "lsp plugin directory exists"
else
    not_ok "lsp plugin directory exists" "$PLUGIN is missing"
fi

if [ "$(sed -n 's/^VERSION = "\([^"]*\)"$/\1/p' "$PLUGIN/main.lua" 2>/dev/null)" = "0.6.2" ]; then
    ok "main.lua reports version 0.6.2"
else
    not_ok "main.lua reports version 0.6.2" "expected VERSION = \"0.6.2\""
fi

if jq -e '.[].Versions[] | select(.Version == "0.6.2")' "$PLUGIN/repo.json" >/dev/null 2>&1; then
    ok "repo.json lists version 0.6.2"
else
    not_ok "repo.json lists version 0.6.2" "missing or invalid version metadata"
fi

# --- Isolated Micro load ------------------------------------------------------

TMP=$(mktemp -d "${TMPDIR:-/tmp}/microboss-lsp-load.XXXXXX") || exit 1
SOCKET="microboss-lsp-$$"
SESSION="mb-lsp-$$"
LOG="$TMP/log.txt"
MICRO_OUT="$TMP/micro.out"
MICRO_BIN=$(command -v micro)

cleanup() {
    tmux -L "$SOCKET" kill-server >/dev/null 2>&1 || true
    rm -rf "$TMP"
}
trap cleanup EXIT HUP INT TERM

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
mkdir -p "$HOME" "$TMP/project"
cp -a "$CONFIG" "$TMP/config"
printf 'fixture\n' > "$TMP/project/fixture.txt"

session_alive() {
    tmux -L "$SOCKET" has-session -t "$SESSION" >/dev/null 2>&1
}

wait_for_log() {
    local pattern=$1 i=0
    while [ "$i" -lt 60 ]; do
        grep -q "$pattern" "$LOG" 2>/dev/null && return 0
        session_alive || return 1
        i=$((i + 1))
        sleep 0.1
    done
    return 1
}

tmux -L "$SOCKET" new-session -d -s "$SESSION" -x 120 -y 40 \
    "cd '$TMP' && HOME='$HOME' XDG_CONFIG_HOME='$XDG_CONFIG_HOME' XDG_CACHE_HOME='$XDG_CACHE_HOME' XDG_DATA_HOME='$XDG_DATA_HOME' '$MICRO_BIN' -config-dir '$TMP/config' -debug '$TMP/project/fixture.txt' >'$MICRO_OUT' 2>&1"

if wait_for_log "Micro started"; then
    ok "Micro starts with the copied config"
else
    not_ok "Micro starts with the copied config" "$(tail -n 5 "$MICRO_OUT" 2>/dev/null)"
fi

if [ -f "$LOG" ]; then
    if grep -Eiq 'lua.*(error|failed)|error.*lua|failed to load plugin|error loading plugin' "$LOG"; then
        not_ok "lsp loads without Lua or plugin errors" "$(grep -Ei 'lua.*(error|failed)|error.*lua|failed to load plugin|error loading plugin' "$LOG" | tail -n 3)"
    else
        ok "lsp loads without Lua or plugin errors"
    fi
else
    not_ok "Micro debug log is present" "expected $LOG"
fi

if session_alive; then
    ok "Micro remains running after plugin load"
else
    not_ok "Micro remains running after plugin load"
fi

if [ ! -e "$HOME/.config/micro" ]; then
    ok "Micro did not create ~/.config/micro under the test HOME"
else
    not_ok "Micro did not create ~/.config/micro under the test HOME"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
