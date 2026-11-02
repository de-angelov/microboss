# Language server plugin

microboss vendors the [Micro LSP client](https://github.com/AndCake/micro-plugin-lsp)
at the pinned upstream release **v0.6.2**. The plugin lives at
`config/plug/lsp/`; its entry point is `config/plug/lsp/main.lua`, which Micro
loads automatically from the plugin directory.

The vendored copy includes the upstream `LICENSE`, `README.md`, `repo.json`, and
`help/` along with the pinned source. microboss never runs implicit plugin
updates, so the editor always starts the version recorded in the repository.

## Configuration

The plugin is configured through Micro's settings, notably `lsp.server` and
`lsp.formatOnSave`. Keep server selections in the microboss configuration rather
than in a personal Micro setup, so every project uses the same pinned toolchain.

Because the launcher starts Micro with `-config-dir` pointing at
`~/.config/microboss`, the vendored plugin is loaded from the microboss
configuration tree. microboss never reads or writes Micro's own
`~/.config/micro`; that directory stays untouched even when a user runs both
editors side by side. See [Architecture](architecture.md) for the full set of
runtime directories.

## Patch policy

Patches are applied directly to the vendored copy under `config/plug/lsp/`, not
to a local checkout of upstream. Every local change must be recorded in
`config/plug/lsp/UPSTREAM.md` with:

- what the patch changes and why it is needed;
- the upstream release the patch applies to;
- the upstream status (reported, merged, or intentionally local).

[UPSTREAM.md](../config/plug/lsp/UPSTREAM.md) is the source of truth for
provenance. It records the pinned tag, archive URL, retrieval date, and archive
checksum. Update it in the same change that touches the vendored source so the
patch history stays auditable.

When upgrading the plugin, replace the vendored tree with the new upstream
release and re-apply or retire each documented patch before updating
`UPSTREAM.md`.
