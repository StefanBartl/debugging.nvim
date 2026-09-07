# Contributing to debugging.nvim

Thank you for your interest! Bugs, ideas and questions are welcome in the
[issue tracker](https://github.com/StefanBartl/debugging.nvim/issues); pull
requests very welcome.

## Getting the repository into a session

Clone it and either symlink the checkout into your plugin directory or add it to
the runtime path directly:

```lua
vim.opt.rtp:prepend("/path/to/debugging.nvim")
require("debugging").setup({})
```

## Ground rules

- Lua only, idiomatic Neovim Lua. 2-space indentation.
- **A debugging tool must not be the thing that breaks the session.** Everything
  here runs inside an editor that is, by assumption, already misbehaving. Wrap
  buffer and API access in `pcall`, never leave a wrapped function unrestored,
  and make every tracer stoppable from a command that does not depend on the
  tracer working.
- **Every category is gated by a feature flag**, and the flag is checked before
  the category is registered — that is what makes `:Debug <Tab>` a report on the
  current session rather than a static catalogue. A category that registers
  unconditionally and then errors is a bug even if the error message is good.
- Nothing platform-specific outside a module that says so in its name or its
  header. `:Debug proc watch` is Windows-only and declares it; the in-process
  tracer beside it is not.
- Commands are registered through `lib.nvim.bindings.usercmd.composer`, never
  with a bare `nvim_create_user_command`. Two-level completion is the point of
  the plugin.
- Descriptive commit messages.

## Project layout

| Path | Contains |
| --- | --- |
| `lua/debugging/bindings/` | The `:Debug` dispatcher, its route tree and completion |
| `lua/debugging/views/` | Auto-refreshing message and Noice windows |
| `lua/debugging/autocmds/` | The live registry reader, the Tree-sitter source audit, and the diff |
| `lua/debugging/actions/` | Reports and inspectors for buffers, windows, tabs, cursor state |
| `lua/debugging/tools/` | Process tracing, startup benchmark, module reload |
| `lua/debugging/terminals/` | The terminal keylogger |
| `lua/debugging/markdown/`, `nvim_options/` | The narrower diagnostics |
| `lua/debugging/config/` | Defaults, feature flags, `setup()` validation |
| `lua/debugging/health.lua` | `:checkhealth debugging` |
| `docs/` | Everything the README links to |
| `TESTS/` | The spec suite |

## Adding a category or an action

1. Implement it as a module that returns data, and keep the rendering separate —
   a report that returns a table can be tested; one that writes to a buffer
   cannot.
2. Add a feature flag in `lua/debugging/config/`, defaulting to whether its
   prerequisite is actually present.
3. Register the route in `lua/debugging/bindings/`, behind that flag, with
   completion for its arguments.
4. Teach `health.lua` to say why the category is off, when it is off.
5. Add a spec under `TESTS/`, including the case where the prerequisite is
   missing.
6. Document it in [`commands.md`](commands.md), the matching page under
   [`FEATURES/`](FEATURES/README.md), and [`BINDINGS.md`](BINDINGS.md).

## Tests

`TESTS/` is a [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
busted-style suite. [GitHub Actions](../.github/workflows/ci.yml) runs it on
every push and PR to `main`.

## Workflow

1. Fork the repository.
2. Branch as `feature/<name>`.
3. Make the change, add a spec, update the affected pages under `docs/`.
4. Open a PR with a clear description of what changed and why.
