# ARCHIVE

Completed work history. Normal orchestrator prompts do not load this file.

## Done

### Pinned language-server toolchain

Task ID: TOOLS-01
Owner: Dev Agent 1
Branch: agent/1/tools-01-toolchain
Status: Done
Completed: 2026-11-01
Category: AFK

## Result

- Added `tools/package.json` and `tools/package-lock.json` with exact pins for
  `typescript` 5.9.3, `typescript-language-server` 5.3.0,
  `vscode-langservers-extracted` 4.10.0, and `@angular/language-server` 21.2.25.
- `tests/smoke/test_tools.sh` validates the manifest and lockfile pins and runs
  `npm ci` with temporary cache/log directories under `tests/tmp`.
- `tools/node_modules/typescript/lib/tsserver.js` is present after install.

## Verification

```sh
npm ci --prefix tools --ignore-scripts
npm ls --prefix tools --depth=0
bash tests/smoke/test_tools.sh
```

- `npm ci --prefix tools --ignore-scripts` exit 0; 37 packages installed.
- `npm ls --prefix tools --depth=0` reports the four exact versions.
- `bash tests/smoke/test_tools.sh`: 23 passed, 0 failed.
- Squash commit `d0b1596` on `main`; `git merge-base --is-ancestor d0b1596
  origin/main` exit 0.

### Vendor fzf and project-aware ignores

Task ID: PLUG-02
Owner: Dev Agent 1
Branch: agent/1/plug-02-fzf
Status: Done
Completed: 2026-11-01
Category: AFK

## Result

- Vendored fzf 1.1.1 under `config/plug/fzf` with `VERSION`, `repo.json`,
  `README.md`, and a small `main.lua` patch that reports a missing `fzf` binary
  in the info bar.
- Launcher exports `FZF_DEFAULT_COMMAND` via `rg --files` with
  `.git`/`node_modules`/`dist`/`coverage` excludes and a portable `find`
  fallback.
- `Ctrl+P` remains mapped to `command:fzf`.
- `tests/smoke/test_fzf.sh`: static checks, both launcher paths, and a
  missing-fzf tmux integration test using a unique socket and temporary `HOME`.
- `docs/keymap.md` and `docs/architecture.md` document quick open and the
  project-aware listing behavior.

## Verification

```sh
jq empty config/bindings.json
bash tests/smoke/test_fzf.sh
bash tests/smoke/test_launcher.sh
bash tests/smoke/test_bindings.sh
```

- `bash tests/smoke/test_fzf.sh`: 29 passed, 0 failed.
- `bash tests/smoke/test_launcher.sh`: 42 passed, 0 failed.
- `bash tests/smoke/test_bindings.sh`: 120 passed, 0 failed.
- Squash commit `895c861` on `main`; `git merge-base --is-ancestor 895c861
  origin/main` exit 0.

### Validate the microboss plan and produce the implementation backlog

Task ID: PLAN-01
Owner: Dev Agent 1
Branch: agent/1/plan-review
Status: Done
Completed: 2026-10-30

## Objective

Validate `PLAN.md` against the actual Micro 2.0.13 capabilities and produce a
concrete, dependency-ordered implementation backlog for microboss. Planning only.

## Result

- `docs/plan-review.md` added: validation table, evidence sources, a
  recommended first vertical slice, 20 dependency-ordered tasks
  (`FOUND-01` through `RELEASE-01`), and HITL risks.
- `PLAN.md` corrected for factual accuracy: pinned Micro 2.0.13 baseline
  (2.0.15 deferred to a separate upgrade task), bindable keymap only, real
  `-options` names, filemanager/fzf defaults, LSP plugin 0.6.2 limitations,
  Angular language-server Node range, rename/code-action deferral, and the
  `detectindent` plugin.
- Embedded terminal confirmed available in Micro but explicitly out of scope.

## Verification

```sh
test -f docs/plan-review.md
test "$(grep -c '^### ' docs/plan-review.md)" -ge 12
git diff --check
```

- `docs/plan-review.md` present; 20 task headings (>= 12).
- `git diff --check` exit 0.
- Squash commit `d42db54` on `main`; `git merge-base --is-ancestor d42db54
  origin/main` exit 0.

## Follow-up

- `TECH.md` still mentions an integrated terminal and `Micro 2.0.13+`. It
  conflicts with the out-of-scope decision and the pinned baseline; the Team
  Lead should align it.

