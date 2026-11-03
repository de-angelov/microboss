#!/usr/bin/env bash
# End-to-end smoke test for FunScript LSP diagnostics in .fun and .funx buffers.

set -uo pipefail

REPO_ROOT=$(CDPATH= cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CONFIG="$REPO_ROOT/config"
FIXTURES="$REPO_ROOT/tests/smoke/fixtures/funscript"

for tool in micro tmux; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'missing required test tool: %s\n' "$tool" >&2
        exit 1
    fi
done

if command -v funscript >/dev/null 2>&1; then
    FUNSCRIPT_BIN=$(command -v funscript)
elif [ -x "$PWD/node_modules/.bin/funscript" ]; then
    FUNSCRIPT_BIN="$PWD/node_modules/.bin/funscript"
else
    printf 'missing FunScript language server prerequisite: install funscript (npm install --save-dev funscript) or put funscript on PATH\n' >&2
    exit 1
fi

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/microboss-funscript-lsp.XXXXXX") || exit 1
SOCKET="microboss-fslsp-$$"
SESSION="mb-fslsp-$$"
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
mkdir -p "$HOME" "$TMP_ROOT/project/node_modules/.bin"
PATH="$REPO_ROOT/scripts:$PATH"
export PATH
cp -a "$CONFIG" "$TMP_ROOT/config"
ln -s "$FUNSCRIPT_BIN" "$TMP_ROOT/project/node_modules/.bin/funscript"

wait_for_diagnostic() {
    local i=0
    while [ "$i" -lt 100 ]; do
        # The invalid declaration produces a diagnostic shown at the cursor.
        if [ "$(tmux -L "$SOCKET" capture-pane -p -t "$SESSION" 2>/dev/null | grep -ci "FunScript has no .let.")" -ge 1 ]; then
            return 0
        fi
        tmux -L "$SOCKET" has-session -t "$SESSION" >/dev/null 2>&1 || return 1
        i=$((i + 1))
        sleep 0.1
    done
    return 1
}

run_fixture() {
    local ext=$1
    local source="$FIXTURES/diagnostic.$ext"
    local target="$TMP_ROOT/project/diagnostic.$ext"
    cp "$source" "$target"

    tmux -L "$SOCKET" new-session -d -s "$SESSION" -x 120 -y 40 \
        "cd '$TMP_ROOT/project' && HOME='$HOME' XDG_CONFIG_HOME='$XDG_CONFIG_HOME' XDG_CACHE_HOME='$XDG_CACHE_HOME' XDG_DATA_HOME='$XDG_DATA_HOME' '$MICRO_BIN' -debug -config-dir '$TMP_ROOT/config' '$target'"

    if wait_for_diagnostic; then
        printf 'ok - Micro received FunScript diagnostics for .%s\n' "$ext"
    else
        printf 'not ok - Micro received FunScript diagnostics for .%s\n' "$ext" >&2
        tmux -L "$SOCKET" capture-pane -p -t "$SESSION" >&2 2>/dev/null || true
        cat "$TMP_ROOT/project/log.txt" >&2 2>/dev/null || true
        tmux -L "$SOCKET" kill-session -t "$SESSION" >/dev/null 2>&1 || true
        return 1
    fi
    tmux -L "$SOCKET" kill-session -t "$SESSION" >/dev/null 2>&1 || true
}

run_fixture fun || exit 1
run_fixture funx || exit 1
[ ! -e "$HOME/.config/micro" ] || {
    printf 'Micro unexpectedly created ~/.config/micro under the test HOME\n' >&2
    exit 1
}
printf 'FunScript LSP smoke test passed\n'
