# Installation

## Requirements

- Neovim 0.9+
- [lib.nvim](https://github.com/WKDSteve/lib.nvim)
- Optional: [ui.nvim](https://github.com/WKDSteve/ui.nvim) (makes the
  recent-messages popup behind `<lt>m` / `<lt>n` / `<lt>e` live and paginated;
  without it the popup is a static snapshot), a clipboard provider (for
  `messages capture`), `noice.nvim` (feeds the recent-messages popup, see
  below, and is read first by `messages capture`), Tree-sitter (markdown /
  indent diagnostics), `which-key.nvim` (groups the views keymap prefix),
  PowerShell (`pwsh` or `powershell.exe`, for `proc watch` — Windows only),
  [gitsuite.nvim](https://github.com/WKDSteve/gitsuite.nvim) (`:Debug report
  buf` warns when the current buffer still has unresolved merge-conflict
  markers)

## What feeds the recent-messages popup

The popup shows what `lib.nvim.messages` has recorded. It has two feeds:

- everything sent through `lib.nvim.notify` — always recorded, no setup needed;
- every other message Neovim shows (`:echomsg`, `print()`, `:write`, Lua and
  `E…` errors, `:!cmd` output) — recorded only while `lib.nvim.messages` has
  attached its `ext_messages` logger.

The logger attaches only while a message renderer is running, because as the
only `ext_messages` listener it would take message and cmdline drawing away
from the terminal UI. debugging.nvim does not attach it for you: the message
store is shared with other plugins, so the policy belongs to your config. Call
`setup` once noice is running:

```lua
-- e.g. in noice.nvim's own `config` function, after require("noice").setup(...)
require("lib.nvim.messages").setup({})
require("lib.nvim.messages").wrap_noice()  -- optional: follow :Noice enable/disable
```

Use `setup({ renderer_override = true })` only if something other than noice
draws `ext_messages`. Without noice and without that call the popup still
works, but holds only the `lib.nvim.notify` entries. `:checkhealth debugging`
reports which case applies (section "recent popup").

## Installation

`cmd = "Debug"` lazy-loads the plugin on first use of the `:Debug` command —
no `event` or `lazy = false` needed.

### lazy.nvim

```lua
{
  "WKDSteve/debugging.nvim",
  cmd = "Debug",
  dependencies = { "WKDSteve/lib.nvim" },
  opts = {},
}
```

### packer.nvim

```lua
use({
  "WKDSteve/debugging.nvim",
  requires = { "WKDSteve/lib.nvim" },
  cmd = "Debug",
  config = function()
    require("debugging").setup({})
  end,
})
```

## Lazy-loading and the view keymaps

`cmd = "Debug"` is the cheapest setup, and it is the right one if you reach for
`:Debug` by name. It has one consequence worth knowing: the seven view keymaps
(`<lt>m`, `<lt>n`, …) are registered by `setup()`, which does not run until the
plugin loads — so they do nothing until you have run `:Debug` once in that
session.

If you want the keymaps live from the start, declare them as the lazy-load
trigger as well, or load the plugin on `VeryLazy`:

```lua
{
  "WKDSteve/debugging.nvim",
  dependencies = { "WKDSteve/lib.nvim" },
  cmd = "Debug",
  keys = { "<lt>m", "<lt>n", "<lt>e", "<lt>c", "<lt>f", "<lt>y", "<lt>x" },
  opts = {},
}
```

Set `views.keymaps.enable = false` if you would rather not have them at all —
see [configuration.md](configuration.md#views-keymaps).
