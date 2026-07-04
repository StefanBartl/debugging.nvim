<!-- ASCII art banner -->
<pre>
    ___      __                   _                       _
   / _ \___ / /  __ _____ ____ _(_)__  ___ _  ___ _   __(_)_ _
  / // / -_) _ \/ // / _ `/ _ `/ / _ \/ _ `/ / _ \ |/ / /  ' \
 /____/\__/_.__/\_,_/\_, /\_, /_/_//_/\_, (_)_//_/___/_/_/_/_/
                    /___//___/        /___/
        one :Debug command for every Neovim debugging tool
</pre>

> 💡 Pairs well with [project-insight.nvim](https://github.com/StefanBartl/project-insight.nvim):
> project-insight analyzes and reports on your codebase (symbols, metrics, file
> tree), while debugging.nvim inspects live editor state (buffers, autocmds,
> messages) at runtime.

![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/Made%20with-Lua-2C2D72?logo=lua&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg)
![Depends](https://img.shields.io/badge/depends-lib.nvim-orange)

---

A single `:Debug {category} {action}` command that groups every debugging tool
in one place: message/Noice views, buffer/tab/window reports, autocmd
inspection (runtime **and** static source audit), buffer/cursor/variable
inspection, a terminal keylogger, indent diagnostics, markdown inline-highlight
debugging, and an opt-in Neo-tree safety bridge.

Built on [lib.nvim](https://github.com/StefanBartl/lib.nvim) as a deliberate
shared dependency.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Command Reference](#command-reference)
- [Tab Completion](#tab-completion)
- [Health Check](#health-check)
- [Architecture](#architecture)

## Features

| Category | Actions | What it does |
|---|---|---|
| `messages` | `show` · `capture` · `clear` | Show / capture `:messages` (file + clipboard) / clear debug windows |
| `noice` | `all` · `errors` | Show all Noice messages / only errors |
| `report` | `buf` · `tab` · `win [id]` | Print buffer / tab / window reports to `:messages` |
| `autocmds` | `runtime [event] [pat]` · `sources [args]` | Live `nvim_get_autocmds` view **or** static source-code audit |
| `inspect` | `buffer [bufnr]` | Inspect buffer-scoped options and state |
| `cursor` | `state` | Print cursor / window / buffer state |
| `dump` | `[varname]` | Recursively dump a global Lua var (or word under cursor) |
| `keylogger` | `start` · `stop` | Log keys pressed in the current terminal buffer |
| `indent` | `show` · `treesitter [true\|false]` | Print indent options / prefer Tree-sitter indent |
| `markdown` | `inline` · `log` | Gather markdown inline-highlight debug info / open the log |
| `module` | `reload` | Reload the Lua module of the current buffer |
| `neotree` | `status` · `exit` · `restart` · `backup-*` · `dryrun-*` · `queue-*` | Neo-tree safety bridge (opt-in, config-specific) |
| `health` | — | Run `:checkhealth debugging` |

## Requirements

- Neovim 0.9+
- [lib.nvim](https://github.com/StefanBartl/lib.nvim)
- Optional: a clipboard provider (for `messages capture`), `noice.nvim` (for
  `noice` views), Tree-sitter (markdown / indent diagnostics), `which-key.nvim`
  (groups the views keymap prefix)

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

## Configuration

Full defaults:

```lua
require("debugging").setup({
  -- Per-category enable flags. `all = true` activates everything.
  features = {
    views        = true,   -- :Debug messages / noice / windows
    reports      = true,   -- :Debug report buf|tab|win
    autocmds     = true,   -- :Debug autocmds runtime|sources
    tools        = true,   -- :Debug inspect|cursor|dump
    terminals    = true,   -- :Debug keylogger
    nvim_options = true,   -- :Debug indent
    markdown     = true,   -- :Debug markdown
    module_reload = true,  -- :Debug module reload
    neotree      = false,  -- :Debug neotree … (config-specific, opt-in)
  },
  views = {
    keymaps  = { enable = true, prefix = "<lt>" },
    autocmds = { enable = true, group_name = "DebugViewsAuto", auto_refresh = true },
    timings  = { delay_messages_ms = 30, delay_noice_ms = 50, retry_delay_ms = 60, attempts = 3 },
    capture  = true,
    output_dir = nil,  -- default: stdpath("config")/docs/debug_views
  },
  command = "Debug",   -- name of the single unified command
})

-- Shorthand: enable every category
require("debugging").setup({ all = true })
```

## Command Reference

```
:Debug                          " overview of enabled categories
:Debug messages show            " open the :messages window
:Debug messages capture         " capture :messages to file + clipboard
:Debug noice errors             " show Noice errors
:Debug report buf               " buffer report
:Debug report win 1000          " window report for window 1000
:Debug autocmds runtime BufEnter *   " live autocmds for an event/pattern
:Debug autocmds sources event=BufWritePre sort=event   " static source audit
:Debug inspect buffer           " inspect current buffer options
:Debug cursor state             " cursor / window / buffer state
:Debug dump my_global           " dump a global var (or word under cursor)
:Debug keylogger start          " log keys in the current terminal buffer
:Debug indent treesitter false  " restore cindent/smartindent
:Debug markdown inline          " gather markdown inline-highlight debug
:Debug module reload            " reload Lua module of the current buffer
:Debug neotree status           " Neo-tree quarantine status (opt-in)
:Debug health                   " run :checkhealth debugging
```

The `autocmds sources` audit accepts `event=`, `sort=` (`source`/`event`/`frequency`),
`impl=`, `summary=`, `freq=`, and `root=` arguments.

## Tab Completion

`:Debug` completes context-sensitively at every position:

```
:Debug <Tab>                       → messages noice report autocmds inspect …
:Debug report <Tab>                → buf tab win
:Debug autocmds <Tab>              → runtime sources
:Debug autocmds sources <Tab>      → event= sort= impl= summary= freq= root=
:Debug autocmds sources event=Buf<Tab>  → event=BufAdd event=BufEnter …
:Debug indent treesitter <Tab>     → true false
:Debug module <Tab>                → reload
```

## Health Check

```
:checkhealth debugging
```

Verifies Neovim version, the lib.nvim modules each feature relies on, clipboard
providers, optional Tree-sitter / Noice, write permissions, and the opt-in
Neo-tree bridge.

## Architecture

```
docs/BINDINGS.lua             Cheatsheet: every keymap, :Debug action, autocmd
plugin/debugging.lua          Load guard (vim.g.loaded_debugging)
lua/debugging/
  init.lua                    setup() — feature gating + :Debug registration
  @types.lua                  LuaLS type definitions
  config/
    DEFAULTS.lua              Immutable defaults
    init.lua                  Merge + access to active config
  commands.lua                :Debug dispatcher + two-level completion
  health.lua                  :checkhealth debugging
  views/                      messages/Noice capture, display, keymaps, autocmds
    which_key.lua              optional which-key group label for the prefix
  usercmds/
    reports.lua               buf/tab/win reports (lib.nvim.buf_win_tab.*)
    module_reload.lua         reload Lua module of the current buffer
    neotree_safety.lua        opt-in Neo-tree bridge (pcall-guarded)
  autocmds/
    runtime.lua               live nvim_get_autocmds view
    sources.lua               static source-code audit
  tools/
    buffer_inspector/         buffer option/state inspection
    cursor/state.lua          cursor/window/buffer state
    vardump/                  recursive Lua value dump
  terminals/keylogger.lua     terminal keylogger
  nvim_options/indent_helpers.lua   indent diagnostics
  markdown/inline_debug.lua   markdown inline-highlight debug
```

Each leaf module exposes plain action functions; `commands.lua` is the only
place that registers a user command. lib.nvim provides notify, `buf_win_tab.*`,
`fs.*`, `cross`, `lazy`, and `normalize`.
