# Audit: Architektur- und Codierungsrichtlinien

Prüft `debugging.nvim` gegen die persönliche Checkliste
[Arch&Coding-Regeln.md](E:/repos/Notes/MyNotes/Checklists/Lua/Arch&Coding-Regeln.md).
Kein 1:1-Abklatsch — jede Sektion wurde gegen den tatsächlichen Code geprüft.
Rein algorithmische/CPU-Zyklen-Referenztabellen (Kapitel 8–10 der Quelle) sind
nicht produktiv relevant für dieses Plugin (keine eigenen Datenstrukturen/Hot-
Loops) und werden nur kurz kommentiert statt einzeln abgeklopft.

Legende: ✅ erfüllt · ⚠ Lücke · ➖ nicht anwendbar

---

## 1. Sicherheitsprinzipien & Fehlerbehandlung

| Regel | Status | Befund |
|---|---|---|
| `pcall()` bevorzugt | ✅ überwiegend | Konsequent in [views/capture/init.lua](../../lua/debugging/views/capture/init.lua), [views/display.lua](../../lua/debugging/views/display.lua), [views/utils.lua](../../lua/debugging/views/utils.lua), [markdown/inline_debug.lua](../../lua/debugging/markdown/inline_debug.lua) (eigener `safe_call`-Wrapper) |
| | ⚠ Lücke | [tools/vardump/init.lua:72](../../lua/debugging/tools/vardump/init.lua) pcallt nur den `_G`-Zugriff, nicht `M.Vardump` selbst (rekursiv, kann bei zyklischen Tabellen o. exotischen Metatables durchschlagen) |
| Type Guards & Literal Checks | ✅ überwiegend | `nvim_*_is_valid()` fast überall vor API-Zugriffen ([views/utils.lua](../../lua/debugging/views/utils.lua) ist vorbildlich) |
| Explizite Rückgaben | ✅ | `capture.capture_messages()`, `markdown.inline_debug.gather()`, `module_reload.reload_current()` geben durchgängig `ok, err` zurück |
| Kein `notify()` in Low-Level-Code | ⚠ Lücke (umgekehrtes Problem) | Mehrere Tools nutzen **rohes `print()`** statt `lib.nvim.notify` oder Rückgabewerte: [tools/buffer_inspector/init.lua](../../lua/debugging/tools/buffer_inspector/init.lua), [tools/cursor/state.lua](../../lua/debugging/tools/cursor/state.lua), [tools/vardump/init.lua](../../lua/debugging/tools/vardump/init.lua), [autocmds/runtime.lua](../../lua/debugging/autocmds/runtime.lua), [nvim_options/indent_helpers.lua](../../lua/debugging/nvim_options/indent_helpers.lua). Das ist zwar für reine Text-Reports nach `:messages` pragmatisch (genau deren Zweck), verletzt aber die Konvention "immer über `lib.notify`" — inkonsistent zum Rest des Repos, das durchgängig `require("lib.nvim.notify").create(...)` nutzt |
| Standardisiertes Error-Wrapping | ➖ | Kein zentraler `safe_call(fn, args)`-Helper im Repo; `markdown/inline_debug.lua` hat einen lokalen `safe_call`, der aber nicht geteilt wird |
| Strukturierte Fehlertypen | ➖ | Keine `InvalidStateError`-artigen Typen; für ein Debug-Tool mit rein UI-seitigen Fehlern (Notify-Text) vertretbar |
| `@error`/`@raises` Tags | ➖ | Nirgends verwendet — LuaLS unterstützt sie ohnehin nicht, laut Checkliste nur "wenn guter Grund" |
| Private Funktionen bleiben lokal | ⚠ Lücke | [tools/vardump/init.lua:12](../../lua/debugging/tools/vardump/init.lua) exportiert `M.Vardump` (rekursiver Pretty-Printer) statt es lokal zu halten — wird nur intern von `M.dump()` gebraucht |
| Argumente immer geprüft (Type-Check/Assert) | ⚠ teilweise | Meiste `run`-Handler in [commands.lua](../../lua/debugging/commands.lua) casten `args[1]` mit `tonumber()` ohne Validierung von `nil`-Ergebnis vs. tatsächlich ungültiger Eingabe (z. B. `:Debug report win abc` → `id = nil`, fällt still auf "alle Fenster" zurück statt Fehlermeldung) |

