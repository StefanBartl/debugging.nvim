# Autocommands

Everything under `:Debug autocmds` — the live registered-autocmd view and
the static source-code audit that complements it.

## Static autocmd source audit

Scans Lua files under a root directory (default: your Neovim config's
`lua/`), finds every `nvim_create_autocmd` call site, and reports where each
autocmd is *defined* (path:line + implementation), grouped by event —
merged in from the former `usrcmds.list.autocmd_audit`. Complements
`debugging.autocmds.runtime`, the live `nvim_get_autocmds()` view.

- **Module:** `autocmds/sources.lua` (`M.run`), `autocmds/runtime.lua`
  (`M.list`)
- **Usercmds:** `:Debug autocmds runtime [event] [pat]`, `:Debug autocmds
  sources […]` (see [BINDINGS.md](../BINDINGS.md#user-commands))

## Tree-sitter parser for `autocmds sources`

The audit parses with the Lua Tree-sitter grammar (`function_call` nodes
named `nvim_create_autocmd`) whenever the parser is available, robust
against multi-line and nested calls that tripped the original text parser;
falls back to the light text/brace parser otherwise.

- **Module:** `autocmds/sources.lua` (`scan_file_ts`, `scan_file_text`,
  `scan_file`, `has_ts_lua`)

## Quickfix output for `sources`

`:Debug autocmds sources qf=true` sends one `path:line` entry per source
call site to the quickfix list and opens it, for direct jump-to-definition.

- **Module:** `autocmds/sources.lua` (`fill_quickfix`, `parse_args`)
- **Usercmds:** `:Debug autocmds sources qf=true` (see
  [BINDINGS.md](../BINDINGS.md#user-commands))

## Combined runtime + sources view

`:Debug autocmds all` fuses the static source audit with the live runtime
view — where each event is *defined* vs currently *registered* — including a
"registered at runtime but no source found" diff, typically plugin-defined
autocmds.

- **Module:** `autocmds/sources.lua` (`M.all`)
- **Usercmds:** `:Debug autocmds all [root=][refresh=][event=]` (see
  [BINDINGS.md](../BINDINGS.md#user-commands))

## `autocmds sources`'s scan moved into lib.nvim

The recursive directory walk delegates to `lib.nvim.fs.collect_recursive`
(dropping the local `uv.fs_scandir`/`fs_scandir_next` walker), and the
per-root result cache is a `lib.nvim.cache.memory` namespace instead of a
hand-rolled local `_cache` table — a few seconds' TTL so repeated calls with
different `sort=`/`event=` combinations don't rescan the whole tree each
time; `refresh=true` forces a rescan regardless.

- **Module:** `autocmds/sources.lua` (`scan_dir`, `get_scan`)
