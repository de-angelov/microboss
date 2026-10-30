# TASKS

Active work board. Keep at most one task In Progress per dev-agent lane.

## Dev Agent 1 In Progress

### Add VS Code-like keymap and validation

Task ID: KEY-01
Owner: Dev Agent 1
Branch: agent/1/key-01-bindings
Status: In Progress
Category: AFK

## Objective

Ship a `bindings.json` that uses only keys Micro 2.0.13 can bind, and document
the differences from VS Code.

## Scope

- `config/bindings.json`
- `config/init.lua` (only the soft-wrap helper if required for `Alt+Z`)
- `docs/keymap.md`
- `tests/smoke/test_bindings.sh`

## Out of Scope

- Plugin implementation, LSP actions, installer, or embedded-terminal bindings.
- Vendoring `filemanager`, `fzf`, or `lsp`.

## Acceptance Criteria

- `jq empty config/bindings.json` passes.
- No binding uses `Ctrl+Shift+<key>`, `Ctrl+Tab`, `Ctrl+\``, `Shift+Escape`, or
  another key absent from Micro 2.0.13's bindable key list.
- The documented set covers: `F2`/`Ctrl+B` tree, `Ctrl+P` fzf, `Ctrl+E`
  command mode, `Ctrl+Q` quit, `Alt+Q` quit all, `Alt+.`/`Alt+,` tabs,
  `Ctrl+\` vsplit, `Alt+\` hsplit, `F3` find next, `Alt+P` find previous,
  `F12`/`Alt+D` definition, `Alt+R` references, `Alt+K` hover, `Ctrl+Space`
  completion, `Alt+F` format, `CtrlUnderscore`/`Alt+/` comment, `Ctrl+D`
  multi-cursor, `Ctrl+U` remove cursor, `Alt+C` clear cursors, `Alt+Shift+D`
  duplicate line, `Alt+Up/Down` move line, and `Alt+Z` soft wrap.
- The test rejects unknown key names and checks that every documented shortcut is
  present in `bindings.json`.
- `docs/keymap.md` explains the unavoidable VS Code differences.

## Verification

```sh
jq empty config/bindings.json
bash tests/smoke/test_bindings.sh
```

## Progress Notes

- 2026-10-30: Task created from the approved plan review.
