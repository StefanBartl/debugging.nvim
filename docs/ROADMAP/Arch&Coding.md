# Audit: Architektur- und Codierungsrichtlinien

Prüft `debugging.nvim` gegen die persönliche Checkliste
[Arch&Coding-Regeln.md](E:/repos/Notes/MyNotes/Checklists/Lua/Arch&Coding-Regeln.md).

**Stand: alle priorisierten Findings abgearbeitet.** Was hier bleibt, sind die
bewusst getroffenen Entscheidungen — Punkte, an denen dieses Repo von der
Checkliste abweicht, samt Begründung. Erledigte Einzelfunde stehen in der
Git-Historie und werden hier nicht dupliziert.

Legende: ➖ nicht anwendbar · 🔁 bewusst zurückgestellt

---

## Bewusste Abweichungen

### ➖ Kein geteilter `safe_call`-Wrapper

Jedes Modul rollt sein eigenes `pcall`-Muster an der API-Grenze. Ein zentraler
Helper würde die Fehlerbehandlung nicht robuster machen, nur indirekter — die
Callsites unterscheiden sich darin, *was* sie im Fehlerfall tun (still
zurückkehren, notifizieren, `ok, err` zurückgeben).

Die beiden Stellen, an denen ein durchgereichter Fehler wirklich unsichtbar
bliebe, sind inzwischen abgedeckt: Autocmd- und Usercommand-Callbacks laufen
über `lib.nvim.autocmd.create` / `lib.nvim.usercmd.create`, die pcallen und
den Fehler notifizieren.

### ➖ Keine strukturierten Fehlertypen, kein `@error`/`@raises`

Keine `InvalidStateError`-artigen Typen: Fehler dieses Plugins enden ausnahmslos
als Notify-Text beim User, es gibt keine Fehlerkette, die ein Aufrufer
programmatisch unterscheiden müsste. `@error`/`@raises` unterstützt LuaLS
ohnehin nicht.

### ➖ Keine Metatable-Objekte

Die Module sind zustandslose Aktionsfunktionen; es gibt kein Objekt, das
Methoden tragen wollte. `views.get_timings()` & Co. decken den Getter-Bedarf
ab.

### 🔁 `@see`-Verlinkung ungenutzt

Kandidat wäre `commands.lua` ↔ `bindings/usercmds.lua`. Siehe
[Checklist.md](./Checklist.md#-see-modulverlinkung).

### 🔁 `#`-Präfix-Konvention in `@alias`

Im Repo gibt es aktuell keine mehrzeiligen `@alias`-Definitionen, die davon
profitieren würden.

### ➖ Kapitel 8–10: Performance & Speicher / Cache / Schwache Tabellen

Kein Hot-Path im Repo. Alle Aktionen sind on-demand ausgelöste
`:Debug`-Befehle, keine `CursorMoved`/`TextChanged`-Handler, keine großen
Datenmengen im Speicher. Die einzige nennenswerte Iteration
([autocmds/sources.lua](../../lua/debugging/autocmds/sources.lua)) wendet die
Empfehlungen bereits an: lokale Aliase für `table.insert`/`concat`/`sort`,
`table.concat` statt Verkettung in Schleifen, plus einen expliziten
Scan-Cache.

### ➖ Kapitel 11: Spezialfälle

Keine Favoriten-/History-Strukturen mit Ringbuffer-Bedarf, keine
Dual-Representation-Anforderungen.

### ➖ README.md (DE) + `/doc/*.txt` (EN) pro Modul

Gilt laut Quelle für `nvim/config`-Module, nicht für eigenständige
Plugin-Repos. Siehe [Checklist.md](./Checklist.md).

## Notiz zu `lib.nvim`-Wrappern

Die im ersten Audit offen gelassene Frage — ob `lib.autocmd`/`lib.usercmd`
gegenüber der rohen API Mehrwert bieten — ist beantwortet: **ja**, beide
pcallen den Callback und notifizieren im Fehlerfall, `usercmd.create` setzt
zusätzlich `force = true` (idempotente Registrierung).

Eine Ausnahme bleibt bewusst bestehen: die Augroup in
[bindings/autocmds.lua](../../lua/debugging/bindings/autocmds.lua) wird weiter
direkt per `nvim_create_augroup(..., { clear = true })` erzeugt, **nicht** über
`lib.nvim.autocmd.group()`. Letzteres cached Gruppen nach Namen und überspringt
das Clear bei Folgeaufrufen — bei einem erneuten `setup()` würden sich die
Autocmds damit verdoppeln. Das Clear-pro-Setup ist genau die Eigenschaft, die
Config-Reload ohne Neovim-Neustart funktionieren lässt.

## Referenzen

- [Checklist.md](./Checklist.md) — Architektur-/Performance-/Coding-Checklisten
- [Zentral-Prinzipien.md](./Zentral-Prinzipien.md) — Event/Lazy/Cache/Debugbarkeit-Audit
- [../TESTS/README.md](../TESTS/README.md) — Spec-Suite
