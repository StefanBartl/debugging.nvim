# Audit: Zentrale Prinzipien für nvim-Module

Prüft `debugging.nvim` gegen die 10 mentalen Check-Fragen aus
[Zentrale-Prinzipien.md](E:/repos/Notes/MyNotes/Checklists/Lua/Zentrale-Prinzipien.md).
Jede Frage wurde gegen die tatsächlichen Module beantwortet, nicht generisch
abgehakt.

---

## 1. Events bündeln, Logik entkoppeln

**Befund: ✅ gut.** Der einzige Ort mit eigenen `nvim_create_autocmd`-Aufrufen
ist [bindings/autocmds.lua](../../lua/debugging/bindings/autocmds.lua) — alle
Events (`WinEnter`, `BufWinEnter`, `FileType`) laufen in einer einzigen
Augroup (`DebugViewsAuto`, konfigurierbar). Kein anderes Modul registriert
eigene Autocmds; die opt-in Neo-tree-Bridge ([actions/neotree_safety.lua](../../lua/debugging/actions/neotree_safety.lua))
delegiert an eine externe Config-Schicht statt eigene Events zu definieren.
Kein Handlungsbedarf.

## 2. Eigene Logik lazy laden

**Befund: ✅ gut, ein Nuance-Punkt.** `cmd = "Debug"` sorgt dafür, dass das
gesamte Plugin erst beim ersten `:Debug`-Aufruf lädt. Leaf-Module werden erst
innerhalb der `run`-Closures in [commands.lua](../../lua/debugging/commands.lua)
per `require()` geladen (echtes Lazy-Loading pro Kategorie). `debugging.views`
wird nur geladen, wenn `features.views = true` ([init.lua](../../lua/debugging/init.lua)).
Einziger Nuance-Punkt: `build_registry()` ([commands.lua:23](../../lua/debugging/commands.lua))
baut beim ersten Zugriff *alle* Kategorie-Einträge (auch deaktivierte) als
Closures auf — unkritisch, da reine Tabellen-/Funktionsdefinitionen ohne
`require()`-Kosten, aber technisch nicht 100 % "nur laden was gebraucht wird".

## 3. Kontext statt Mehrfach-API-Zugriffe

**Befund: ⚠ kleine Lücke.** [views/utils.lua](../../lua/debugging/views/utils.lua)
`M.focus_and_bottom()` ruft `M.make_focusable(win)` auf (Zeile 156) und ruft
danach `M.force_focus(win)` (Zeile 157) auf, welches *intern selbst nochmal*
`M.make_focusable(win)` aufruft ([Zeile 120](../../lua/debugging/views/utils.lua)).
Das bedeutet ein redundanter `nvim_win_get_config`/`nvim_win_set_config`-Zyklus
pro Aufruf. Nicht performancekritisch (kein Hot-Path), aber ein Kandidat für
"dieselbe Information wird zweimal abgefragt". [tools/cursor/state.lua](../../lua/debugging/tools/cursor/state.lua)
ruft mehrere unabhängige `nvim_*`-Funktionen sequenziell auf — das ist hier
sachlich richtig, da jede Funktion eine andere Information liefert (kein
Kontext-Objekt nötig, es ist ein reiner State-Report).

## 4. Autocommand-Gruppen sauber nutzen

**Befund: ✅ gut.** [bindings/autocmds.lua](../../lua/debugging/bindings/autocmds.lua)
erzeugt die Augroup mit `{ clear = true }`
([Zeile 16](../../lua/debugging/bindings/autocmds.lua)) — ein Reload/Reinit
ohne Neustart funktioniert sauber, da die Gruppe bei jedem `setup()` neu
geleert wird. Klar benannt (`ac.group_name`, Default `"DebugViewsAuto"`),
konfigurierbar.

## 5. Event oder Command?

**Befund: ✅ gut.** Alle fachlichen Aktionen (Reports, Inspect, Dump, …) laufen
über den expliziten `:Debug`-Befehl, nicht über Autocmds — korrekt, da sie
alle *explizit angestoßene* Aktionen sind. Die einzigen Autocmds (View-
Refresh bei `WinEnter`/`BufWinEnter`) sind bewusst zustandsgetrieben (ein
Debug-Fenster muss aktualisiert werden, wenn man wieder hineinschaut) — das
ist der richtige Anwendungsfall für ein Event statt eines Commands.

## 6. Treesitter notwendig oder nicht?

