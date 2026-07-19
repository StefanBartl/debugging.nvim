---@module 'debugging.tools.proc_trace'
---@brief `:Debug proc {start|stop|status|log|watch}` — diagnose UI freezes.
---@description
--- Thin command-surface layer over `lib.nvim.system.proc_trace` (which does
--- the actual instrumentation of vim.fn.system/systemlist, vim.system, and
--- vim.fn.jobstart). This module adds the pieces that are genuinely
--- debugging.nvim's job: opening the resulting log in a buffer, and driving
--- a bundled external process-watcher script for the blind spots
--- `proc_trace` cannot see (LSP clients and other C-internal spawns never go
--- through the wrapped Lua APIs).
---
--- `start`/`stop` only make sense called early — ideally the very first line
--- of init.lua, before any plugin can cache a local reference to the
--- functions being wrapped. Starting late (e.g. after `:Debug proc start`
--- once Neovim is already up) still catches everything that spawns AFTER
--- that point, which is enough for freezes that happen on a later action
--- (opening a file, an LSP attach, ...) rather than at startup itself.

require("debugging.tools.@types")

local notify = require("lib.nvim.notify").create("[debugging.tools.proc_trace]")

local M = {}

---@param args string[]?
---@return Dbg.Tools.ProcTraceOpts|nil
local function parse_start_args(args)
  if not args or not args[1] then
    return nil
  end
  local threshold = tonumber(args[1])
  if not threshold then
    notify.warn(("ignoring non-numeric threshold_ms: %q"):format(args[1]))
    return nil
  end
  return { threshold_ms = threshold }
end

---Start instrumentation. `:Debug proc start [threshold_ms]`.
---@param args string[]
---@return nil
function M.start(args)
  local ok, trace = pcall(require, "lib.nvim.system.proc_trace")
  if not ok then
    notify.error("lib.nvim.system.proc_trace not available: " .. tostring(trace))
    return
  end
  local opts = parse_start_args(args)
  local result = trace.start(opts)
  notify.info(("tracing active → %s"):format(result.path))
end

---Stop instrumentation. `:Debug proc stop`.
---@return nil
function M.stop()
  local ok, trace = pcall(require, "lib.nvim.system.proc_trace")
  if not ok then
    notify.error("lib.nvim.system.proc_trace not available: " .. tostring(trace))
    return
  end
  local result = trace.stop()
  notify.info(("stopped (log: %s)"):format(tostring(result.path)))
end

---Print whether tracing is active and the current log path.
---`:Debug proc status`.
---@return nil
function M.status()
  local ok, trace = pcall(require, "lib.nvim.system.proc_trace")
  if not ok then
    notify.error("lib.nvim.system.proc_trace not available: " .. tostring(trace))
    return
  end
  notify.info(("active=%s  log=%s"):format(tostring(trace.is_active()), tostring(trace.log_path())))
end

---Open the proc_trace log in a scratch tab. `:Debug proc log`.
---@return nil
function M.open_log()
  local ok, trace = pcall(require, "lib.nvim.system.proc_trace")
  if not ok then
    notify.error("lib.nvim.system.proc_trace not available: " .. tostring(trace))
    return
  end
  local path = trace.log_path()
  if not path or vim.fn.filereadable(path) == 0 then
    notify.warn("no proc_trace log yet — run `:Debug proc start` first")
    return
  end
  vim.cmd("tabnew")
  vim.cmd("silent edit " .. vim.fn.fnameescape(path))
  vim.bo.bufhidden = "wipe"
end

--- Locate the bundled PowerShell process-watcher script on the runtimepath.
---@return string|nil
local function find_watch_script()
  local hits = vim.api.nvim_get_runtime_file("scripts/watch-nvim-procs.ps1", false)
  return hits[1]
end

---Open a terminal split running the bundled external process watcher.
---`:Debug proc watch [seconds]`. Windows-only: the script inspects the
---Win32 process tree via CIM, which has no equivalent this plugin bundles
---for other platforms. On Linux/macOS, `pstree`/`ps` from a regular terminal
---cover the same ground well enough that a bundled script isn't worth it.
---@param args string[]
---@return nil
function M.watch(args)
  if vim.fn.has("win32") ~= 1 then
    notify.warn("`:Debug proc watch` bundles a Windows-only script (Win32 CIM process tree). "
      .. "On this platform, use `pstree -p <nvim_pid>` or `watch -n0.2 'pgrep -P <nvim_pid>'` instead.")
    return
  end

  local script = find_watch_script()
  if not script then
    notify.error("scripts/watch-nvim-procs.ps1 not found on the runtimepath")
    return
  end

  local seconds = args and args[1] and tonumber(args[1]) or 120
  local shell_exe = vim.fn.executable("pwsh") == 1 and "pwsh" or "powershell"

  vim.cmd("botright split")
  vim.fn.termopen({
    shell_exe, "-NoLogo", "-NoProfile", "-File", script,
    "-Seconds", tostring(seconds),
  })
  vim.cmd("startinsert")
  notify.info(("watching child processes for %ds — reproduce the freeze now"):format(seconds))
end

return M
