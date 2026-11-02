#!/bin/sh
# microboss installer.
#
# Installs the isolated Micro configuration, links the launcher onto PATH, and
# installs the pinned language-server toolchain. Safe to re-run: unchanged files
# are reported and left alone, and --force backs up an existing managed file
# before replacing it.
#
# POSIX sh only: no bashisms, and every directory can be overridden through the
# same environment variables the launcher uses, which keeps tests and alternate
# installs away from the real user directories.

set -u

PROGRAM=microboss
MICRO_MIN_VERSION=2.0.13

DEV=0
INSTALL_TOOLS=1
FORCE=0
PREFIX=

die() {
    printf '%s: %s\n' "$PROGRAM" "$1" >&2
    exit "${2:-1}"
}

usage() {
    cat <<'EOF'
Usage: install.sh [options]

Options:
  --dev         Symlink the repository config instead of copying it.
  --no-tools    Install configuration only; skip the pinned toolchain.
  --prefix DIR  Install the launcher in DIR (default: $HOME/.local/bin).
  --force       Back up and replace existing microboss-managed files.
  -h, --help    Show this help.
EOF
}

# Print the directory that contains the real installer file. $1 is the path this
# script was invoked as ($0), which may be relative or a symlink.
resolve_script_dir() {
    _mb_script=$1
    case $_mb_script in
        */*) ;;
        *)
            _mb_script=$(command -v "$_mb_script" 2>/dev/null) ||
                die "cannot locate the installer on PATH" 127
            ;;
    esac
    while [ -L "$_mb_script" ]; do
        _mb_dir=$(CDPATH= cd -P "$(dirname "$_mb_script")" 2>/dev/null && pwd) ||
            die "cannot resolve the installer directory"
        _mb_target=$(readlink "$_mb_script") ||
            die "cannot resolve the installer symlink: $_mb_script"
        case $_mb_target in
            /*) _mb_script=$_mb_target ;;
            *) _mb_script=$_mb_dir/$_mb_target ;;
        esac
    done
    CDPATH= cd -P "$(dirname "$_mb_script")" && pwd
}

while [ $# -gt 0 ]; do
    case $1 in
        --dev) DEV=1 ;;
        --no-tools) INSTALL_TOOLS=0 ;;
        --force) FORCE=1 ;;
        --prefix)
            [ $# -ge 2 ] || die "--prefix needs a directory" 2
            PREFIX=$2
            shift
            ;;
        --prefix=*) PREFIX=${1#--prefix=} ;;
        -h|--help)
            usage
            exit 0
            ;;
        *) die "unknown option: $1 (try --help)" 2 ;;
    esac
    shift
done

if [ -z "${HOME:-}" ]; then
    die "HOME is not set; microboss needs it to find its config, data, and cache directories"
fi

SCRIPT_DIR=$(resolve_script_dir "$0") || exit 1
REPO_ROOT=$(dirname "$SCRIPT_DIR")
CONFIG_SRC=$REPO_ROOT/config
LAUNCHER_SRC=$REPO_ROOT/bin/microboss
TOOLS_SRC=$REPO_ROOT/tools

for _src in "$CONFIG_SRC" "$LAUNCHER_SRC"; do
    [ -e "$_src" ] || die "distribution is incomplete: missing $_src"
done

CONFIG_DIR=${MICROBOSS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/microboss}
DATA_DIR=${MICROBOSS_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/microboss}
CACHE_DIR=${MICROBOSS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/microboss}

if [ -z "$PREFIX" ]; then
    PREFIX=$HOME/.local/bin
fi
case $PREFIX in
    /*) ;;
    *) PREFIX=$(pwd)/$PREFIX ;;
esac

RUN_TMP=${TMPDIR:-/tmp}/microboss-install.$$
mkdir -p "$RUN_TMP" || die "cannot create temporary directory: $RUN_TMP"
trap 'rm -rf "$RUN_TMP"' EXIT HUP INT TERM

SUMMARY=
CHANGED=0

summary_line() {
    SUMMARY="$SUMMARY  $1
"
}

changed_line() {
    CHANGED=$((CHANGED + 1))
    summary_line "$1"
}

BACKUP_ROOT=$CACHE_DIR/backups
BACKUP_DIR=

# backup_item <path> <name>: copy a file, directory, or symlink into a
# per-run backup directory under the cache. The summary records the location so
# the user can restore it by hand.
backup_item() {
    _backup_src=$1
    _backup_name=$2
    if [ -z "$BACKUP_DIR" ]; then
        _backup_stamp=$(date +%Y%m%d%H%M%S 2>/dev/null) || _backup_stamp=backup
        BACKUP_DIR=$BACKUP_ROOT/$_backup_stamp-$$
        mkdir -p "$BACKUP_DIR" ||
            die "cannot create backup directory: $BACKUP_DIR"
    fi
    _backup_dest=$BACKUP_DIR/$_backup_name
    mkdir -p "$(dirname "$_backup_dest")" ||
        die "cannot create backup directory for $_backup_src"
    if [ -L "$_backup_src" ]; then
        ln -s "$(readlink "$_backup_src")" "$_backup_dest" ||
            die "cannot back up $_backup_src"
    elif [ -d "$_backup_src" ]; then
        cp -R "$_backup_src" "$_backup_dest" ||
            die "cannot back up $_backup_src"
    else
        cp -p "$_backup_src" "$_backup_dest" ||
            die "cannot back up $_backup_src"
    fi
    summary_line "backup: $_backup_src -> $_backup_dest"
}

remove_path() {
    if [ -L "$1" ] || [ -f "$1" ]; then
        rm -f "$1"
    else
        rm -rf "$1"
    fi
}

# list_config_conflicts: print the relative paths that differ between the
# repository config and an existing installed copy. A non-directory target is
# reported as the single entry "config".
list_config_conflicts() {
    if [ -L "$CONFIG_DIR" ]; then
        printf '%s\n' config
        return 0
    fi
    if [ -e "$CONFIG_DIR" ] && [ ! -d "$CONFIG_DIR" ]; then
        printf '%s\n' config
        return 0
    fi
    [ -d "$CONFIG_DIR" ] || return 0

    find "$CONFIG_SRC" -mindepth 1 -type f -print > "$RUN_TMP/config-files" ||
        die "cannot list $CONFIG_SRC"
    while IFS= read -r _src; do
        _rel=${_src#"$CONFIG_SRC"/}
        _dest=$CONFIG_DIR/$_rel
        if [ -e "$_dest" ] && ! cmp -s "$_src" "$_dest"; then
            printf '%s\n' "$_rel"
        fi
    done < "$RUN_TMP/config-files"
}

# copy_config: copy the repository config file by file so an idempotent re-run
# can report what changed and --force can back up only the files it replaces.
copy_config() {
    _new=0
    _replaced=0
    _unchanged=0

    find "$CONFIG_SRC" -mindepth 1 -print > "$RUN_TMP/config-entries" ||
        die "cannot list $CONFIG_SRC"
    while IFS= read -r _src; do
        _rel=${_src#"$CONFIG_SRC"/}
        _dest=$CONFIG_DIR/$_rel

        if [ -d "$_src" ] && [ ! -L "$_src" ]; then
            if [ -e "$_dest" ] && [ ! -d "$_dest" ]; then
                backup_item "$_dest" "config/$_rel"
                remove_path "$_dest" ||
                    die "cannot remove conflicting path: $_dest"
                _replaced=$((_replaced + 1))
            fi
            [ -d "$_dest" ] || mkdir -p "$_dest" ||
                die "cannot create config directory: $_dest"
            continue
        fi

        if [ -e "$_dest" ] || [ -L "$_dest" ]; then
            if [ ! -L "$_dest" ] && cmp -s "$_src" "$_dest"; then
                _unchanged=$((_unchanged + 1))
                continue
            fi
            backup_item "$_dest" "config/$_rel"
            remove_path "$_dest" ||
                die "cannot remove old config file: $_dest"
            _replaced=$((_replaced + 1))
        else
            _new=$((_new + 1))
        fi

        cp -p "$_src" "$_dest" || die "cannot copy $_src to $_dest"
    done < "$RUN_TMP/config-entries"

    if [ $((_new + _replaced)) -gt 0 ]; then
        CHANGED=$((CHANGED + 1))
    fi
    summary_line "config: copied to $CONFIG_DIR ($_new new, $_replaced replaced, $_unchanged unchanged)"
}

config_is_dev_link() {
    [ -L "$CONFIG_DIR" ] || return 1
    _dev_target=$(CDPATH= cd -P "$CONFIG_DIR" 2>/dev/null && pwd) || return 1
    [ "$_dev_target" = "$CONFIG_SRC" ]
}

install_config() {
    if [ "$DEV" -eq 1 ]; then
        if config_is_dev_link; then
            summary_line "config: symlink already points $CONFIG_DIR -> $CONFIG_SRC"
            return 0
        fi
        if [ -e "$CONFIG_DIR" ] || [ -L "$CONFIG_DIR" ]; then
            [ "$FORCE" -eq 1 ] ||
                die "config: $CONFIG_DIR already exists; rerun with --force to back it up and replace it"
            backup_item "$CONFIG_DIR" config
            remove_path "$CONFIG_DIR" ||
                die "cannot remove old config: $CONFIG_DIR"
        fi
        mkdir -p "$(dirname "$CONFIG_DIR")" ||
            die "cannot create config parent directory: $(dirname "$CONFIG_DIR")"
        ln -s "$CONFIG_SRC" "$CONFIG_DIR" ||
            die "cannot symlink $CONFIG_DIR -> $CONFIG_SRC"
        changed_line "config: symlinked $CONFIG_DIR -> $CONFIG_SRC"
        return 0
    fi

    CONFLICTS=$(list_config_conflicts)
    if [ -n "$CONFLICTS" ]; then
        if [ "$FORCE" -ne 1 ]; then
            printf '%s\n' "$CONFLICTS" > "$RUN_TMP/config-conflicts"
            _listing=$(sed 's/^/  /' "$RUN_TMP/config-conflicts")
            die "config: refusing to overwrite local changes in $CONFIG_DIR:
$_listing
rerun with --force to back them up and replace them"
        fi
        # A symlink or file at the config path has to be moved out of the way
        # before the directory can be populated file by file.
        if [ -L "$CONFIG_DIR" ] ||
            { [ -e "$CONFIG_DIR" ] && [ ! -d "$CONFIG_DIR" ]; }; then
            backup_item "$CONFIG_DIR" config
            remove_path "$CONFIG_DIR" ||
                die "cannot remove old config: $CONFIG_DIR"
        fi
    fi

    mkdir -p "$(dirname "$CONFIG_DIR")" ||
        die "cannot create config parent directory: $(dirname "$CONFIG_DIR")"
    [ -d "$CONFIG_DIR" ] || mkdir -p "$CONFIG_DIR" ||
        die "cannot create config directory: $CONFIG_DIR"
    copy_config
}

LAUNCHER_DEST=

launcher_is_current() {
    [ -L "$LAUNCHER_DEST" ] || return 1
    _launcher_current=$(readlink "$LAUNCHER_DEST") || return 1
    case $_launcher_current in
        /*) ;;
        *) _launcher_current=$PREFIX/$_launcher_current ;;
    esac
    _launcher_dir=$(CDPATH= cd -P "$(dirname "$_launcher_current")" 2>/dev/null && pwd) ||
        return 1
    [ "$_launcher_dir/$(basename "$_launcher_current")" = "$LAUNCHER_SRC" ]
}

is_managed_launcher() {
    [ -f "$1" ] || return 1
    grep -q "microboss launcher" "$1" 2>/dev/null
}

install_launcher() {
    LAUNCHER_DEST=$PREFIX/microboss

    if launcher_is_current; then
        summary_line "launcher: unchanged ($LAUNCHER_DEST)"
        return 0
    fi

    if [ -e "$LAUNCHER_DEST" ] || [ -L "$LAUNCHER_DEST" ]; then
        if [ "$FORCE" -ne 1 ]; then
            if is_managed_launcher "$LAUNCHER_DEST"; then
                summary_line "launcher: existing file kept ($LAUNCHER_DEST; use --force to replace)"
                return 0
            fi
            die "refusing to replace unmanaged file: $LAUNCHER_DEST (use --force to back it up and replace it)" 2
        fi
        backup_item "$LAUNCHER_DEST" launcher
        remove_path "$LAUNCHER_DEST" ||
            die "cannot remove old launcher: $LAUNCHER_DEST"
    fi

    mkdir -p "$PREFIX" || die "cannot create launcher directory: $PREFIX"
    ln -s "$LAUNCHER_SRC" "$LAUNCHER_DEST" ||
        die "cannot symlink $LAUNCHER_DEST -> $LAUNCHER_SRC"
    changed_line "launcher: installed: $LAUNCHER_DEST -> $LAUNCHER_SRC"
}

supported_node() {
    _node_raw=$(node --version 2>/dev/null) || return 1
    _node_version=${_node_raw#v}
    _node_major=${_node_version%%.*}
    _node_rest=${_node_version#*.}
    _node_minor=${_node_rest%%.*}
    case $_node_major in
        ''|*[!0-9]*) return 1 ;;
    esac
    case $_node_minor in
        ''|*[!0-9]*) _node_minor=0 ;;
    esac
    if [ "$_node_major" -eq 20 ]; then
        [ "$_node_minor" -ge 19 ]
        return $?
    fi
    if [ "$_node_major" -eq 22 ]; then
        [ "$_node_minor" -ge 12 ]
        return $?
    fi
    [ "$_node_major" -ge 24 ]
}

install_tools() {
    if [ "$INSTALL_TOOLS" -ne 1 ]; then
        summary_line "toolchain: skipped (--no-tools)"
        return 0
    fi

    command -v node >/dev/null 2>&1 ||
        die "node not found on PATH; install Node.js ^20.19.0 || ^22.12.0 || >=24.0.0, or rerun with --no-tools" 127
    command -v npm >/dev/null 2>&1 ||
        die "npm not found on PATH; install npm, or rerun with --no-tools" 127
    if ! supported_node; then
        die "unsupported Node.js version $(node --version 2>/dev/null); microboss needs ^20.19.0 || ^22.12.0 || >=24.0.0 (or rerun with --no-tools)"
    fi

    TOOLS_DIR=$DATA_DIR/tools
    mkdir -p "$TOOLS_DIR" ||
        die "cannot create tool directory: $TOOLS_DIR"

    _manifests_changed=0
    for _file in package.json package-lock.json; do
        [ -f "$TOOLS_SRC/$_file" ] ||
            die "missing pinned toolchain file: $TOOLS_SRC/$_file"
        if [ ! -f "$TOOLS_DIR/$_file" ] ||
            ! cmp -s "$TOOLS_SRC/$_file" "$TOOLS_DIR/$_file"; then
            if [ -f "$TOOLS_DIR/$_file" ]; then
                backup_item "$TOOLS_DIR/$_file" "tools-$_file"
            fi
            cp "$TOOLS_SRC/$_file" "$TOOLS_DIR/$_file" ||
                die "cannot install $TOOLS_DIR/$_file"
            _manifests_changed=1
        fi
    done

    if [ "$FORCE" -ne 1 ] && [ "$_manifests_changed" -eq 0 ] &&
        [ -d "$TOOLS_DIR/node_modules/.bin" ]; then
        summary_line "toolchain: unchanged ($TOOLS_DIR)"
        return 0
    fi

    printf 'Installing pinned language-server toolchain in %s...\n' "$TOOLS_DIR"
    npm ci --prefix "$TOOLS_DIR" --no-audit --no-fund --ignore-scripts ||
        die "npm ci failed in $TOOLS_DIR"
    changed_line "toolchain: npm ci installed ($TOOLS_DIR)"
}

install_config
install_launcher
install_tools

if command -v micro >/dev/null 2>&1; then
    summary_line "micro: found on PATH"
else
    summary_line "micro: not found on PATH (install Micro $MICRO_MIN_VERSION or newer before launching)"
fi

printf '\n%s install summary\n' "$PROGRAM"
printf '%s' "$SUMMARY"
printf '  changed: %d item(s)\n\n' "$CHANGED"
