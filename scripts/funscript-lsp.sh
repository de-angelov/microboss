#!/bin/sh
# FunScript language-server launcher.
#
# Resolves the FunScript CLI from the current project first, then from PATH, and
# replaces itself with `funscript lsp --stdio`. Standard input, output, and error
# are left untouched so the editor and the server can speak LSP over stdio.

set -u

PROGRAM=funscript-lsp
FUNSCRIPT_URL=https://github.com/de-angelov/funscript

die() {
    printf '%s: %s\n' "$PROGRAM" "$1" >&2
    exit "${2:-1}"
}

# Prefer the project's pinned install. The project root is the current working
# directory, which is how an editor starts a project-scoped language server.
PROJECT_DIR=$(pwd -P 2>/dev/null) || PROJECT_DIR=
if [ -n "$PROJECT_DIR" ] &&
    [ -f "$PROJECT_DIR/node_modules/.bin/funscript" ] &&
    [ -x "$PROJECT_DIR/node_modules/.bin/funscript" ]; then
    FUNSCRIPT=$PROJECT_DIR/node_modules/.bin/funscript
else
    FUNSCRIPT=$(command -v funscript 2>/dev/null) || FUNSCRIPT=
    if [ -z "$FUNSCRIPT" ] || [ ! -f "$FUNSCRIPT" ] || [ ! -x "$FUNSCRIPT" ]; then
        die "FunScript executable not found: looked in ./node_modules/.bin/funscript and on PATH. Install it in the project (npm install --save-dev funscript) or globally. See $FUNSCRIPT_URL." 127
    fi
fi

exec "$FUNSCRIPT" lsp --stdio
