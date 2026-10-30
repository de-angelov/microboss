# microboss — Implementation Plan

**Status:** Draft for approval
**Product:** `microboss`
**Repository:** <https://github.com/de-angelov/microboss>
**Target editor:** Micro 2.0.13+ (pin the exact version during implementation)
**Primary platforms:** Linux and macOS; Windows through WSL is best-effort
**Workflow:** slopboss board, one dev agent, OpenCode `opencode/deepseek-v4.1-flash-free`

---

## 1. Product thesis

Micro is fast, scriptable, and pleasant in a terminal, but a fresh install is a
long way from a modern TypeScript editor. Users have to discover plugins, write
LSP configuration, learn a new keymap, and debug language servers themselves.

**microboss** closes that gap. It is an opinionated, reproducible distribution
that turns Micro into a lightweight VS Code alternative for terminal-based
TypeScript, React, and Angular work. It keeps Micro's speed and small footprint,
but ships the defaults, keybindings, language tooling, docs, and diagnostics that
make it usable on day one.

The product is successful when a developer can install one command, open a real
React or Angular repository, and get completion, diagnostics, navigation, file
exploration, fuzzy search, and a terminal without editing a config file.

### Design inspirations

- **LazyVim:** sensible defaults, modular layers, pinned dependencies, a health
  check, and documentation that makes the defaults discoverable.
- **VS Code:** familiar shortcuts, a file explorer, quick open, an integrated
  terminal, and predictable editor behavior.
- **Micro:** stay small, stay terminal-native, and prefer plain files that users
  can inspect and change.

---

## 2. Goals

### Must have for 1.0

1. A single `microboss` command that launches an isolated Micro instance.
2. A one-command installer that works on a clean Linux or macOS machine.
3. VS Code-like defaults for the shortcuts developers use every day.
4. A file explorer, fuzzy file finder, and integrated terminal.
5. Working LSP support for TypeScript, JavaScript, TSX/JSX, HTML, CSS, and JSON.
6. Working Angular language support in Angular CLI workspaces, including
   external templates.
7. Project-aware language-server startup that handles monorepos and nested
   `tsconfig.json` files instead of starting every server in every buffer.
8. A `microboss doctor` command that finds missing or broken dependencies and
   tells the user exactly how to fix them.
9. Documentation for installation, keybindings, LSP, updating, and
   troubleshooting.
10. An automated smoke test that runs against fixture projects.

### Should have

- Prettier integration when the project already has a Prettier config.
- Angular and React snippets for common file patterns.
- A status line that shows the active LSP state and git branch.
- `microboss update` with rollback-safe, pinned updates.
- CI that installs the distribution in a clean container and runs the smoke test.

### Non-goals

- Reimplementing VS Code. Debugging, extensions, notebooks, and a GUI are out of
  scope.
- Replacing the user's existing `~/.config/micro`. microboss is isolated by
  default.
- Supporting every language. The initial language set is deliberately narrow.
- Bundling a full Node distribution unless the installer cannot find a suitable
  one. Prefer a checked, documented system dependency.
- Managing project dependencies or running builds. microboss configures the
  editor; it does not become the project's package manager.

---

## 3. Target user and primary workflow

The primary user:

- works in a terminal, often over SSH or inside tmux;
- edits TypeScript, React, and Angular projects;
- knows VS Code shortcuts and does not want to relearn an editor;
- wants fast startup and low memory use;
- values reproducible setup and a doctor command more than a plugin marketplace.

Typical session:

```sh
cd ~/projects/my-react-app
microboss .
```

Then:

