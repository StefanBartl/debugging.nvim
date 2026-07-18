# Diagnosing UI Freezes

`:Debug proc` answers "what exactly is blocking Neovim right now?" — for the
class of freeze caused by a slow or hung external process (a Git shell-out
down an unresponsive network share, an LSP tool waiting on a subprocess, a
plugin spawning far more processes than expected).

Two complementary layers:

1. **`proc start` / `stop` / `status` / `log`** — wraps `vim.fn.system`,
   `vim.fn.systemlist`, `vim.system`, and `vim.fn.jobstart` (via
   [`lib.nvim.system.proc_trace`](https://github.com/StefanBartl/lib.nvim/blob/main/lua/lib/nvim/system/README.md#libnvimsystemproc_trace))
   to log each call's duration, with a full Lua stack traceback for calls at
   or above a threshold (default 200ms) — so you see not just *that* something
   was slow, but *which plugin/config line* triggered it.
2. **`proc watch [seconds]`** (Windows only) — opens a terminal split running
   a bundled PowerShell script that polls the Win32 process tree and reports
   every child process of this Neovim instance with its start time and
   lifetime. This is the layer that catches what `proc_trace` structurally
   cannot: LSP-server subprocesses and any other spawn that never goes
   through `vim.fn.*`/`vim.system`.

Typical session:

```vim
:Debug proc start 200        " ideally as the very first thing after startup
" ... reproduce the freeze (open a file, trigger the slow action, ...) ...
:Debug proc stop
:Debug proc log              " inspect entries + tracebacks
```

Or, to see literally every child process regardless of how it was spawned:

```vim
:Debug proc watch 60
" ... reproduce the freeze in this same Neovim instance ...
" Ctrl+C in the terminal split once the freeze is over → sorted-by-lifetime summary
```

**Honest limits:** `proc_trace` only sees calls through the exact API tables
it wraps — a plugin that cached `local system = vim.fn.system` before
`proc start` ran bypasses it (start as early as possible, ideally the first
line of `init.lua`, to minimize this). `proc watch` has no bundled
equivalent on Linux/macOS; `pstree -p <nvim_pid>` or a `watch`-looped `ps`
covers the same ground there.
