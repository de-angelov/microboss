# FunScript language server

`scripts/funscript-lsp.sh` is a small adapter that starts the FunScript language
server. It resolves the FunScript CLI and replaces itself with:

```sh
funscript lsp --stdio
```

On success the launcher itself writes nothing to standard output or standard
error and does not redirect the server's streams, so LSP JSON-RPC traffic stays
intact. When FunScript is not installed it prints an actionable message to
standard error and exits with status 127.

## Prerequisites

Install FunScript following the upstream instructions at
<https://github.com/de-angelov/funscript>. The package provides the `funscript`
executable.

- Project-local (recommended): `npm install --save-dev funscript` creates
  `node_modules/.bin/funscript`.
- Global: install the package so `funscript` is on `PATH`.

FunScript is experimental. Pin it in the project's lockfile so the language
server matches the source being edited.

## Resolution order

Run the launcher with the project root as the current working directory. It
selects the first executable it finds:

1. `<cwd>/node_modules/.bin/funscript`
2. `funscript` on `PATH`

There is no hard-coded install location. A project-local install wins over a
global one. A project-local entry that exists but is not executable is skipped,
so the `PATH` install is still usable.

## Usage

```sh
cd path/to/funscript-project
/path/to/microboss/scripts/funscript-lsp.sh
```

The process speaks the Language Server Protocol over stdin and stdout. A missing
executable produces:

```text
funscript-lsp: FunScript executable not found: looked in ./node_modules/.bin/funscript and on PATH. Install it in the project (npm install --save-dev funscript) or globally. See https://github.com/de-angelov/funscript.
```

## Micro wiring

This page documents the launcher only. Wiring it into Micro's `lsp` plugin,
`settings.json`, and the per-project dispatcher is a follow-up task; the current
microboss configuration does not start the FunScript server automatically.

## Verification

```sh
bash -n scripts/funscript-lsp.sh
bash tests/smoke/test_funscript_lsp_launcher.sh
```

The smoke test uses temporary projects and fake `funscript` executables to check
project-local selection, `PATH` fallback, argument forwarding, stdio passthrough,
and the missing-server message.