## 2. Modularisierung & Strukturprinzipien

| Regel | Status | Befund |
|---|---|---|
| Modul = eine Verantwortung | ✅ | Durchgängig eingehalten; die `bindings/`-Restrukturierung (siehe [docs/ROADMAP.md](../ROADMAP.md)) hat das nochmal geschärft: Registrierung (`bindings/`) getrennt von Logik (`commands.lua`, `actions/`) |
| Reine Funktionen bevorzugt | ✅ überwiegend | Reporting-/Inspect-Module sind reine Leser ohne Seiteneffekte außer Ausgabe |
| Lokale statt globale Funktionen | ⚠ Lücke | s. o. `M.Vardump` |
| Entwurfsmuster wo sinnvoll | ✅ | Registry-Pattern in [commands.lua](../../lua/debugging/commands.lua) (`build_registry()` → category→action→fn-Tabelle) ist genau das empfohlene "Tools via Registry" |
| Keine globalen States | ⚠ Lücke | [views/display.lua:11](../../lua/debugging/views/display.lua) hält ein modul-lokales `WINDOWS`-Registry, das aber **inkonsistent befüllt wird**: nur der `capture_lib`-Zweig in `execute_and_refresh()` schreibt `WINDOWS[tag] = win` (Zeile 77); der häufigere Pfad über `find_window_by_tag()` (Suche via `vim.w[win].custom_tag`) aktualisiert `WINDOWS` nie. Damit findet `clear_all()` (Zeile 132) oft keine Fenster, obwohl welche offen sind — echter Zustands-Bug, nicht nur Stilfrage |
| Pure Functions | ✅ | s. o. |

## 3. Buffer- & Window-Management

| Regel | Status | Befund |
|---|---|---|
| Zuerst `local win/buf`, dann prüfen | ✅ | Konsequent in [views/utils.lua](../../lua/debugging/views/utils.lua), [views/display.lua](../../lua/debugging/views/display.lua) |
| `~= nil` & `nvim_*_is_valid()` | ✅ vorbildlich | [views/utils.lua](../../lua/debugging/views/utils.lua) prüft praktisch jede API-Berührung doppelt ab (win **und** buf) |
| Keine API-Calls ohne Prüfung | ⚠ kleine Lücke | [tools/cursor/state.lua:32-34](../../lua/debugging/tools/cursor/state.lua) iteriert `nvim_list_wins()` und liest `vim.w[w]` ohne erneutes `nvim_win_is_valid(w)` (in der Praxis ungefährlich, da die Liste frisch ist, aber inkonsistent zum Rest) |
| Einheitliche UI-Methoden | ✅ | `open`/`close`/`focus`-artige Helper in [views/utils.lua](../../lua/debugging/views/utils.lua) (`make_focusable`, `force_focus`, `focus_and_bottom`, `ensure_bottom`) sind konsistent benannt |
| Zustand zentral via `ui_state` | ⚠ Lücke | Kein eigenes `ui_state`-Modul; `WINDOWS` in `display.lua` ist der einzige Fenster-State und wie oben beschrieben fehlerhaft gepflegt |
| `cleanup_all()` | ✅ vorhanden | `display.clear_all()` (aber siehe State-Bug oben — räumt nicht zuverlässig auf) |

## 4. Methoden, Metatables & Datenmodelle