- `F2` or `Ctrl+B` opens the file explorer;
- `Ctrl+P` opens fuzzy file search;
- `Ctrl+`` opens the integrated terminal;
- `Ctrl+Space` requests completion;
- `F12` goes to definition;
- `Shift+F12` finds references;
- `Ctrl+/` toggles a comment;
- `Ctrl+S` saves;
- `Ctrl+W` closes the current tab;
- `Ctrl+\` splits the editor.

---

## 4. Distribution architecture

### 4.1 Runtime layout

microboss owns three directories and never writes to the user's existing Micro
configuration:

| Path | Purpose |
| --- | --- |
| `~/.config/microboss/` | Micro settings, bindings, `init.lua`, vendored plugins. |
| `~/.local/share/microboss/` | Pinned language-server toolchain, lockfiles, logs. |
| `~/.cache/microboss/` | Disposable caches, downloaded archives, test artifacts. |

The repository is the source of truth for the distribution. The installed config
is either a copy (default) or a symlink (`microboss install --dev`). Copying is
the safe default for users; symlinking is convenient while developing microboss
itself.

### 4.2 Launcher

`bin/microboss` is a small POSIX shell wrapper. It:

1. resolves its own location and the installed distribution root;
2. verifies that Micro is available;
3. exports the microboss toolchain on `PATH`;
4. starts Micro with `-config-dir ~/.config/microboss`;
5. passes through every user argument, including files and `+LINE:COL`.

The wrapper must not depend on the current working directory and must work when
invoked through a symlink in `~/.local/bin`.

### 4.3 Configuration package

The distribution ships:

```text
config/
├── settings.json          # editor defaults
├── bindings.json          # VS Code-like keymap
├── init.lua               # small compatibility helpers
└── plug/
    ├── lsp/               # pinned and patched LSP plugin
    ├── filemanager/       # pinned file explorer
    └── fzf/               # pinned fuzzy finder
