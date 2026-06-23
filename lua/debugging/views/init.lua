---@module 'debugging.views'
---@brief Unified debug views: :messages / Noice with capture, display, windows.
---@description
--- setup() wires optional keymaps + auto-refresh autocmds. The actual actions are
--- exposed as functions and invoked by the central `:Debug` dispatcher; this
--- module no longer registers its own user commands.

require("debugging.views.@types")

local capture  = require("debugging.views.capture")
local display  = require("debugging.views.display")
local keymaps  = require("debugging.views.keymaps")
local autocmds = require("debugging.views.autocmds")

local M = {}

---@type Dbg.Views.Timings  Resolved timings, shared with the action functions.
local _timings = {
  delay_messages_ms = 30,
  delay_noice_ms = 50,
  retry_delay_ms = 60,
  attempts = 3,
}

---@param opts Dbg.Views.Modules|nil
function M.setup(opts)
  opts = opts or {}

  _timings = vim.tbl_extend("force", _timings, opts.timings or {})

  local km = vim.tbl_extend("force", {
    enable = true,
    map = (vim.keymap and vim.keymap.set) or function() end,
    prefix = "<lt>",
  }, opts.keymaps or {})

  local ac = vim.tbl_extend("force", {
    enable = true,
    group_name = "DebugViewsAuto",
    auto_refresh = true,
  }, opts.autocmds or {})

  if km.enable then
    keymaps.setup(km, _timings)
  end
  if ac.enable then
    autocmds.setup(ac, _timings)
  end

  if opts.capture and opts.output_dir then
    capture.base_dir = opts.output_dir
  end
end

-- Action functions (called by the :Debug dispatcher) ---------------------------

---Show the :messages window.
---@return nil
function M.messages_show()
  display.execute_and_refresh("messages", "messages", _timings)
end

---Capture :messages to file + clipboard.
---@return nil
function M.messages_capture()
  capture.capture_messages({ debug = false })
end

---Show all Noice messages.
---@return nil
function M.noice_all()
  display.execute_and_refresh("noice_all", "Noice all", _timings)
end

---Show Noice errors.
---@return nil
function M.noice_errors()
  vim.cmd("Noice errors")
end

---Close all debug windows.
---@return nil
function M.windows_clear()
  display.clear_all()
end

return M
