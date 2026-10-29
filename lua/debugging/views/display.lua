---@module 'debugging.views.display'
--- Find and close the debug log windows. Windows are identified solely by the
--- `custom_tag` window variable and looked up via find_window_by_tag() rather
--- than tracked in a module-level registry — a deliberate choice, since a
--- stale registry is exactly what once made clear_all() miss open windows.
---
--- `<m`/`<n`/`<e` (messages/all/errors) are `debugging.views.recent`'s live,
--- `lib.nvim.messages`-backed popup; it tags its window `recent_*` and closes
--- itself through the kit surface's own `nice_quit`. Nothing here re-runs a
--- command or refreshes a window any more.

local window_tag = require("lib.nvim.window").tag

local api = vim.api

local M = {}

---@type string[]  Known view tags, so `clear_all()` finds every window this
--- subsystem can open (the three `debugging.views.recent` popups).
local KNOWN_TAGS = { "recent_messages", "recent_all", "recent_errors" }

---Find the window currently showing the view tagged `tag`.
---@param tag string
---@return integer|nil
function M.find_window_by_tag(tag)
  return window_tag.find(tag)
end

---Clear all debug windows.
---@return nil
function M.clear_all()
  for _, tag in ipairs(KNOWN_TAGS) do
    local win = M.find_window_by_tag(tag)
    if win and api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end
end

return M
