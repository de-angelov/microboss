# Plan Review — microboss Phase 0

**Task:** PLAN-01
**Reviewer:** Dev Agent 1
**Date:** 2026-10-30
**Reviewed revision:** `702363e` on `agent/1/plan-review`
**Scope:** documentation-only validation. No editor implementation, installer,
plugin, or test code is added by this task.

## Method

The review compared `README.md`, `PLAN.md`, `VERSION`, and the repository layout
with the installed toolchain and the upstream sources it depends on:

- `micro --version`, `micro -help`, `micro -options`, `micro -plugin list`, and
  `micro -plugin available` on the installed Micro 2.0.13.
- The Micro 2.0.13 help files and command implementation from
  `github.com/micro-editor/micro` (`runtime/help/*.md`, `internal/action/command.go`).
- The installed Micro plugins `lsp` 0.6.2, `filemanager` 3.5.1, and `fzf` 1.1.1
  in `~/.config/micro/plug`.
- npm registry metadata and package contents for `typescript`,
  `typescript-language-server`, `vscode-langservers-extracted`, and
  `@angular/language-server`.
- The local environment: Node 20.20.2, npm 10.8.2, `fzf`, and `rg`.

The review deliberately does not treat the local `~/.config/micro` as a target.
It is read-only evidence that vendored plugins and the existing LSP mapping work
with Micro 2.0.13.

## Validation results

The following assumptions were checked. "Confirmed" means the installed tool or
upstream source supports the statement; "corrected" means `PLAN.md` was changed
because the original statement was inaccurate or incomplete.

| Assumption | Result | Evidence |
| --- | --- | --- |
| Micro version | Confirmed for 2.0.13; corrected baseline wording | `micro --version` reports `2.0.13`. GitHub tags show 2.0.15 is current upstream. `PLAN.md` now pins 2.0.13 as the tested baseline and treats 2.0.15 as a separate upgrade task. |
| `-config-dir` support | Confirmed | `micro -help` lists `-config-dir dir` ("Specify a custom location for the configuration directory"). |
| Terminal command availability | Confirmed, but out of scope | Micro 2.0.13 provides `term exec?` and `shell.TermEmuSupported` on Linux/macOS. `PLAN.md` intentionally scopes out an embedded terminal; microboss runs inside the host terminal. |
| Plugin pinning | Confirmed limitation; vendoring is required | Micro loads plugins from `<config-dir>/plug`. The plugin manager installs a compatible version from a channel but exposes no documented version-pin flag. The plan's vendored `config/plug/*` layout is the correct way to pin. |
| TypeScript 5.9.x requirement | Confirmed | `typescript@5.9.3` contains `lib/tsserver.js`; `typescript@7.0.2` contains only `lib/version.cjs`, `lib/getExePath.js`, and `lib/tsc.js`. `typescript-language-server@5.3.0` is installed alongside TypeScript 5.9.3. |
| Angular language-server Node requirement | Corrected | `@angular/language-server@21.2.25` declares `engines.node` as `^20.19.0 || ^22.12.0 || >=24.0.0`. "Node 20.19+" was too broad because Node 21 and Node 23 are excluded. |
| Language-server pins | Confirmed | `typescript-language-server@5.3.0`, `vscode-langservers-extracted@4.10.0` (HTML/CSS/JSON binaries), and `@angular/language-server@21.2.25` (binary `ngserver`) are available. |
| `filemanager` behavior | Corrected | 3.5.1 provides `tree` and `openonstart`, but `showdotfiles` and `showignored` default to `true`. The plan now hides dotfiles and VCS-ignored paths by default. The plugin also focuses the tree after opening, so a wrapper must restore editor focus. |
| `fzf` behavior | Corrected | 1.1.1 provides only a `fzf` command. It has no ignore list; microboss must export `FZF_DEFAULT_COMMAND` or patch the plugin. |
| LSP plugin behavior | Corrected | 0.6.2 implements hover, definition, completion, formatting, references, and diagnostics. It keys servers by filetype, uses one global `rootUri` from the working directory, returns after the first matching filetype, sends Micro's filetype as the LSP `languageId`, and does not implement rename or code actions. |
| Keymap feasibility | Corrected | Micro 2.0.13 does not list `Ctrl+Shift+<key>`, `Ctrl+Tab`, Ctrl+backtick, `Shift+Escape`, or `Shift+F3` as bindable keys. `Ctrl+Shift` is documented as indistinguishable from `Ctrl` in terminals. There is no `CloseTab` action; `Ctrl+W` defaults to `NextSplit`. |

