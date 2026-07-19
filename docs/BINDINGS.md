# debugging.nvim — Binding Cheatsheet

Machine-readable overview of every keymap, user command, and autocommand
defined by `debugging.nvim`. This file is documentation only and mirrors the
source of truth:

- keymaps  — `lua/debugging/bindings/keymaps.lua`
- commands — `lua/debugging/bindings/usercmds.lua` (registration) + `lua/debugging/commands.lua` (dispatch/completion logic)
- autocmds — `lua/debugging/bindings/autocmds.lua`

Any change there must be reflected here.

## Default Keymaps

Normal-mode keymaps installed by `bindings.setup()`, gated by
`config.views.keymaps.enable`. The prefix defaults to `<lt>`, i.e. the
literal `<` key.

| lhs | mode | desc |
| --- | --- | --- |
| `<lt>m` | n | Show `:messages` view (auto-refreshing) |
| `<lt>n` | n | Show Noice all view (auto-refreshing) |
| `<lt>e` | n | Show Noice errors (`:Noice errors`) |
| `<lt>c` | n | Capture `:messages` to file + clipboard |
| `<lt>x` | n | Close all debug view windows |

## User Commands

Single `:Debug {category} {action} [args]` dispatcher. Categories are gated
by `config.features.*`.

| command | desc |
| --- | --- |
| `:Debug` | Overview of enabled categories |
| `:Debug messages show\|capture\|clear` | Show / capture (file+clipboard) / clear `:messages` views |
| `:Debug noice all\|errors` | Show all Noice messages / only errors |
| `:Debug report buf\|tab\|win [id]` | Buffer / tab / window report to `:messages` |
| `:Debug autocmds runtime [event] [pat]` | Live `nvim_get_autocmds()` view |
| `:Debug autocmds sources [event=][sort=][impl=][summary=][freq=][root=][refresh=][qf=]` | Static source-code audit of `nvim_create_autocmd` call sites (Tree-sitter parser with text fallback; cached per root; `refresh=true` forces a rescan; `qf=true` sends `path:line` to the quickfix list) |
| `:Debug autocmds all [root=][refresh=][event=]` | Combined view: where each event is defined (sources) vs currently registered (runtime), plus a runtime-only diff |
| `:Debug inspect buffer [bufnr]` | Inspect buffer-scoped options and state |
| `:Debug inspect window [winid]` | Inspect window-scoped options and state |
| `:Debug inspect tab [tabnr]` | Inspect a tab page's windows and their buffers |
| `:Debug cursor state` | Print cursor / window / buffer state |
| `:Debug dump [varname]` | Recursively dump a global Lua var (or word under cursor) |
| `:Debug keylogger start [file]\|stop` | Log keys pressed in the current terminal buffer (optionally append to a file) |
| `:Debug indent show` | Print indentation-related buffer options |
| `:Debug indent treesitter [true\|false]` | Prefer Tree-sitter indent, or restore with false |
| `:Debug markdown inline` | Gather markdown inline-highlight debug info |
| `:Debug markdown log` | Open the most recent markdown debug log |
| `:Debug module reload` | Reload the Lua module of the current buffer |
| `:Debug performance startup [runs]` | Benchmark startup time and list the slowest sourced scripts |
| `:Debug neotree status\|exit\|restart\|backup-list\|backup-clean\|dryrun-toggle\|dryrun-report\|queue-status\|queue-clear` | Opt-in Neo-tree safety bridge (needs `features.neotree = true`) |
| `:Debug health` | Run `:checkhealth debugging` |

## Autocommands

Registered by `bindings.setup()` into the `config.views.autocmds.group_name`
augroup (default `DebugViewsAuto`), plus the `FileType` close-window
autocmd.

| event | group | pattern | desc |
| --- | --- | --- | --- |
| `WinEnter` | `DebugViewsAuto` | `*` | Auto-refresh an open debug view when re-entering its window |
| `BufWinEnter` | `DebugViewsAuto` | `*` | Auto-refresh an open debug view when its buffer re-enters a window |
| `FileType` | `DebugViewsAuto` | `messages/noice` | Bind `q` / `<Esc>` to close the debug window |
