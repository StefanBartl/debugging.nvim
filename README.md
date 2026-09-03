> **Alpha stage — active development.** This repository is in its development phase — breaking changes are to be expected at any time. Pin a commit or tag if you depend on it.

# debugging.nvim

```
    ___      __                   _                       _
   / _ \___ / /  __ _____ ____ _(_)__  ___ _  ___ _   __(_)_ _
  / // / -_) _ \/ // / _ `/ _ `/ / _ \/ _ `/ / _ \ |/ / /  ' \
 /____/\__/_.__/\_,_/\_, /\_, /_/_//_/\_, (_)_//_/___/_/_/_/_/
                    /___//___/        /___/
        one :Debug command for every Neovim debugging tool
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-active%20development-blue)
[![CI](https://github.com/StefanBartl/debugging.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/debugging.nvim/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey)

> 💡 Pairs well with [insights.nvim](https://github.com/StefanBartl/insights.nvim):
> insights analyses the codebase you are editing (symbols, imports, metrics,
> file tree), while debugging.nvim inspects the editor itself — buffers,
> windows, autocmds, messages — as it is running.
>
> And with
> [runtime-analysis.nvim](https://github.com/StefanBartl/runtime-analysis.nvim):
> that one records what your config *does* over time (telemetry, benchmarks,
> stall detection); this one answers a single question right now, in the
> session where something is already going wrong.

One `:Debug {category} {action}` command for every Neovim debugging tool.

Debugging tools accumulate as scattered one-off commands, each with a name you
have to remember before you can use it. This plugin puts all of them behind a
single dispatcher with two-level tab completion, so the surface is
discoverable rather than memorised — and every category is gated by a feature
flag, so `:Debug <Tab>` lists what *your* setup can actually do, not a static
catalogue. Built on [lib.nvim](https://github.com/StefanBartl/lib.nvim) as a
deliberate shared dependency.

---

## Table of Contents

- [What it can do](#what-it-can-do)
- [Quick Start](#quick-start)
- [Documentation](#documentation)

---

## What it can do

- **Views** — auto-refreshing `:messages` and Noice windows, captured to a file or the clipboard.
- **Autocmds** — the live registry, a Tree-sitter source-code audit, and a combined view of where the two disagree.
- **Inspection** — buffer/window/tab reports and inspectors, cursor state, recursive Lua value dumps.
- **UI freezes** — a blocking-call tracer with Lua tracebacks, plus an external process-tree watcher on Windows.
- **The rest** — terminal keylogger, indent and markdown diagnostics, module reload, startup benchmark, opt-in Neo-tree safety bridge.

Each of these is written up in [docs/FEATURES/](docs/FEATURES/README.md), one
page per group, with the reasoning behind it.

## Quick Start

Requires Neovim 0.9+ and [lib.nvim](https://github.com/StefanBartl/lib.nvim).
`cmd = "Debug"` lazy-loads the plugin on first use of the `:Debug` command —
which also defers the view keymaps, see
[installation.md](docs/installation.md#lazy-loading-and-the-view-keymaps).

```lua
-- lazy.nvim
{
  "StefanBartl/debugging.nvim",
  cmd = "Debug",
  dependencies = { "StefanBartl/lib.nvim" },
  opts = {},
}
```

```vim
:Debug messages show   " open the :messages window
:Debug health          " run :checkhealth debugging
```

## Documentation

Start with the [documentation index](docs/README.md) — it lists every page and
says what each one answers.

- [Documentation index](docs/README.md) — the full map of what is written down.
- [Features](docs/FEATURES/README.md) — what each group of `:Debug` categories does, and why it works that way.
- [Installation](docs/installation.md) — requirements and setup for lazy.nvim and packer.nvim.
- [Configuration](docs/configuration.md) — every `setup()` option and its default.
- [Command reference](docs/commands.md) — every category and action, with completion behaviour.
- [Workflow](docs/WORKFLOW.md) — which category to reach for when, and the gotchas in each.
- [Diagnosing UI freezes](docs/troubleshooting.md) — using `:Debug proc` to trace blocking calls and hung child processes.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, user command, and autocommand in one table.

## License

MIT — see [LICENSE](LICENSE).
