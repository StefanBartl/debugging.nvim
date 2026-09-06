---@module 'debugging.views.capture.clipboard'
--- Clipboard helper, delegating to lib.nvim.cross.copy_to_clipboard.
---
--- This module's own per-OS fallback chain (pbcopy/clip.exe/wl-copy/xclip/
--- xsel, plus a WSL clip.exe path and a command-injection fix) was
--- upstreamed into lib.nvim.cross.copy_to_clipboard rather than kept as a
--- private duplicate. Debug notifications are coarser now (one overall
--- result instead of one per tool tried) since the shared helper doesn't
--- expose per-step hooks.

local notify = require("lib.nvim.notify").create("[debugging.views.capture.clipboard]")
local copy_to_clipboard = require("lib.nvim.cross.copy_to_clipboard")

---@param text string
---@param debug boolean
---@return boolean
return function(text, debug)
  local ok = copy_to_clipboard(text)
  if debug then
    notify.debug(ok and "clipboard write ok" or "clipboard write failed (no provider available)")
  end
  return ok
end
