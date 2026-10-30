# TASKS

Active work board. Keep at most one task In Progress per dev-agent lane.

## Dev Agent 1 In Progress

### Harden launcher for symlinked installs and toolchain

Task ID: LAUNCH-01
Owner: Dev Agent 1
Branch: agent/1/launch-01-hardening
Status: In Progress
Category: AFK

## Objective

Harden the launcher for symlinked installs, the isolated toolchain, cursor
arguments, and test overrides.

## Scope

- `bin/microboss`
- `tests/smoke/test_launcher.sh`
- `docs/architecture.md`

## Out of Scope

- Installer, update, doctor, or plugin behavior.

## Acceptance Criteria

- Works when invoked through a symlink in a temporary `PATH` directory.
- Prepends `$MICROBOSS_DATA/tools/node_modules/.bin` to `PATH` when that
  directory exists, without duplicating an existing entry.
- Passes `FILE`, `+LINE:COL`, and `--` arguments through unchanged.
- Respects `MICROBOSS_CONFIG`, `MICROBOSS_DATA`, and `MICROBOSS_CACHE`.
- The test runs with a temporary `HOME` and asserts `~/.config/micro` is not
  created or modified.
- `bash -n bin/microboss` passes.

## Verification

```sh
bash -n bin/microboss
bash tests/smoke/test_launcher.sh
```

## Progress Notes

- 2026-10-30: Task created from the approved plan review.
