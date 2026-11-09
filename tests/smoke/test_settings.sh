#!/usr/bin/env bash
# Smoke test for config/settings.json: valid JSON, expected options, and
# portable paths.

set -uo pipefail

REPO_ROOT=$(CDPATH= cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SETTINGS="$REPO_ROOT/config/settings.json"

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

# value_of <jq-args...>
value_of() {
    jq -r "$@" "$SETTINGS" 2>/dev/null
}

# check_type <key> <json-type>
check_type() {
    check_eq "settings.$1 is $2" "$(value_of --arg k "$1" '.[$k] | type')" "$2"
}

if ! command -v jq >/dev/null 2>&1; then
    printf 'missing required test tool: jq\n' >&2
    exit 1
fi

if jq empty "$SETTINGS" 2>/dev/null; then
    ok "settings.json is valid JSON"
else
    not_ok "settings.json is valid JSON"
fi

# --- Required options ---------------------------------------------------------

for key in mouse ruler statusline softwrap saveundo backup backupdir \
    autoindent rmtrailingws paste smartpaste clipboard scrollspeed; do
    check_true "settings.$key is present" \
        'jq -e --arg k "$key" "has(\$k)" "$SETTINGS" >/dev/null 2>&1'
done

# --- JSON types ---------------------------------------------------------------

check_type mouse boolean
check_type ruler boolean
check_type statusline boolean
check_type softwrap boolean
check_type saveundo boolean
check_type backup boolean
check_type backupdir string
check_type autoindent boolean
check_type rmtrailingws boolean
check_type paste boolean
check_type smartpaste boolean
check_type clipboard string
check_type scrollspeed number

# --- Expected defaults --------------------------------------------------------

check_eq "mouse is enabled" "$(value_of '.mouse')" "true"
check_eq "ruler is enabled" "$(value_of '.ruler')" "true"
check_eq "statusline is enabled" "$(value_of '.statusline')" "true"
check_eq "softwrap is disabled for code" "$(value_of '.softwrap')" "false"
check_eq "saveundo is enabled" "$(value_of '.saveundo')" "true"
check_eq "backup is enabled" "$(value_of '.backup')" "true"
check_eq "autoindent is enabled" "$(value_of '.autoindent')" "true"
check_eq "rmtrailingws is enabled" "$(value_of '.rmtrailingws')" "true"
check_eq "paste mode is disabled" "$(value_of '.paste')" "false"
check_eq "smartpaste is enabled" "$(value_of '.smartpaste')" "true"
check_eq "clipboard uses the terminal" "$(value_of '.clipboard')" "terminal"
check_eq "scrollspeed keeps Micro's default" "$(value_of '.scrollspeed')" "2"

# --- Portable paths -----------------------------------------------------------

check_eq "backupdir points under ~/.cache/microboss" \
    "$(value_of '.backupdir')" "~/.cache/microboss"

check_true "backupdir does not hard-code a home directory" \
    '! printf "%s" "$(value_of ".backupdir")" | grep -Eq "(^|/)(home|Users)/"'

check_true "settings.json does not reference ~/.config/micro" \
    '! grep -q "\.config/micro" "$SETTINGS"'

# --- Summary ------------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
