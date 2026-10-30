# TASKS

Active work board. Keep at most one task In Progress per dev-agent lane.

## Dev Agent 1 In Progress

### Vendor filemanager and explorer defaults

Task ID: PLUG-01
Owner: Dev Agent 1
Branch: agent/1/plug-01-filemanager
Status: In Progress
Category: AFK

## Objective

Vendor `filemanager` 3.5.1, bind the explorer, hide noise by default, and keep
editor focus.

## Scope

- `config/plug/filemanager/`
- `config/bindings.json`
- `config/settings.json`
- `config/init.lua`
- `tests/smoke/test_filemanager.sh`

## Out of Scope

- fzf, LSP, installer, update.

## Acceptance Criteria

- The vendored plugin reports version 3.5.1 and includes its `repo.json` and
  license.
- `F2` and `Ctrl+B` open and close the tree. If focus restoration needs a
  wrapper, a small `init.lua` wrapper is allowed.
- `filemanager.showdotfiles` and `filemanager.showignored` are `false`.
- Opening the tree does not leave the cursor trapped in the tree after the
  wrapper runs; the smoke test asserts the active pane is not the tree after
  opening a fixture file.
- Opening and closing the tree works in a temporary fixture.
- The test does not read or write `~/.config/micro`.

## Verification

```sh
jq empty config/settings.json config/bindings.json
bash tests/smoke/test_filemanager.sh
```

## Progress Notes

- 2026-10-30: Task created from the approved plan review.
