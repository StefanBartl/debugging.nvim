
---@module 'debugging.cursor.state'

local M = {}

---Print the current cursor / window / buffer state to :messages.
---@return nil
function M.print()
  local api = vim.api
  local current_win = api.nvim_get_current_win()

  print("=== Cursor Debug State ===")
  print("Current Win ID: " .. current_win)
  print("Win Valid: " .. tostring(api.nvim_win_is_valid(current_win)))

  local ok_buf, buf = pcall(api.nvim_win_get_buf, current_win)
  print("Buffer ID: " .. (ok_buf and buf or "ERROR"))

  if ok_buf and buf then
    print("Buf Valid: " .. tostring(api.nvim_buf_is_valid(buf)))
    print("Buf Lines: " .. api.nvim_buf_line_count(buf))
  end

  local ok_cursor, cursor = pcall(api.nvim_win_get_cursor, current_win)
  print("Cursor Pos: " .. (ok_cursor and vim.inspect(cursor) or "ERROR"))

  print("Mode: " .. api.nvim_get_mode().mode)
  print("Window Tag: " .. tostring(vim.w[current_win] and vim.w[current_win].custom_tag or "none"))

  -- Check all windows
  print("\n=== All Windows ===")
  for _, w in ipairs(api.nvim_list_wins()) do
    local tag = vim.w[w] and vim.w[w].custom_tag or "none"
    print(string.format("Win %d: tag=%s", w, tag))
  end
end

return M
