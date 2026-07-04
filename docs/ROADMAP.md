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
- `docs/BINDINGS.lua` cheatsheet (keymaps, :Debug actions, autocmds)
- Optional which-key group label for the views keymap prefix

---

## Geplante Features

### Autocmd-Audit

- **Tree-sitter-Parser für `autocmds sources`** — das aktuelle Text-/Klammer-
  Parsing (`read_brace_block`, Regex auf `nvim_create_autocmd`) ist fragil bei
  mehrzeiligen/verschachtelten Aufrufen. Auf Treesitter umstellen (Lua-Grammar,
  `function_call` mit Namen `nvim_create_autocmd`).

- **Quickfix-Ausgabe für `sources`** — `path:line` zusätzlich in die Quickfix-
  Liste statt nur Scratch-Buffer; ermöglicht direktes Springen zur Definition.

- **Runtime + Sources vereinen** — `:Debug autocmds all` zeigt eine kombinierte
  Ansicht (wo definiert ↔ aktuell registriert), inkl. „registriert aber keine
  Quelle gefunden"-Diff (z. B. von Plugins).

### Shared → lib.nvim

- **Scratch/Float-UI nach lib.nvim** — der Scratch-Buffer-Aufbau (autocmd-audit,
  künftige Reports) wird mit project-insight geteilt; gemeinsame Helper nach
  `lib.nvim` auslagern und von beiden Plugins importieren.

- **rg-Scan-Util nach lib.nvim** — falls `autocmds sources` auf rg/Treesitter
  umgestellt wird, die Scan-Infrastruktur mit project-insight teilen.

### Neue Kategorien / Aktionen

- **`performance`** — `startup_benchmark` (in den Alt-Typen referenziert, nie
  implementiert): Startup-Zeiten messen (`--startuptime`-Auswertung) und
  Lazy-Load-Übersicht.

- **`dump` für Locals/Upvalues** — derzeit nur Globals; optional via `debug.*`
  Locals des aufrufenden Frames inspizieren.

- **`inspect window` / `inspect tab`** — analog zu `inspect buffer` für Fenster-
  und Tab-Optionen (ergänzt die `report`-Kategorie um interaktive Inspektion).

- **`keylogger` mit Logfile** — Tastendrücke optional in eine Datei schreiben
  statt nur `notify`, für längere Sessions.

### Neo-tree

- **Bridge injizierbar machen** — statt fixem `require("config.neotree.*")` die
  Safety-/Quarantine-Module per Config übergeben (`neotree = { safety = …,
  quarantine = … }`), damit das Modul ohne die private Config nutzbar ist.

### DX

- **`:Debug` Overview als Float** statt `notify` (scrollbar bei vielen Kategorien).

---

## Nicht geplant

- **Eigene Notify-/Buf-Win-Tab-Utilities** — kommen bewusst aus lib.nvim.
- **Legacy-Einzelbefehle** (`:BufReport`, `:DebugMessagesShow`, …) — bewusst
  zugunsten des einheitlichen `:Debug` entfernt.
- **Generischer Profiler** — Performance-Profiling gehört in ein eigenes Plugin;
  `performance` bleibt auf Startup-Diagnose beschränkt.
