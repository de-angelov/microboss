#!/usr/bin/env bash
# Smoke test for scripts/install.sh.
#
# Runs the installer with a temporary HOME, a fake npm, and temporary XDG
# directories, so the real user configuration and the real Node toolchain are
# never touched.

set -uo pipefail

REPO_ROOT=$(CDPATH= cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
INSTALLER="$REPO_ROOT/scripts/install.sh"
SRC_CONFIG="$REPO_ROOT/config"
SRC_TOOLS="$REPO_ROOT/tools"

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

TMP=$(mktemp -d "${TMPDIR:-/tmp}/microboss-install-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

FAKEBIN="$TMP/fakebin"
NPM_LOG="$TMP/npm.log"
OUT="$TMP/stdout"
ERR="$TMP/stderr"
STATUS=0

mkdir -p "$FAKEBIN"

# Fake npm: record the invocation and create node_modules so the installer's
# toolchain marker check can recognise a completed install.
cat > "$FAKEBIN/npm" <<'FAKE'
#!/bin/sh
{
    printf 'call:'
    for arg in "$@"; do
        printf ' %s' "$arg"
    done
    printf '\n'
} >> "${MICROBOSS_TEST_NPM_LOG:?MICROBOSS_TEST_NPM_LOG is not set}"

prefix=
while [ $# -gt 0 ]; do
    case $1 in
        --prefix)
            prefix=$2
            shift 2
            ;;
        *) shift ;;
    esac
done
[ -n "$prefix" ] && mkdir -p "$prefix/node_modules/.bin"
exit 0
FAKE
chmod +x "$FAKEBIN/npm"

# Fake node: the installer checks the Node.js range before invoking npm. A
# supported version keeps the test independent of the host toolchain.
cat > "$FAKEBIN/node" <<'FAKE'
#!/bin/sh
case ${1:-} in
    --version) printf 'v20.20.2\n' ;;
    *) exit 0 ;;
esac
FAKE
chmod +x "$FAKEBIN/node"

# run_install <home> [args...]
run_install() {
    local home=$1
    shift
    : > "$NPM_LOG"
    : > "$OUT"
    : > "$ERR"
    env -u MICROBOSS_CONFIG -u MICROBOSS_DATA -u MICROBOSS_CACHE \
        -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME \
        HOME="$home" PATH="$FAKEBIN:/usr/bin:/bin" \
        MICROBOSS_TEST_NPM_LOG="$NPM_LOG" \
        "$INSTALLER" "$@" > "$OUT" 2> "$ERR"
    STATUS=$?
}

