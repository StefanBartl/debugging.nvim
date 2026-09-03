# Autocommand inspection

Everything under `:Debug autocmds` — three related views on autocommands that
answer three different questions, and are easy to mix up.

## Three views, three questions

| Action | Answers | Source |
|---|---|---|
| `runtime [event] [pat]` | What is registered *right now* | `nvim_get_autocmds()` |
| `sources [args]` | Where in the source tree it is *defined* | static scan of `nvim_create_autocmd` call sites |
| `all [args]` | Whether those two agree | fuses both, flags runtime-only events |

`autocmds all` is the one that answers "is this plugin-defined autocmd
expected": it flags events registered at runtime with no matching source
found, which is `sources`'s structural blind spot (dynamically registered
autocmds, typically from another plugin) made visible rather than silently
absent.

- **Module:** `autocmds/runtime.lua` (`M.list`), `autocmds/sources.lua`
  (`M.run`, `M.all`)
- **Config:** `opts.features.autocmds`
- **Usercmds:** `:Debug autocmds runtime [event] [pat]`,
  `:Debug autocmds sources [event=][sort=][impl=][summary=][freq=][root=][refresh=][qf=]`,
  `:Debug autocmds all [root=][refresh=][event=]` — see
  [BINDINGS.md](../BINDINGS.md#user-commands)

## Tree-sitter parser, with a text fallback

The static audit finds call sites by walking `function_call` nodes named
`nvim_create_autocmd` with the Lua Tree-sitter grammar whenever that parser is
available — robust against the multi-line and nested calls that a plain text
parser mis-reads. Without the parser it falls back to a light text/brace scan,
which is why an oddly wrapped call can show up under `runtime` but not under
`sources` on a machine with no Lua parser installed.

- **Module:** `autocmds/sources.lua` (`scan_file_ts`, `scan_file_text`,
  `scan_file`, `has_ts_lua`)

## Quickfix output

`sources qf=true` sends one `path:line` entry per call site to the quickfix
list and opens it, turning "find who registered this autocmd" into a normal
`:cnext`/`<CR>` jump instead of reading a scratch report.

- **Module:** `autocmds/sources.lua` (`fill_quickfix`, `parse_args`)
- **Usercmds:** `:Debug autocmds sources qf=true`

## Cached scan

The recursive directory walk goes through `lib.nvim.fs.collect_recursive`, and
results are cached per project root in a `lib.nvim.cache.memory` namespace for
a few seconds — so repeated calls with different `sort=`/`event=` combinations
do not rescan the whole tree each time. The trade-off is visible: a source edit
made right before re-running `sources` needs `refresh=true`, not a second plain
run.

- **Module:** `autocmds/sources.lua` (`scan_dir`, `get_scan`)
- **Usercmds:** `:Debug autocmds sources refresh=true`