```

Plugins are vendored or installed from a lockfile with exact versions. A plugin
update is a reviewed change, not an implicit side effect of starting the editor.

### 4.4 Installer and updater

`scripts/install.sh` is idempotent and safe to re-run. It:

- detects Linux/macOS and architecture;
- checks for Micro and a supported Node.js;
- installs pinned Micro plugins into the isolated config directory;
- installs pinned language servers into `~/.local/share/microboss/tools`;
- writes the `microboss` launcher to `~/.local/bin`;
- creates a backup before replacing any microboss-managed file;
- supports `--dev` (symlink repo config) and `--no-tools` (config only).

`microboss update` refreshes the distribution from the repository, updates the
pinned toolchain, and runs `microboss doctor` afterwards. It never overwrites
user-owned files without a backup.

### 4.5 Health check

`microboss doctor` is the primary support tool. It checks:

- Micro version and the `-config-dir` capability;
- Node.js version and `node`/`npm` availability;
- TypeScript 5.9.x and the presence of `lib/tsserver.js`;
- `typescript-language-server`;
- HTML, CSS, and JSON language servers;
- Angular language server and its Node compatibility;
- `fzf` availability and shell integration;
- plugin directory integrity and pinned versions;
- `settings.json` and `bindings.json` syntax;
- the integrated terminal and the configured shell;
- write access to config, data, and cache directories;
- the current project's detected language servers, when run inside a project.

Each failure prints a short explanation and a copy-pasteable fix. `--json` is
available for CI and tests.

---

## 5. Editor experience

### 5.1 Defaults

- true color and 256-color fallback;
- mouse support where the terminal supports it;
- line numbers and a readable status line;
- soft wrap off for code, with a toggle;
- persistent undo and swap files in the microboss cache;
- auto-indent and detected indentation for existing files;
- trim trailing whitespace on save;
- bracketed paste;
- clipboard through the terminal's OSC 52 support when available, with a
  documented fallback;
- smooth scrolling disabled by default for predictable terminal behavior.

### 5.2 File explorer

Use the pinned `filemanager` plugin:

- `F2` and `Ctrl+B` toggle the tree;
- `Ctrl+Shift+E` is an alternate explorer binding;
- hidden files are shown on demand;
- `node_modules`, `dist`, `.git`, and common build output are filtered by
  default;
- opening a directory from the explorer selects the file in the current tab;
- the tree must not steal focus from the editor when it opens.

### 5.3 Fuzzy finder

Use the pinned `fzf` plugin with a project-aware ignore list:

- `Ctrl+P` searches files;
- `Ctrl+Shift+P` opens the Micro command palette;
- `Ctrl+F` uses the editor's in-buffer search;
- `Ctrl+Shift+F` runs a project-wide text search when `rg` is available;
- ignore `.git`, `node_modules`, `dist`, `coverage`, and lockfile noise where
  appropriate.

### 5.4 Integrated terminal

Use Micro's built-in terminal support, with the `term` command:

- `Ctrl+`` opens a terminal in a horizontal split;
- `Ctrl+Shift+`` opens a new terminal tab;
- the shell is taken from `$SHELL`, then `/bin/bash`, then `/bin/sh`;
- the terminal inherits the microboss toolchain on `PATH`;
- terminal tabs are named after the running command;
- closing the terminal returns focus to the editor.

The exact key names must be verified against the pinned Micro version because
terminal keybindings are terminal-emulator dependent.

### 5.5 Tabs, splits, search, and editing

- `Ctrl+N` new tab; `Ctrl+W` close tab; `Ctrl+Q` quit all.
- `Ctrl+Tab` / `Ctrl+Shift+Tab` cycle tabs.
- `Ctrl+\` vertical split; `Ctrl+Shift+\` horizontal split.
- `Ctrl+F` incremental search; `F3` / `Shift+F3` next/previous match.
- `Ctrl+D` add cursor at next match; `Ctrl+U` remove cursor;
  `Shift+Escape` clear all cursors.
- `Shift+Alt+Up/Down` duplicate line up/down.
- `Alt+Up/Down` move line up/down.
- `Ctrl+/` toggle comment.
- `Shift+Alt+F` format the buffer through LSP or Prettier.
- `Ctrl+Space` LSP completion.

---

## 6. VS Code keymap

Where Micro has an equivalent action, use the VS Code shortcut. Where it does
not, keep a documented Micro-native alternative.

| Action | VS Code | microboss | Notes |
| --- | --- | --- | --- |
| Save | `Ctrl+S` | `Ctrl+S` | Micro default. |
| Save as | `Ctrl+Shift+S` | `Ctrl+Shift+S` | |
| Command palette | `Ctrl+Shift+P` | `Ctrl+Shift+P` | Maps to Micro command mode. |
| Quick open | `Ctrl+P` | `Ctrl+P` | fzf plugin. |
| Explorer | `Ctrl+Shift+E` | `F2`, `Ctrl+B`, `Ctrl+Shift+E` | `F2` preserves existing muscle memory. |
| Terminal | ``Ctrl+` `` | ``Ctrl+` `` | Built-in terminal. |
| New terminal | ``Ctrl+Shift+` `` | ``Ctrl+Shift+` `` | Verify terminal key support. |
| Close editor | `Ctrl+W` | `Ctrl+W` | |
| Close all | `Ctrl+Shift+W` | `Ctrl+Q` | Micro native. |
| Next tab | `Ctrl+Tab` | `Ctrl+Tab` | |
| Previous tab | `Ctrl+Shift+Tab` | `Ctrl+Shift+Tab` | |
| Split editor | `Ctrl+\` | `Ctrl+\` | |
| Find | `Ctrl+F` | `Ctrl+F` | |
| Find next | `F3` | `F3` | |
| Find previous | `Shift+F3` | `Shift+F3` | |
| Go to definition | `F12` | `F12`, `Alt+D` | LSP. |
| Find references | `Shift+F12` | `Shift+F12`, `Alt+R` | LSP. |
| Hover | `Ctrl+K Ctrl+I` | `Alt+K` | Single Micro-friendly chord. |
| Rename symbol | `F2` | `Ctrl+Shift+R` | `F2` is taken by the explorer. |
| Completion | `Ctrl+Space` | `Ctrl+Space` | LSP. |
| Format document | `Shift+Alt+F` | `Shift+Alt+F` | LSP/Prettier. |
| Toggle comment | `Ctrl+/` | `Ctrl+/` | |
| Multi-cursor next | `Ctrl+D` | `Ctrl+D` | |
| Undo last cursor | `Ctrl+U` | `Ctrl+U` | |
| Select line | `Ctrl+L` | `Ctrl+L` | |
| Delete line | `Ctrl+Shift+K` | `Ctrl+Shift+K` | |
| Duplicate line | `Shift+Alt+Down` | `Shift+Alt+Down` | |
| Move line | `Alt+Up/Down` | `Alt+Up/Down` | |
| Toggle soft wrap | `Alt+Z` | `Alt+Z` | `init.lua` helper. |

### Keymap rules

1. Do not silently break Micro defaults that users rely on. Document every
   intentional override.
2. Avoid chords that require a terminal to send a key it cannot send. Prefer
   single modifiers plus a letter.
3. Keep `F2` as the explorer because the existing dotfiles workflow uses it;
   offer `Ctrl+B` for VS Code users.
4. Ship a `docs/keymap.md` cheat sheet and a `microboss keys` command that prints
   it inside the editor.
5. Add a `bindings.json` validation test so an invalid key name fails CI rather
   than silently doing nothing.

---

## 7. Language-server strategy

### 7.1 Server matrix

| Language/file type | Server | Source |
| --- | --- | --- |
| TypeScript, JavaScript, TSX, JSX | `typescript-language-server` | `typescript-language-server@5.3.0` |
| TypeScript SDK | `typescript@5.9.3` | Must include `lib/tsserver.js`; TypeScript 7 currently does not. |
| HTML | `vscode-html-language-server` | `vscode-langservers-extracted@4.10.0` |
| CSS/SCSS/LESS | `vscode-css-language-server` | `vscode-langservers-extracted@4.10.0` |
| JSON/JSONC | `vscode-json-language-server` | `vscode-langservers-extracted@4.10.0` |
| Angular templates and TS | `@angular/language-server@21` | Angular LS 21; requires Node.js 20.19+. |

The exact pins are recorded in `tools/package.json` and `tools/package-lock.json`
inside the distribution, not resolved at runtime.

### 7.2 Why a patched LSP plugin

The upstream Micro LSP plugin (0.6.2 at the time of planning) has two verified
reliability problems:

1. It appends fallback server entries, which can produce duplicate filetype
   registrations and inconsistent dispatch.
2. Its startup path can stop after the first server because of an empty
   `rootUri` guard, so a second language server never starts for a buffer.

microboss vendors the pinned plugin and carries a small, documented patch for
both issues. The patch is kept in `config/plug/lsp/` with an upstream note and a
regression test. If upstream fixes the issues, the patch is dropped and the
plugin version is bumped deliberately.

### 7.3 Project-aware dispatcher

A buffer must be routed to the right server for its project, not just its file
extension. The dispatcher:

1. finds the nearest project root by walking upward for `tsconfig.json`,
   `angular.json`, `package.json`, or `jsconfig.json`;
2. detects Angular workspaces by `angular.json` and the presence of
   `@angular/core`;
3. starts the Angular language server for Angular TypeScript and external
   templates (`*.html` with an Angular component context);
4. starts the TypeScript server for plain TS/JS/TSX/JSX projects;
5. runs HTML/CSS/JSON servers only for the relevant file types;
6. reuses an existing server when the new buffer belongs to the same project;
7. keeps one server per `(server, root)` pair, not one per buffer;
8. exposes the chosen root and server in `microboss lsp` and `doctor`.

Monorepo rules:

- a nested `tsconfig.json` wins over the repository root;
- `node_modules` is never treated as a project root;
- the Angular workspace root is the directory containing `angular.json`;
- if a project has both Angular and a standalone TypeScript library, each file
  goes to the server appropriate for its nearest root;
- if detection is ambiguous, prefer the TypeScript server and print a warning in
  `microboss lsp` rather than starting two servers and duplicating diagnostics.

### 7.4 Toolchain isolation

Language servers are installed under
`~/.local/share/microboss/tools/node_modules/.bin` and exposed to Micro through
the launcher's `PATH`. The installer writes an npm lockfile and uses `npm ci`.
This avoids depending on globally installed packages and prevents a global
TypeScript upgrade from breaking the editor.

A user may opt into system tools with `microboss install --system-tools`, but
the default is isolated.

### 7.5 LSP UX

- diagnostics appear in the gutter and status line;
- `F12`/`Alt+D` definition, `Shift+F12`/`Alt+R` references, `Alt+K` hover;
- `Ctrl+Space` completion with documentation preview;
- `Ctrl+Shift+R` rename symbol;
- `Shift+Alt+F` format;
- code actions through the command palette;
- server startup failures are visible in `microboss doctor`, not silently
  swallowed;
- logs are written to `~/.local/share/microboss/logs/lsp.log` with rotation.

---

## 8. Repository layout

```text
microboss/
├── README.md
├── PLAN.md
├── VERSION
├── CHANGELOG.md
├── bin/
│   └── microboss
├── config/
│   ├── settings.json
│   ├── bindings.json
│   ├── init.lua
│   └── plug/
│       ├── lsp/
│       ├── filemanager/
│       └── fzf/
├── tools/
│   ├── package.json
│   └── package-lock.json
├── scripts/
│   ├── install.sh
│   ├── update.sh
│   ├── doctor.sh
│   └── smoke.sh
├── docs/
│   ├── architecture.md
│   ├── keymap.md
│   ├── lsp.md
│   ├── troubleshooting.md
│   └── updating.md
└── tests/
    ├── fixtures/
    │   ├── react-ts/
    │   └── angular/
    └── smoke/
