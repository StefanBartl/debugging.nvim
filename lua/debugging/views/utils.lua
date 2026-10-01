---@module 'debugging.views.utils'
--- Debug-view-specific window helpers.
---
--- The generic focus/scroll primitives this module used to carry its own
--- copy of (ensure_bottom, make_focusable, force_focus, reveal_at_bottom)
--- moved to `lib.nvim.window.focus_helpers` -- call that directly. This
--- file now only keeps what's genuinely specific to this plugin's own
--- views: identifying a debug-owned buffer by filetype.

local api = vim.api
local M = {}

---Identify messages/noice buffers by filetype
---@param buf integer
---@return boolean
function M.is_target_view(buf)
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return false
  end
  local ok_ft, ft = pcall(function()
    return vim.bo[buf].filetype
  end)
  if not ok_ft then
    return false
  end
  if ft == "messages" then
    return true
  end
  if ft == "noice" then
    local ok_bt, bt = pcall(function()
      return vim.bo[buf].buftype
    end)
    return ok_bt and (bt == "nofile" or bt == "")
  end
  return false
end

return M
