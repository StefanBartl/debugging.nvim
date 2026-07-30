# Audit: Checklisten für Lua/Neovim-Architektur, Performance und Codierungsregeln

Prüft `debugging.nvim` gegen
[Checklist.md](E:/repos/Notes/MyNotes/Checklists/Lua/Checklist.md).

**Stand: alle Findings abgearbeitet.** Diese Datei führt nur noch die Punkte,
die *bewusst* nicht umgesetzt wurden (mit Begründung) — damit ein späterer
Audit-Lauf sie nicht erneut als Lücke meldet. Die erledigten Einzelfunde sind
aus der Git-Historie nachvollziehbar und hier nicht mehr dupliziert.

Legende: ➖ nicht anwendbar · 🔁 bewusst zurückgestellt

---

## Bewusst nicht umgesetzt

### 🔁 `@types/`-Ordner nicht in jedem Subverzeichnis

Vorhanden in `lua/debugging/@types/`, `views/`, `markdown/`, `autocmds/`,
`bindings/` und `tools/` — überall dort, wo es echte mehrfeldrige Strukturen
gibt. **Nicht** angelegt für `actions/`, `terminals/`, `nvim_options/`: diese
Module nehmen nur Primitive entgegen (bufnr, varname, boolesche Flags) und
rendern direkt in einen Notify-String. Ein leerer Platzhalter-Ordner brächte
keinen LSP-Mehrwert. Vermerkt im Kopf von
[tools/@types/init.lua](../../lua/debugging/tools/@types/init.lua).

### ✅ Gruppierungs-Stil in den `@types`-Dateien — erledigt

Die Quell-Checkliste schlägt `--- #####…` + `-- Xy.lua`-Kommentar pro
Quelldatei vor. `autocmds/@types` und `tools/@types` folgten dem bereits;
`views/` und `markdown/` sind jetzt nachgezogen. `views/@types` erreichte mit
sechs Klassen ohnehin die im ursprünglichen Vermerk genannte Schwelle von
~3 Quelldatei-Gruppen: die Klassen sind nun nach `capture/init.lua`,
`display.lua` und `init.lua` gruppiert (`Timings` ist bewusst als von
`display.lua` *und* `init.lua` geteilt ausgewiesen, statt willkürlich einer
der beiden zugeschlagen zu werden). Bei der Gelegenheit haben die bis dahin
undokumentierten Felder Beschreibungen bekommen.

### ✅ `@see`-Modulverlinkung — erledigt

Umgesetzt für den in dieser Datei selbst vorgeschlagenen Kandidaten:
`commands.lua` ↔ `bindings/usercmds.lua` (Dispatch-/Registrierungs-Split).
Beide Header verwiesen bereits prosaisch aufeinander; daraus sind jetzt
echte `@see`-Tags geworden, die LuaLS auflösen kann.

### ➖ Funktionales Programmieren (Filter/Sinks/Pumps)

`debugging.nvim` verarbeitet keine großen Datenströme. Die größte Datenmenge
ist der rekursive Datei-Scan in `autocmds/sources.lua`, der pro Datei komplett
eingelesen wird (`vim.fn.readfile`) — bei typischen Config-Größen
unproblematisch; eine Streaming-Umstellung wäre Overengineering.

### ➖ Async via `vim.loop`/`vim.uv`

`autocmds/sources.lua` delegiert den Verzeichnis-Scan an
`lib.nvim.fs.collect_recursive` (das intern `vim.uv`/`fs_scandir`/
`fs_scandir_next` nutzt), synchron. Durch den 5s-Cache
(`CACHE_TTL_SECONDS`, jetzt eine `lib.nvim.cache.memory`-Namespace) fällt der
Scan pro Debug-Session i. d. R. nur einmal an. Erst relevant, falls `root=` in
der Praxis auf sehr große Fremdverzeichnisse zeigt.

### ➖ Standardisiertes Error-Wrapping / strukturierte Fehlertypen

Kein zentraler `safe_call(fn, args)`-Helper und keine `InvalidStateError`-artigen
Typen. Für ein Debug-Tool, dessen Fehler ausnahmslos als Notify-Text beim User
landen, wäre eine Fehlertyp-Hierarchie Ballast. Die pcall-Abdeckung an den
API-Grenzen ist durchgängig; die Autocmd-/Usercmd-Callbacks werden zusätzlich
von den `lib.nvim`-Wrappern gepcallt.

### ➖ GC-Steuerung, Ringbuffer, Metatable-Objekte, Snapshot/Restore

Kein `collectgarbage()`-Bedarf, kein History-/FIFO-Feature, keine
zustandsbehafteten Objekte, kein Undo/Redo — jeweils ohne Anwendungsfall im
aktuellen Feature-Set.

### ➖ C/C++ / FFI

Kein Bedarf an nativen Erweiterungen für ein textbasiertes Debug-Tool.

### ➖ Sortieralgorithmen / Datenstrukturen / Komplexität / Bitoperationen

Vollständig N/A. `debugging.nvim` implementiert keine eigenen Sortier-, Such-
oder Container-Algorithmen und keine Bit-Tricks — es nutzt ausschließlich
Lua-Bordmittel (`table.sort`, `table.concat`, einfache Tabellen) für kleine,
on-demand generierte Report-Daten. Diese Kapitel der Quell-Checkliste zielen
auf Bibliotheks-/Datenstruktur-Code, nicht auf ein Editor-Plugin.

### ➖ Performance-Spickzettel

Kein Hotpath vorhanden. Die empfohlenen Techniken (`t[i]` statt
`table.insert`, `table.concat` statt `..`, lokale Aliase) sind an den wenigen
relevanten Stellen (`autocmds/sources.lua`) bereits angewendet.

### ➖ README.md (DE) + `/doc/*.txt` (EN) pro Modul

Gilt laut Quelle explizit für `nvim/config`-Module, nicht für eigenständige
Plugin-Repos. `debugging.nvim` hat stattdessen ein englisches README + vimdoc
auf Repo-Ebene, was für ein publizierbares Plugin korrekt ist.

## Referenzen

- [Arch&Coding.md](./Arch&Coding.md) — Architektur-/Coding-Audit
- [Zentral-Prinzipien.md](./Zentral-Prinzipien.md) — Event/Lazy/Cache/Debugbarkeit-Audit
- [../ROADMAP.md](../ROADMAP.md) — Feature-Roadmap des Plugins
- [../TESTS/README.md](../TESTS/README.md) — Spec-Suite (schließt den ehemaligen "keine Tests"-Fund)
