# slopboss board backup

This folder is a portable snapshot of the **slopboss** board used to build
microboss. It lets you restore the same workflow on another machine without
recreating the board or remembering the agent/model settings.

## What is here

```text
slopboss/
├── README.md          # this file
├── backup.sh          # refresh the snapshot from a live board
├── restore.sh         # recreate the board and workspaces
└── board/             # snapshot of the board/configuration files
```

The `board/` directory contains:

- `AGENTS.md`, `DEV_AGENT.md`, `TEAM_LEAD_AGENT.md`
- `BACKLOG.md`, `TASKS.md`, `ARCHIVE.md`
- `CONFIG.md` (provider, model, repository, branch, agent count)
- `TECH.md` (build, test, and verification conventions)

The `workspaces/` directory is intentionally **not** backed up. `restore.sh`
recreates the team-lead and dev-agent clones from the product repository.

## Restore on another machine

Prerequisites:

- `slopboss` installed and on `PATH` (or set `SLOPBOSS_BIN`)
- SSH access to `git@github.com:de-angelov/microboss.git`
- Micro 2.0.13, Node.js in the Angular-supported range, npm, and OpenCode
- OpenCode authenticated for `opencode/deepseek-v4.1-flash-free`

Then:

```sh
git clone git@github.com:de-angelov/microboss.git
cd microboss
./slopboss/restore.sh ~/projects/microboss-board
slopboss run --dir ~/projects/microboss-board
```

`restore.sh` runs `slopboss setup` with one agent and the OpenCode provider,
then replaces the scaffolded board files with this snapshot so the active task,
archive, model pins, and conventions are preserved.

If the target board already exists, the snapshot files are replaced. Move or
back up an existing board first if you need to keep it.

## Refresh this snapshot

From the repository root, with the live board at its default location:

```sh
./slopboss/backup.sh
```

Or point it at another board:

```sh
./slopboss/backup.sh ~/projects/microboss-board
```

Commit the updated `slopboss/board/` files afterward.

## Notes

- The snapshot currently uses **one dev agent** to keep token use and merge
  conflicts low.
- `CONFIG.md` pins the OpenCode dev and team-lead models to
  `opencode/deepseek-v4.1-flash-free`.
- The full implementation task list lives in the product repository at
  `docs/plan-review.md`; the board's `TASKS.md` only contains the current
  active task.
- Embedded-terminal support is out of scope. microboss runs inside a Tilix tab,
  tmux pane, or similar host terminal.
