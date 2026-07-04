# Audit: Checklisten für Lua/Neovim-Architektur, Performance und Codierungsregeln

Prüft `debugging.nvim` gegen
[Checklist.md](E:/repos/Notes/MyNotes/Checklists/Lua/Checklist.md).
Die Quelle deckt neben Architektur/Coding auch generische CS-Themen ab
(Sortieralgorithmen, Datenstrukturen, Bitoperationen), die für dieses Repo
**nicht anwendbar** sind — `debugging.nvim` implementiert keine eigenen
Sortier-, Baum-, Hash- oder Bit-Routinen. Diese Abschnitte werden am Ende
kurz mit Begründung als ➖ N/A markiert statt einzeln durchdekliniert.

Legende: ✅ erfüllt · ⚠ Lücke · ➖ nicht anwendbar

---

## Schnell-Check (10 Punkte, vor jedem Merge)

| Prüfschritt | Priorität | Status | Befund |
|---|---|---|---|
| Fehlerbehandlung vorhanden | 🔴 | ✅ überwiegend | `pcall` durchgängig an API-Grenzen; s. Detail in [Arch&Coding.md §1](./Arch&Coding.md#1-sicherheitsprinzipien--fehlerbehandlung) |
| Type Guards | 🔴 | ✅ | `type(...)`/`nil`-Checks vor den meisten API-Zugriffen |
| Buffer/Window validieren | 🔴 | ✅ vorbildlich | [views/utils.lua](../../lua/debugging/views/utils.lua) ist die Referenzimplementierung im Repo |
| Keine globalen States | 🔴 | ⚠ Lücke | `WINDOWS`-Tabelle in [views/display.lua](../../lua/debugging/views/display.lua) ist Modul-State, der inkonsistent gepflegt wird (Detail: [Arch&Coding.md](./Arch&Coding.md)) |
| Single Responsibility | 🔴 | ✅ | Nach der `bindings/`-Restrukturierung sauber getrennt: Registrierung vs. Dispatch vs. Aktion |
| UI-Cleanup | 🟡 | ⚠ Lücke | `display.clear_all()` existiert, räumt aber wegen des State-Bugs nicht zuverlässig auf |
| Performance-Hotspots | 🟡 | ✅ | Kein Hot-Path; wo iteriert wird ([autocmds/sources.lua](../../lua/debugging/autocmds/sources.lua)), werden `table.concat`/lokale Aliase korrekt genutzt |
| Annotationen vollständig | 🟡 | ⚠ Lücke | Ältere Leaf-Module ohne `@brief`/`@description` (Detail: [Arch&Coding.md §5](./Arch&Coding.md#5-dokumentation--annotationen)) |
| Testbarkeit | 🟡 | ⚠ Lücke | Kein `docs/TESTS/**`, keine Property-Tests für die reinen Parser-Funktionen in `autocmds/sources.lua` |
| Import-Reihenfolge | 🟢 | ✅ | System → Notify → Config → Leaf-Requires eingehalten |

### Bonuspunkt: Custom `lib`-Modul nutzen

✅ **Gut, mit kleinen Lücken.** `lib.nvim.notify`, `lib.nvim.buf_win_tab.*`,
`lib.nvim.fs.*`, `lib.nvim.cross`, `lib.lua.lazy` werden durchgängig genutzt
(s. [health.lua](../../lua/debugging/health.lua) für die vollständige
Abhängigkeitsliste). Lücken: `print()` statt `lib.notify` in mehreren Tools
(s. [Arch&Coding.md](./Arch&Coding.md)); `bindings/autocmds.lua` und
`bindings/usercmds.lua` nutzen `vim.api.nvim_create_autocmd`/
`nvim_create_user_command` direkt statt eines `lib.autocmd`/`lib.usercmd`-
Wrappers (sofern ein solcher in `lib.nvim` existiert und Mehrwert bietet —
zu prüfen).

## PR-Review-Checkliste (Detail)

### 1. Sicherheit und Fehlerbehandlung

✅ Siehe [Arch&Coding.md §1](./Arch&Coding.md#1-sicherheitsprinzipien--fehlerbehandlung)
für die Detailanalyse (pcall-Abdeckung, `tools/vardump` als einzige echte
Lücke bei rekursiven Aufrufen).

### 2. Modularität und Struktur

✅ Single Responsibility eingehalten. ⚠ Keine-Globals-Regel hat eine Ausnahme
(`WINDOWS` in `views/display.lua`). ✅ Config-Folder mit `config/DEFAULTS.lua`
vorhanden ([config/DEFAULTS.lua](../../lua/debugging/config/DEFAULTS.lua)).
✅ Tools/Registry-Pattern in [commands.lua](../../lua/debugging/commands.lua)
umgesetzt.

### 3. Buffer-/Window-Management (Neovim)

✅ Handle-Validierung durchgängig vor jedem `nvim_buf_*`/`nvim_win_*`.
⚠ Race-Conditions: `vim.defer_fn`-Callbacks in
[views/display.lua](../../lua/debugging/views/display.lua) und
[bindings/autocmds.lua](../../lua/debugging/bindings/autocmds.lua) validieren
Handles nach dem Delay erneut (`api.nvim_win_is_valid(win)` in den Callbacks)
— das ist korrekt umgesetzt, kein Fund hier.

### 4. UI-State-Management

⚠ Kein zentrales `ui_state`-Modul mit Getter/Setter für Fenster-Handles; direkter
Tabellenzugriff auf `WINDOWS` in `views/display.lua`. Kein Snapshot/Restore
(nicht nötig für dieses Feature-Set).

### 5. Dokumentation und Annotationen

⚠ Siehe [Arch&Coding.md §5](./Arch&Coding.md#5-dokumentation--annotationen) —
uneinheitliche Kopf-Tags zwischen alten und neuen Dateien.

### 6. Testbarkeit und Lesbarkeit

⚠ Kein Test-Entrypoint. Die reine Parser-Logik in `autocmds/sources.lua`
(`normalize_events`, `read_brace_block`, `parse_args`) ist pure-function-
artig und wäre mit überschaubarem Aufwand isoliert testbar — guter erster
Kandidat, falls `docs/TESTS/**` eingeführt wird.

### 7. Tooling

⚠→✅ **Gerade behoben:** Vor diesem Audit hatte das Repo **kein** `.luarc.json`
— das erklärt die durchgängigen "Undefined global `vim`"-Diagnosen, die
während der gesamten Session in fast jeder editierten Datei auftraten. Jetzt
vorhanden: [.luarc.json](../../.luarc.json) mit `diagnostics.globals = ["vim"]`,
`workspace.library`, `hint.enable = true`. Formatter/Linter (stylua, luacheck)
sind weiterhin nicht konfiguriert — optionale nächste Stufe.

## Coding-Checkliste (beim Implementieren)

### Funktionales Programmieren in Lua (Filter/Sinks/Pumps)

➖ N/A — `debugging.nvim` verarbeitet keine großen Datenströme (keine
Log-Datei-Streaming-Analyse, keine Netzwerk-/Kompressions-Pipelines). Die
größte Datenmenge, die verarbeitet wird, ist der rekursive Datei-Scan in
`autocmds/sources.lua`, der pro Datei komplett eingelesen wird
(`vim.fn.readfile`) — bei typischen Neovim-Config-Größen unproblematisch;
eine Streaming-Umstellung wäre Overengineering für den aktuellen Use-Case.

### A. Strings und Tabellen

✅ Keine String-Verkettung in Schleifen gefunden. `table.concat` konsequent
genutzt. Keine Tabellen-Vorreservierung nötig (keine großen, vorab bekannten
Tabellengrößen im Code).

### B. Performance-Quickwins

✅ Lokale Funktions-Refs in `autocmds/sources.lua` (Hot-Loop-Kandidat, s. o.).
➖ Async via `vim.loop`/`vim.uv`: `autocmds/sources.lua` nutzt `vim.uv` bereits
für den Verzeichnis-Scan (`fs_scandir`/`fs_scandir_next`,
[Zeile 12](../../lua/debugging/autocmds/sources.lua)), aber synchron
(blockierend) statt mit Callbacks — für die üblichen Config-Größen (wenige
hundert Dateien) unkritisch, bei sehr großen Scan-Roots (`root=` auf ein
großes Fremdverzeichnis gesetzt) könnte das spürbar blockieren. Kein akuter
Fund, aber ein Kandidat für "Async statt Blocken", falls `root=` in der
Praxis auf große Verzeichnisse zeigt.

### C. Neovim-API sicher verwenden

✅ Siehe oben (Buffer-/Window-Management).

### D. State- und Datenmodelle

⚠ `WINDOWS`-Tabelle ohne Getter/Setter, direkter Feldzugriff — einziger Fund,
mehrfach oben dokumentiert.

### E. Garbage-Collector bewusst steuern

➖ N/A — keine große Objektfreigabe nötig, kein `collectgarbage()`-Bedarf
identifiziert.

### F. Lazy-Loading und On-Demand-Konfiguration

✅ `config/init.lua` merged Defaults erst bei `setup()`
([config/init.lua](../../lua/debugging/config/init.lua)) — kein
Metatable-basiertes On-Demand-Resolving nötig, da die Config einmalig beim
Setup vollständig gemerged wird (angemessen für die überschaubare
Config-Größe dieses Plugins).

## Architektur-Checkliste

| Aspekt | Status | Befund |
|---|---|---|
| Schichten/Module | ✅ | Klare Trennung: `bindings/` (Registrierung) → `commands.lua` (Dispatch) → `actions/`/`tools/`/`views/` (Logik) |
| Abhängigkeiten via DI | ✅ | `bindings/keymaps.lua` erhält `km`/`timings` als Parameter statt globalem Zugriff |
| Erweiterbarkeit (Registries/Factories) | ✅ | `commands.lua`s `build_registry()` ist genau das |
| Testbarkeit | ⚠ | s. o. — pure Kernlogik vorhanden (Parser in `autocmds/sources.lua`), aber nicht isoliert getestet |

### C/C++ nativer Quellcode / FFI

➖ N/A — kein Bedarf an nativen Erweiterungen für ein Text-basiertes
Debug-Tool.

## Anti-Pattern-Check

| Muster | Status | Befund |
|---|---|---|
| Globaler State | ⚠ | `WINDOWS` in `views/display.lua` (modul-lokal, nicht `_G`, aber inkonsistent gepflegt — s. o.) |
| API ohne Guards | ✅ überwiegend | Ausnahme: [tools/cursor/state.lua:32-34](../../lua/debugging/tools/cursor/state.lua) fehlt erneute `is_valid`-Prüfung in der Fenster-Iteration |
| String-Concat im Loop | ✅ | Nicht gefunden |
| Closures im Loop | ✅ | Nicht gefunden |
| Viele kleine temporäre Tabellen | ✅ | Kein Muster gefunden, das einen Tabellenpool rechtfertigen würde |

## Import- und Dateistruktur-Check

| Punkt | Status | Befund |
|---|---|---|
| Import-Reihenfolge | ✅ | Eingehalten |
| Datei-Header (`@module`, `@class`, `@brief`, `@description`) | ⚠ | s. [Arch&Coding.md §5](./Arch&Coding.md#5-dokumentation--annotationen) |
| Typ-Ablage (`@types`-Ordner) | ⚠ | Nur 3/9 Subverzeichnisse haben `@types/` — s. [Arch&Coding.md §5](./Arch&Coding.md#5-dokumentation--annotationen) |

## Performance-Spickzettel

➖ Nicht anwendbar im Sinne von "muss optimiert werden" — es gibt keinen
Hotpath. Die dort empfohlenen Techniken (`t[i]` statt `table.insert`,
`table.concat` statt `..`, Memoization, Debounced Writes) sind an den
wenigen relevanten Stellen (`autocmds/sources.lua`) bereits korrekt
angewendet.

## Sortieralgorithmen / Einfüge-Lösch-Update-Algorithmen / Zeit- und
## Platzkomplexität / Bitoperationen

➖ **Vollständig N/A für dieses Repo.** `debugging.nvim` implementiert keine
eigenen Sortier-, Such- oder Container-Algorithmen und keine Bit-Tricks — es
nutzt ausschließlich Lua-Bordmittel (`table.sort`, `table.concat`, einfache
Tabellen als Listen/Maps) für kleine, on-demand generierte Report-Daten.
Diese Kapitel der Quell-Checkliste sind für Bibliotheks-/Datenstruktur-Code
gedacht, nicht für ein Editor-Debug-Plugin.

## Reviewer-Notizen (ausgefüllte Vorlage)

| Bereich | Beobachtung | Empfehlung |
|---|---|---|
| Sicherheit | pcall-Abdeckung durchgängig gut, eine Lücke in `tools/vardump` | Rekursiven `Vardump`-Aufruf selbst pcallen oder Tiefenlimit hart erzwingen |
| Modularität | Sehr sauber nach `bindings/`-Refactor | — |
| Neovim-API | Handle-Validierung vorbildlich | Redundanten `make_focusable()`-Call in `focus_and_bottom()` entfernen |
| Performance | Kein Hot-Path, keine Anti-Patterns | `autocmds sources` könnte cachen (optional) |
| Doku/Annotation | Uneinheitlich zwischen alt/neu | `@brief`/`@description` in `tools/*`, `terminals/*` nachziehen |
| Tests | Keine vorhanden | Parser-Funktionen in `autocmds/sources.lua` sind guter erster Kandidat |
| `:checkhealth`-Modul implementiert? | ✅ Ja, umfassend ([health.lua](../../lua/debugging/health.lua)) | — |

## Referenzen

- [Arch&Coding.md](./Arch&Coding.md) — detaillierte Architektur-/Coding-Audit (Quelle der meisten hier verlinkten Einzelfunde)
- [Zentral-Prinzipien.md](./Zentral-Prinzipien.md) — Event/Lazy/Cache/Debugbarkeit-Audit
- [../ROADMAP.md](../ROADMAP.md) — bestehende Feature-Roadmap des Plugins