| Regel | Status | Befund |
|---|---|---|
| Metatables für Methoden wenn sinnvoll | ➖ | Keine Metatable-Objekte im Repo — bei der Größe/Art der Module (zustandslose Aktionsfunktionen) nicht nötig |
| Getter/Setter für Zustand | ✅ neu | Die `bindings/`-Refaktorierung hat genau das eingeführt: `views.get_timings()`, `get_keymaps_config()`, `get_autocmds_config()` ([views/init.lua](../../lua/debugging/views/init.lua)) statt direktem Feldzugriff |
| Ringbuffer-Strukturen | ➖ | Nicht benötigt (kein History/FIFO-Feature aktuell) |
| `__index` via Shared Metatables | ➖ | Nicht benötigt |

## 5. Dokumentation & Annotationen

| Regel | Status | Befund |
|---|---|---|
| Einheitliche Datei-Tags (`@module`, `@class`, `@brief`, `@description`) | ⚠ Lücke | Nur die kürzlich anfgefassten/neuen Dateien haben volle Tags (z. B. [bindings/*.lua](../../lua/debugging/bindings/), [views/init.lua](../../lua/debugging/views/init.lua)). Reine `@module`-Zeile ohne `@brief`/`@description`: [tools/buffer_inspector/init.lua](../../lua/debugging/tools/buffer_inspector/init.lua), [tools/cursor/state.lua](../../lua/debugging/tools/cursor/state.lua), [tools/vardump/init.lua](../../lua/debugging/tools/vardump/init.lua), [autocmds/runtime.lua](../../lua/debugging/autocmds/runtime.lua) (hat `@brief`+`@description`, gut), [nvim_options/indent_helpers.lua](../../lua/debugging/nvim_options/indent_helpers.lua), [terminals/keylogger.lua](../../lua/debugging/terminals/keylogger.lua) |
| Kommentare pro Funktion (`@param`, `@return`) | ✅ überwiegend | Fast alle `M.*`-Funktionen haben `@param`/`@return`; Ausnahme: [tools/vardump/init.lua:12](../../lua/debugging/tools/vardump/init.lua) `M.Vardump` hat keine Annotation |
| Konsistentes Naming (camelCase/snake_case, aber konsistent) | ⚠ Lücke | [tools/vardump/init.lua](../../lua/debugging/tools/vardump/init.lua): `M.Vardump` (PascalCase) bricht mit dem sonst durchgängigen `snake_case` (`M.dump`, `M.reload_current`, `M.print_indent_options`, …) |
| Explizite Typisierungen (`@alias`, `@field`) | ✅ | `@types/init.lua` in `lua/debugging/`, `views/`, `markdown/` definieren `Dbg.*`-Klassen sauber |
| Modulverlinkung via `@see` | ➖ | Nirgends verwendet — bei der überschaubaren Modulzahl kein akuter Schmerzpunkt, aber z. B. `commands.lua` ↔ `bindings/usercmds.lua` (Dispatch/Registrierungs-Split) wäre ein guter Kandidat |
| `/types`-Ordner pro Subverzeichnis | ⚠ Lücke | Nur 3 von ~10 Subverzeichnissen haben `@types/`: `lua/debugging/@types/`, `views/@types/`, `markdown/@types/`. Fehlend in `tools/`, `autocmds/`, `actions/`, `bindings/`, `terminals/`, `nvim_options/` — dort sind Typen entweder inline (z. B. `Dbg.ActionFn` in [commands.lua:13](../../lua/debugging/commands.lua)) oder fehlen ganz |
| README.md (DE) + `/doc/*.txt` (EN) pro Modul | ➖ N/A | Diese Regel gilt laut Quelle explizit für `nvim/config`-Module, nicht für eigenständige Plugin-Repos. `debugging.nvim` hat stattdessen ein einziges (englisches) README + vimdoc auf Repo-Ebene, was für ein publizierbares Plugin korrekt ist |

## 6. Testbarkeit & Lesbarkeit

| Regel | Status | Befund |
|---|---|---|
| Klein & fokussiert (SRP) | ✅ | Funktionen sind durchgängig kurz und einzweckig |
| Klarheit vor Kürze | ✅ | Kein "cleverer" Code auf Kosten der Lesbarkeit gefunden |
| Testbarkeit durch Design | ⚠ teilweise | `views/display.lua`s `WINDOWS`-Tabelle ist versteckter Modul-State (s. o.), erschwert isoliertes Testen. Der Rest (reine `M.*`-Funktionen mit expliziten Parametern) ist gut testbar |
| Snapshot-/Restore-Funktion | ➖ | Kein `ToolState`-Analogon vorhanden — nicht nötig, da kein Undo/Redo-Feature |
| Separater Test-Entry (`tools/_test`) | ⚠ Lücke | Kein `docs/TESTS/**` und kein Dry-Run-Entrypoint vorhanden (bereits in der vorherigen CHECKLIST.md-Runde als "wenn sinnvoll" zurückgestellt — bei einem reinen Debug-Werkzeug mit viel UI-Nebenwirkung ist automatisiertes Testen tatsächlich aufwändig, aber zumindest die reinen Parser (`autocmds/sources.lua`: `normalize_events`, `read_brace_block`, `parse_args`) wären gute erste Testkandidaten) |

## 7. Fehlerbehandlung & Validierung (Sicherheit)

| Erweiterung | Status | Befund |
|---|---|---|
| Standardisierter Error-Wrapping-Mechanismus | ➖ | s. o. (Kapitel 1) — kein geteilter `safe_call`, jedes Modul rollt sein eigenes `pcall`-Muster |
| Fehlertypen strukturieren | ➖ | Nicht vorhanden; für dieses Plugin (keine komplexe Fehlerkette, meist "hat geklappt" vs. "Notify mit Text") vertretbar |

## 8.–10. Performance & Speicher / Cache / Schwache Tabellen

➖ **Kein Hot-Path im Repo.** Alle Aktionen sind on-demand ausgelöste Debug-Befehle
(`:Debug ...`), keine `CursorMoved`/`TextChanged`-Handler, keine großen
Datenmengen im Speicher. Die einzige Stelle mit nennenswerter Iteration ist
[autocmds/sources.lua](../../lua/debugging/autocmds/sources.lua) (rekursiver
Verzeichnis-Scan + Zeilen-Regex), und dort werden die Performance-Empfehlungen
der Checkliste bereits **korrekt angewendet**: lokale Aliase für
`table.insert`/`table.concat`/`table.sort` ([Zeile 14](../../lua/debugging/autocmds/sources.lua))
und `table.concat` statt String-Verkettung in Schleifen. Kein Handlungsbedarf.

## 11. Spezialfälle

➖ Nicht anwendbar — keine Favoriten-/History-Strukturen mit Ringbuffer-Bedarf,
keine Dual-Representation-Anforderungen.

## MISC — Cross-Plattform

| Regel | Status | Befund |
|---|---|---|
| POSIX + Windows lauffähig | ✅ vorbildlich | [views/capture/clipboard/init.lua](../../lua/debugging/views/capture/clipboard/init.lua) nutzt `lib.nvim.cross` für Plattformerkennung (macOS/Windows/WSL/Linux) mit sauberen Fallback-Ketten (`pbcopy`→`clip.exe`→`wl-copy`→`xclip`→`xsel`). [health.lua](../../lua/debugging/health.lua) prüft alle Anbieter inkl. `clip.exe` |
| `lib.notify` statt `vim.notify()`/`print()` | ⚠ Lücke | s. Kapitel 1 — mehrere Tools nutzen `print()` |
| `lib.map`/`lib.usercmd`/`lib.autocmd` | ⚠ teilweise | `bindings/keymaps.lua` nutzt den injizierten `km.map` (Default `vim.keymap.set`), nicht `lib.map` direkt — das ist als DI-Pattern in Ordnung, aber `bindings/autocmds.lua` und `bindings/usercmds.lua` rufen `vim.api.nvim_create_autocmd`/`nvim_create_user_command` direkt statt über `lib.autocmd`/`lib.usercmd`, falls diese Wrapper zusätzlichen Mehrwert (z. B. einheitliches Cleanup) bieten |
| `lib.cross`/`lib.cross_plattform` | ✅ | s. o. |
| `lib.lazy` gegen unnötige Ladelast | ✅ | `capture/init.lua` nutzt `lib.lua.lazy` für `clipboard`/`fs.write.to_file`; `commands.lua`s Registry lädt Leaf-Module erst bei Aufruf |
| `lib.memo` für Memoization | ➖ | Kein Memoization-Bedarf identifiziert (keine teuren wiederholten Berechnungen) |

## Annotations-Regeln (Detail)

Deckt sich mit Kapitel 5. Zusätzlich:

- Die vorhandenen `@types/init.lua`-Dateien folgen **nicht** dem in der Checkliste
  vorgeschlagenen Gruppierungs-Stil (`--- #####...` + `-- Xy.lua`-Kommentar pro
  Quelldatei) — sie sind flach nach `@class` sortiert. Bei aktuell 3 Type-Dateien
  mit wenigen Klassen ist das noch übersichtlich; sollte bei Wachstum nachgezogen
  werden.
- `#`-Präfix-Konvention in `@alias`/`@return`-Kommentaren wird nirgends genutzt
  (im Repo gibt es aktuell keine mehrzeiligen `@alias`-Definitionen, die davon
  profitieren würden).

## Importreihung

| Erwartete Reihenfolge | Status | Befund |
|---|---|---|
| System/Kern → Debug/Notify → Config/Utils → State → UI → Controller → Keymaps | ✅ überwiegend | Typisches Muster: `notify` zuerst, dann fachliche Requires (z. B. [views/keymaps.lua](../../lua/debugging/bindings/keymaps.lua): `notify` → `display` → `capture`). [commands.lua](../../lua/debugging/commands.lua) hält `notify`/`config` oben, Leaf-Module werden lazy in den Handlern importiert (per Design, nicht Regelverstoß) |

## (Direkt-)Importe vs. Alias / Tabellen / Strings

✅ Keine Auffälligkeiten. Keine String-Verkettung in Schleifen gefunden;
`table.concat` wird überall dort verwendet, wo Zeilen gesammelt werden
(`commands.lua` `overview()`, `autocmds/sources.lua` `generate_output()`,
`views/capture/init.lua`). Keine Performance-kritischen Pfade, die von
lokalen Funktions-Aliasen profitieren würden (keine 1000+-Iterationen im
Code gefunden).

---

## Zusammenfassung: Konkrete Findings (priorisiert)

| # | Finding | Priorität | Datei |
|---|---|---|---|
| 1 | `WINDOWS`-Registry in `views/display.lua` wird inkonsistent gepflegt → `clear_all()` schließt nicht zuverlässig alle Debug-Fenster | 🔴 | [views/display.lua](../../lua/debugging/views/display.lua) |
| 2 | `M.Vardump` sollte lokal + snake_case (`dump_value` o. ä.) sein, nicht als PascalCase-Public-API exportiert | 🟡 | [tools/vardump/init.lua](../../lua/debugging/tools/vardump/init.lua) |
| 3 | `print()` statt `lib.nvim.notify` in mehreren Tools (Inkonsistenz zum Rest des Repos) | 🟡 | tools/*, autocmds/runtime.lua, nvim_options/indent_helpers.lua |
| 4 | Fehlende `@brief`/`@description` in älteren Leaf-Modulen | 🟢 | tools/*, terminals/keylogger.lua |
| 5 | Fehlende `@types/`-Ordner in `tools/`, `autocmds/`, `actions/`, `bindings/`, `terminals/`, `nvim_options/` | 🟢 | s. o. |
| 6 | `terminals/keylogger.lua` hat deutsche Kommentare (Rest des Repos ist englisch) | 🟢 | [terminals/keylogger.lua](../../lua/debugging/terminals/keylogger.lua) |
| 7 | `markdown/inline_debug.lua`-Kopfkommentar nennt `/tmp` als Zielpfad, tatsächlich wird nach `stdpath("data")/debuglog/markdown_inline` geschrieben | 🟢 | [markdown/inline_debug.lua:1-6](../../lua/debugging/markdown/inline_debug.lua) |