## Confirmed details worth recording

- Micro's `typescript` syntax matches both `.ts` and `.tsx`; `.jsx` uses the
  `jsx` filetype. The LSP patch therefore needs an extension-to-`languageId`
  map (`typescriptreact` and `javascriptreact`) rather than using the Micro
  filetype verbatim.
- `typescript-language-server` is invoked with `--stdio`; the HTML, CSS, and
  JSON servers from `vscode-langservers-extracted` are also stdio servers.
- The Angular language server binary is `ngserver`, not
  `@angular/language-server`.
- `fzf` is installed at `~/.local/bin/fzf`; `rg` is installed at `/usr/bin/rg`.
- `detectindent` 1.1.1 is not a Micro built-in; it must be vendored under
  `config/plug/detectindent/` to provide the indentation-detection default.
- The installed Micro plugin manager has `lsp` 0.6.2, `filemanager` 3.5.1, and
  `fzf` 1.1.1 available, matching the pins in the plan.

## Remaining inconsistency outside this task

`TECH.md` still describes an "integrated terminal" and "Micro 2.0.13+". The
product plan now scopes out an embedded terminal and pins 2.0.13 as the tested
baseline. `TECH.md` is a board file owned by the Team Lead, so this review does
not edit it; the Team Lead should align it before Phase 1 starts.

## Corrections applied to PLAN.md

The following factual corrections were made. All are small, targeted edits:

1. Target editor changed from "Micro 2.0.13+" to "Micro 2.0.13 (tested
   baseline; 2.0.15 is current upstream and is evaluated in a separate upgrade
   task)".
2. The typical-session key list now uses supported keys (`Alt+R` for references,
   `CtrlUnderscore` for comment, `Ctrl+Q` for closing the current pane).
3. Editor defaults now name the actual Micro 2.0.13 options (`mouse`, `ruler`,
   `statusline`, `softwrap`, `saveundo`, `backup`, `autoindent`, `rmtrailingws`,
   `paste`, `smartpaste`, `clipboard`, `scrollspeed`).
4. File-explorer defaults now match `filemanager` 3.5.1: dotfiles and
   VCS-ignored paths are hidden by default, and the tree's focus behavior is
   documented as something the wrapper must correct.
5. Fuzzy-finder text now records that the pinned plugin has no ignore list and
   that `FZF_DEFAULT_COMMAND` (or a patch) provides project-aware ignores.
6. The VS Code keymap table now contains only keys Micro 2.0.13 can bind.
   `Ctrl+Shift` chords, `Ctrl+Tab`, `Shift+Escape`, and `Shift+F3` were
   replaced with reliable alternatives or marked deferred. The Ctrl+backtick
   chord is no longer a microboss binding because the embedded terminal is out
   of scope.
7. The keymap rules now state that `Ctrl+Shift+<key>` is unavailable in
   terminals unless a raw escape sequence is configured.
8. The LSP plugin section now describes the real 0.6.2 limitations: filetype
   keying, one global `rootUri`, early return after the first filetype match,
   missing rename/code actions, and incorrect `languageId` for TSX/JSX.
9. The Angular Node requirement is now the exact `engines.node` range in the
   server matrix, acceptance criteria, risk table, and open questions.
10. Rename is removed from the 1.0 acceptance criterion and marked deferred
    until the pinned LSP plugin implements `textDocument/rename`.
11. LSP UX now lists `Alt+F` for formatting and explicitly defers rename and
    code actions.

## Recommended first vertical slice for Phase 1

Start with a thin slice that proves isolation and the editor surface before
adding language servers:

`FOUND-01 -> CONF-01 -> KEY-01 -> PLUG-01 -> PLUG-02`

