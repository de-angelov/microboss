# TASKS

Active work board. Keep at most one task In Progress per dev-agent lane.

## Dev Agent 1 In Progress

### Add default editor settings

Task ID: CONF-01
Owner: Dev Agent 1
Branch: agent/1/conf-01-settings
Status: In Progress
Category: AFK

## Objective

Ship a valid `config/settings.json` with the editor defaults in `PLAN.md` §5.1
using exact Micro 2.0.13 option names.

## Scope

- `config/settings.json`
- `tests/smoke/test_settings.sh`

## Out of Scope

- Keybindings, plugin options, LSP server configuration, installer, or an
  embedded terminal.
- Adding `init.lua` unless a setting cannot be expressed in JSON.

## Acceptance Criteria

- `jq empty config/settings.json` passes.
- Settings include `mouse`, `ruler`, `statusline`, `softwrap`, `saveundo`,
  `backup`, `backupdir`, `autoindent`, `rmtrailingws`, `paste`, `smartpaste`,
  `clipboard`, and `scrollspeed`.
- `backupdir` points under `~/.cache/microboss` without hard-coding a user's home
  directory.
- The test asserts the presence and JSON type of every setting.
- No reference to `~/.config/micro` appears in the config.

## Verification

```sh
jq empty config/settings.json
bash tests/smoke/test_settings.sh
```

## Progress Notes

- 2026-10-30: Task created from the approved plan review.
