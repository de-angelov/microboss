# TASKS

Active work board. Keep at most one task In Progress per dev-agent lane.

## Dev Agent 1 In Progress

### Repository skeleton and isolated launcher

Task ID: FOUND-01
Owner: Dev Agent 1
Branch: agent/1/found-01-launcher
Status: In Progress
Category: AFK

## Objective

Add the minimal distribution skeleton and a launcher that starts Micro with an
isolated config directory.

## Scope

- `bin/microboss`
- `config/` directory skeleton
- `docs/architecture.md` stub
- `tests/smoke/test_launcher.sh`
- `tests/fixtures/empty/.gitkeep`

## Out of Scope

- Editor settings, keybindings, plugins, toolchain, installer, doctor, LSP.
- Embedded terminal support.

## Acceptance Criteria

- `bin/microboss` is POSIX `sh`, resolves its own path through a symlink, and
  execs `micro -config-dir "$MICROBOSS_CONFIG" "$@"`.
- It fails with a clear message when `micro` is not on `PATH`.
- A temp-`HOME` test asserts that `~/.config/micro` is not created or modified.
- `MICROBOSS_CONFIG`, `MICROBOSS_DATA`, and `MICROBOSS_CACHE` can override the
  default directories for tests.
- `bash -n bin/microboss` passes.

## Verification

```sh
bash -n bin/microboss
bash tests/smoke/test_launcher.sh
```

## Progress Notes

- 2026-10-30: Task created from the approved plan review.