```

The user's project directories are never modified by the installer or tests.
Fixtures are self-contained; the smoke test copies them to a temporary
directory before opening Micro.

---

## 9. CLI surface

```text
microboss [FILE...]              Launch the editor.
microboss install [options]      Install/repair config and pinned tools.
microboss update                 Update distribution and pinned tools.
microboss doctor [--json]        Diagnose the installation.
microboss lsp [--json]           Show detected projects and server status.
microboss keys                   Print the keymap cheat sheet.
microboss version                Print distribution and component versions.
```

### Installer options

| Option | Meaning |
| --- | --- |
| `--dev` | Symlink repo config instead of copying; for distribution development. |
| `--no-tools` | Configure Micro only; do not install language servers. |
| `--system-tools` | Use compatible tools already on `PATH`. |
| `--prefix DIR` | Install the launcher somewhere other than `~/.local/bin`. |
| `--force` | Replace microboss-managed files after making a backup. |

The installer must be safe to run twice and must print a summary of what changed.

---

## 10. Documentation plan

| Document | Contents |
| --- | --- |
| `README.md` | What microboss is, install, first launch, feature summary. |
| `docs/keymap.md` | Complete keymap, VS Code differences, terminal caveats. |
| `docs/lsp.md` | Supported languages, server pins, project detection, logs. |
| `docs/troubleshooting.md` | Common failures and exact fixes; how to run doctor. |
| `docs/updating.md` | Update, rollback, pinning, and `--dev` mode. |
| `docs/architecture.md` | Distribution layout, launcher, config isolation, plugin patch. |
| `CHANGELOG.md` | User-visible changes per release. |

Every feature added after 1.0 must update at least one of these documents.

---

## 11. Delivery phases

### Phase 0 — Plan and board (current)

- Create the `microboss` repository and this plan.
- Set up the slopboss board with one dev agent.
- Run a planning session using OpenCode DeepSeek free.
- Produce a task breakdown in `BACKLOG.md`; do not implement editor code yet.

**Exit:** the plan is accepted and the backlog contains small, ordered tasks.

### Phase 1 — Foundation and MVP editor

- `bin/microboss` launcher and config isolation.
- `settings.json`, `bindings.json`, and `init.lua`.
- Pinned `filemanager` and `fzf` plugins.
- Integrated terminal defaults.
- TypeScript/JavaScript/TSX/JSX LSP through the patched plugin.
- Installer, `doctor`, and smoke-test skeleton.
- README, keymap, LSP, and troubleshooting docs.

**Exit:** `microboss` opens a React TypeScript project and provides working
completion, diagnostics, hover, definition, references, explorer, fuzzy find,
and terminal without touching `~/.config/micro`.

### Phase 2 — Angular and multi-server hardening

- Angular language server integration.
- Project-aware dispatcher for nested and monorepo roots.
- HTML/CSS/JSON servers and Angular external templates.
- LSP status command and log rotation.
- Angular fixture and smoke test.

**Exit:** the Angular fixture gets template diagnostics, completion, and
navigation; the dispatcher starts the correct server per project and never
duplicates a server for the same root.

### Phase 3 — Polish and release

- Prettier integration when a project config exists.
- React/Angular snippets.
- Status line with LSP and git state.
- Update/rollback flow and CI matrix.
- Release documentation and a tagged `v0.1.0`.

**Exit:** clean-machine install, doctor, and smoke tests pass in CI; the release
is tagged and documented.

---

## 12. Acceptance criteria for 1.0

1. A clean Linux machine with Micro and Node 20.19+ can run one install command
   and then `microboss`.
2. `~/.config/micro` is byte-for-byte unchanged after installation and use.
3. Opening `~/react-app` (React 19 + Vite + TypeScript) gives:
   - TSX diagnostics in the gutter;
   - completion for React and project symbols;
   - hover, definition, references, and rename;
   - working `F2`/`Ctrl+B` explorer, `Ctrl+P` fuzzy find, and `Ctrl+`` terminal.
