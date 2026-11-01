# Keymap

microboss keeps VS Code muscle memory where Micro 2.0.13 can receive the key.
Where a terminal cannot send a VS Code chord, microboss uses a documented
single-modifier alternative instead of silently binding a key that does nothing.

`config/bindings.json` is the source of truth. This page explains what each
shortcut does and why some VS Code shortcuts cannot be reproduced.

## Quick reference

| Action | VS Code | microboss | Notes |
| --- | --- | --- | --- |
| Save | `Ctrl+S` | `Ctrl+S` | Micro default. |
| Save as | `Ctrl+Shift+S` | `Alt+S` | `Ctrl+Shift` is not distinguishable from `Ctrl` in most terminals. |
| Command palette | `Ctrl+Shift+P` | `Ctrl+E` | Opens Micro's command mode. |
| Quick open | `Ctrl+P` | `Ctrl+P` | Runs the vendored fzf plugin. Overrides Micro's `FindPrevious`. Project files respect `.gitignore` and exclude `.git`, `node_modules`, `dist`, and `coverage`. |
| Explorer | `Ctrl+Shift+E` | `F2`, `Ctrl+B` | Toggles the file tree and returns focus to the editor. Overrides Micro's `F2` Save and `Ctrl+B` shell mode. |
| Close editor | `Ctrl+W` | `Ctrl+Q` | Micro's `Quit` closes the current pane. There is no `CloseTab` action, and `Ctrl+W` is `NextSplit`. |
| Close all | `Ctrl+Shift+W` | `Alt+Q` | Quits every tab and split. |
| New tab | `Ctrl+N` | `Ctrl+T` | Micro's `AddTab` opens an empty buffer in a new tab. |
| Next tab | `Ctrl+Tab` | `Alt+.` | `Ctrl+Tab` is usually captured by the terminal or tmux. |
| Previous tab | `Ctrl+Shift+Tab` | `Alt+,` | `Ctrl+Shift+Tab` is terminal-dependent. |
| Split editor | `Ctrl+\` | `Ctrl+\` | Vertical split. |
| Horizontal split | `Ctrl+Shift+\` | `Alt+\` | `Ctrl+Shift` is not distinguishable in most terminals. |
| Open file | `Ctrl+O` | `Ctrl+O` | Prompts for a path. |
| Find | `Ctrl+F` | `Ctrl+F` | In-buffer search. |
| Find next | `F3` | `F3` | Rebound from Micro's `Find` to `FindNext`. |
| Find previous | `Shift+F3` | `Alt+P` | `Shift+F3` is terminal-dependent. |
| Go to definition | `F12` | `F12`, `Alt+D` | Provided by the LSP plugin. |
| Find references | `Shift+F12` | `Alt+R` | Provided by the LSP plugin. |
| Hover | `Ctrl+K Ctrl+I` | `Alt+K` | Provided by the LSP plugin. |
| Completion | `Ctrl+Space` | `Ctrl+Space` | Provided by the LSP plugin. |
| Format document | `Shift+Alt+F` | `Alt+F` | Provided by the LSP plugin. |
| Toggle comment | `Ctrl+/` | `CtrlUnderscore`, `Alt+/` | `Ctrl+/` normally arrives as `CtrlUnderscore`; `Alt+/` is the fallback. |
| Multi-cursor next | `Ctrl+D` | `Ctrl+D` | Rebound from `DuplicateLine` to `SpawnMultiCursor`. |
| Remove cursor | `Ctrl+U` | `Ctrl+U` | Rebound from `ToggleMacro` to `RemoveMultiCursor`. |
| Clear cursors | `Escape` | `Alt+C` | Removes every secondary cursor. |
| Delete line | `Ctrl+Shift+K` | `Ctrl+K` | `Ctrl+Shift` is unavailable, so this keeps Micro's `CutLine`. |
| Select line | `Ctrl+L` | `Ctrl+L` | Rebound from `command-edit:goto` to `SelectLine`. |
| Duplicate line | `Shift+Alt+Down` | `Alt+Shift+D` | Micro has no directional duplicate-line action. |
| Move line up | `Alt+Up` | `Alt+Up` | Micro default. |
| Move line down | `Alt+Down` | `Alt+Down` | Micro default. |
| Toggle soft wrap | `Alt+Z` | `Alt+Z` | `config/init.lua` toggles the buffer's `softwrap` setting. |

## File explorer

`F2` and `Ctrl+B` toggle the vendored `filemanager` tree. Dotfiles and
VCS-ignored paths are hidden by default: `config/settings.json` sets
`filemanager.showdotfiles` and `filemanager.showignored` to `false`. The
upstream plugin focuses the new tree pane, so `config/init.lua` wraps its `tree`
command and returns focus to the editor after the tree opens.

## Quick open

`Ctrl+P` runs the vendored `fzf` plugin. The launcher exports
`FZF_DEFAULT_COMMAND`, so the file list is project-aware:

- when `rg` is available, `rg --files` respects `.gitignore` and also excludes
  `.git`, `node_modules`, `dist`, and `coverage`;
- when `rg` is missing, a portable `find` command prunes the same directories;
- both forms include hidden files, so files such as `.gitignore` remain
  reachable.

`fzf` is optional. If the binary is missing, `Ctrl+P` shows
`fzf not found on PATH. Install fzf to use quick open (Ctrl+P).` in the info bar
and the editor keeps running.

## Unavoidable VS Code differences

Terminals send key events, not VS Code's logical key chords. That creates a few
hard limits:

- **`Ctrl+Shift+<key>` is unavailable.** Most terminals cannot distinguish
  `Ctrl+Shift+P` from `Ctrl+P`. microboss therefore uses `Ctrl+E` for the
  command palette, `Alt+S` for Save as, `Alt+Q` for Quit all, `Alt+\` for a
  horizontal split, `Alt+F` for formatting, and `Ctrl+K` for deleting a line.
- **`Ctrl+Tab` is unavailable.** Tilix, tmux, and many other terminals capture
  it for their own tab switching. Use `Alt+.` and `Alt+,` instead.
- **`Ctrl+\`` is unavailable.** It is often intercepted by the terminal, and
  microboss does not embed a terminal, so there is no terminal binding to
  reproduce.
