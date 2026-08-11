# Features

Every debugging tool this plugin ships is reached through one dispatcher,
`:Debug {category} {action} [args]`. Each entry below is one category —
what it shows, where it lives, and how to reach it. Categories are gated by
`config.features.*` (see `docs/configuration.md`); a disabled category simply
does not appear in `:Debug <Tab>`.

## Messages / Noice views

Auto-refreshing scratch windows for `:messages` and, when `noice.nvim` is
installed, its message history — plus a capture-to-file-and-clipboard action
for pasting into an issue or a chat.

- **Module:** `lua/debugging/views/` (`display`, `capture`)
- **Config:** `opts.features.views`, `opts.views.keymaps`, `opts.views.autocmds`, `opts.views.timings`, `opts.views.capture`, `opts.views.output_dir`
- **Keymaps:** `<lt>m`/`<lt>n`/`<lt>e`/`<lt>c`/`<lt>x` — see [BINDINGS.md#default-keymaps](BINDINGS.md#default-keymaps)
- **Usercmds:** `:Debug messages show|capture|clear`, `:Debug noice all|errors` — see [BINDINGS.md#user-commands](BINDINGS.md#user-commands)
- **Autocmds:** `WinEnter`/`BufWinEnter` auto-refresh, `FileType` close-window binding — see [BINDINGS.md#autocommands](BINDINGS.md#autocommands)

## Reports

Prints a snapshot of a buffer, window, or the current tab's window/buffer
layout straight to `:messages` — the fastest way to see scoped
options/state without opening an inspector window.

- **Module:** `lua/debugging/actions/reports.lua` (built on `lib.nvim.buf_win_tab.*`)
- **Config:** `opts.features.reports`
- **Usercmds:** `:Debug report buf|tab|win [id]`

## Autocmd inspection

Three related views on autocommands: a live `nvim_get_autocmds()` dump, a
static source-code audit of `nvim_create_autocmd` call sites across the
project, and a combined view that fuses the two — showing, per event, where
it is defined versus currently registered, and flagging events registered at
runtime with no source found (typically plugin-internal).

The static audit parses with the Lua Tree-sitter grammar when the parser is
available (robust against multi-line/nested calls) and falls back to a plain
text parser otherwise. Results are cached per project root for a few seconds
via `lib.nvim.cache.memory`.

- **Module:** `lua/debugging/autocmds/runtime.lua`, `lua/debugging/autocmds/sources.lua`
- **Config:** `opts.features.autocmds`
- **Usercmds:** `:Debug autocmds runtime [event] [pat]`, `:Debug autocmds sources [event=][sort=][impl=][summary=][freq=][root=][refresh=][qf=]`, `:Debug autocmds all [root=][refresh=][event=]`

## Inspect / cursor / dump

Buffer/window/tab option-and-state inspection, a cursor/window/buffer state
printer, and a recursive dumper for any global Lua value (or the word under
the cursor) — the everyday "what does Neovim think is going on here" trio.

- **Module:** `lua/debugging/tools/buffer_inspector/`, `lua/debugging/tools/cursor/state.lua`, `lua/debugging/tools/vardump/`
- **Config:** `opts.features.tools`
- **Usercmds:** `:Debug inspect buffer|window|tab [id]`, `:Debug cursor state`, `:Debug dump [varname]`

## Terminal keylogger

Logs keys pressed inside the current terminal buffer, optionally appending
them to a file for a session that outlives the current Neovim instance.

- **Module:** `lua/debugging/terminals/keylogger.lua`
- **Config:** `opts.features.terminals`, `opts.terminals.keylogger.logfile`
- **Usercmds:** `:Debug keylogger start [file]`, `:Debug keylogger stop`

## Indent diagnostics

Prints the current buffer's indentation-related options, and can force
Tree-sitter-driven indent on or restore `cindent`/`smartindent`.

- **Module:** `lua/debugging/nvim_options/indent_helpers.lua`
- **Config:** `opts.features.nvim_options`
- **Usercmds:** `:Debug indent show`, `:Debug indent treesitter [true|false]`

## Markdown inline-highlight debug

Gathers debug info for markdown inline highlighting (the extmarks/syntax
state behind rendered inline styling) and opens the most recent debug log.

- **Module:** `lua/debugging/markdown/inline_debug.lua`
- **Config:** `opts.features.markdown`
- **Usercmds:** `:Debug markdown inline`, `:Debug markdown log`

## Module reload

Reloads the Lua module backing the current buffer — `package.loaded` cache
eviction plus a fresh `require`, for iterating on a plugin's own source
without restarting Neovim.

- **Module:** `lua/debugging/actions/module_reload.lua`
- **Config:** `opts.features.module_reload`
- **Usercmds:** `:Debug module reload`

## UI-freeze diagnosis (`proc`)

- **Tab:** true

Answers "what exactly is blocking Neovim right now?" for freezes caused by a
slow or hung external process. Two complementary layers: an in-process
tracer that wraps `vim.fn.system`, `vim.fn.systemlist`, `vim.system`, and
`vim.fn.jobstart` (via `lib.nvim.system.proc_trace`) to log each call's
duration with a full Lua stack traceback once it crosses a threshold
(default 200ms); and, on Windows, an external process-tree watcher — a
bundled PowerShell script (`scripts/watch-nvim-procs.ps1`) that polls the
Win32 process tree and reports every child process of this Neovim instance,
catching spawns that never go through `vim.fn.*`/`vim.system` at all (LSP
server subprocesses, for example).

- **Module:** `lua/debugging/tools/proc_trace.lua` (delegates to `lib.nvim.system.proc_trace`; drives `scripts/watch-nvim-procs.ps1` for `proc watch`)
- **Config:** `opts.features.proc_trace`
- **Usercmds:** `:Debug proc start [threshold_ms]`, `:Debug proc stop`, `:Debug proc status`, `:Debug proc log`, `:Debug proc watch [seconds]`

### Honest limits

`proc_trace` only sees calls through the exact API tables it wraps — a
plugin that cached `local system = vim.fn.system` before `proc start` ran
bypasses it entirely, which is why the recommended habit is starting the
tracer as early as possible (ideally the first line of `init.lua`), not
reactively once a freeze is already suspected.

`proc watch` has no bundled equivalent on Linux/macOS — `pstree -p
<nvim_pid>` or a `watch`-looped `ps` covers the same ground there. See
[docs/troubleshooting.md](troubleshooting.md) for a full walkthrough.

## Startup benchmark

Spawns a headless Neovim under `--startuptime`, reports the total time
(optionally averaged over N runs) and lists the slowest sourced scripts —
for tracking whether a config or plugin change actually moved startup time,
rather than guessing from `:Debug proc` traces.

- **Module:** `lua/debugging/tools/startup.lua`
- **Config:** `opts.features.performance`
- **Usercmds:** `:Debug performance startup [runs]`

## Neo-tree safety bridge

Opt-in bridge to a user-specific Neo-tree watcher-quarantine and safety
layer: quarantine status/exit/restart, backup list/clean, dry-run
toggle/report, and queue status/clear. The two targets (`neotree.quarantine`,
`neotree.safety`) are injectable — a module name to `require`, or an
already-loaded table — so the bridge degrades gracefully with a clear
notification instead of erroring when the target config layer isn't present.
Disabled by default because it depends on config that lives outside this
plugin.

- **Module:** `lua/debugging/actions/neotree_safety.lua`
- **Config:** `opts.features.neotree` (default `false`), `opts.neotree.quarantine`, `opts.neotree.safety`
- **Usercmds:** `:Debug neotree status|exit|restart|backup-list|backup-clean|dryrun-toggle|dryrun-report|queue-status|queue-clear`

## Unified `:Debug` command and tab completion

- **Tab:** true

Every feature above is reached through one user command,
`:Debug {category} {action} [args]`, built via
[`lib.nvim.usercmd.composer`](https://github.com/StefanBartl/lib.nvim) with
two-level, context-sensitive tab completion. Only categories enabled by the
active config appear in completion — `neotree`, for instance, stays out of
`:Debug <Tab>` until `features.neotree = true` is set, so the command surface
always matches what is actually usable, not a static list of everything this
plugin could ever do. Running `:Debug` with no arguments renders a scrollable
floating-window overview of enabled categories (`overview = "notify"`
switches this to a plain notification instead).

### `autocmds sources`'s extra completion

`:Debug autocmds sources <Tab>` completes its own keyword arguments
(`event=`, `sort=`, `impl=`, `summary=`, `freq=`, `root=`, `refresh=`,
`qf=`), and `event=` itself completes against real event names once typed
far enough (`event=Buf<Tab>` → `event=BufAdd event=BufEnter …`) — the
completion logic lives in `lua/debugging/commands.lua`, separate from the
registration in `lua/debugging/bindings/usercmds.lua`.

## Health check

`:checkhealth debugging` verifies the Neovim version, the lib.nvim modules
each enabled feature relies on, clipboard providers (for `messages
capture`), optional Tree-sitter/Noice, write permissions for capture/keylog
output, and the opt-in Neo-tree bridge's resolvability.

- **Module:** `lua/debugging/health.lua`
- **Usercmds:** `:Debug health` (also reachable directly as `:checkhealth debugging`)
