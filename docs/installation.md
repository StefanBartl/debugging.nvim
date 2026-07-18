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