4. Opening the Angular 21 demo project gives:
   - TypeScript diagnostics;
   - external-template diagnostics and completion;
   - navigation from a template to its component;
   - no duplicate diagnostics from multiple servers.
5. `microboss doctor` exits non-zero when a required component is missing and
   prints a fix for every failure.
6. `microboss doctor --json` is machine-readable and covered by a test.
7. The smoke test runs against both fixtures in a temporary directory and leaves
   no changes in the source fixtures.
8. Startup does not block on a language server that is not needed for the
   current buffer.
9. The keymap parses without errors and every documented shortcut is either
   functional or explicitly marked as a terminal limitation.
10. All documentation links resolve and the install instructions work from a
    clean checkout.

---

## 13. Test matrix

| Scenario | What is verified |
| --- | --- |
| Empty directory | Launch, explorer, config creation, no crash. |
| React 19 + Vite + TS fixture | TSX LSP, React symbols, formatting, explorer filters. |
| Angular 21 fixture | Angular LS, external template, nested roots. |
| Monorepo with two `tsconfig.json` files | Per-file root selection, no duplicate servers. |
| Missing language server | Doctor failure, actionable message, editor still opens. |
| Read-only home / no write access | Clear error before partial install. |
| Re-run installer | Idempotence, backups, no duplicate plugin entries. |
| `--dev` mode | Symlinked config updates live; uninstall leaves repo intact. |
| Terminal without true color | Graceful 256-color fallback. |
| SSH session without clipboard | Documented OSC 52 behavior and fallback. |

