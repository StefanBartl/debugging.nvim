# Installation

## Requirements

- Neovim 0.9+
- [lib.nvim](https://github.com/StefanBartl/lib.nvim)
- Optional: a clipboard provider (for `messages capture`), `noice.nvim` (for
  `noice` views), Tree-sitter (markdown / indent diagnostics), `which-key.nvim`
  (groups the views keymap prefix), PowerShell (`pwsh` or `powershell.exe`, for
  `proc watch` — Windows only)

## Installation

`cmd = "Debug"` lazy-loads the plugin on first use of the `:Debug` command —
no `event` or `lazy = false` needed.

### lazy.nvim

```lua
{
  "StefanBartl/debugging.nvim",
  cmd = "Debug",
  dependencies = { "StefanBartl/lib.nvim" },
  opts = {},
}
```

### packer.nvim

```lua
use({
  "StefanBartl/debugging.nvim",
  requires = { "StefanBartl/lib.nvim" },
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
  "StefanBartl/debugging.nvim",
  dependencies = { "StefanBartl/lib.nvim" },
  cmd = "Debug",
  keys = { "<lt>m", "<lt>n", "<lt>e", "<lt>c", "<lt>f", "<lt>y", "<lt>x" },
  opts = {},
}
```

Set `views.keymaps.enable = false` if you would rather not have them at all —
see [configuration.md](configuration.md#views-keymaps).
