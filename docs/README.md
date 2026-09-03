# debugging.nvim — Documentation

Everything written down about debugging.nvim, and what each page is for.
The [repository README](../README.md) is the short version; this is the index.

## Start here

| Page | What it answers |
|---|---|
| [installation.md](installation.md) | How do I install it, and what does it need? |
| [FEATURES/](FEATURES/README.md) | What can it actually do — one page per group of `:Debug` categories. |
| [WORKFLOW.md](WORKFLOW.md) | Which category do I reach for when, and how do they chain together? |

## Reference

| Page | What it answers |
|---|---|
| [commands.md](commands.md) | What does each `:Debug {category} {action}` do, with which arguments? |
| [configuration.md](configuration.md) | Which `setup()` options exist, and what are their defaults? |
| [BINDINGS.md](BINDINGS.md) | Every keymap, user command, and autocommand at a glance. |

## When something is wrong

| Page | What it answers |
|---|---|
| [troubleshooting.md](troubleshooting.md) | Neovim is hanging — how do I find out which process or which call is blocking it? |

`:checkhealth debugging` is the other half of that answer: it reports which
optional dependency each feature is missing, per feature rather than as one
generic warning.

## Under the hood

| Page | What it answers |
|---|---|
| [architecture.md](architecture.md) | How are the modules laid out, and which parts come from lib.nvim? |
| [../TESTS/README.md](../TESTS/README.md) | The headless spec suite, and how to run it. |

`:DocMap` generates a browsable module map under `docs/map/` — an interactive
`index.html` alongside the same data as JSON and Markdown, `:DocMap full` for
LuaLS-enriched detail. It is deliberately **not** committed: a checked-in copy
is stale the moment anything it describes changes, and nothing here gates that.
Open any file in this repo and run it, rather than looking for it in the
repository.

## Conventions

Two things run through every page and are worth knowing once:

- **Everything is one command.** There are no separate `:DebugMessages`-style
  commands; `:Debug {category} {action} [args]` is the whole surface, and
  `:Debug` with no arguments lists what is currently reachable.
- **Categories are gated by `features.*`.** A category switched off in
  `setup()` disappears from `:Debug <Tab>` entirely. A command that "does not
  exist" is far more often a disabled feature than a typo — `:Debug health`
  settles it.
