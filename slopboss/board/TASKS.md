# TASKS

Active work board. Keep at most one task In Progress per dev-agent lane.

## Dev Agent 1 In Progress

### Vendor fzf and project-aware ignores

Task ID: PLUG-02
Owner: Dev Agent 1
Branch: agent/1/plug-02-fzf
Status: In Progress
Category: AFK

## Objective

Vendor `fzf` 1.1.1, bind `Ctrl+P`, and provide project-aware file listing
without breaking non-git directories.

## Scope

- `config/plug/fzf/`
- `config/bindings.json`
- `bin/microboss`
- `tests/smoke/test_fzf.sh`

## Out of Scope

- Project-wide text-search UI, filemanager, LSP.

## Acceptance Criteria

- The vendored plugin reports version 1.1.1.
- `Ctrl+P` runs `command:fzf`.
- The launcher exports `FZF_DEFAULT_COMMAND` using `rg --files` with excludes
  for `.git`, `node_modules`, `dist`, and `coverage` when `rg` is available.
- The launcher falls back to a portable `find` command when `rg` is missing.
- A missing `fzf` binary prints a clear message and does not crash Micro.
- Any tmux integration test uses a unique `tmux -L <socket>` server and never
  kills the default tmux server.
- The test uses a temporary `HOME` and never reads or writes `~/.config/micro`.

## Verification

```sh
jq empty config/bindings.json
bash tests/smoke/test_fzf.sh
```

## Progress Notes

- 2026-11-01: Task created from the approved plan review.