- **`Shift+Escape` is unreliable.** `Escape` already deselects, clears the info
  bar, removes secondary cursors, and clears search highlighting in Micro.
- **`Shift+F3` and `Shift+F12` are terminal-dependent.** Use `Alt+P` for the
  previous match and `Alt+R` for references.
- **Micro has no `CloseTab` action.** `Ctrl+Q` closes the current pane, which is
  the closest equivalent to VS Code's Close editor. `Ctrl+W` is Micro's
  `NextSplit`, not a close shortcut.
- **Micro has no directional duplicate-line action.** `Alt+Shift+D` duplicates
  the current line or selection regardless of cursor direction.
- **`Ctrl+/` usually arrives as `CtrlUnderscore`.** Both `CtrlUnderscore` and
  `Alt+/` toggle a comment.
- **`Ctrl+Space` can be captured by an input method or terminal.** If it does
  not reach Micro, run `lspcompletion` from the command palette (`Ctrl+E`).
- **`Alt+Shift+D` depends on the terminal.** Some terminals drop the Shift
  modifier for letters. If your terminal does, bind another single-modifier key
  in `config/bindings.json`.

## Customizing

Edit `config/bindings.json` and restart Micro. Use Micro's key names, not the
display names in the table above:

- write `CtrlP`, not `Ctrl+P`;
- write `Alt-p`, not `Alt+P`;
- write `CtrlBackslash` for `Ctrl+\`;
- write `Alt-\` for `Alt+\`;
- write `CtrlSpace` for `Ctrl+Space`.

Micro accepts an optional dash between modifiers and keys, which is why the
bindings file uses forms such as `Alt-.` and `Alt-/`. See `> help keybindings`
inside Micro for the full key-name reference.
