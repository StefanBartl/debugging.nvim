# debugging.nvim — Roadmap

## Implemented (v0.1)

- Single `:Debug {category} {action}` command with two-level tab completion
- Categories: messages, noice, report, autocmds (runtime + sources), inspect,
  cursor, dump, keylogger, indent, markdown, neotree (opt-in), health
- Static autocmd source audit merged in from the former `usrcmds.list.autocmd_audit`
- Per-category feature flags + `all = true` shorthand
- `config/DEFAULTS.lua` config system, idempotent `setup()`
- `:checkhealth debugging` covering lib.nvim deps + per-feature externals
- Neo-tree bridge is pcall-guarded (graceful degrade when config layer absent)
- Built on lib.nvim as a deliberate shared dependency
- `docs/BINDINGS.md` cheatsheet (keymaps, :Debug actions, autocmds)
- Optional which-key group label for the views keymap prefix
- Headless spec suite in [docs/TESTS](./TESTS/README.md) (config merge, the
  `autocmds sources` parsers, `:Debug` dispatch and completion)
- stylua/luacheck config, `.luarc.json`, complete `@brief`/`@description`
  headers across every module

## Implemented (v0.2)

- **Tree-sitter parser for `autocmds sources`** — the audit now parses with the
  Lua Tree-sitter grammar (`function_call` named `nvim_create_autocmd`) when the
  parser is available, robust against multi-line/nested calls, and falls back to
  the original text parser otherwise.
- **Quickfix output for `sources`** — `:Debug autocmds sources qf=true` sends
  `path:line` to the quickfix list for direct jump-to-definition.
- **Combined runtime + sources** — `:Debug autocmds all` fuses the static audit
  with the live view (defined ↔ registered), including a "registered at runtime
  but no source found" diff (typically plugin-defined).
- **`inspect window` / `inspect tab`** — window-scoped options/state and a tab
  page's window/buffer layout, alongside `inspect buffer`.
- **`keylogger` with logfile** — `:Debug keylogger start [file]` (or
  `terminals.keylogger.logfile`) appends recorded keys to disk for long sessions.
- **`:Debug` overview as float** — the no-argument overview renders in a
  scrollable floating window by default (`overview = "notify"` restores the old
  behaviour).
- **Neo-tree bridge injectable** — the quarantine/safety targets come from the
  `neotree` config (module name *or* a table), so the bridge works without the
  private `config.neotree.*` layout.
- **`performance startup`** — `startup_benchmark`: spawns a headless Neovim under
  `--startuptime`, reports the total (optionally averaged over N runs) and the
  slowest sourced scripts.

The architecture audit that drove much of the above is fully worked off; the
three checklists under [docs/ROADMAP/](./ROADMAP/) now carry only the items
that were deliberately declined.

## Implemented (v0.3)

- **Scratch/Float-UI moved into lib.nvim** — the scratch-buffer construction
  used by the autocmd audit, `performance startup`, and the `:Debug` float
  overview now goes through shared [lib.nvim](https://github.com/StefanBartl/lib.nvim)
  helpers instead of each hand-rolling `vim.cmd("new")`/`nvim_open_win`:
  `lib.nvim.window.make_scratch` (the float overview), the new
  `lib.nvim.window.open_scratch_split` (report-style scratch splits), and the
  new `lib.nvim.window.tag` (`vim.w[win].custom_tag` lookup, replacing the
  local `find_window_by_tag`/`get_window_tag` in `views/display.lua`).
- **`autocmds sources`'s scan moved into lib.nvim** — the recursive directory
  walk now delegates to `lib.nvim.fs.collect_recursive` (dropping the local
  `uv.fs_scandir`/`fs_scandir_next` walker), and the per-root result cache is
  a `lib.nvim.cache.memory` namespace instead of a hand-rolled `_cache` table.
- Both additions are generic lib.nvim modules (not debugging.nvim-specific),
  so any other plugin can import the same helpers.

`dump` for locals/upvalues remains intentionally unimplemented: at the point
a `:Debug dump` call runs, the Lua stack only contains the command callback
and the dispatcher — there is no user frame with interesting locals to
inspect. That would need a real breakpoint/hook context, which this plugin
does not provide, and building one would turn a diagnostic tool into a
debugger — out of scope (see "Nicht geplant" below).

---

## Nicht geplant

- **Eigene Notify-/Buf-Win-Tab-Utilities** — kommen bewusst aus lib.nvim.
- **Legacy-Einzelbefehle** (`:BufReport`, `:DebugMessagesShow`, …) — bewusst
  zugunsten des einheitlichen `:Debug` entfernt.
- **Generischer Profiler** — Performance-Profiling gehört in ein eigenes Plugin;
  `performance` bleibt auf Startup-Diagnose beschränkt.
- **`dump` für Locals/Upvalues** — siehe Begründung unter "Implemented (v0.3)"
  oben; ein sinnvoller Locals-Dump bräuchte einen echten Breakpoint-/
  Hook-Kontext, den dieses Plugin bewusst nicht bereitstellt.
