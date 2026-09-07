> **Beta stage — active development.** This repository is past its first shape and in
> active use, but the surface is not frozen: breaking changes are still possible. Pin a
> commit or tag if you depend on it.

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
![Status](https://img.shields.io/badge/status-beta-orange)
[![CI](https://github.com/StefanBartl/debugging.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/debugging.nvim/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey)

One `:Debug {category} {action}` command for every Neovim debugging tool.

Debugging tools accumulate as scattered one-off commands, each with a name you
have to remember before you can use it. This plugin puts all of them behind a
single dispatcher with two-level tab completion, so the surface is discoverable
rather than memorised.

---

## Table of contents

- [Documentation](#documentation)
- [What it does](#what-it-does)
- [Around it](#around-it)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [What you get with the defaults](#what-you-get-with-the-defaults)
- [Health check](#health-check)
- [Contributing](#contributing)
- [Feedback](#feedback)
- [License](#license)

---

## Documentation

Start at [docs/README.md](docs/README.md), which lists every page and says what
each one answers.

- [Features](docs/FEATURES/README.md) — what each group of `:Debug` categories does, and why it works that way.
- [Installation](docs/installation.md) — requirements, every plugin manager, and what lazy-loading costs.
- [Configuration](docs/configuration.md) — every `setup()` option and its default.
- [Command reference](docs/commands.md) — every category and action, with completion behaviour.
- [Workflow](docs/WORKFLOW.md) — which category to reach for when, and the gotchas in each.
- [Diagnosing UI freezes](docs/troubleshooting.md) — using `:Debug proc` to trace blocking calls and hung child processes.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, user command and autocommand in one table.
- [Architecture](docs/architecture.md) — module layout and the dispatcher's shape.

`:help debugging` is the same reference inside the editor.

---

## What it does

| Category | Does |
| --- | --- |
| **Views** | Auto-refreshing `:messages` and Noice windows, captured to a file or the clipboard |
| **Autocmds** | The live registry, a Tree-sitter audit of the source, and a combined view of where the two disagree |
| **Inspection** | Buffer, window and tab reports and inspectors, cursor state, recursive Lua value dumps |
| **UI freezes** | A blocking-call tracer with Lua tracebacks, plus an external process-tree watcher on Windows |
| **The rest** | Terminal keylogger, indent and Markdown diagnostics, module reload, startup benchmark, opt-in Neo-tree safety bridge |

Every category is gated by a feature flag, so `:Debug <Tab>` lists what *your*
setup can actually do rather than a static catalogue. That is the difference
between a dispatcher and a menu: the completion is a report on the current
session, not a table copied from the documentation.

The autocmd category is the clearest case of why the editor needs inspecting at
all. The live registry says what is registered *now*; the Tree-sitter audit says
what the source claims to register. They disagree more often than anyone expects,
and only the third view — the diff — makes that visible.

Each group is written up in [docs/FEATURES/](docs/FEATURES/README.md), one page
each, with the reasoning behind it.

---

## Around it

> **[insights.nvim](https://github.com/StefanBartl/insights.nvim)** — analyses the
> codebase you are editing (symbols, imports, metrics, file tree); this one
> inspects the editor itself — buffers, windows, autocmds, messages — as it runs.
>
> **[runtime-analysis.nvim](https://github.com/StefanBartl/runtime-analysis.nvim)** —
> records what your config *does* over time (telemetry, benchmarks, stall
> detection); this one answers a single question right now, in the session where
> something is already going wrong.
>
> **[dap.nvim](https://github.com/StefanBartl/dap.nvim)** — debugs your *program*
> over the Debug Adapter Protocol. This one debugs the editor around it, with no
> adapter involved.
>
> All of the above are soft: without them everything else works unchanged.
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) is the one real
> dependency — see [Requirements](#requirements).

---

## Requirements

| | |
| --- | --- |
| Neovim | **0.9+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | required — the `:Debug` dispatcher is built on its `usercmd.composer` |

Optional, each detected at runtime; the matching category simply does not appear
in `:Debug <Tab>` when absent:

| | |
| --- | --- |
| A Tree-sitter Lua parser | The autocmd source audit, and therefore the registry-versus-source diff |
| [noice.nvim](https://github.com/folke/noice.nvim) | The Noice message view alongside the plain `:messages` one |
| [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) | The opt-in Neo-tree safety bridge |
| Windows | `:Debug proc`'s external process-tree watcher is Windows-only; the in-process blocking tracer works everywhere |

---

## Installation

```lua
-- lazy.nvim
{
  "StefanBartl/debugging.nvim",
  cmd = "Debug",
  dependencies = { "StefanBartl/lib.nvim" },
  opts = {},
}
```

`cmd = "Debug"` lazy-loads the plugin on first use, which also defers the view
keymaps — see
[installation.md](docs/installation.md#lazy-loading-and-the-view-keymaps) for
when that matters and how to avoid it. Other plugin managers are in
[docs/installation.md](docs/installation.md).

---

## Quickstart

Ask `:Debug` what it can do — the completion is the catalogue:

```vim
:Debug <Tab>
```

Then pick a category and an action:

```vim
:Debug messages show       " the :messages window, auto-refreshing
:Debug autocmds all        " combined sources-vs-runtime view, and the diff
:Debug report buf          " buffer report
:Debug proc start 200      " log every system()/jobstart call over 200ms
```

Verify your setup any time with:

```vim
:checkhealth debugging
```

---

## What you get with the defaults

`opts = {}` enables every category whose prerequisites are present. The ones
worth knowing on day one:

| Command | Does |
| --- | --- |
| `:Debug` | Overview of the categories your setup has enabled |
| `:Debug messages show` | An auto-refreshing `:messages` window you can leave open |
| `:Debug messages capture` | The same content to a file and the clipboard |
| `:Debug autocmds runtime BufEnter *` | The live registry, for one event and pattern |
| `:Debug autocmds all` | Registry versus what the source claims to register, plus the diff |
| `:Debug report buf` | Every buffer, with its options and state |
| `:Debug dump my_global` | A recursive dump of a Lua value, or the word under the cursor |
| `:Debug proc start 200` | Log every `system()`/`jobstart` call over 200 ms |
| `:Debug module reload` | Reload the current buffer's Lua module without restarting |
| `:Debug health` | `:checkhealth debugging` |

The full two-level surface is [docs/commands.md](docs/commands.md); every key and
autocommand is in the [bindings cheatsheet](docs/BINDINGS.md).

---

## Health check

```vim
:checkhealth debugging
```

Reports whether `lib.nvim` resolved, which categories are enabled and which are
gated off because their prerequisite is missing, and whether the Tree-sitter Lua
parser needed by the autocmd audit is installed.

---

## Contributing

Clone the repository and either symlink it or add it to your runtime path.
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) has the ground rules and the project
layout; [docs/architecture.md](docs/architecture.md) explains the dispatcher a
new category has to register with.

Pull requests very welcome.

---

## Feedback

Your feedback is very welcome. Use the
[issue tracker](https://github.com/StefanBartl/debugging.nvim/issues) to report
bugs, suggest features or ask usage questions; anything more open-ended fits a
[discussion](https://github.com/StefanBartl/debugging.nvim/discussions).

If you find this plugin useful, a ⭐ on GitHub supports its development.

---

## License

MIT — see [LICENSE](LICENSE).
