# TASKS

Active work board. Keep at most one task In Progress per dev-agent lane.

## Dev Agent 1 In Progress

### Pinned language-server toolchain

Task ID: TOOLS-01
Owner: Dev Agent 1
Branch: agent/1/tools-01-toolchain
Status: In Progress
Category: AFK

## Objective

Add a lockfile-based toolchain with exact server and TypeScript pins.

## Scope

- `tools/package.json`
- `tools/package-lock.json`
- `tests/smoke/test_tools.sh`

## Out of Scope

- Installer and doctor scripts, LSP plugin, editor configuration.

## Acceptance Criteria

- Exact pins: `typescript@5.9.3`, `typescript-language-server@5.3.0`,
  `vscode-langservers-extracted@4.10.0`, and
  `@angular/language-server@21.2.25`.
- `npm ci --prefix tools --ignore-scripts` succeeds and
  `tools/node_modules/typescript/lib/tsserver.js` exists.
- `npm ls --prefix tools --depth=0` shows the exact versions.
- The lockfile is committed with the manifest.
- The test uses temporary cache/log directories where practical and does not
  write outside the repo.

## Verification

```sh
npm ci --prefix tools --ignore-scripts
test -f tools/node_modules/typescript/lib/tsserver.js
npm ls --prefix tools --depth=0
bash tests/smoke/test_tools.sh
```

## Progress Notes

- 2026-11-01: Task created from the approved plan review.
