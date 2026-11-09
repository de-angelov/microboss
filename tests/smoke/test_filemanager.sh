#!/usr/bin/env bash
# Smoke test for the vendored filemanager plugin and explorer defaults.
#
# Static checks cover the pinned version, metadata, license, settings, bindings,
# and the focus wrapper. The integration check drives Micro in a detached tmux
# session with a temporary HOME and config directory, opens and closes the tree
# with F2 and Ctrl+B, and asserts that the editor keeps focus. The test never
# reads or writes ~/.config/micro.

set -uo pipefail

REPO_ROOT=$(CDPATH= cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CONFIG="$REPO_ROOT/config"
PLUGIN="$CONFIG/plug/filemanager"
SETTINGS="$CONFIG/settings.json"
BINDINGS="$CONFIG/bindings.json"
INIT_LUA="$CONFIG/init.lua"

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

# --- Vendored plugin ----------------------------------------------------------

check_true "filemanager plugin directory exists" '[ -d "$PLUGIN" ]'
check_eq "vendored filemanager VERSION is 3.5.1" \
    "$(cat "$PLUGIN/VERSION" 2>/dev/null)" "3.5.1"
check_true "filemanager.lua reports version 3.5.1" \
    'grep -q "^VERSION = \"3.5.1\"" "$PLUGIN/filemanager.lua"'
check_true "filemanager repo.json is valid JSON" \
    'jq empty "$PLUGIN/repo.json" >/dev/null 2>&1'
check_true "filemanager repo.json lists version 3.5.1" \
    'jq -e ".[].Versions[] | select(.Version == \"3.5.1\")" "$PLUGIN/repo.json" >/dev/null 2>&1'
check_true "filemanager LICENSE is present" '[ -s "$PLUGIN/LICENSE" ]'
check_true "filemanager syntax file is present" '[ -s "$PLUGIN/syntax.yaml" ]'

# --- Explorer defaults and bindings ------------------------------------------

check_true "settings.json is valid JSON" \
    'jq empty "$SETTINGS" >/dev/null 2>&1'
check_true "bindings.json is valid JSON" \
    'jq empty "$BINDINGS" >/dev/null 2>&1'

check_eq "filemanager.showdotfiles is false" \
    "$(jq -r '."filemanager.showdotfiles"' "$SETTINGS" 2>/dev/null)" "false"
check_eq "filemanager.showignored is false" \
    "$(jq -r '."filemanager.showignored"' "$SETTINGS" 2>/dev/null)" "false"

check_eq "F2 runs command:tree" \
    "$(jq -r '.F2' "$BINDINGS" 2>/dev/null)" "command:tree"
check_eq "CtrlB runs command:tree" \
    "$(jq -r '.CtrlB' "$BINDINGS" 2>/dev/null)" "command:tree"

check_true "init.lua defines the filemanager wrapper" \
    'grep -q "function toggle_filemanager" "$INIT_LUA"'
check_true "init.lua installs the wrapper as the tree command" \
    'grep -q "MakeCommand(\"tree\", toggle_filemanager" "$INIT_LUA"'
check_true "init.lua restores focus with PreviousSplit" \
    'grep -q "PreviousSplit" "$INIT_LUA"'

check_true "config does not reference ~/.config/micro" \
    '! grep -Rq --include="*.json" --include="*.lua" "\.config/micro" "$CONFIG"'

# --- Integration fixture ------------------------------------------------------

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/microboss-filemanager.XXXXXX") || exit 1
SOCKET="microboss-fm-$$"
SESSION="mb-fm-$$"
LOG="$TMP_ROOT/log.txt"
MICRO_OUT="$TMP_ROOT/micro.out"
FIXTURE="$TMP_ROOT/project/sample.txt"

cleanup() {
    tmux -L "$SOCKET" kill-server >/dev/null 2>&1 || true
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

export HOME="$TMP_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
mkdir -p "$HOME" "$TMP_ROOT/project"

cp -a "$CONFIG" "$TMP_ROOT/config"
mkdir -p "$TMP_ROOT/config/plug/probe"
cat > "$TMP_ROOT/config/plug/probe/probe.lua" <<'PROBE'
local micro = import("micro")
local config = import("micro/config")

function dump()
    local tab = micro.CurTab()
    local pane = micro.CurPane()
    micro.Log("PROBE panes=" .. tostring(#tab.Panes) .. " active=" .. tostring(pane.Buf.Path))
end

function init()
    config.MakeCommand("probe", dump, config.NoComplete)
end
PROBE

jq '. + {"F9": "lua:probe.dump"}' "$TMP_ROOT/config/bindings.json" \
    > "$TMP_ROOT/config/bindings.json.tmp" \
    && mv "$TMP_ROOT/config/bindings.json.tmp" "$TMP_ROOT/config/bindings.json"

printf 'fixture\n' > "$FIXTURE"
printf 'hidden\n' > "$TMP_ROOT/project/.hidden"

probe_count() {
    grep -c 'PROBE ' "$LOG" 2>/dev/null || true
}

probe_line() {
    grep 'PROBE ' "$LOG" 2>/dev/null | tail -n 1 | sed 's/.*PROBE //'
}

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

send_key() {
    tmux -L "$SOCKET" send-keys -t "$SESSION" "$1" >/dev/null 2>&1
}

tmux -L "$SOCKET" new-session -d -s "$SESSION" -x 120 -y 40 \
    "cd '$TMP_ROOT' && HOME='$HOME' XDG_CONFIG_HOME='$XDG_CONFIG_HOME' XDG_CACHE_HOME='$XDG_CACHE_HOME' XDG_DATA_HOME='$XDG_DATA_HOME' micro -config-dir '$TMP_ROOT/config' -debug '$FIXTURE' >'$MICRO_OUT' 2>&1"

if wait_for_log "Micro started"; then
    ok "Micro started in a temporary fixture"
else
    not_ok "Micro started in a temporary fixture" "$(tail -n 3 "$MICRO_OUT" 2>/dev/null)"
fi

send_key F9
if wait_for_probe 1; then
    ok "probe reports the initial editor pane"
else
    not_ok "probe reports the initial editor pane" "$(tail -n 3 "$MICRO_OUT" 2>/dev/null)"
fi
check_eq "editor starts as the only pane" "$(probe_line)" "panes=1 active=$FIXTURE"

send_key F2
sleep 0.2
send_key F9
if wait_for_probe 2; then
    ok "F2 opens the tree"
else
    not_ok "F2 opens the tree" "last probe: $(probe_line)"
fi
check_eq "F2 opens the tree and restores editor focus" \
    "$(probe_line)" "panes=2 active=$FIXTURE"
check_true "F2 leaves the editor, not the tree, as the active pane" \
    '! printf "%s" "$(probe_line)" | grep -q "active=filemanager"'

send_key F2
sleep 0.2
send_key F9
if wait_for_probe 3; then
    ok "F2 closes the tree"
else
    not_ok "F2 closes the tree" "last probe: $(probe_line)"
fi
check_eq "F2 closes the tree and keeps editor focus" \
    "$(probe_line)" "panes=1 active=$FIXTURE"

send_key C-b
sleep 0.2
send_key F9
if wait_for_probe 4; then
    ok "Ctrl+B opens the tree"
else
    not_ok "Ctrl+B opens the tree" "last probe: $(probe_line)"
fi
check_eq "Ctrl+B opens the tree and restores editor focus" \
    "$(probe_line)" "panes=2 active=$FIXTURE"
check_true "Ctrl+B leaves the editor, not the tree, as the active pane" \
    '! printf "%s" "$(probe_line)" | grep -q "active=filemanager"'

send_key C-b
sleep 0.2
send_key F9
if wait_for_probe 5; then
    ok "Ctrl+B closes the tree"
else
    not_ok "Ctrl+B closes the tree" "last probe: $(probe_line)"
fi
check_eq "Ctrl+B closes the tree and keeps editor focus" \
    "$(probe_line)" "panes=1 active=$FIXTURE"

tmux -L "$SOCKET" kill-session -t "$SESSION"
tmux -L "$SOCKET" new-session -d -s "$SESSION" -x 120 -y 40 \
    "MICROBOSS_CONFIG='$TMP_ROOT/config' '$REPO_ROOT/bin/microboss' '$TMP_ROOT/project'"
folder_opened=0
for _ in $(seq 1 60); do
    if tmux -L "$SOCKET" capture-pane -p -t "$SESSION" 2>/dev/null | grep -q 'sample.txt'; then
        folder_opened=1
        break
    fi
    sleep 0.1
done
check_eq "folder launch opens its project tree" "$folder_opened" "1"
send_key C-w
send_key Down
send_key Enter
opened=0
for _ in $(seq 1 60); do
    if tmux -L "$SOCKET" capture-pane -p -t "$SESSION" 2>/dev/null | grep -q 'fixture'; then
        opened=1
        break
    fi
    sleep 0.1
done
check_eq "Enter opens the selected tree file" "$opened" "1"
send_key End
send_key Enter
tmux -L "$SOCKET" send-keys -t "$SESSION" -l 'secondline'
sleep 0.2
check_true "Enter still inserts a newline in source files" \
    'tmux -L "$SOCKET" capture-pane -p -t "$SESSION" | grep -q "secondline"'

check_true "Micro did not create ~/.config/micro under the test HOME" \
    '[ ! -e "$HOME/.config/micro" ]'

# --- Summary -----------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