**Befund: ⚠ Bezeichnungs-/Korrektheitslücke.**
[nvim_options/indent_helpers.lua](../../lua/debugging/nvim_options/indent_helpers.lua)
`M.prefer_treesitter_indent()` schaltet lediglich `cindent`/`smartindent` aus
([Zeile 34-41](../../lua/debugging/nvim_options/indent_helpers.lua)) — es prüft
nicht, ob für den aktuellen Filetype überhaupt ein Treesitter-Indent-Ausdruck
registriert ist, und setzt `indentexpr` selbst nicht. Der Funktionsname
verspricht mehr, als der Code tut ("prefer treesitter indent" impliziert
Aktivierung, tatsächlich wird nur die Konkurrenz abgeschaltet). Für ein reines
Diagnose-Tool ist das vertretbar, sollte aber im Docstring präzisiert werden
("disables cindent/smartindent so an existing Tree-sitter indentexpr can take
over" statt "prefer"). [markdown/inline_debug.lua](../../lua/debugging/markdown/inline_debug.lua)s
Treesitter-Nutzung ist dagegen korrekt minimal (nur Parser-Präsenz-Check, keine
echten Queries) — angemessen für ein Diagnose-Tool.

## 7. Cache vorhanden und explizit?

**Befund: ⚠ Lücke (Optimierungspotenzial, keine Korrektheitsfrage).**
[autocmds/sources.lua](../../lua/debugging/autocmds/sources.lua) `M.run()`
scannt bei **jedem** Aufruf den kompletten Verzeichnisbaum neu (`scan_dir()`,
rekursiv, Zeile-für-Zeile-Regex über jede `.lua`-Datei). Bei wiederholten
Aufrufen während einer Debug-Session (z. B. `sort=` mehrfach durchprobieren)
wird jedes Mal neu gescannt, obwohl sich der Quellcode zwischen den Aufrufen
i. d. R. nicht ändert. Ein einfacher Cache mit expliziter Invalidierung (z. B.
"neu scannen, wenn älter als N Sekunden" oder ein `:Debug autocmds sources
refresh=true`-Flag) wäre ein sinnvoller, kleiner Gewinn — aber kein
Korrektheitsproblem, da das Tool ohnehin nur auf explizite Anfrage läuft.

## 8. Allokationen im Hot-Path vermeiden

**Befund: ➖ nicht anwendbar.** Es gibt keinen Hot-Path (keine
`CursorMoved`/`TextChanged`-Handler im Repo). Die einzige nennenswerte
Iteration ([autocmds/sources.lua](../../lua/debugging/autocmds/sources.lua))
nutzt bereits lokale Funktions-Aliase (`tbl_insert`, `tbl_concat`, `tbl_sort`,
[Zeile 14](../../lua/debugging/autocmds/sources.lua)) und vermeidet
String-Verkettung in Schleifen zugunsten von `table.concat`.

## 9. Debugbarkeit eingeplant?

**Befund: ⚠ eine konkrete Lücke.**
[terminals/keylogger.lua](../../lua/debugging/terminals/keylogger.lua)s
`log_key()` bricht die rekursive `vim.schedule`-Kette **stillschweigend** ab,
sobald der aktuelle Buffer beim erneuten Einstieg kein Terminal mehr ist
([Zeile 22-24](../../lua/debugging/terminals/keylogger.lua)) — `M.logging`
bleibt dabei `true`. Verlässt man während des Loggings den Terminal-Buffer,
denkt der User (und `:Debug keylogger stop` "bestätigt" das später auch so),
dass noch geloggt wird, obwohl die Schleife längst tot ist. Eine Notify beim
stillen Abbruch ("keylogger stopped: left terminal buffer") würde die
Debugbarkeit dieses Debug-Tools selbst deutlich verbessern. Ansonsten: alle
anderen Module sind über `:checkhealth debugging` klar in ihrem
Aktivierungsstatus einsehbar ([health.lua](../../lua/debugging/health.lua)).

## 10. Laufzeit wichtiger als Startup?

**Befund: ✅ gut.** Kein Code läuft bei `CursorMoved`/`TextChanged`/`BufEnter`
in hoher Frequenz. Startup-Kosten sind durch `cmd = "Debug"` bereits auf
"praktisch null bis zum ersten Aufruf" reduziert — für ein Debug-Werkzeug, das
per Definition nicht auf dem heißen Pfad des Editors liegt, ist Laufzeit hier
sekundär und korrekt priorisiert.

---

## Kurzform (mental) — zusammengefasst

| Frage | Antwort für debugging.nvim |
|---|---|
| Wann läuft es? | Nur auf `:Debug ...`-Aufruf, plus 2 Auto-Refresh-Events für offene Debug-Fenster |
| Muss es jetzt laufen? | Ja — alles ist explizit angefordert |
| Lädt es mehr als nötig? | Nein, `cmd`-Lazy-Load + Closure-Registry sind sauber |
| Läuft es öfter als nötig? | `autocmds/sources.lua` scannt bei jedem Aufruf neu (kein Cache) — einziger Kandidat |
| Wird Arbeit wiederholt? | s. o. (Sources-Scan); sonst nein |
| Ist der Datenfluss klar? | Ja, mit einer Ausnahme: `views/display.lua`s `WINDOWS`-State (s. [Arch&Coding.md](./Arch&Coding.md#zusammenfassung-konkrete-findings-priorisiert)) |

## Konkrete Findings (priorisiert)

| # | Finding | Priorität | Datei |
|---|---|---|---|
| 1 | Keylogger stoppt beim Buffer-Wechsel still, ohne Notify — `M.logging` bleibt fälschlich `true` | 🟡 | [terminals/keylogger.lua](../../lua/debugging/terminals/keylogger.lua) |
| 2 | `autocmds sources` cached nichts zwischen Aufrufen — wiederholte Full-Scans | 🟡 | [autocmds/sources.lua](../../lua/debugging/autocmds/sources.lua) |
| 3 | `focus_and_bottom()` ruft `make_focusable()` redundant zweimal auf | 🟢 | [views/utils.lua](../../lua/debugging/views/utils.lua) |
| 4 | `prefer_treesitter_indent()`-Name verspricht mehr als der Code prüft/tut | 🟢 | [nvim_options/indent_helpers.lua](../../lua/debugging/nvim_options/indent_helpers.lua) |
