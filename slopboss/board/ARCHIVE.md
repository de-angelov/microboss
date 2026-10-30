# ARCHIVE

Completed work history. Normal orchestrator prompts do not load this file.

## Done

### Validate the microboss plan and produce the implementation backlog

Task ID: PLAN-01
Owner: Dev Agent 1
Branch: agent/1/plan-review
Status: Done
Completed: 2026-10-30

## Objective

Validate `PLAN.md` against the actual Micro 2.0.13 capabilities and produce a
concrete, dependency-ordered implementation backlog for microboss. Planning only.

## Result

- `docs/plan-review.md` added: validation table, evidence sources, a
  recommended first vertical slice, 20 dependency-ordered tasks
  (`FOUND-01` through `RELEASE-01`), and HITL risks.
- `PLAN.md` corrected for factual accuracy: pinned Micro 2.0.13 baseline
  (2.0.15 deferred to a separate upgrade task), bindable keymap only, real
  `-options` names, filemanager/fzf defaults, LSP plugin 0.6.2 limitations,
  Angular language-server Node range, rename/code-action deferral, and the
  `detectindent` plugin.
- Embedded terminal confirmed available in Micro but explicitly out of scope.

## Verification

```sh
test -f docs/plan-review.md
test "$(grep -c '^### ' docs/plan-review.md)" -ge 12
git diff --check
```

- `docs/plan-review.md` present; 20 task headings (>= 12).
- `git diff --check` exit 0.
- Squash commit `d42db54` on `main`; `git merge-base --is-ancestor d42db54
  origin/main` exit 0.

## Follow-up

- `TECH.md` still mentions an integrated terminal and `Micro 2.0.13+`. It
  conflicts with the out-of-scope decision and the pinned baseline; the Team
  Lead should align it.

### Repository skeleton and isolated launcher

Task ID: FOUND-01
Owner: Dev Agent 1
Branch: agent/1/found-01-launcher
Status: Done
Completed: 2026-10-30

## Objective

Add the minimal distribution skeleton and a launcher that starts Micro with an
isolated config directory.

## Result

- `bin/microboss`: POSIX `sh` launcher that resolves its own path through
  symlinks, exports `MICROBOSS_ROOT`, `MICROBOSS_CONFIG`, `MICROBOSS_DATA`, and
  `MICROBOSS_CACHE`, fails with an actionable message when `micro` is missing,
  and execs `micro -config-dir "$MICROBOSS_CONFIG" "$@"`.
- Directories default under `HOME` with XDG support
  (`${XDG_CONFIG_HOME:-$HOME/.config}/microboss` and equivalents) and remain
  overridable through the three `MICROBOSS_*` variables.
- `config/.gitkeep`, `tests/fixtures/empty/.gitkeep`, and a
  `docs/architecture.md` stub.
- `tests/smoke/test_launcher.sh`: 33 assertions using a temporary `HOME` and a
  fake `micro`; covers default and overridden directories, XDG bases, argument
  passthrough (`FILE`, `+LINE:COL`, `--`), symlinked invocation, POSIX `sh`
  invocation, missing `micro`, and that `~/.config/micro` is neither created nor
  modified.

## Verification

```sh
bash -n bin/microboss
bash tests/smoke/test_launcher.sh
```

- `bash -n bin/microboss` exit 0; `sh -n bin/microboss` exit 0.
- `bash tests/smoke/test_launcher.sh`: 33 passed, 0 failed (re-run on `main`
  after the squash merge).
- `git diff --check` exit 0.
- Squash commit `dd20fed` on `main`; `git merge-base --is-ancestor dd20fed
  origin/main` exit 0.

### Add default editor settings

Task ID: CONF-01
Owner: Dev Agent 1
Branch: agent/1/conf-01-settings
Status: Done
Completed: 2026-10-30

## Objective

Ship a valid `config/settings.json` with the editor defaults in `PLAN.md` §5.1
using exact Micro 2.0.13 option names.

## Result

- `config/settings.json`: mouse, ruler, statusline, saveundo, backup,
  autoindent, rmtrailingws, paste, and smartpaste enabled; softwrap disabled;
  `backupdir` set to `~/.cache/microboss`; `clipboard` set to `terminal`;
  `scrollspeed` kept at Micro's default of 2.
- `tests/smoke/test_settings.sh`: 42 assertions covering JSON validity, the
  presence and JSON type of every required setting, expected default values,
  portable `backupdir`, and the absence of a `~/.config/micro` reference.
- Removed the now-obsolete `config/.gitkeep` placeholder.

## Verification

```sh
jq empty config/settings.json
bash tests/smoke/test_settings.sh
git diff --check
```

- `jq empty config/settings.json` exit 0.
- `bash tests/smoke/test_settings.sh`: 42 passed, 0 failed (re-run on `main`
  after the squash merge).
- `git diff --check` exit 0.
- Squash commit `360c522` on `main`; `git merge-base --is-ancestor 360c522
  origin/main` exit 0.
