---@module 'debugging.tools.startup'
---@brief `:Debug performance startup [runs]` — startup-time benchmark.
---@description
--- Spawns a fresh headless Neovim with your real config under `--startuptime`,
--- parses the resulting log, and reports the total startup time plus the
--- slowest sourced scripts (the practical "what is loading at startup / which
--- lazy-loads actually fire" overview). Pass a run count to average the total
--- over several launches, smoothing out cold-cache noise.
---
--- Each measurement runs in its own subprocess and quits immediately, so it
--- has no effect on the current session.

local notify = require("lib.nvim.notify").create("[debugging.tools.startup]")

local M = {}

---@class Dbg.Tools.StartupEntry
---@field self_ms number   Self time spent sourcing this script (msec)
---@field clock number     Absolute clock at this line (msec)
---@field event string     The sourced script / event label

---Parse a `--startuptime` log into a total and per-script self-times.
---@param lines string[]
---@return number total_ms
---@return Dbg.Tools.StartupEntry[] entries  Sourced-script lines (3 columns)
function M.parse(lines)
  local total, max_clock = 0, 0
  local entries = {}
  for _, line in ipairs(lines) do
    local numstr, event = line:match("^%s*([%d%.%s]+):%s*(.+)$")
    if numstr and event then
      local vals = {}
      for n in numstr:gmatch("[%d%.]+") do
        vals[#vals + 1] = tonumber(n)
      end
      if #vals >= 1 then
        local clock = vals[1]
        if clock > max_clock then max_clock = clock end
        if event:match("NVIM STARTED") then
          total = clock
        end
        -- Three-column lines are "sourcing <script>": clock, self+sourced, self.
        if #vals >= 3 then
          entries[#entries + 1] = { self_ms = vals[3], clock = clock, event = event }
        end
      end
    end
  end
  if total == 0 then
    total = max_clock
  end
  table.sort(entries, function(a, b) return a.self_ms > b.self_ms end)
  return total, entries
end

---Run one headless launch under --startuptime and return its parsed result.
---@return number? total_ms
---@return Dbg.Tools.StartupEntry[]? entries
---@return string? err
local function measure_once()
  local prog = vim.v.progpath
  if not prog or prog == "" then
    return nil, nil, "cannot locate the Neovim binary (vim.v.progpath is empty)"
  end
  local log = vim.fn.tempname()
  local out = vim.fn.system({ prog, "--headless", "--startuptime", log, "-c", "qa!" })
  if vim.v.shell_error ~= 0 and vim.fn.filereadable(log) == 0 then
    return nil, nil, ("nvim exited %d: %s"):format(vim.v.shell_error, tostring(out))
  end
  if vim.fn.filereadable(log) == 0 then
    return nil, nil, "no startuptime log was produced"
  end
  local lines = vim.fn.readfile(log)
  vim.fn.delete(log)
  local total, entries = M.parse(lines)
  return total, entries
end

---`:Debug performance startup [runs]`. Benchmark startup time and show a report.
---@param args string[]
---@return nil
function M.startup(args)
  local runs = tonumber(args and args[1]) or 1
  runs = math.max(1, math.min(math.floor(runs), 20))

  local totals = {}
  local last_entries
  for _ = 1, runs do
    local total, entries, err = measure_once()
    if not total then
      notify.error(err or "startup benchmark failed")
      return
    end
    totals[#totals + 1] = total
    last_entries = entries
  end

  local sum, min, max = 0, math.huge, 0
  for _, t in ipairs(totals) do
    sum = sum + t
    min = math.min(min, t)
    max = math.max(max, t)
  end
  local avg = sum / #totals

  local lines = {
    "=== Startup Benchmark ===",
    "",
    "Neovim: " .. vim.v.progpath,
    string.format("Runs: %d", runs),
    string.format("Total startup: avg %.1f ms (min %.1f, max %.1f)", avg, min, max),
    "",
    "--- Slowest sourced scripts (self time, last run) ---",
    "",
  }
  local shown = math.min(#(last_entries or {}), 15)
  if shown == 0 then
    lines[#lines + 1] = "(no per-script timings in the log)"
  end
  for i = 1, shown do
    local e = last_entries[i]
    lines[#lines + 1] = string.format("  %6.1f ms  %s", e.self_ms, e.event)
  end

  vim.cmd("new")
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.filetype = "startup-benchmark"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.modifiable = false
end

return M
