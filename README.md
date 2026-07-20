<!-- ASCII art banner -->
<pre>
    ___      __                   _                       _
   / _ \___ / /  __ _____ ____ _(_)__  ___ _  ___ _   __(_)_ _
  / // / -_) _ \/ // / _ `/ _ `/ / _ \/ _ `/ / _ \ |/ / /  ' \
 /____/\__/_.__/\_,_/\_, /\_, /_/_//_/\_, (_)_//_/___/_/_/_/_/
                    /___//___/        /___/
        one :Debug command for every Neovim debugging tool
</pre>

> 💡 Pairs well with [insights.nvim](https://github.com/StefanBartl/insights.nvim):
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
inspection (runtime, a Tree-sitter static source audit, **and** a combined
sources-vs-runtime view), buffer/window/tab/cursor/variable inspection, a
terminal keylogger, indent diagnostics, markdown inline-highlight debugging,
UI-freeze diagnosis (blocking-call tracing + an external process-tree watcher),
a startup-time benchmark, and an opt-in Neo-tree safety bridge. Built on
[lib.nvim](https://github.com/StefanBartl/lib.nvim) as a deliberate shared
dependency.

## Quick Start

Requires Neovim 0.9+ and [lib.nvim](https://github.com/StefanBartl/lib.nvim).
`cmd = "Debug"` lazy-loads the plugin on first use of the `:Debug` command.

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

- [Installation](docs/installation.md) — requirements and setup for lazy.nvim / packer.nvim.
- [Configuration](docs/configuration.md) — full `setup()` defaults and options.
- [Commands](docs/commands.md) — feature overview, full command reference, tab completion, and health check.
- [Diagnosing UI Freezes](docs/troubleshooting.md) — using `:Debug proc` to trace blocking calls and hung child processes.
- [Architecture](docs/architecture.md) — module layout and responsibilities.
- [Bindings Cheatsheet](docs/BINDINGS.md) — every keymap, user command, and autocommand.
- [Tests](docs/TESTS/README.md) — headless spec suite and how to run it.
- [Roadmap](docs/ROADMAP.md) — what is implemented and what is planned.
