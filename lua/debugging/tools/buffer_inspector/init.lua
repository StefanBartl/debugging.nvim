---@module 'debugging.tools.buffer_inspector'
---@brief Inspect buffer / window / tab scoped options and state for debugging.
---@description
--- Backs `:Debug inspect buffer|window|tab`. Each inspector renders the
--- scope-relevant options plus a little basic state as a notify report.

local notify = require("lib.nvim.notify").create("[debugging.tools.buffer_inspector]")

local api = vim.api
local M = {}

---@type string[]  Buffer-scoped options to report (window/global opts excluded)
local BUF_OPTIONS = { "modifiable", "readonly", "buftype", "filetype", "buflisted", "modified" }

---@type string[]  Window-scoped options to report
local WIN_OPTIONS = {
  "number", "relativenumber", "wrap", "cursorline", "cursorcolumn",
  "list", "spell", "foldmethod", "foldenable", "signcolumn", "winfixwidth",
  "winfixheight",
}

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

---Report window-scoped options + basic state.
---@param winid? integer  Defaults to the current window.
---@return nil
function M.window(winid)
  winid = winid or api.nvim_get_current_win()
  if not api.nvim_win_is_valid(winid) then
    notify.error("Invalid window")
    return
  end

  local bufnr = api.nvim_win_get_buf(winid)
  local pos = api.nvim_win_get_position(winid)
  local cursor = api.nvim_win_get_cursor(winid)

  local lines = {
    string.format("Window %d state:", winid),
    string.format("  tabpage   = %s", tostring(api.nvim_win_get_tabpage(winid))),
    string.format("  buffer    = %d (%s)", bufnr, api.nvim_buf_get_name(bufnr)),
    string.format("  width     = %d", api.nvim_win_get_width(winid)),
    string.format("  height    = %d", api.nvim_win_get_height(winid)),
    string.format("  position  = row %d, col %d", pos[1], pos[2]),
    string.format("  cursor    = line %d, col %d", cursor[1], cursor[2]),
  }

  local cfg = api.nvim_win_get_config(winid)
  if cfg and cfg.relative and cfg.relative ~= "" then
    lines[#lines + 1] = string.format("  floating  = yes (relative=%s)", cfg.relative)
  end

  for _, name in ipairs(WIN_OPTIONS) do
    local ok, val = pcall(api.nvim_get_option_value, name, { win = winid })
    if ok then
      lines[#lines + 1] = string.format("  %-13s = %s", name, tostring(val))
    end
  end

  notify.info(table.concat(lines, "\n"))
end

---Report tabpage state: its windows and the buffers they show.
---@param tabnr? integer  Tab *number* (1-based, as shown in the tabline).
---                       Defaults to the current tabpage.
---@return nil
function M.tab(tabnr)
  local tabpage
  if tabnr == nil then
    tabpage = api.nvim_get_current_tabpage()
  else
    local tabs = api.nvim_list_tabpages()
    tabpage = tabs[tabnr]
    if not tabpage then
      notify.error(string.format("Invalid tab number %d (have %d tabpages)", tabnr, #tabs))
      return
    end
  end

  local wins = api.nvim_tabpage_list_wins(tabpage)
  local cur_win = api.nvim_tabpage_get_win(tabpage)

  local lines = {
    string.format("Tabpage %s state:", tostring(tabpage)),
    string.format("  number    = %d", api.nvim_tabpage_get_number(tabpage)),
    string.format("  windows   = %d", #wins),
    string.format("  current   = window %d", cur_win),
    "  layout:",
  }

  for _, win in ipairs(wins) do
    local bufnr = api.nvim_win_get_buf(win)
    local name = api.nvim_buf_get_name(bufnr)
    if name == "" then name = "[No Name]" end
    lines[#lines + 1] = string.format(
      "    win %-6d buf %-4d %s%s",
      win, bufnr, name, win == cur_win and "  <-- current" or ""
    )
  end

  notify.info(table.concat(lines, "\n"))
end

return M
