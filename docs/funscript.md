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

Microboss configures the `funscript` filetype to start `funscript-lsp`, the
adapter in `scripts/funscript-lsp.sh`. The `microboss` launcher adds its
installation's `scripts/` directory to `PATH`, so the adapter works when Micro
starts from a project directory. Both `.fun` and `.funx` are detected as the
Micro filetype `funscript`; the LSP plugin sends `funscript` as the language ID
for both, keeping them separate from the TypeScript route.

Press `Alt+K` on a symbol to open hover information in a split. Close that
split with `Ctrl+Q` to return to the source file.

Run `microboss path/to/project` to open a folder with its file tree. Use
`Ctrl+W` to switch panes, arrow keys to navigate, `Enter` or `Tab` to open a file or
enter a directory, and `F2` to toggle the tree. `Ctrl+P` opens fuzzy file
search when `fzf` is installed.

Install FunScript in the project or globally as described above, then open a
`.fun` or `.funx` file with `microboss`. To verify the wiring, start Micro from
the project root and inspect its LSP log for `Starting server funscript`. The
adapter's missing-server error names the searched locations and gives the
project-local and global installation options. If launching Micro directly
instead of through `microboss`, put the installation's `scripts/` directory on
`PATH` so Micro can find `funscript-lsp`.

## Verification

```sh
bash -n scripts/funscript-lsp.sh
bash tests/smoke/test_funscript_lsp_launcher.sh
```

The smoke test uses temporary projects and fake `funscript` executables to check
project-local selection, `PATH` fallback, argument forwarding, stdio passthrough,
and the missing-server message.
