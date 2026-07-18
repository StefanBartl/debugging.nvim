# Commands

## Features

| Category | Actions | What it does |
|---|---|---|
| `messages` | `show` · `capture` · `clear` | Show / capture `:messages` (file + clipboard) / clear debug windows |
| `noice` | `all` · `errors` | Show all Noice messages / only errors |
| `report` | `buf` · `tab` · `win [id]` | Print buffer / tab / window reports to `:messages` |
| `autocmds` | `runtime [event] [pat]` · `sources [args]` | Live `nvim_get_autocmds` view **or** static source-code audit |
| `inspect` | `buffer [bufnr]` | Inspect buffer-scoped options and state |
| `cursor` | `state` | Print cursor / window / buffer state |
| `dump` | `[varname]` | Recursively dump a global Lua var (or word under cursor) |
| `keylogger` | `start` · `stop` | Log keys pressed in the current terminal buffer |
| `indent` | `show` · `treesitter [true\|false]` | Print indent options / prefer Tree-sitter indent |
| `markdown` | `inline` · `log` | Gather markdown inline-highlight debug info / open the log |
| `module` | `reload` | Reload the Lua module of the current buffer |
| `proc` | `start [threshold_ms]` · `stop` · `status` · `log` · `watch [seconds]` | Diagnose UI freezes: log slow `system()`/`jobstart` calls with tracebacks, plus an external process-tree watcher (Windows) |
| `neotree` | `status` · `exit` · `restart` · `backup-*` · `dryrun-*` · `queue-*` | Neo-tree safety bridge (opt-in, config-specific) |
| `health` | — | Run `:checkhealth debugging` |

## Command Reference

```
:Debug                          " overview of enabled categories
:Debug messages show            " open the :messages window
:Debug messages capture         " capture :messages to file + clipboard
:Debug noice errors             " show Noice errors
:Debug report buf               " buffer report
:Debug report win 1000          " window report for window 1000
:Debug autocmds runtime BufEnter *   " live autocmds for an event/pattern
:Debug autocmds sources event=BufWritePre sort=event   " static source audit
:Debug inspect buffer           " inspect current buffer options
:Debug cursor state             " cursor / window / buffer state
:Debug dump my_global           " dump a global var (or word under cursor)
:Debug keylogger start          " log keys in the current terminal buffer
:Debug indent treesitter false  " restore cindent/smartindent
:Debug markdown inline          " gather markdown inline-highlight debug
:Debug module reload            " reload Lua module of the current buffer
:Debug proc start 200           " start logging system()/jobstart calls ≥200ms
:Debug proc stop                " stop and restore the wrapped functions
:Debug proc log                 " open the log
:Debug proc watch 60            " (Windows) external process-tree watcher, 60s
:Debug neotree status           " Neo-tree quarantine status (opt-in)
:Debug health                   " run :checkhealth debugging
```

The `autocmds sources` audit accepts `event=`, `sort=` (`source`/`event`/`frequency`),
`impl=`, `summary=`, `freq=`, `root=`, and `refresh=` arguments. Results are
cached per `root` for a few seconds; pass `refresh=true` to force a rescan.

## Tab Completion

`:Debug` completes context-sensitively at every position:

```
:Debug <Tab>                       → messages noice report autocmds inspect …
:Debug report <Tab>                → buf tab win
:Debug autocmds <Tab>              → runtime sources
:Debug autocmds sources <Tab>      → event= sort= impl= summary= freq= root= refresh=
:Debug autocmds sources event=Buf<Tab>  → event=BufAdd event=BufEnter …
:Debug indent treesitter <Tab>     → true false
:Debug module <Tab>                → reload
:Debug proc <Tab>                  → start stop status log watch
```

## Health Check

```
:checkhealth debugging
```

Verifies Neovim version, the lib.nvim modules each feature relies on, clipboard
providers, optional Tree-sitter / Noice, write permissions, and the opt-in
Neo-tree bridge.
