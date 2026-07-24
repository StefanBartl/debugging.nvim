---@module 'debugging.tools.cursor.state'
---@brief Print the current cursor / window / buffer state for debugging.
---@description
--- A one-shot snapshot of the active window/buffer/cursor plus a list of all
--- windows and their `custom_tag` (see `debugging.views.display`), invoked
--- via `:Debug cursor state`.

local notify = require("lib.nvim.notify").create("[debugging.tools.cursor.state]")
local window_tag = require("lib.nvim.window").tag

local M = {}

---Report the current cursor / window / buffer state.
---@return nil
function M.print()
  local api = vim.api
  local current_win = api.nvim_get_current_win()

  local lines = {
    "=== Cursor Debug State ===",
    "Current Win ID: " .. current_win,
    "Win Valid: " .. tostring(api.nvim_win_is_valid(current_win)),
  }

  local ok_buf, buf = pcall(api.nvim_win_get_buf, current_win)
  lines[#lines + 1] = "Buffer ID: " .. (ok_buf and buf or "ERROR")

  if ok_buf and buf then
    lines[#lines + 1] = "Buf Valid: " .. tostring(api.nvim_buf_is_valid(buf))
    lines[#lines + 1] = "Buf Lines: " .. api.nvim_buf_line_count(buf)
  end

  local ok_cursor, cursor = pcall(api.nvim_win_get_cursor, current_win)
  lines[#lines + 1] = "Cursor Pos: " .. (ok_cursor and vim.inspect(cursor) or "ERROR")

  lines[#lines + 1] = "Mode: " .. api.nvim_get_mode().mode
  lines[#lines + 1] = "Window Tag: " .. tostring(window_tag.get(current_win) or "none")

  lines[#lines + 1] = ""
  lines[#lines + 1] = "=== All Windows ==="
  for _, w in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(w) then
      lines[#lines + 1] = string.format("Win %d: tag=%s", w, window_tag.get(w) or "none")
    end
  end

  notify.info(table.concat(lines, "\n"))
end

return M