# run_install_env <home> <VAR=value>... -- [args...]
run_install_env() {
    local home=$1
    shift
    local overrides=()
    while [ $# -gt 0 ] && [ "$1" != "--" ]; do
        overrides+=("$1")
        shift
    done
    [ $# -gt 0 ] && shift

    : > "$NPM_LOG"
    : > "$OUT"
    : > "$ERR"
    env -u MICROBOSS_CONFIG -u MICROBOSS_DATA -u MICROBOSS_CACHE \
        -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME \
        HOME="$home" PATH="$FAKEBIN:/usr/bin:/bin" \
        MICROBOSS_TEST_NPM_LOG="$NPM_LOG" "${overrides[@]}" \
        "$INSTALLER" "$@" > "$OUT" 2> "$ERR"
    STATUS=$?
}

npm_calls() {
    grep -c '^call: ci ' "$NPM_LOG" 2>/dev/null || true
}

micro_snapshot() {
    (cd "$TEST_HOME/.config/micro" && ls -A | sort && cat settings.json buffers)
}

tree_snapshot() {
    (cd "$1" && find . -type f -exec cksum {} + | sort)
}

# --- Syntax and executable bit ------------------------------------------------

if bash -n "$INSTALLER"; then
    ok "bash -n accepts scripts/install.sh"
else
    not_ok "bash -n accepts scripts/install.sh"
fi

check_true "scripts/install.sh is executable" '[ -x "$INSTALLER" ]'

# --- Default install ----------------------------------------------------------

TEST_HOME="$TMP/home"
mkdir -p "$TEST_HOME"
mkdir -p "$TEST_HOME/.config/micro"
printf 'user-owned\n' > "$TEST_HOME/.config/micro/settings.json"
printf 'buffer\n' > "$TEST_HOME/.config/micro/buffers"
MICRO_BEFORE=$(micro_snapshot)

DEFAULT_CONFIG="$TEST_HOME/.config/microboss"
DEFAULT_LAUNCHER="$TEST_HOME/.local/bin/microboss"
DEFAULT_DATA="$TEST_HOME/.local/share/microboss"
DEFAULT_TOOLS="$DEFAULT_DATA/tools"
DEFAULT_BACKUPS="$TEST_HOME/.cache/microboss/backups"

run_install "$TEST_HOME"
check_eq "default install exits 0" "$STATUS" "0"
check_true "config settings are copied" \
    'cmp -s "$SRC_CONFIG/settings.json" "$DEFAULT_CONFIG/settings.json"'
check_true "bindings and init.lua are copied" \
    '[ -f "$DEFAULT_CONFIG/bindings.json" ] && [ -f "$DEFAULT_CONFIG/init.lua" ]'
check_true "vendored plugins are copied" \
    '[ -f "$DEFAULT_CONFIG/plug/filemanager/filemanager.lua" ] &&
     [ -f "$DEFAULT_CONFIG/plug/fzf/main.lua" ]'
check_eq "plugin directories are not duplicated" \
    "$(find "$DEFAULT_CONFIG/plug" -mindepth 1 -maxdepth 1 -type d | wc -l |
        tr -d ' ')" \
    "$(find "$SRC_CONFIG/plug" -mindepth 1 -maxdepth 1 -type d | wc -l |
        tr -d ' ')"
check_eq "fzf is present exactly once" \
    "$(find "$DEFAULT_CONFIG/plug" -type d -name fzf | wc -l | tr -d ' ')" "1"
check_true "launcher is installed and executable" \
    '[ -x "$DEFAULT_LAUNCHER" ] && cmp -s "$REPO_ROOT/bin/microboss" "$DEFAULT_LAUNCHER"'
check_true "pinned manifest is copied into the data directory" \
    'cmp -s "$SRC_TOOLS/package.json" "$DEFAULT_TOOLS/package.json"'
check_true "pinned lockfile is copied into the data directory" \
    'cmp -s "$SRC_TOOLS/package-lock.json" "$DEFAULT_TOOLS/package-lock.json"'
check_eq "npm ci runs once" "$(npm_calls)" "1"
check_true "npm ci uses the installed toolchain prefix" \
    'grep -Fq "call: ci --prefix $DEFAULT_TOOLS --no-audit --no-fund" "$NPM_LOG"'
check_true "installer prints a summary" 'grep -q "install summary" "$OUT"'
check_true "summary reports the config copy" 'grep -q "config: copied" "$OUT"'
check_true "summary reports the installed launcher" \
    'grep -q "launcher: installed: $DEFAULT_LAUNCHER" "$OUT"'
check_true "summary reports the installed toolchain" \
    'grep -q "toolchain: npm ci installed" "$OUT"'
check_eq "existing ~/.config/micro is unchanged" \
    "$(micro_snapshot)" "$MICRO_BEFORE"

# --- Re-running is idempotent -------------------------------------------------

BEFORE=$(tree_snapshot "$DEFAULT_CONFIG"
    tree_snapshot "$DEFAULT_TOOLS"
    cksum < "$DEFAULT_LAUNCHER")
run_install "$TEST_HOME"
check_eq "re-run exits 0" "$STATUS" "0"
check_eq "re-run leaves installed files unchanged" \
    "$(tree_snapshot "$DEFAULT_CONFIG"
        tree_snapshot "$DEFAULT_TOOLS"
        cksum < "$DEFAULT_LAUNCHER")" "$BEFORE"
check_eq "re-run does not run npm ci again" "$(npm_calls)" "0"
check_true "re-run reports unchanged config files" \
    'grep -q "config: copied to .*0 new, 0 replaced" "$OUT"'
check_true "re-run reports the launcher unchanged" \
    'grep -q "launcher: unchanged" "$OUT"'
check_true "re-run reports the toolchain unchanged" \
    'grep -q "toolchain: unchanged" "$OUT"'
check_true "re-run creates no backup directory" '[ ! -d "$DEFAULT_BACKUPS" ]'
check_eq "re-run leaves ~/.config/micro unchanged" \
    "$(micro_snapshot)" "$MICRO_BEFORE"

# --- --no-tools ---------------------------------------------------------------

NOTOOLS_HOME="$TMP/home-no-tools"
mkdir -p "$NOTOOLS_HOME"
run_install "$NOTOOLS_HOME" --no-tools
check_eq "--no-tools exits 0" "$STATUS" "0"
check_true "--no-tools installs the config" \
    '[ -f "$NOTOOLS_HOME/.config/microboss/settings.json" ]'
