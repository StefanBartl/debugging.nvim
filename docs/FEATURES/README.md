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