### Repository skeleton and isolated launcher

Task ID: FOUND-01
Owner: Dev Agent 1
Branch: agent/1/found-01-launcher
Status: Done
Completed: 2026-10-30

## Objective

Add the minimal distribution skeleton and a launcher that starts Micro with an
isolated config directory.

## Result

- `bin/microboss`: POSIX `sh` launcher that resolves its own path through
  symlinks, exports `MICROBOSS_ROOT`, `MICROBOSS_CONFIG`, `MICROBOSS_DATA`, and
  `MICROBOSS_CACHE`, fails with an actionable message when `micro` is missing,
  and execs `micro -config-dir "$MICROBOSS_CONFIG" "$@"`.
- Directories default under `HOME` with XDG support
  (`${XDG_CONFIG_HOME:-$HOME/.config}/microboss` and equivalents) and remain
  overridable through the three `MICROBOSS_*` variables.
- `config/.gitkeep`, `tests/fixtures/empty/.gitkeep`, and a
  `docs/architecture.md` stub.
- `tests/smoke/test_launcher.sh`: 33 assertions using a temporary `HOME` and a
  fake `micro`; covers default and overridden directories, XDG bases, argument
  passthrough (`FILE`, `+LINE:COL`, `--`), symlinked invocation, POSIX `sh`
  invocation, missing `micro`, and that `~/.config/micro` is neither created nor
  modified.

## Verification

```sh
bash -n bin/microboss
bash tests/smoke/test_launcher.sh
```

- `bash -n bin/microboss` exit 0; `sh -n bin/microboss` exit 0.
- `bash tests/smoke/test_launcher.sh`: 33 passed, 0 failed (re-run on `main`
  after the squash merge).
- `git diff --check` exit 0.
- Squash commit `dd20fed` on `main`; `git merge-base --is-ancestor dd20fed
  origin/main` exit 0.

### Add default editor settings

Task ID: CONF-01
Owner: Dev Agent 1
Branch: agent/1/conf-01-settings
Status: Done
Completed: 2026-10-30

## Objective

Ship a valid `config/settings.json` with the editor defaults in `PLAN.md` §5.1
using exact Micro 2.0.13 option names.

## Result

- `config/settings.json`: mouse, ruler, statusline, saveundo, backup,
  autoindent, rmtrailingws, paste, and smartpaste enabled; softwrap disabled;
  `backupdir` set to `~/.cache/microboss`; `clipboard` set to `terminal`;
  `scrollspeed` kept at Micro's default of 2.
- `tests/smoke/test_settings.sh`: 42 assertions covering JSON validity, the
  presence and JSON type of every required setting, expected default values,
  portable `backupdir`, and the absence of a `~/.config/micro` reference.
- Removed the now-obsolete `config/.gitkeep` placeholder.

## Verification

```sh
jq empty config/settings.json
bash tests/smoke/test_settings.sh
git diff --check
```

- `jq empty config/settings.json` exit 0.
- `bash tests/smoke/test_settings.sh`: 42 passed, 0 failed (re-run on `main`
  after the squash merge).
- `git diff --check` exit 0.
- Squash commit `360c522` on `main`; `git merge-base --is-ancestor 360c522
  origin/main` exit 0.

### Add VS Code-like keymap and validation

Task ID: KEY-01
Owner: Dev Agent 1
Branch: agent/1/key-01-bindings
Status: Done
Completed: 2026-10-30

## Objective

Ship a `bindings.json` that uses only keys Micro 2.0.13 can bind, and document
the differences from VS Code.

## Result

- `config/bindings.json`: VS Code-like keymap covering the explorer, fzf quick
  open, command mode, quit, tabs, splits, search, LSP navigation, completion and
  formatting, comments, multi-cursor editing, line editing, and soft wrap. Keys
  use Micro spellings without `+` separators.
- `config/init.lua`: `toggle_softwrap` helper for `Alt+Z`; Micro 2.0.13 has no
  built-in soft-wrap toggle action.
- `docs/keymap.md`: quick-reference table plus the unavoidable terminal and
  Micro differences (`Ctrl+Shift`, `Ctrl+Tab`, `Ctrl+\``, `Shift+Escape`,
  missing `CloseTab`, directional duplicate-line, `Ctrl+/`, and `Ctrl+Space`).
