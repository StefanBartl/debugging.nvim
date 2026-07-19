# Audit: Zentrale Prinzipien für nvim-Module

Prüft `debugging.nvim` gegen die 10 mentalen Check-Fragen aus
[Zentrale-Prinzipien.md](E:/repos/Notes/MyNotes/Checklists/Lua/Zentrale-Prinzipien.md).

**Stand: alle Findings abgearbeitet.** Was bleibt, ist die Kurzfassung der
Antworten (als Referenz für künftige Änderungen) plus die zwei Punkte, die
bewusst so stehen bleiben.

---

## Kurzform

| Frage | Antwort für debugging.nvim |
|---|---|
| Wann läuft es? | Nur auf `:Debug ...`-Aufruf, plus 2 Auto-Refresh-Events für offene Debug-Fenster |
| Muss es jetzt laufen? | Ja — alles ist explizit angefordert |
| Lädt es mehr als nötig? | Nein, `cmd = "Debug"`-Lazy-Load + Closure-Registry |
| Läuft es öfter als nötig? | Nein — der Sources-Scan cached pro `root` für 5s (`refresh=true` erzwingt Rescan) |
| Wird Arbeit wiederholt? | Nein |
| Ist der Datenfluss klar? | Ja — Debug-Fenster werden ausschließlich über `vim.w[win].custom_tag` identifiziert, es gibt kein paralleles Registry |
| Event oder Command? | Fachliche Aktionen als Command; Events nur für zustandsgetriebenen View-Refresh |
| Autocmd-Gruppen sauber? | Eine Augroup (`DebugViewsAuto`, konfigurierbar), `clear = true` pro `setup()` |
| Debugbarkeit? | `:checkhealth debugging`; Autocmd-/Usercmd-Callbacks melden Fehler über die `lib.nvim`-Wrapper |

## Bewusst so belassen

### 🔁 `build_registry()` baut alle Kategorie-Closures

[commands.lua](../../lua/debugging/commands.lua) legt beim ersten Zugriff auch
die Einträge deaktivierter Kategorien als Closures an. Unkritisch: das sind
reine Tabellen-/Funktionsdefinitionen ohne `require()`-Kosten — die
Leaf-Module werden erst *innerhalb* der Closure geladen. Technisch nicht
100 % „nur laden was gebraucht wird", praktisch aber kostenlos.

### ➖ Allokationen im Hot-Path

Nicht anwendbar — es gibt keinen Hot-Path (keine
`CursorMoved`/`TextChanged`-Handler). Die einzige nennenswerte Iteration
([autocmds/sources.lua](../../lua/debugging/autocmds/sources.lua)) nutzt
lokale Funktions-Aliase und `table.concat` statt Verkettung in Schleifen.

### ✅ Treesitter für den Sources-Parser (umgesetzt)

`autocmds/sources.lua` parst `nvim_create_autocmd`-Callsites jetzt per
Tree-sitter (Lua-Grammar, `function_call` mit Namen `nvim_create_autocmd`),
sobald der Lua-Parser verfügbar ist; der alte Text-/Klammer-Parser bleibt als
Fallback und ist weiter durch
[sources_spec.lua](../TESTS/sources_spec.lua) abgesichert. Der End-to-End-Test
(`sources.run`) läuft in CI gegen den Tree-sitter-Pfad, da der Lua-Parser dort
vorhanden ist.

`markdown/inline_debug.lua` nutzt Treesitter bewusst minimal (nur
Parser-Präsenz-Check, keine Queries) — angemessen für ein Diagnose-Tool.

## Referenzen

- [Arch&Coding.md](./Arch&Coding.md) — Architektur-/Coding-Audit
- [Checklist.md](./Checklist.md) — Architektur-/Performance-/Coding-Checklisten
- [../TESTS/README.md](../TESTS/README.md) — Spec-Suite
