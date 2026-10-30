# Architecture

microboss is a thin distribution around the Micro terminal editor. The
repository is the source of truth; the installed configuration is either a copy
of `config/` or, for distribution development, a symlink to it.

## Directory layout

```text
microboss/
├── bin/microboss        # launcher
├── config/              # Micro settings, bindings, init.lua, vendored plugins
├── docs/                # user-facing documentation
├── scripts/             # install, update, doctor, smoke tests
├── tests/               # smoke tests and fixtures
└── VERSION
```

## Runtime directories

microboss never reads or writes Micro's own `~/.config/micro`. All state lives
under dedicated directories:

| Variable | Default | Purpose |
| --- | --- | --- |
| `MICROBOSS_CONFIG` | `${XDG_CONFIG_HOME:-$HOME/.config}/microboss` | Settings, bindings, `init.lua`, vendored plugins. |
| `MICROBOSS_DATA` | `${XDG_DATA_HOME:-$HOME/.local/share}/microboss` | Pinned language-server toolchain and lockfiles. |
| `MICROBOSS_CACHE` | `${XDG_CACHE_HOME:-$HOME/.cache}/microboss` | Disposable caches, backups, test artifacts. |

All three variables are exported to Micro, so configuration can refer to them
without hard-coding a user's home directory. They also make the launcher testable
with a temporary `HOME`.

## Launcher

`bin/microboss` is a POSIX `sh` script. It:

1. resolves its own path, following symlinks, so it works from any working
   directory, from a link such as `~/.local/bin/microboss`, and when invoked by
   bare name from `PATH`;
2. exports `MICROBOSS_ROOT` (the distribution root) and the three runtime
   directory variables;
3. prepends `$MICROBOSS_DATA/tools/node_modules/.bin` to `PATH` when it exists,
   so the pinned toolchain wins over global tools; an entry that is already on
   `PATH` is left in place instead of being duplicated;
4. checks that `micro` is on `PATH` and fails with an actionable message when it
   is not;
5. execs `micro -config-dir "$MICROBOSS_CONFIG" "$@"`, passing every user
   argument, including `FILE`, `+LINE:COL`, and `--`, through unchanged.

The launcher does not create directories, install plugins, or modify the user's
environment; those are installer and `doctor` responsibilities.

## Verification

```sh
bash -n bin/microboss
bash tests/smoke/test_launcher.sh
```

The smoke test runs the launcher with a temporary `HOME` and a fake `micro`, and
asserts that `~/.config/micro` is neither created nor modified.