- `tests/smoke/test_bindings.sh`: 117 assertions. Validates JSON shape, checks
  every key against Micro 2.0.13's named events and single-rune fallback,
  rejects the forbidden chords, and keeps `docs/keymap.md` and `bindings.json`
  in sync in both directions.

## Verification

```sh
jq empty config/bindings.json
bash tests/smoke/test_bindings.sh
bash -n tests/smoke/*.sh
git diff --check
```

- `jq empty config/bindings.json` exit 0.
- `bash tests/smoke/test_bindings.sh`: 117 passed, 0 failed (re-run on `main`
  after the squash merge).
- `bash -n tests/smoke/*.sh` exit 0.
- `git diff --check` exit 0.
- All binding keys were accepted by Micro 2.0.13's `findEvent` parser in a
  throwaway test against the upstream source.
- Squash commit `b6d54fc` on `main`; `git merge-base --is-ancestor b6d54fc
  origin/main` exit 0.


### Harden launcher for symlinked installs and toolchain

Task ID: LAUNCH-01
Owner: Dev Agent 1
Branch: agent/1/launch-01-hardening
Status: Done
Completed: 2026-10-30

## Objective

Harden the launcher for symlinked installs, the isolated toolchain, cursor
arguments, and test overrides.

## Result

- `bin/microboss`: prepends `$MICROBOSS_DATA/tools/node_modules/.bin` to `PATH`
  when that directory exists, leaving an entry that is already present in place
  and exporting `PATH` only when it changes. Applies before the `micro` lookup,
  so the pinned toolchain wins over global tools.
- `tests/smoke/test_launcher.sh`: fake `micro` records `PATH`; new checks cover
  the toolchain prepend, preservation of existing entries, no duplicate entry,
  and no `PATH` change when the toolchain directory is absent. The symlink test
  now also invokes `microboss` by bare name through a temporary `PATH` directory.
  All runs still use a temporary `HOME` and assert `~/.config/micro` is not
  created or modified.
- `docs/architecture.md`: documents symlink/bare-name resolution, the toolchain
  `PATH` prepend, and `FILE`, `+LINE:COL`, `--` passthrough.

## Verification

```sh
bash -n bin/microboss
bash tests/smoke/test_launcher.sh
```

- `bash -n bin/microboss` exit 0.
- `bash -n tests/smoke/*.sh` exit 0.
- `bash tests/smoke/test_launcher.sh`: 42 passed, 0 failed (re-run on `main`
  after the squash merge).
- `git diff --check` exit 0.
- Squash commit `1d052f1` on `main`; `git merge-base --is-ancestor 1d052f1
  origin/main` exit 0.

### Vendor filemanager and explorer defaults

Task ID: PLUG-01
Owner: Dev Agent 1
Branch: agent/1/plug-01-filemanager
Status: Done
Completed: 2026-11-01

## Objective

Vendor `filemanager` 3.5.1, bind the explorer, hide noise by default, and keep
editor focus.

## Result

- `config/plug/filemanager/`: vendored filemanager 3.5.1 with `repo.json`,
  `LICENSE`, `VERSION`, `syntax.yaml`, and the upstream plugin files.
- `config/settings.json`: `filemanager.showdotfiles` and
  `filemanager.showignored` set to `false`.
- `config/init.lua`: `postinit` wrapper replaces the plugin's `tree` command,
  toggles the tree, and calls `PreviousSplit()` when the tree takes focus.
- `config/bindings.json`: `F2` and `Ctrl+B` continue to run `command:tree`.
- `docs/architecture.md` and `docs/keymap.md`: document the vendored plugin,
  explorer defaults, and focus behavior.
- `tests/smoke/test_filemanager.sh`: 31 assertions. Static checks cover the
  pinned version, metadata, license, settings, bindings, and wrapper. A real
  Micro session in a detached tmux socket with a temporary `HOME` asserts that
  `F2` and `Ctrl+B` open and close the tree without leaving focus there, and
  that `~/.config/micro` is untouched.

## Verification

```sh
jq empty config/settings.json config/bindings.json
bash tests/smoke/test_filemanager.sh
bash -n tests/smoke/test_filemanager.sh
git diff --check
```

- `bash tests/smoke/test_filemanager.sh`: 31 passed, 0 failed.
- `jq empty config/settings.json config/bindings.json` exit 0.
- `git diff --check` exit 0.
- Merge commit `b13a408` on `main`; `git merge-base --is-ancestor b13a408
  origin/main` exit 0.
