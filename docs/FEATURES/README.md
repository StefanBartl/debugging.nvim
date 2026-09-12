# Features

Every debugging tool this plugin ships is reached through one dispatcher,
`:Debug {category} {action} [args]`. This folder is the feature catalog: what
each group of categories does, and why it works the way it does.

Categories are gated by `features.*` (see
[configuration.md](../configuration.md)) — a disabled category does not even
appear in `:Debug <Tab>`. For reference detail rather than reasoning — exact
arguments, defaults, event names — see [commands.md](../commands.md),
[configuration.md](../configuration.md) and the
[bindings cheatsheet](../BINDINGS.md).

## At a glance

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

## Pages

| Page | What it covers |
|---|---|
| [CORE.md](CORE.md) | The unified `:Debug` command, its two-level completion, the feature flags and config system behind it, and `:checkhealth debugging`. |
| [VIEWS.md](VIEWS.md) | Auto-refreshing `:messages` and Noice windows, capturing them to a file or the clipboard, and the keymaps that drive both. |
| [AUTOCMDS.md](AUTOCMDS.md) | The three views on autocommands — live, static source audit, and the combined diff that shows where they disagree. |
| [TOOLS.md](TOOLS.md) | The single-purpose categories: reports, inspectors, keylogger, indent and markdown diagnostics, module reload, startup benchmark, Neo-tree bridge. |
| [PROC.md](PROC.md) | Diagnosing a UI freeze: the in-process call tracer, the external process-tree watcher, and what neither of them can see. |

## Where to start

`CORE.md` first, even if you only want one tool — the feature flags and
completion behaviour it describes decide what the other four pages can reach
at all. If you are here because Neovim is hanging, skip straight to
[PROC.md](PROC.md).
