---@module 'debugging.tools.buffer_inspector'
---@brief Inspect buffer-scoped options and state for debugging.

local notify = require("lib.nvim.notify").create("[debugging.tools.buffer_inspector]")

local api = vim.api
local M = {}

---@type string[]  Buffer-scoped options to report (window/global opts excluded)
local BUF_OPTIONS = { "modifiable", "readonly", "buftype", "filetype", "buflisted", "modified" }

---Report buffer-scoped options + basic state.
---@param bufnr? integer
---@return nil
function M.inspect(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then
    notify.error("Invalid buffer")
    return
  end

  local lines = {
    string.format("Buffer %d state:", bufnr),
    string.format("  name      = %s", api.nvim_buf_get_name(bufnr)),
    string.format("  lines     = %d", api.nvim_buf_line_count(bufnr)),
    string.format("  loaded    = %s", tostring(api.nvim_buf_is_loaded(bufnr))),
  }

  for _, name in ipairs(BUF_OPTIONS) do
    local ok, val = pcall(api.nvim_get_option_value, name, { buf = bufnr })
    if ok then
      lines[#lines + 1] = string.format("  %-9s = %s", name, tostring(val))
    end
  end

  notify.info(table.concat(lines, "\n"))
end

return M
