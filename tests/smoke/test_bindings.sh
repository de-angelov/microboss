#!/usr/bin/env bash
# Smoke test for config/bindings.json: valid JSON, key names that Micro 2.0.13
# can actually bind, and documentation coverage.

set -uo pipefail

REPO_ROOT=$(CDPATH= cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
BINDINGS="$REPO_ROOT/config/bindings.json"
KEYMAP="$REPO_ROOT/docs/keymap.md"

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

check_true() {
    if eval "$2"; then
        ok "$1"
    else
        not_ok "$1" "failed: $2"
    fi
}

if ! command -v jq >/dev/null 2>&1; then
    printf 'missing required test tool: jq\n' >&2
    exit 1
fi

# --- Micro 2.0.13 bindable key names -----------------------------------------
#
# These names come from internal/action/bindings.go in Micro v2.0.13. A key is
# either one of these named events or a single printable character, optionally
# prefixed by Ctrl, Alt, or Shift.

KEY_EVENTS="Up Down Right Left UpLeft UpRight DownLeft DownRight Center
PageUp PageDown Home End Insert Delete Help Exit Clear Cancel Print Pause
Backtab Tab Esc Escape Enter Backspace OldBackspace PgUp PgDown"

CTRL_KEYS="CtrlSpace CtrlA CtrlB CtrlC CtrlD CtrlE CtrlF CtrlG CtrlH CtrlI
CtrlJ CtrlK CtrlL CtrlM CtrlN CtrlO CtrlP CtrlQ CtrlR CtrlS CtrlT CtrlU CtrlV
CtrlW CtrlX CtrlY CtrlZ CtrlLeftSq CtrlBackslash CtrlRightSq CtrlCarat
CtrlUnderscore"

for i in {1..64}; do
    KEY_EVENTS="$KEY_EVENTS F$i"
done

KEY_EVENTS=$(printf '%s' "$KEY_EVENTS" | tr '\n' ' ')
CTRL_KEYS=$(printf '%s' "$CTRL_KEYS" | tr '\n' ' ')

# is_bindable_key <key>
#
# Mirrors Micro's findSingleEvent parser closely enough to reject typo keys. It
# deliberately rejects Ctrl+Shift chords, Ctrl+Tab, Ctrl+backtick, and
# Shift+Escape because terminals cannot deliver them reliably.
is_bindable_key() {
    local key=$1
    local base=$key
    local has_ctrl=0 has_alt=0 has_shift=0
    local upper

    case $key in
        '' | *'+'* | *'<'* | *'>'*)
            return 1
            ;;
    esac

    while :; do
        case $base in
            CtrlH)
                # Micro treats CtrlH as a key name, not Ctrl plus H.
                break
                ;;
            Ctrl*)
                has_ctrl=1
                base=${base#Ctrl}
                ;;
            Alt*)
                has_alt=1
                base=${base#Alt}
                ;;
            Shift*)
                has_shift=1
                base=${base#Shift}
                ;;
            -*)
                [ "$base" = "-" ] && break
                base=${base#-}
                ;;
            *)
                break
                ;;
        esac
    done

    [ -n "$base" ] || return 1

    if [ "$has_ctrl" -eq 1 ] && [ "$has_shift" -eq 1 ]; then
        return 1
    fi
    if [ "$has_ctrl" -eq 1 ] && [ "$base" = "Tab" ]; then
        return 1
    fi
    if [ "$has_shift" -eq 1 ] && [ "$base" = "Escape" ]; then
        return 1
    fi
    if [ "$has_ctrl" -eq 1 ] && [ "$base" = '`' ]; then
        return 1
    fi

    if [ "$base" = "CtrlH" ]; then
        [ "$has_ctrl" -eq 0 ]
        return
    fi

    if [ "$has_ctrl" -eq 1 ]; then
        upper=$(printf '%s' "${base:0:1}" | tr '[:lower:]' '[:upper:]')${base:1}
        case " $CTRL_KEYS " in
            *" Ctrl$upper "*)
                return 0
                ;;
        esac
        # Micro falls back to a single-character rune for unnamed Ctrl keys.
        [ ${#base} -eq 1 ] && return 0
        return 1
    fi

    case " $KEY_EVENTS " in
        *" $base "*)
            return 0
            ;;
    esac
    [ ${#base} -eq 1 ] && return 0
    return 1
}

# normalize_key <display-or-binding-name>
#
# Display names use plus signs and friendly spellings such as Ctrl+\; binding
# names use Micro spellings such as CtrlBackslash and Alt-\. Both collapse to
# the same comparison form.
normalize_key() {
    local key=$1
    key=${key//+/}
    key=${key//-/}
    key=${key//\\/Backslash}
    printf '%s' "$key" | tr '[:upper:]' '[:lower:]'
}

# documented_tokens prints every backticked shortcut in the microboss column of
# the keymap table.
documented_tokens() {
    awk -F'|' '
        /^\|/ {
            cell = $4
            while (match(cell, /`[^`]+`/)) {
                print substr(cell, RSTART + 1, RLENGTH - 2)
                cell = substr(cell, RSTART + RLENGTH)
            }
        }
    ' "$KEYMAP"
}

# --- JSON validity -----------------------------------------------------------

if jq empty "$BINDINGS" 2>/dev/null; then
    ok "bindings.json is valid JSON"
else
    not_ok "bindings.json is valid JSON"
fi

check_true "bindings.json is a JSON object" \
    'jq -e "type == \"object\"" "$BINDINGS" >/dev/null 2>&1'

check_true "every binding value is a non-empty string" \
    '! jq -e "to_entries[] | select((.value | type) != \"string\" or (.value | length) == 0)" "$BINDINGS" >/dev/null 2>&1'

# --- Key names ---------------------------------------------------------------

KEYS=$(jq -r 'keys[]' "$BINDINGS" 2>/dev/null)
while IFS= read -r key; do
    [ -n "$key" ] || continue
    if is_bindable_key "$key"; then
        ok "key $key is bindable in Micro 2.0.13"
    else
        not_ok "key $key is bindable in Micro 2.0.13" \
            "unknown key name or a terminal-unreliable chord"
    fi
done <<< "$KEYS"

# Prove the validator rejects the exact chords the task forbids, plus a typo.
for bad_key in CtrlShiftP CtrlTab 'Ctrl`' ShiftEscape 'Ctrl+P' HyperX; do
    if is_bindable_key "$bad_key"; then
        not_ok "validator rejects $bad_key"
    else
        ok "validator rejects $bad_key"
    fi
done

# The same chords must not appear in the shipped bindings at all.
check_no_key_pattern() {
    local label=$1
    local pattern=$2
    if jq -r 'keys[]' "$BINDINGS" | grep -Fq -- "$pattern"; then
        not_ok "$label"
    else
        ok "$label"
    fi
}

check_no_key_pattern "bindings.json has no Ctrl+Shift chord" "CtrlShift"
check_no_key_pattern "bindings.json has no Ctrl+Tab chord" "CtrlTab"
check_no_key_pattern "bindings.json has no Ctrl+backtick chord" 'Ctrl`'
check_no_key_pattern "bindings.json has no Shift+Escape chord" "ShiftEscape"

# --- Documentation coverage --------------------------------------------------

check_true "docs/keymap.md exists" '[ -f "$KEYMAP" ]'

DOC_TOKENS=$(documented_tokens 2>/dev/null)
if [ -n "$DOC_TOKENS" ]; then
    ok "keymap documents at least one shortcut"
else
    not_ok "keymap documents at least one shortcut"
fi

NORMALIZED_BINDINGS=""
while IFS= read -r key; do
    [ -n "$key" ] || continue
    NORMALIZED_BINDINGS="$NORMALIZED_BINDINGS $(normalize_key "$key")"
done <<< "$KEYS"

while IFS= read -r token; do
    [ -n "$token" ] || continue
    normalized=$(normalize_key "$token")
    case " $NORMALIZED_BINDINGS " in
        *" $normalized "*)
            ok "documented shortcut $token has a binding"
            ;;
        *)
            not_ok "documented shortcut $token has a binding"
            ;;
    esac
done <<< "$DOC_TOKENS"

# The reverse direction keeps the cheat sheet complete when bindings are added.
NORMALIZED_DOCS=""
while IFS= read -r token; do
    [ -n "$token" ] || continue
    NORMALIZED_DOCS="$NORMALIZED_DOCS $(normalize_key "$token")"
done <<< "$DOC_TOKENS"

while IFS= read -r key; do
    [ -n "$key" ] || continue
    normalized=$(normalize_key "$key")
    case " $NORMALIZED_DOCS " in
        *" $normalized "*)
            ok "binding $key is documented"
            ;;
        *)
            not_ok "binding $key is documented"
            ;;
    esac
done <<< "$KEYS"

# --- Summary -----------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
