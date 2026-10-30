#!/usr/bin/env bash
# Refresh the portable slopboss board snapshot from a live board.
set -euo pipefail

BOARD_DIR="${1:-$HOME/projects/microboss-board}"
HERE="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BOARD_FILES=(
  AGENTS.md
  ARCHIVE.md
  BACKLOG.md
  CONFIG.md
  DEV_AGENT.md
  TASKS.md
  TEAM_LEAD_AGENT.md
  TECH.md
)

if [ ! -d "$BOARD_DIR" ]; then
  printf 'error: board directory does not exist: %s\n' "$BOARD_DIR" >&2
  exit 1
fi

mkdir -p "$HERE/board"
for file in "${BOARD_FILES[@]}"; do
  if [ ! -f "$BOARD_DIR/$file" ]; then
    printf 'error: missing board file: %s/%s\n' "$BOARD_DIR" "$file" >&2
    exit 1
  fi
  cp "$BOARD_DIR/$file" "$HERE/board/$file"
  printf 'backed up %s\n' "$file"
done

printf '\nSnapshot refreshed in %s/board\n' "$HERE"
printf 'Review and commit the changes before relying on them on another machine.\n'
