---@module 'debugging.views'
---@brief Unified debug views: :messages / Noice with capture, display, windows.
---@description
--- setup() resolves timings + keymap/autocmd config for the views subsystem.
--- The actual keymaps/autocmds/which-key labels are wired by
--- `debugging.bindings` (see lua/debugging/bindings/); this module exposes
--- the resolved config via getters plus the plain action functions invoked
--- by the central `:Debug` dispatcher.

require("debugging.views.@types")

local capture = require("debugging.views.capture")
local display = require("debugging.views.display")

local M = {}

---@type Dbg.Views.Timings  Resolved timings, shared with the action functions.
local _timings = {
  delay_messages_ms = 30,
  delay_noice_ms = 50,
  retry_delay_ms = 60,
  attempts = 3,
}

---@type Dbg.Views.Keymaps
local _keymaps_cfg = { enable = true, prefix = "<lt>" }

---@type Dbg.Views.Autocmds
local _autocmds_cfg = { enable = true, group_name = "DebugViewsAuto", auto_refresh = true }

---@param opts Dbg.Views.Modules|nil
function M.setup(opts)
  opts = opts or {}

  _timings = vim.tbl_extend("force", _timings, opts.timings or {})

  _keymaps_cfg = vim.tbl_extend("force", {
    enable = true,
    map = (vim.keymap and vim.keymap.set) or function() end,
    prefix = "<lt>",
  }, opts.keymaps or {})

  _autocmds_cfg = vim.tbl_extend("force", {
    enable = true,
    group_name = "DebugViewsAuto",
    auto_refresh = true,
  }, opts.autocmds or {})

  if opts.capture and opts.output_dir then
    capture.base_dir = opts.output_dir
  end
end

---@return Dbg.Views.Timings
function M.get_timings()
  return _timings
end

---@return Dbg.Views.Keymaps
function M.get_keymaps_config()
  return _keymaps_cfg
end

---@return Dbg.Views.Autocmds
function M.get_autocmds_config()
  return _autocmds_cfg
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
