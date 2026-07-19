---@module 'debugging.capture.clipboard'
---@brief Clipboard helper, delegating to lib.nvim.cross.copy_to_clipboard.
---@description
--- This module's own per-OS fallback chain (pbcopy/clip.exe/wl-copy/xclip/
--- xsel with has_exec pre-checks, plus a WSL absolute-path clip.exe
--- fallback) was more complete than lib.nvim's version at the time this was
--- written, so it was upstreamed into lib.nvim.cross.copy_to_clipboard
--- instead of being kept as a private duplicate (which also had a command-
--- injection bug in its Linux fallback, fixed in the same upstream change:
--- it built shell strings by concatenating the clipboard text directly).
--- The per-attempt debug notifications this module used to emit are
--- necessarily coarser now (one overall result instead of one per tool
--- tried), since the shared helper doesn't expose per-step hooks.

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
