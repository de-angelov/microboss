# microboss

**microboss** is an opinionated, LazyVim-style distribution of the
[Micro](https://micro-editor.github.io/) terminal editor for TypeScript, React,
and Angular development.

It aims to feel like a lightweight VS Code for the terminal: a familiar editor
surface, a file explorer, fuzzy file finding, and language-server support that
works in real projects without a pile of manual setup. It runs inside an existing
terminal tab (Tilix, tmux, SSH, or similar); it does not embed a terminal.

```sh
microboss
```

## Status

Planning. The implementation plan lives in [PLAN.md](PLAN.md). No editor
packaging has been published yet.

## Principles

- **Batteries included, not bloated.** A small, pinned set of plugins and tools
  that cover the daily TS/React/Angular workflow.
- **VS Code muscle memory.** Keep the shortcuts developers already know wherever
  Micro allows it, and document the few unavoidable differences.
- **Modular and recoverable.** Every layer can be inspected, updated, and
  repaired independently. `microboss doctor` tells you what is broken.
- **Isolated by default.** microboss uses its own config, data, and cache
  directories. It never rewrites an existing `~/.config/micro`.
- **Docs are part of the product.** If a feature is not documented and
  discoverable, it is not finished.

## Planned command surface

| Command | Purpose |
| --- | --- |
| `microboss` | Launch the editor with the microboss config. |
| `microboss install` | Install or repair pinned plugins and language servers. |
| `microboss update` | Update the distribution and pinned components. |
| `microboss doctor` | Check the environment and print actionable fixes. |
| `microboss lsp` | Show language-server status for the current project. |
| `microboss version` | Print the distribution version. |

## Repository layout

```text
microboss/
├── bin/                 # launcher and CLI
├── config/              # Micro settings, bindings, init.lua, vendored plugins
├── docs/                # user-facing docs and troubleshooting
├── scripts/             # install, update, doctor, smoke tests
├── tests/               # fixtures and automated smoke tests
├── PLAN.md              # the implementation plan
└── VERSION
```

## Development workflow

This repository is developed with **slopboss**, one agent at a time. The board
keeps planning, implementation, and verification as small, reviewable tasks.
See [PLAN.md](PLAN.md) for the phased delivery plan.