check_true "--no-tools installs the launcher" \
    '[ -x "$NOTOOLS_HOME/.local/bin/microboss" ]'
check_true "--no-tools does not run npm" '[ ! -s "$NPM_LOG" ]'
check_true "--no-tools does not create a tools directory" \
    '[ ! -e "$NOTOOLS_HOME/.local/share/microboss/tools" ]'
check_true "--no-tools summary says the toolchain was skipped" \
    'grep -q "toolchain: skipped (--no-tools)" "$OUT"'

# --- --prefix -----------------------------------------------------------------

PREFIX_HOME="$TMP/home-prefix"
CUSTOM_BIN="$TMP/custom-bin"
mkdir -p "$PREFIX_HOME"
run_install "$PREFIX_HOME" --prefix "$CUSTOM_BIN" --no-tools
check_eq "--prefix exits 0" "$STATUS" "0"
check_true "--prefix installs the launcher elsewhere" \
    '[ -x "$CUSTOM_BIN/microboss" ]'
check_true "--prefix does not write the default launcher" \
    '[ ! -e "$PREFIX_HOME/.local/bin/microboss" ]'

# --- --dev and --force --------------------------------------------------------

DEV_HOME="$TMP/home-dev"
DEV_CONFIG="$DEV_HOME/.config/microboss"
DEV_BACKUPS="$DEV_HOME/.cache/microboss/backups"
mkdir -p "$DEV_HOME"

run_install "$DEV_HOME" --dev --no-tools
check_eq "--dev exits 0" "$STATUS" "0"
check_true "--dev creates a symlink" '[ -L "$DEV_CONFIG" ]'
check_true "--dev links to the repository config" \
    '[ "$DEV_CONFIG" -ef "$SRC_CONFIG" ]'
check_true "--dev summary reports the symlink" \
    'grep -q "config: symlinked" "$OUT"'

run_install "$DEV_HOME" --dev --no-tools
check_eq "--dev re-run exits 0" "$STATUS" "0"
check_true "--dev re-run keeps the symlink" \
    '[ -L "$DEV_CONFIG" ] && [ "$DEV_CONFIG" -ef "$SRC_CONFIG" ]'
check_true "--dev re-run reports the symlink unchanged" \
    'grep -q "config: symlink already points" "$OUT"'

# Copying over a --dev symlink needs an explicit --force.
run_install "$DEV_HOME" --no-tools
check_true "copy over a dev symlink fails without --force" '[ "$STATUS" -ne 0 ]'
check_true "failed copy leaves the symlink in place" \
    '[ -L "$DEV_CONFIG" ] && [ "$DEV_CONFIG" -ef "$SRC_CONFIG" ]'
check_true "failed copy tells the user about --force" \
    'grep -q -- "--force" "$ERR"'

run_install "$DEV_HOME" --force --no-tools
check_eq "forced copy over a symlink exits 0" "$STATUS" "0"
check_true "forced copy replaces the symlink with a directory" \
    '[ ! -L "$DEV_CONFIG" ] && [ -d "$DEV_CONFIG" ]'
check_true "forced copy installs real files" \
    'cmp -s "$SRC_CONFIG/settings.json" "$DEV_CONFIG/settings.json"'
check_true "forced copy backs up the old symlink" \
    'find "$DEV_BACKUPS" -type l -name config | grep -q .'
check_true "forced copy summary reports a backup" \
    'grep -q "backup:" "$OUT"'

# A modified file needs --force, and the old content is backed up.
printf 'local edit\n' >> "$DEV_CONFIG/settings.json"
EDITED=$(cat "$DEV_CONFIG/settings.json")

run_install "$DEV_HOME" --no-tools
check_true "modified config fails without --force" '[ "$STATUS" -ne 0 ]'
check_eq "modified config is untouched without --force" \
    "$(cat "$DEV_CONFIG/settings.json")" "$EDITED"
check_true "modified config failure names the file" \
    'grep -q "settings.json" "$ERR"'
check_true "modified config failure suggests --force" \
    'grep -q -- "--force" "$ERR"'

run_install "$DEV_HOME" --force --no-tools
check_eq "forced config repair exits 0" "$STATUS" "0"
check_eq "forced config repair restores the managed file" \
    "$(cat "$DEV_CONFIG/settings.json")" "$(cat "$SRC_CONFIG/settings.json")"
check_true "forced config repair backs up the edited file" \
    'grep -r -q "local edit" "$DEV_BACKUPS"'
check_true "forced config repair summary reports the replacement" \
    'grep -q "0 new, 1 replaced" "$OUT"'

# --- Summary ------------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
