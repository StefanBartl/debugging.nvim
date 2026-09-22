---@module 'debugging.actions.reports'
--- `:Debug report buf|tab|win` — snapshot reports of the editor state.
---
--- Thin formatting layer over `lib.nvim.buf_win_tab.*`: collects the current
--- buffer / tabpage / window properties and renders them as a notify report.
--- `win` takes an optional window id and defaults to reporting every window.

local notify = require("lib.nvim.notify").create("[debugging.actions.reports]")

local buflib = require("lib.nvim.buf_win_tab.buffer_utils")
local winlib = require("lib.nvim.buf_win_tab.windows_utils")
local tablib = require("lib.nvim.buf_win_tab.tabs_utils")

local M = {}

---@internal
---Whether the current buffer still has unresolved merge-conflict markers
---(gitsuite.nvim, optional) -- explains otherwise confusing symptoms (wrong
---syntax highlighting, LSP errors) that a buffer report should surface.
---@param bufnr integer
---@return boolean has  false when gitsuite.nvim is not installed or errors.
local function has_conflicts(bufnr)
  local ok, conflict = pcall(require, "gitsuite.features.conflict")
  if not ok then
    return false
  end
  local ok_call, result = pcall(conflict.has_conflicts, bufnr)
  return ok_call and result == true
end

---Print a buffer report to :messages.
---@return nil
function M.buf()
  buflib.print_summary()
  if has_conflicts(vim.api.nvim_get_current_buf()) then
    notify.warn("current buffer has unresolved merge-conflict markers")
  end
end

---Print a tab report to :messages.
---@return nil
function M.tab()
  local r = tablib.collect_report()
  for _, l in ipairs(r.textual) do
    notify.info(l)
  end
end

---Print a window report to :messages. Optional explicit window id.
---@param winid? integer
---@return nil
function M.win(winid)
  if winid ~= nil and not vim.api.nvim_win_is_valid(winid) then
    notify.error("Invalid window ID: " .. tostring(winid))
    return
  end
  local r = winlib.collect_win_report(winid)
  for _, l in ipairs(r.textual) do
    notify.info(l)
  end
end

return M
