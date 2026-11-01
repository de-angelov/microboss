# TASKS

Active work board. Keep at most one task In Progress per dev-agent lane.

## Dev Agent 1 In Progress

### Idempotent installer

Task ID: INSTALL-01
Owner: Dev Agent 1
Branch: agent/1/install-01
Status: In Progress
Category: AFK

## Objective

Implement a safe, repeatable installer for the isolated config, launcher, and
optional toolchain.

## Scope

- `scripts/install.sh`
- `tests/smoke/test_install.sh`
- `docs/architecture.md`

## Out of Scope

- Update/rollback, doctor, LSP runtime behavior.

## Acceptance Criteria

- Default mode copies `config/` to `${XDG_CONFIG_HOME:-$HOME/.config}/microboss`.
- `--dev` symlinks the repository `config/` instead of copying.
- `--no-tools` installs config only and does not run `npm ci`.
- `--prefix DIR` installs the launcher outside `~/.local/bin`.
- `--force` backs up an existing microboss-managed file before replacing it.
- Re-running is idempotent and does not duplicate plugin entries.
- The test asserts `~/.config/micro` is unchanged.
- The installer prints a summary of what changed.
- The install uses the pinned `tools/package.json` and lockfile when installing
  the toolchain into `$MICROBOSS_DATA/tools`.

## Verification

```sh
bash -n scripts/install.sh
bash tests/smoke/test_install.sh
```

## Progress Notes

- 2026-11-01: Task created from the approved plan review.
