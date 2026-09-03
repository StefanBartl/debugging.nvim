# Views

`:Debug messages` and `:Debug noice` — auto-refreshing scratch windows over
Neovim's own message history, plus the capture actions that get that history
out of the editor and into an issue or a chat.

## Auto-refreshing message and Noice views

Scratch windows for `:messages` and, when [noice.nvim] is installed, its
message history. Each window carries a tag; re-entering it (`WinEnter`) or
bringing its buffer back into a window (`BufWinEnter`) re-runs the underlying
command and rewrites the buffer, so a view left open in a split keeps showing
current output instead of a frozen snapshot from when it was opened.

`q` and `<Esc>` close a view window — bound per buffer through a `FileType`
autocmd rather than globally, so neither key changes meaning anywhere else.

- **Module:** `views/display.lua` (`execute_and_refresh`, `refresh_log_view`,
  `clear_all`), `views/init.lua`
- **Config:** `opts.features.views`, `opts.views.autocmds`,
  `opts.views.timings`
- **Usercmds:** `:Debug messages show|clear`, `:Debug noice all|errors` — see
  [BINDINGS.md](../BINDINGS.md#user-commands)
- **Autocmds:** `WinEnter` / `BufWinEnter` auto-refresh, `FileType`
  close-window binding — see [BINDINGS.md](../BINDINGS.md#autocommands)

[noice.nvim]: https://github.com/folke/noice.nvim

## Capture to file, to clipboard, or both

`capture_messages` writes the current `:messages` output to a timestamped file
under `opts.views.output_dir` (default: `stdpath("config")/docs/debug_views`),
copies it to the clipboard, or does both.

Three separate keys cover the choice rather than a prefix tree: `<lt>c` for
both, `<lt>f` for file only, `<lt>y` for clipboard only. A `<lt>c`-then-maybe-
`f` tree would make the common case wait to see whether a second key follows,
for the sake of the two rare ones.

- **Module:** `views/capture/init.lua`, `views/capture/clipboard/init.lua`
  (delegates to `lib.nvim.cross.copy_to_clipboard`)
- **Config:** `opts.views.capture`, `opts.views.output_dir`
- **Usercmds:** `:Debug messages capture` (file + clipboard)
- **Keymaps:** `<lt>c` / `<lt>f` / `<lt>y` — see
  [BINDINGS.md](../BINDINGS.md#default-keymaps)

## Individually overridable keymaps

The seven view keymaps are declared through `lib.nvim.bindings.keymap`'s
registry, which is what makes each one overridable on its own. `prefix` used
to be the only lever, so a user who wanted a different key for one view had to
move all seven; `keymaps = { messages = "<leader>dm" }` now moves exactly one,
`= false` drops one, and `prefix` still supplies the default for the rest.
which-key gets a `"Debug"` group label for the prefix from the same
declaration, if it is installed.

- **Module:** `bindings/keymaps.lua` (`M.setup`)
- **Config:** `opts.views.keymaps.enable`, `opts.views.keymaps.prefix`
  (default `"<lt>"`, the literal `<` key), plus one optional key per action —
  see [configuration.md](../configuration.md)
- **Keymaps:** `<lt>m` / `<lt>n` / `<lt>e` / `<lt>c` / `<lt>f` / `<lt>y` /
  `<lt>x` — see [BINDINGS.md](../BINDINGS.md#default-keymaps)

## Timing budget for slow sources

A view opens a command's window, waits for it to render, then reads it back.
How long to wait is configurable per source, because the answer depends on the
machine: too short and the view reports "no output" for a command that was
merely still rendering.

- **Module:** `views/display.lua`, `views/init.lua`
- **Config:** `opts.views.timings.delay_messages_ms`, `.delay_noice_ms`,
  `.retry_delay_ms`, `.attempts`, `.capture_timeout_ms` — see
  [configuration.md](../configuration.md)
