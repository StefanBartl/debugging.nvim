# Core

The `:Debug` command itself, the config/feature-flag system it dispatches
through, and the cross-cutting infrastructure (health check, lib.nvim
dependency, docs, tests, tooling) that every category below relies on.

## Unified `:Debug` dispatcher with two-level completion

A single `:Debug {category} {action} [args]` user command replaces what used
to be a set of separate legacy commands. `debugging.commands` builds a
category → action → handler registry lazily (leaf modules load on demand),
and drives both dispatch and `:command-complete` from that same registry, so
completion can never drift out of sync with what actually runs.

- **Module:** `commands.lua` (`M.dispatch`, `M.complete`, `build_registry`)
- **Usercmds:** `:Debug {category} {action}` (see
  [BINDINGS.md](../BINDINGS.md#user-commands))
- **Config:** `opts.command` (name of the registered command, default
  `"Debug"`)

## Per-category feature flags with `all = true` shorthand

Every category (`views`, `reports`, `autocmds`, `tools`, `terminals`,
`nvim_options`, `markdown`, `neotree`, `module_reload`, `proc_trace`,
`performance`) is gated by its own `config.features.*` boolean, checked by
the dispatcher before a category is even reachable from completion. Passing
`{ all = true }` to `setup()` flips every flag on at once instead of listing
each one.

- **Module:** `config/init.lua` (`M.setup`), `commands.lua` (`enabled`,
  `enabled_categories`)
- **Config:** `opts.features.*` (see `config/DEFAULTS.lua`), `opts.all`

## `config/DEFAULTS.lua` config system with idempotent `setup()`

`config/DEFAULTS.lua` is the single, immutable source of truth for every
default; `config/init.lua` deep-merges user options over a fresh copy of it
and exposes the active table via `get()`. `debugging.setup()` itself guards
against being called twice (`_done` flag), so a config that gets required
and set up from more than one place in a user's own config is safe.

- **Module:** `config/DEFAULTS.lua`, `config/init.lua` (`M.setup`, `M.get`),
  `init.lua` (`M.setup`)

## `:checkhealth debugging`

Covers the plugin's own load state, every `lib.nvim` module it depends on,
per-feature external tools (clipboard provider, `nvim-treesitter`, `noice`,
which-key, PowerShell/CIM on Windows for `proc watch`), write permissions
for its state directory, and the injectable Neo-tree bridge targets — one
`vim.health.start()` section per concern, so a missing optional piece shows
up as exactly the feature it degrades rather than a generic warning.

- **Module:** `health.lua` (`M.check`)
- **Usercmds:** `:Debug health` / `:checkhealth debugging` (see
  [BINDINGS.md](../BINDINGS.md#user-commands))

## Built on lib.nvim as a deliberate shared dependency

Notifications, the scratch/float window helpers, buffer/window/tab report
utilities, filesystem writes, path normalization, the recursive directory
walker, and the in-memory scan cache all come from
[`lib.nvim`](https://github.com/StefanBartl/lib.nvim) rather than being
hand-rolled per feature — the same modules `:checkhealth debugging`'s
"lib.nvim" section verifies are present.

- **Docs:** [`docs/TESTS/README.md`](../TESTS/README.md)

## `docs/BINDINGS.md` cheatsheet

Machine-readable overview of every keymap, user command, and autocommand
`debugging.nvim` defines, kept in sync by hand with `bindings/keymaps.lua`,
`bindings/usercmds.lua` + `commands.lua`, and `bindings/autocmds.lua`.

- **Module:** `bindings/keymaps.lua`, `bindings/usercmds.lua`,
  `bindings/autocmds.lua`
- **Docs:** [`docs/BINDINGS.md`](../BINDINGS.md)

## Optional which-key group label

Registers a `"Debug views"` group label for the views keymap prefix with
which-key, if it is installed — a soft dependency, no-op otherwise. Supports
both the which-key v3 (`add`) and v2 (`register`) APIs.

- **Module:** `bindings/which_key.lua` (`M.setup`, `M.available`)
- **Config:** `opts.views.keymaps.prefix` (default `"<lt>"`)

## Headless spec suite

Config merge behaviour, the `autocmds sources` parsers, and `:Debug`
dispatch/completion are covered by a headless Neovim spec suite, runnable
without a UI.

- **Module:** `docs/TESTS/commands_spec.lua`, `docs/TESTS/config_spec.lua`,
  `docs/TESTS/sources_spec.lua`, `docs/TESTS/startup_spec.lua`,
  `docs/TESTS/harness.lua`, `docs/TESTS/run.lua`
- **Docs:** [`docs/TESTS/README.md`](../TESTS/README.md)

## Lint/format tooling and complete module headers

`stylua.toml`, `.luacheckrc`, and `.luarc.json` at the repo root, plus a
complete `@brief`/`@description` header on every module — the same
documentation convention this `docs/FEATURES/` catalog itself follows.

- **Module:** `stylua.toml`, `.luacheckrc`, `.luarc.json`

## `:Debug` overview as a scrollable float

The no-argument `:Debug` overview renders in a scrollable floating window by
default, listing every enabled category and its actions; falls back to a
single `lib.nvim` notification if a float can't be opened (headless / no UI)
or when explicitly configured to.

- **Module:** `commands.lua` (`overview`, `overview_float`)
- **Config:** `opts.overview` (`"float"` default, or `"notify"`)

## Scratch/float-UI moved into lib.nvim

The scratch-buffer construction used by the autocmd audit's output window,
`performance startup`'s report, and the `:Debug` float overview all go
through shared `lib.nvim` helpers instead of each hand-rolling
`vim.cmd("new")`/`nvim_open_win`: `lib.nvim.window.make_scratch` (the float
overview), `lib.nvim.window.open_scratch_split` (report-style scratch
splits), and `lib.nvim.window.tag` (window-tag lookup/reuse, replacing the
former local `find_window_by_tag`/`get_window_tag` in `views/display.lua`).
Both are generic `lib.nvim` modules, not `debugging.nvim`-specific, so any
other plugin can import the same helpers.

- **Module:** `commands.lua` (`overview_float`), `autocmds/sources.lua`
  (`show_scratch`), `tools/startup.lua`, `views/display.lua`
  (`get_window_tag`), `tools/cursor/state.lua`
