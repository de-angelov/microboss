#!/usr/bin/env bash
# Restore the portable slopboss board snapshot and its workspaces.
set -euo pipefail

BOARD_DIR="${1:-$HOME/projects/microboss-board}"
SLOPBOSS_BIN="${SLOPBOSS_BIN:-slopboss}"
REPO_URL="${MICROBOSS_REPO_URL:-git@github.com:de-angelov/microboss.git}"
BRANCH="${MICROBOSS_BASE_BRANCH:-main}"
HERE="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v "$SLOPBOSS_BIN" >/dev/null 2>&1; then
  printf 'error: slopboss not found on PATH (set SLOPBOSS_BIN to override)\n' >&2
  exit 1
fi

if [ -e "$BOARD_DIR/BACKLOG.md" ]; then
  printf 'warning: an existing board was found at %s\n' "$BOARD_DIR" >&2
  printf '         the snapshot files will replace its board/config files\n' >&2
fi

mkdir -p "$BOARD_DIR"

# Create/reuse the workspaces and scaffold any missing board files. The snapshot
# is copied afterward so the active task, archive, model pins, and conventions
# are restored exactly.
"$SLOPBOSS_BIN" setup \
  --dir "$BOARD_DIR" \
  --repo "$REPO_URL" \
  --branch "$BRANCH" \
  --agents 1 \
  --provider opencode \
  --skip-interview

cp -f "$HERE/board/"*.md "$BOARD_DIR"/

printf '\nRestored slopboss board in %s\n' "$BOARD_DIR"
printf 'Start the single agent with:\n'
printf '  %s run --dir %s\n' "$SLOPBOSS_BIN" "$BOARD_DIR"