Local verification uses the existing projects:

- `/home/dangelov/react-app` for React/TSX;
- `/home/dangelov/projects/angular` for Angular.

These are read-only fixtures from microboss's perspective. The smoke test copies
them to a temporary directory before editing.

---

## 14. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Micro plugin APIs change between releases. | Pin Micro and plugin versions; test upgrades explicitly. |
| Upstream LSP plugin remains unmaintained. | Vendor the pinned plugin, keep the patch small, add regression tests. |
| Angular LS requires a newer Node than the user's. | Doctor checks Node 20.19+; print the exact requirement; do not silently fall back. |
| TypeScript 7 drops `tsserver.js`. | Pin TypeScript 5.9.x in the isolated toolchain; check for the file in doctor. |
| Terminal keybindings differ by emulator. | Verify the common terminals; document limits; provide alternate bindings. |
| fzf is not installed. | Installer installs a pinned binary or prints a package-manager command; editor still works without it. |
| LSP startup slows editor launch. | Lazy-start per project/buffer; never block the UI on a server. |
| Monorepo root detection is wrong. | Explicit rules, `microboss lsp` diagnostics, and fixture tests. |
| Users expect their existing Micro config. | Isolated by default; `--dev`/migration docs; never overwrite `~/.config/micro`. |
| Scope creep into a full IDE. | Keep the non-goals visible; defer debugging and extension systems. |

---

## 15. Decisions and defaults

These are the defaults for implementation unless the user changes them:

1. **Isolated installation.** `microboss` uses `~/.config/microboss` and leaves
   `~/.config/micro` untouched.
2. **Copy by default, symlink in development.** Users get a stable copy;
   `microboss install --dev` symlinks the repository for contribution.
3. **Angular is part of 1.0.** It is delivered in Phase 2, after the MVP editor
   foundation, but it is a release blocker, not an optional extra.
4. **One dev agent.** The slopboss board is configured with a single dev agent
   and the OpenCode DeepSeek free model for the initial planning and
   implementation work.
5. **No implementation before plan acceptance.** Phase 0 produces the plan,
   backlog, and test strategy only.

---

## 16. Slopboss workflow

- Board root: `~/projects/microboss-board`
- Product repo: `git@github.com:de-angelov/microboss.git`
- Base branch: `main`
- Provider: `opencode`
- Model: `opencode/deepseek-v4.1-flash-free`
- Dev agents: 1
- First task: read this plan, validate assumptions, and write a concrete
  task breakdown to `BACKLOG.md`; do not write editor code.

The repository's `PLAN.md` is the source of truth for scope. The board's
`TECH.md` is the source of truth for build, test, and verification commands. A
task is not complete until the matching documentation and tests are updated.

---

## 17. Open questions for the user

1. Should the command be `microboss` (matching the repository) or `microbosss`
   with three `s` characters? The plan uses `microboss`.
2. Should microboss support macOS in the first release, or Linux only?
3. Is a bundled Node runtime acceptable if no suitable Node is installed, or
   should the installer require Node 20.19+ and stop with instructions?
4. Should the first release include Prettier formatting, or defer it to the
   polish phase?

None of these block Phase 0. The plan assumes the recommended defaults above.
