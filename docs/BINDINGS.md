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

Each key is individually overridable by its action name — the names in the
table below — so moving one does not mean moving all seven. See
[configuration.md](configuration.md#views-keymaps).

| lhs | mode | action | desc |
| --- | --- | --- | --- |
| `<lt>m` | n | `messages` | Show `:messages` view (auto-refreshing) |
| `<lt>n` | n | `noice_all` | Show Noice all view (auto-refreshing) |
| `<lt>e` | n | `noice_errors` | Show Noice errors (`:Noice errors`) |
| `<lt>c` | n | `capture` | Capture `:messages` to file + clipboard |
| `<lt>f` | n | `capture_file` | Capture `:messages` to file only |
| `<lt>y` | n | `capture_clipboard` | Capture `:messages` to clipboard only |
| `<lt>x` | n | `clear` | Close all debug view windows |

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
| `:Debug inspect buffer [bufnr]` | Inspect buffer-scoped options and state. `[bufnr]` completes against the loaded buffers. |
| `:Debug inspect window [winid]` | Inspect window-scoped options and state |
| `:Debug inspect tab [tabnr]` | Inspect a tab page's windows and their buffers |
| `:Debug cursor state` | Print cursor / window / buffer state |
| `:Debug dump [varname]` | Recursively dump a global Lua var (or word under cursor) |
| `:Debug keylogger start [file]\|stop` | Log keys pressed in the current terminal buffer (optionally append to a file). `[file]` gets path completion — the file need not exist yet; the directory part completes on the way there. |
| `:Debug indent show` | Print indentation-related buffer options |
| `:Debug indent treesitter [true\|false]` | Prefer Tree-sitter indent, or restore with false |
| `:Debug markdown inline` | Gather markdown inline-highlight debug info |
| `:Debug markdown log` | Open the most recent markdown debug log |
| `:Debug module reload` | Reload the Lua module of the current buffer |
| `:Debug proc start [threshold_ms]\|stop\|status\|log` | In-process tracer for `system()`/`jobstart` calls: log durations, plus a full Lua traceback for calls at or above the threshold (default 200ms) |
| `:Debug proc watch [seconds]` | (Windows) external process-tree watcher — every child process of this Neovim instance, however it was spawned |
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
