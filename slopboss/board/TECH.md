# TECH

microboss is an opinionated, LazyVim-style distribution of the Micro terminal
editor for TypeScript, React, and Angular development. It ships an isolated
configuration, VS Code-like bindings, a file explorer, fuzzy finding, and pinned
language-server tooling. It runs inside an existing terminal tab (Tilix, tmux,
SSH); embedding a terminal is explicitly out of scope.

## Technology Stack

- Language: POSIX shell for the launcher/installer; Lua for Micro helpers; JSON
  for Micro settings and bindings.
- Editor: Micro 2.0.13 (tested baseline; 2.0.15 is current upstream and is
  evaluated in a separate upgrade task).
- Plugins: Micro `lsp` 0.6.2 (vendored and patched), `filemanager` 3.5.1, and
  `fzf` 1.1.1.
- Toolchain: Node.js `^20.19.0 || ^22.12.0 || >=24.0.0`, npm, TypeScript 5.9.x,
  `typescript-language-server` 5.3.x, `vscode-langservers-extracted` 4.10.x,
  and `@angular/language-server` 21.2.x (binary `ngserver`).
- Target projects: React 19 + Vite + TypeScript; Angular 21 CLI workspaces.
- Platform: Linux and macOS first; Windows through WSL is best-effort.

## Architecture

- `bin/microboss` launches Micro with `-config-dir ~/.config/microboss`.
- `config/` contains settings, bindings, `init.lua`, and vendored plugins.
- `~/.local/share/microboss/tools` contains the pinned language-server toolchain.
- `~/.cache/microboss` contains disposable caches and test artifacts.
- The installer never modifies `~/.config/micro`.
- The LSP dispatcher chooses one server per `(server, project root)` pair and
  supports nested `tsconfig.json` files and Angular workspaces.

## Commands

- Install (planned): `./scripts/install.sh --dev`
- Test (launcher): `bash tests/smoke/test_launcher.sh`
- Test (full suite, planned): `./scripts/smoke.sh`
- Build / typecheck: `bash -n bin/microboss` and `bash -n tests/smoke/*.sh`
- Lint / format: `git diff --check`; validate JSON with `jq empty config/*.json`
  when config files exist.

Phase 1 is in progress. Only run commands that exist in the branch; do not assume
planned install or smoke scripts are present yet.

## Tooling & Token Efficiency

- Lean test reporter flags: not applicable until the shell test harness exists.
- Targeted test syntax: run the smallest command listed above for the files
  changed; use `git diff --check` before every commit.
- Keep command output short. Do not paste full directory listings or logs into
  task notes; summarize and link to the relevant path.

## Conventions

- Directory layout: `bin/`, `config/`, `scripts/`, `docs/`, `tests/`, and
  `tools/` as described in `PLAN.md`.
- Documentation: update the relevant `docs/` page whenever behavior changes.
- Testing: add a focused test for every behavior change; keep fixtures
  self-contained and copy them to a temporary directory before editing.
- Definition of done: the task's acceptance criteria pass, targeted verification
  passes, changes are committed, the branch is squash-merged to `main`, and the
  task is moved to `ARCHIVE.md`.
- Avoid: modifying `/home/dangelov/.config/micro`, editing real user projects,
  adding unpinned dependencies, and adding embedded-terminal support.
