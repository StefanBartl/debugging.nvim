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

---

## Geplante Features

### Shared → lib.nvim

These require changes in the separate [lib.nvim](https://github.com/StefanBartl/lib.nvim)
repository, so they are tracked here but implemented there.

- **Scratch/Float-UI nach lib.nvim** — der Scratch-Buffer-Aufbau (autocmd-audit,
  Reports, das neue `:Debug` Float-Overview) wird mit project-insight geteilt;
  gemeinsame Helper nach `lib.nvim` auslagern und von beiden Plugins importieren.

- **rg-Scan-Util nach lib.nvim** — die Scan-Infrastruktur von `autocmds sources`
  mit project-insight teilen.

### Neue Aktionen

- **`dump` für Locals/Upvalues** — bewusst zurückgestellt. Zum Zeitpunkt eines
  `:Debug dump`-Aufrufs besteht der Lua-Stack nur aus dem Command-Callback und
  dem Dispatcher; es gibt keinen Nutzer-Frame mit interessanten Locals zu
  inspizieren. Sinnvoll erst mit einem echten Breakpoint-/Hook-Kontext, den
  dieses Plugin nicht hat.

---

## Nicht geplant

- **Eigene Notify-/Buf-Win-Tab-Utilities** — kommen bewusst aus lib.nvim.
- **Legacy-Einzelbefehle** (`:BufReport`, `:DebugMessagesShow`, …) — bewusst
  zugunsten des einheitlichen `:Debug` entfernt.
- **Generischer Profiler** — Performance-Profiling gehört in ein eigenes Plugin;
  `performance` bleibt auf Startup-Diagnose beschränkt.
