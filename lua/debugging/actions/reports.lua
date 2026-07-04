---@module 'debugging.actions.reports'

local notify = require("lib.nvim.notify").create("[debugging.actions.reports]")

local buflib = require("lib.nvim.buf_win_tab.buffer_utils")
local winlib = require("lib.nvim.buf_win_tab.windows_utils")
local tablib = require("lib.nvim.buf_win_tab.tabs_utils")

local M = {}

---Print a buffer report to :messages.
---@return nil
function M.buf()
  buflib.print_summary()
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
