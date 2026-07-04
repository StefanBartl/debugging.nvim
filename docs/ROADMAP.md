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

## Implementierungsplan (aus Architektur-Audit)

Aus dem Abgleich gegen drei persönliche Lua/Neovim-Checklisten
([docs/ROADMAP/Arch&Coding.md](./ROADMAP/Arch&Coding.md),
[docs/ROADMAP/Zentral-Prinzipien.md](./ROADMAP/Zentral-Prinzipien.md),
[docs/ROADMAP/Checklist.md](./ROADMAP/Checklist.md)). Priorisiert nach
Schweregrad; jeder Punkt verlinkt auf die Detailbegründung im jeweiligen Audit.

### 🔴 Kritisch

- [x] **`WINDOWS`-Registry in `views/display.lua` korrekt pflegen** — `clear_all()`
  nutzt jetzt dieselbe `vim.w[win].custom_tag`-Suche wie `find_window_by_tag()`
  statt der inkonsistent gepflegten `WINDOWS`-Tabelle (entfernt). Verifiziert
  per Headless-Test: Fenster wird getaggt → gefunden → `clear_all()` schließt
  es → nicht mehr auffindbar.
  ([Arch&Coding.md](./ROADMAP/Arch&Coding.md#2-modularisierung--strukturprinzipien))

### 🟡 Empfohlen

- [x] **`print()` durch `lib.nvim.notify` ersetzen** in `tools/buffer_inspector`,
  `tools/cursor/state.lua`, `tools/vardump`, `autocmds/runtime.lua`,
  `nvim_options/indent_helpers.lua` — Konsistenz mit dem Rest des Repos.
  ([Arch&Coding.md](./ROADMAP/Arch&Coding.md#1-sicherheitsprinzipien--fehlerbehandlung))
- [x] **`tools/vardump`: `M.Vardump` lokal + snake_case machen** (jetzt
  `local function dump_value`), Tiefenlimit (`MAX_DEPTH = 30`) + `pcall` gegen
  zyklische Tabellen ergänzt. Verifiziert per Headless-Test mit selbstreferenzierender
  Tabelle. ([Arch&Coding.md](./ROADMAP/Arch&Coding.md#5-dokumentation--annotationen))
- [x] **Keylogger: stilles Stoppen sichtbar machen** — `terminals/keylogger.lua`
  notifiziert jetzt ("Stopped: left the terminal buffer") und setzt `M.logging
  = false`, wenn die Rekursionskette abbricht, weil der Buffer kein Terminal
  mehr ist. Verifiziert per Headless-Test (gemockter `getcharstr`).
  ([Zentral-Prinzipien.md](./ROADMAP/Zentral-Prinzipien.md#9-debugbarkeit-eingeplant))
- [x] **`views/utils.lua`: redundanten `make_focusable()`-Call entfernen** in
  `focus_and_bottom()` (wird bereits intern von `force_focus()` aufgerufen).
  ([Zentral-Prinzipien.md](./ROADMAP/Zentral-Prinzipien.md#3-kontext-statt-mehrfach-api-zugriffe))
- [ ] **`autocmds sources`: optionalen Cache erwägen** (z. B. Ergebnis für N
  Sekunden behalten, `refresh=true`-Flag zum Erzwingen), um wiederholte
  Full-Scans während einer Session zu vermeiden. Zurückgestellt — Design-
  Entscheidung (Cache-Invalidierungsstrategie), kein reiner Bugfix.
  ([Zentral-Prinzipien.md](./ROADMAP/Zentral-Prinzipien.md#7-cache-vorhanden-und-explizit))

### 🟢 Nice-to-have

- [ ] `@brief`/`@description` in verbleibenden Leaf-Modulen nachziehen
  (`tools/cursor/state.lua`, `nvim_options/indent_helpers.lua`) — bereits
  ergänzt in `tools/vardump` und `terminals/keylogger.lua`.
- [ ] `@types/`-Ordner für `tools/`, `autocmds/`, `actions/`, `bindings/`,
  `terminals/`, `nvim_options/` ergänzen (aktuell nur in `debugging/@types`,
  `views/@types`, `markdown/@types`).
- [x] `terminals/keylogger.lua`: deutsche Kommentare ins Englische übersetzt.
- [ ] `markdown/inline_debug.lua`: veralteten Kopfkommentar-Verweis auf `/tmp`
  korrigieren (tatsächliches Ziel: `stdpath("data")/debuglog/markdown_inline`).
- [x] `nvim_options/indent_helpers.lua`: Docstring von `prefer_treesitter_indent`
  präzisiert (schaltet nur `cindent`/`smartindent` ab, aktiviert Treesitter
  nicht selbst).
- [x] `tools/cursor/state.lua`: erneute `nvim_win_is_valid()`-Prüfung in der
  Fenster-Iteration ergänzt.
- [ ] Formatter/Linter (`stylua`, `luacheck`) einrichten — `.luarc.json` ist
  jetzt vorhanden ([../.luarc.json](../.luarc.json)), Formatter/Linter fehlen
  noch. ([Checklist.md](./ROADMAP/Checklist.md#7-tooling))

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