Acceptance for the slice:

- `microboss src/App.tsx` launches Micro with `~/.config/microboss` and leaves
  `~/.config/micro` byte-for-byte unchanged.
- `F2` and `Ctrl+B` open the explorer; dotfiles and gitignored paths are hidden.
- `Ctrl+P` opens fzf with project-aware ignores.
- `Alt+S`, `Ctrl+E`, `Ctrl+Q`, `Alt+Q`, `Alt+.`/`Alt+,`, `Ctrl+\`, `Alt+\`,
  `F3`, `Alt+P`, `Ctrl+D`, `Ctrl+U`, `Alt+C`, and `CtrlUnderscore` behave as
  documented in `docs/keymap.md`.
- A temporary manual check copies the React fixture to a temporary directory and
  leaves the source fixture unchanged.

After that slice, `TOOLS-01 -> LSP-01 -> LSP-02 -> LSP-03 -> LSP-04 -> SMOKE-01`
adds the TypeScript/React language-server path and automates the end-to-end
check. `INSTALL-01`, `DOCTOR-01`, and `DOCS-01` make the result installable and
supportable, which is the Phase 1 exit.

## Implementation backlog

The tasks below are ordered by dependency. Each task is intentionally small
enough to review as one branch and one squash commit. Paths are relative to the
repository root. `LSP-02` (dispatch patch) and `RELEASE-01` (CI plus release
polish) are the two largest tasks; split them further if the Team Lead's
complexity budget requires it.

### FOUND-01 — Repository skeleton and isolated launcher

**Objective:** Add the minimal distribution skeleton and a launcher that starts
Micro with an isolated config directory.

**In scope:**
- `bin/microboss`
- `config/` directory skeleton
- `docs/architecture.md` stub
- `tests/smoke/test_launcher.sh`
- `tests/fixtures/empty/.gitkeep`

**Out of scope:**
- Editor settings, keybindings, plugins, toolchain, installer, doctor, LSP.

**Acceptance criteria:**
- `bin/microboss` is POSIX `sh`, resolves its own path through a symlink, and
  execs `micro -config-dir "$MICROBOSS_CONFIG" "$@"`.
- It fails with a clear message when `micro` is not on `PATH`.
- A temp-`HOME` test asserts that `~/.config/micro` is not created or modified.
- `MICROBOSS_CONFIG`, `MICROBOSS_DATA`, and `MICROBOSS_CACHE` can override the
  default directories for tests.
- `bash -n bin/microboss` passes.

**Verification:**
```sh
bash -n bin/microboss
bash tests/smoke/test_launcher.sh
```

**Dependencies:** none.

### CONF-01 — Editor defaults

**Objective:** Ship a valid `settings.json` with the defaults in `PLAN.md` §5.1
using exact Micro 2.0.13 option names.

**In scope:**
- `config/settings.json`
- `config/plug/detectindent/`
- `tests/smoke/test_settings.sh`

**Out of scope:**
- Keybindings, other plugin options, LSP server configuration, installer.

**Acceptance criteria:**
- `jq empty config/settings.json` passes.
- Settings include `mouse`, `ruler`, `statusline`, `softwrap`, `saveundo`,
  `backup`, `backupdir`, `autoindent`, `rmtrailingws`, `paste`, `smartpaste`,
  `clipboard`, and `scrollspeed`.
- The vendored `detectindent` plugin is 1.1.1, loads without errors, and
  provides the indentation-detection default.
- `backupdir` points under `~/.cache/microboss` without hard-coding a user's home
  directory.
- The test asserts the presence and JSON type of every setting.

**Verification:**
```sh
jq empty config/settings.json
bash tests/smoke/test_settings.sh
```

**Dependencies:** FOUND-01.

### KEY-01 — VS Code-like keymap and validation

**Objective:** Ship a `bindings.json` that uses only keys Micro 2.0.13 can bind,
and document the differences from VS Code.

**In scope:**
- `config/bindings.json`
- `docs/keymap.md`
- `tests/smoke/test_bindings.sh`

**Out of scope:**
- Plugin implementation, LSP actions, terminal-emulator bindings.

**Acceptance criteria:**
- `jq empty config/bindings.json` passes.
- No binding uses `Ctrl+Shift+<key>`, `Ctrl+Tab`, Ctrl+backtick, `Shift+Escape`, or
  another key absent from Micro's bindable key list.
- The documented set covers: `F2`/`Ctrl+B` tree, `Ctrl+P` fzf, `Ctrl+E`
  command mode, `Ctrl+Q` quit, `Alt+Q` quit all, `Alt+.`/`Alt+,` tabs,
  `Ctrl+\` vsplit, `Alt+\` hsplit, `F3` find next, `Alt+P` find previous,
  `F12`/`Alt+D` definition, `Alt+R` references, `Alt+K` hover, `Ctrl+Space`
  completion, `Alt+F` format, `CtrlUnderscore`/`Alt+/` comment, `Ctrl+D`
  multi-cursor, `Ctrl+U` remove cursor, `Alt+C` clear cursors, `Alt+Shift+D`
  duplicate line, `Alt+Up/Down` move line, and `Alt+Z` soft wrap.
- The test rejects unknown key names and checks that every documented shortcut
  is present in `bindings.json`.

**Verification:**
```sh
jq empty config/bindings.json
bash tests/smoke/test_bindings.sh
```

**Dependencies:** FOUND-01, CONF-01.

### LAUNCH-01 — Launcher hardening

**Objective:** Harden the launcher for symlinked installs, the isolated
toolchain, cursor arguments, and test overrides.

**In scope:**
- `bin/microboss`
- `tests/smoke/test_launcher.sh`
- `docs/architecture.md`

**Out of scope:**
- Installer, update, doctor, plugin behavior.

**Acceptance criteria:**
- Works when invoked through a symlink in a temporary `PATH` directory.
- Prepends `~/.local/share/microboss/tools/node_modules/.bin` to `PATH` when the
  directory exists, without duplicating an existing entry.
- Passes `FILE`, `+LINE:COL`, and `--` arguments through unchanged.
- Respects `MICROBOSS_CONFIG`, `MICROBOSS_DATA`, and `MICROBOSS_CACHE`.
- `bash -n` passes and the test runs with a temp `HOME`.

**Verification:**
```sh
bash -n bin/microboss
bash tests/smoke/test_launcher.sh
```

**Dependencies:** FOUND-01.

### PLUG-01 — Vendor filemanager and explorer defaults

**Objective:** Vendor `filemanager` 3.5.1, bind the explorer, hide noise by
default, and keep editor focus.

**In scope:**
- `config/plug/filemanager/`
- `config/bindings.json`
- `config/settings.json`
- `config/init.lua`
- `tests/smoke/test_filemanager.sh`

**Out of scope:**
- fzf, LSP, installer, update.

**Acceptance criteria:**
- The vendored plugin reports version 3.5.1 and includes its `repo.json` and
  license.
- `F2` and `Ctrl+B` run `command:tree`.
- `filemanager.showdotfiles` and `filemanager.showignored` are `false`.
- Opening the tree restores focus to the editor; the test asserts the active
  pane is not the tree after the wrapper runs.
- Opening and closing the tree works in a temporary fixture.

**Verification:**
```sh
jq empty config/settings.json config/bindings.json
bash tests/smoke/test_filemanager.sh
```

**Dependencies:** FOUND-01, KEY-01.

### PLUG-02 — Vendor fzf and project-aware ignores

**Objective:** Vendor `fzf` 1.1.1, bind `Ctrl+P`, and provide project-aware file
listing without breaking non-git directories.

**In scope:**
- `config/plug/fzf/`
- `config/bindings.json`
- `bin/microboss`
- `tests/smoke/test_fzf.sh`

**Out of scope:**
- Project-wide text-search UI, filemanager, LSP.

**Acceptance criteria:**
- The vendored plugin reports version 1.1.1.
- `Ctrl+P` runs `command:fzf`.
- The launcher exports `FZF_DEFAULT_COMMAND` using `rg --files` with excludes
  for `.git`, `node_modules`, `dist`, and `coverage` when `rg` is available.
- The launcher falls back to a portable `find` command when `rg` is missing.
- A missing `fzf` binary prints a clear message and does not crash Micro.

**Verification:**
```sh
jq empty config/bindings.json
bash tests/smoke/test_fzf.sh
```

**Dependencies:** FOUND-01, KEY-01, LAUNCH-01.

### TOOLS-01 — Pinned language-server toolchain

**Objective:** Add a lockfile-based toolchain with exact server and TypeScript
pins.

**In scope:**
- `tools/package.json`
- `tools/package-lock.json`
- `tests/smoke/test_tools.sh`

**Out of scope:**
- Installer and doctor scripts, LSP plugin, editor configuration.

**Acceptance criteria:**
- Exact pins: `typescript@5.9.3`, `typescript-language-server@5.3.0`,
  `vscode-langservers-extracted@4.10.0`, and
  `@angular/language-server@21.2.25`.
- `npm ci --prefix tools` succeeds and
  `tools/node_modules/typescript/lib/tsserver.js` exists.
- `npm ls --prefix tools --depth=0` shows the exact versions.
- The lockfile is committed with the manifest.

**Verification:**
```sh
npm ci --prefix tools --ignore-scripts
test -f tools/node_modules/typescript/lib/tsserver.js
npm ls --prefix tools --depth=0
```

**Dependencies:** FOUND-01.

### INSTALL-01 — Idempotent installer

**Objective:** Implement a safe, repeatable installer for the isolated config,
launcher, and optional toolchain.

**In scope:**
- `scripts/install.sh`
- `tests/smoke/test_install.sh`
- `docs/architecture.md`

**Out of scope:**
- Update/rollback, doctor, LSP runtime behavior.

**Acceptance criteria:**
- Default mode copies config; `--dev` symlinks the repository config.
- `--no-tools` installs config only.
- `--prefix DIR` installs the launcher outside `~/.local/bin`.
- `--force` backs up before replacing a microboss-managed file.
- Re-running is idempotent and does not duplicate plugin entries.
- The test asserts `~/.config/micro` is unchanged.
- The installer prints a summary of what changed.

**Verification:**
```sh
bash -n scripts/install.sh
bash tests/smoke/test_install.sh
```

**Dependencies:** FOUND-01, TOOLS-01.

### DOCTOR-01 — Doctor command

**Objective:** Implement `microboss doctor` with human-readable and JSON output
and actionable fixes.

**In scope:**
- `scripts/doctor.sh`
- `bin/microboss`
- `tests/smoke/test_doctor.sh`
- `docs/troubleshooting.md` stub

**Out of scope:**
- Auto-repair, update, package installation.

**Acceptance criteria:**
- Checks Micro version and `-config-dir`, Node range, toolchain binaries,
  `lib/tsserver.js`, plugin directories and versions, JSON syntax, write access
  to config/data/cache, `TERM`/`COLORTERM`, `fzf`, and `rg`.
- Every failure prints a short explanation and a copy-pasteable fix.
- `--json` emits valid JSON with stable keys.
- Exits non-zero when a required component is missing.

**Verification:**
```sh
bash -n scripts/doctor.sh
bash tests/smoke/test_doctor.sh
```

**Dependencies:** TOOLS-01, INSTALL-01.

### LSP-01 — Vendor pinned LSP plugin

**Objective:** Vendor upstream `lsp` 0.6.2 with license, metadata, and an
upstream note before patching it.

**In scope:**
- `config/plug/lsp/`
- `docs/lsp.md` stub
- `tests/smoke/test_lsp_load.sh`

**Out of scope:**
- Dispatcher patch, server integration, rename/code actions.

**Acceptance criteria:**
- Files match upstream 0.6.2 and `repo.json` identifies 0.6.2.
- `UPSTREAM.md` records the source URL, version, and patch policy.
- Micro 2.0.13 loads the plugin without Lua errors.
- The smoke test checks Micro's log for load errors.

**Verification:**
```sh
bash tests/smoke/test_lsp_load.sh
```

**Dependencies:** FOUND-01, TOOLS-01.

### LSP-02 — Patch LSP dispatch

**Objective:** Patch the vendored plugin to key servers by `(server, root)`,
compute `rootUri` per buffer, map LSP `languageId`, and allow multiple servers
per filetype.

**In scope:**
- `config/plug/lsp/main.lua`
- `config/plug/lsp/UPSTREAM.md`
- `tests/smoke/test_lsp_dispatch.sh`

**Out of scope:**
- Root detection rules (LSP-03), concrete server integration (LSP-04), rename
  and code actions.

**Acceptance criteria:**
- `cmd`, `id`, `capabilities`, and `currentAction` are keyed by server and root,
  not filetype alone.
- `rootUri` is derived from the buffer's project root.
- Duplicate filetype entries start distinct servers.
- The same `(server, root)` pair reuses one process.
- `.tsx` maps to `typescriptreact` and `.jsx` maps to `javascriptreact` in
  `didOpen`.
- A fake LSP server regression test asserts two servers for two roots.

**Verification:**
```sh
bash tests/smoke/test_lsp_dispatch.sh
```

**Dependencies:** LSP-01.

### LSP-03 — Project root detection

**Objective:** Implement the root-detection rules from `PLAN.md` §7.3 with
fixture tests.

**In scope:**
- `config/plug/lsp/root.lua` (or an equivalent helper)
- `tests/fixtures/monorepo/`
- `tests/smoke/test_root_detection.sh`

**Out of scope:**
- Starting servers, diagnostics UI, editor bindings.

**Acceptance criteria:**
- Walks upward for `tsconfig.json`, `angular.json`, `package.json`, and
  `jsconfig.json`.
- A nested `tsconfig.json` wins over the repository root.
- `node_modules` is never treated as a project root.
- The Angular workspace root is the directory containing `angular.json`.
- Ambiguous Angular/TypeScript input prefers TypeScript and records a warning.
- The test covers each rule with temporary fixtures.

**Verification:**
```sh
bash tests/smoke/test_root_detection.sh
```

**Dependencies:** LSP-02.

### LSP-04 — TypeScript and React LSP integration

**Objective:** Wire `typescript-language-server` with `typescript@5.9.3` for
TypeScript, JavaScript, TSX, and JSX, and prove it on the React fixture.

**In scope:**
- `config/settings.json`
- `config/plug/lsp/main.lua`
- `config/plug/lsp/servers.lua` (if needed)
- `tests/fixtures/react-ts/`
- `tests/smoke/test_ts_lsp.sh`

**Out of scope:**
- Angular, HTML/CSS/JSON servers, rename, code actions, Prettier.

**Acceptance criteria:**
- `lsp.server` maps `typescript`, `javascript`, and `jsx` to
  `typescript-language-server --stdio`.
- `.tsx` buffers use the `typescriptreact` language ID and `.jsx` buffers use
  `javascriptreact`.
- The React fixture reports diagnostics, completion, hover, definition, and
  references.
- A missing server produces a doctor-visible failure, not a silent editor crash.
- Startup does not block on a server for an unopened file type.

**Verification:**
```sh
bash tests/smoke/test_ts_lsp.sh
```

**Dependencies:** LSP-02, LSP-03, TOOLS-01.

### SMOKE-01 — Smoke harness

**Objective:** Add the repeatable smoke harness that copies fixtures to a
temporary directory and verifies the Phase 1 slice.

**In scope:**
- `scripts/smoke.sh`
- `tests/fixtures/`
- `tests/smoke/`
- `tests/tmp/` (ignored)

**Out of scope:**
- Angular, HTML/CSS/JSON, CI, release packaging.

**Acceptance criteria:**
- `scripts/smoke.sh` runs the launcher, settings, keymap, explorer, fzf, and
  TypeScript LSP checks.
- Fixtures are copied to a temporary directory before any editor run.
- The source fixtures are byte-for-byte unchanged after the run.
- The script exits non-zero on the first failed check and prints the failing
  command.
- No test writes to `~/.config/micro`.

**Verification:**
```sh
bash scripts/smoke.sh
```

**Dependencies:** PLUG-01, PLUG-02, LSP-04.

### DOCS-01 — User documentation and link check

**Objective:** Write the user-facing documentation required by `PLAN.md` §10 and
verify its links.

**In scope:**
- `README.md`
- `docs/architecture.md`
- `docs/keymap.md`
- `docs/lsp.md`
- `docs/troubleshooting.md`
- `docs/updating.md`
- `CHANGELOG.md`
- `tests/smoke/test_docs.sh`

**Out of scope:**
- New behavior, new commands, release tagging.

**Acceptance criteria:**
- Each document covers the topics in `PLAN.md` §10.
- `docs/keymap.md` marks every terminal-emulator limitation.
- `docs/lsp.md` records the pins, root rules, and the deferred rename/code
  actions.
- `docs/troubleshooting.md` tells users how to run `doctor` and read logs.
- The link check resolves every relative Markdown link.

**Verification:**
```sh
bash tests/smoke/test_docs.sh
```

**Dependencies:** FOUND-01, CONF-01, KEY-01, INSTALL-01, DOCTOR-01, LSP-04.

### ANG-01 — Angular language server and external templates

**Objective:** Add `@angular/language-server@21.2.25` (`ngserver`) for Angular
TypeScript and external templates, with an Angular fixture.

**In scope:**
- `config/plug/lsp/`
- `config/settings.json`
- `tools/package.json`
- `tools/package-lock.json`
- `tests/fixtures/angular/`
- `tests/smoke/test_angular_lsp.sh`

**Out of scope:**
- Plain HTML/CSS/JSON servers, rename, code actions, Prettier.

**Acceptance criteria:**
- Angular workspaces are detected by `angular.json`.
- Angular TypeScript and external `.html` templates route to `ngserver`.
- The fixture gets template diagnostics, completion, and navigation from a
  template to its component.
- A plain TypeScript file in the same workspace still uses the TypeScript
  server.
- No duplicate diagnostics are produced for the same root.

**Verification:**
```sh
bash tests/smoke/test_angular_lsp.sh
```

**Dependencies:** LSP-02, LSP-03, TOOLS-01.

### WEB-01 — HTML, CSS, and JSON language servers

**Objective:** Add the `vscode-langservers-extracted` servers and route them by
file type and project root.

**In scope:**
- `config/settings.json`
- `config/plug/lsp/`
- `tests/fixtures/web/`
- `tests/smoke/test_web_lsp.sh`

**Out of scope:**
- Angular templates, TypeScript, rename, code actions.

**Acceptance criteria:**
- `html`, `css`, `scss`, `json`, and `jsonc` map to the correct binaries with
  `--stdio`.
- Angular external templates do not use the plain HTML server.
- Each server reuses one process per `(server, root)`.
- The fixture gets diagnostics and completion for HTML, CSS, and JSON.
- Missing servers are reported by `doctor`.

**Verification:**
```sh
bash tests/smoke/test_web_lsp.sh
```

**Dependencies:** LSP-02, LSP-03, TOOLS-01.

### LSPCLI-01 — LSP status command and log rotation

**Objective:** Add `microboss lsp` and log rotation for language-server
diagnostics.

**In scope:**
- `bin/microboss`
- `scripts/lsp-status.sh` (or equivalent)
- `config/plug/lsp/main.lua`
- `docs/lsp.md`
- `tests/smoke/test_lsp_status.sh`

**Out of scope:**
- New language servers, rename, code actions, update.

**Acceptance criteria:**
- `microboss lsp` lists detected roots and the chosen server for each.
- `--json` emits machine-readable output.
- LSP logs are written to `~/.local/share/microboss/logs/lsp.log` and rotate at
  a documented size.
- `doctor` can read the same log for startup failures.
- The test covers an empty project, a TypeScript project, and an Angular
  workspace.

**Verification:**
```sh
bash tests/smoke/test_lsp_status.sh
```

**Dependencies:** ANG-01, WEB-01, LSP-04.

### UPDATE-01 — Update and rollback flow

**Objective:** Add a pinned, rollback-safe update path.

**In scope:**
- `scripts/update.sh`
- `bin/microboss`
- `docs/updating.md`
- `tests/smoke/test_update.sh`

**Out of scope:**
- New features, CI, release tagging.

**Acceptance criteria:**
- `microboss update` refreshes the distribution and pinned toolchain.
- A backup is created before replacing managed files.
- A failed update restores the previous managed files.
- `microboss doctor` runs after a successful update.
- The test uses a temporary install root and does not touch the real home
  directory.

**Verification:**
```sh
bash -n scripts/update.sh
bash tests/smoke/test_update.sh
```

**Dependencies:** INSTALL-01, DOCTOR-01.

### RELEASE-01 — CI matrix, polish, and v0.1.0

**Objective:** Finish the release surface: CI installs on a clean container,
Prettier/snippets/status line polish, and the `v0.1.0` tag.

**In scope:**
- `.github/workflows/`
- `config/settings.json`
- `config/init.lua`
- `docs/`
- `CHANGELOG.md`
- `VERSION`

**Out of scope:**
- New language servers, debugging, extension system.

**Acceptance criteria:**
- CI runs `scripts/install.sh`, `microboss doctor`, and `scripts/smoke.sh` on a
  clean Linux container.
- Prettier formatting is available when the project has a Prettier config.
- React/Angular snippets and the LSP/git status line are documented.
- `VERSION` is `0.1.0`, `CHANGELOG.md` has the release entry, and the tag is
  created after CI passes.
- `git diff --check` passes.

**Verification:**
```sh
bash scripts/smoke.sh
bash -n bin/microboss scripts/*.sh
git diff --check
```

**Dependencies:** all previous tasks.

## Risks and HITL decisions

These need a human decision before the dependent task starts. They are recorded
here rather than silently assumed.

1. **Micro baseline: 2.0.13 or 2.0.15?** The installed and tested version is
   2.0.13; 2.0.15 is current upstream. Recommendation: ship 0.1.0 on 2.0.13 and
   make 2.0.15 a separate upgrade task with its own smoke run.
2. **Keymap compromises.** Terminals cannot send `Ctrl+Shift+<key>` or
   Ctrl+backtick, Micro has no `CloseTab` action, and `Ctrl+P`/`Ctrl+B`/`F2` override
   Micro defaults. Recommendation: approve the corrected table in `PLAN.md` §6
   or choose different single-modifier keys in `KEY-01`.
3. **LSP patch scope.** Per-root dispatch, multiple servers per filetype, and
   `languageId` mapping require a non-trivial patch to upstream 0.6.2.
   Recommendation: approve the patch and keep rename/code actions out of 1.0.
4. **Node policy.** Angular LS supports `^20.19.0 || ^22.12.0 || >=24.0.0`.
   Recommendation: require a supported Node and stop with instructions; do not
   bundle Node in 0.1.0.
5. **Angular LS version.** The plan says `@21`; the latest 21.x is 21.2.25 and
   the latest overall is 22.2.4. Recommendation: pin 21.2.25 for 0.1.0 and
   evaluate 22 after the Angular fixture passes.
6. **macOS in the first release.** The plan targets Linux and macOS first, but
   all local evidence is Linux. Recommendation: keep macOS best-effort in 0.1.0
   and add it to CI before claiming support.
7. **fzf installation policy.** The plan allows a pinned binary or a
   package-manager instruction. Recommendation: prefer a system `fzf` and print
   an install hint; do not download an unpinned binary.
8. **Prettier in 1.0.** Prettier is a "should have" and a Phase 3 item, but it
   is not in the 1.0 acceptance criteria. Recommendation: keep it in Phase 3.
9. **Board consistency.** `TECH.md` still mentions an integrated terminal and
   "Micro 2.0.13+". The Team Lead should update it to match this review before
   Phase 1 starts.

## Verification for this review

The task's verification commands are:

```sh
test -f docs/plan-review.md
test "$(grep -c '^### ' docs/plan-review.md)" -ge 12
git diff --check
git log --oneline -1
```

`docs/plan-review.md` contains 20 ordered task proposals. `git diff --check`
passes. The branch is committed and squash-merged into `main` as described in
the task completion notes.
