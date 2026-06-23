---@module 'debugging.tools.buffer_inspector'
---@brief Inspect buffer-scoped options and state for debugging.

local api = vim.api
local M = {}

---@type string[]  Buffer-scoped options to report (window/global opts excluded)
local BUF_OPTIONS = { "modifiable", "readonly", "buftype", "filetype", "buflisted", "modified" }

---Print buffer-scoped options + basic state to :messages.
---@param bufnr? integer
---@return nil
function M.inspect(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then
    print("[buffer_inspector] Invalid buffer")
    return
  end

  print(string.format("[buffer_inspector] Buffer %d state:", bufnr))
  print(string.format("  name      = %s", api.nvim_buf_get_name(bufnr)))
  print(string.format("  lines     = %d", api.nvim_buf_line_count(bufnr)))
  print(string.format("  loaded    = %s", tostring(api.nvim_buf_is_loaded(bufnr))))

  for _, name in ipairs(BUF_OPTIONS) do
    local ok, val = pcall(api.nvim_get_option_value, name, { buf = bufnr })
    if ok then
      print(string.format("  %-9s = %s", name, tostring(val)))
    end
  end
end

return M
