# UI-freeze diagnosis

`:Debug proc` answers "what exactly is blocking Neovim right now?" for the
class of freeze caused by a slow or hung external process — a Git shell-out
down an unresponsive network share, an LSP tool waiting on a subprocess, a
plugin spawning far more processes than expected.

Two complementary layers, because neither one alone sees the whole picture.
[troubleshooting.md](../troubleshooting.md) walks through a full session.

## In-process tracer (`proc start|stop|status|log`)

Wraps `vim.fn.system`, `vim.fn.systemlist`, `vim.system` and `vim.fn.jobstart`
via `lib.nvim.system.proc_trace`, logging each call's duration and, once it
crosses a threshold (default 200 ms), a full Lua stack traceback. The
traceback is the point: it names not just *that* something was slow but which
plugin or config line triggered it.

- **Module:** `tools/proc_trace.lua` (delegates to
  `lib.nvim.system.proc_trace`)
- **Config:** `opts.features.proc_trace`
- **Usercmds:** `:Debug proc start [threshold_ms]`, `:Debug proc stop`,
  `:Debug proc status`, `:Debug proc log`

## External process-tree watcher (`proc watch`, Windows)

Opens a terminal split running a bundled PowerShell script
(`scripts/watch-nvim-procs.ps1`) that polls the Win32 process tree and reports
every child process of this Neovim instance with its start time and lifetime,
sorted by lifetime once stopped. This is the layer that catches what the tracer
structurally cannot: LSP-server subprocesses and any other spawn that never
goes through `vim.fn.*` or `vim.system` at all.

- **Module:** `tools/proc_trace.lua` (drives `scripts/watch-nvim-procs.ps1`)
- **Usercmds:** `:Debug proc watch [seconds]`

## Honest limits

The tracer only sees calls through the exact API tables it wraps. A plugin that
did `local system = vim.fn.system` at its own load time, before `proc start`
ran, holds a reference to the original function and bypasses the tracer
entirely. There is no fix from inside `:Debug` — the habit that works is
starting the tracer as early as possible (ideally the first line of
`init.lua`), not reactively once a freeze is already suspected.

`proc watch` has no bundled equivalent on Linux or macOS; `pstree -p
<nvim_pid>`, or a `watch`-looped `ps`, covers the same ground there.
