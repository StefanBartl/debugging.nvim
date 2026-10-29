---@module 'debugging.views'
--- Unified debug views: :messages / Noice with capture, display, windows.
---
--- setup() resolves the keymap/recent/capture config for the views subsystem.
--- The actual keymaps are wired by
--- `debugging.bindings` (see lua/debugging/bindings/); this module exposes
--- the resolved config via getters plus the plain action functions invoked
--- by the central `:Debug` dispatcher.

require("debugging.views.@types")

local notify = require("lib.nvim.notify").create("[debugging.views]")
local capture = require("debugging.views.capture")
local display = require("debugging.views.display")

local M = {}

---@type Dbg.Views.Recent
local DEFAULT_RECENT = {
  window_s = 10,
  min_entries = 5,
  order = "newest_last",
  collapsed_default = false,
}

---@type Dbg.Views.Keymaps
local _keymaps_cfg = { enable = true, prefix = "<lt>" }

---@type Dbg.Views.Recent
local _recent_cfg = vim.tbl_extend("force", {}, DEFAULT_RECENT)

---Resolve the keymap/recent/capture config for the views subsystem.
---@param opts Dbg.Views.Modules|nil
---@return nil
function M.setup(opts)
  opts = opts or {}

  _keymaps_cfg = vim.tbl_extend("force", {
    enable = true,
    prefix = "<lt>",
  }, opts.keymaps or {})

  _recent_cfg = vim.tbl_extend("force", {}, DEFAULT_RECENT, opts.recent or {})

  if opts.capture and opts.output_dir then
    capture.base_dir = opts.output_dir
  end
end

---Get the resolved keymaps config.
---@return Dbg.Views.Keymaps
function M.get_keymaps_config()
  return _keymaps_cfg
end

---Get the resolved recent-messages-popup config.
---@return Dbg.Views.Recent
function M.get_recent_config()
  return _recent_cfg
end

-- Action functions (called by the :Debug dispatcher and the <m/n/e keymaps) ---

---Show the recent-messages popup, filtered to non-error entries. Replaces
---the old raw `:messages` dump -- backed by `lib.nvim.messages` + (when
---ui.nvim is installed) `ui.kit.message_log` now; see `debugging.views.recent`.
---@return nil
function M.messages_show()
  require("debugging.views.recent").show("non_error")
end

---Capture :messages to file + clipboard.
--- Notifies here — the top-level boundary for this dispatch path — from the
--- status `debugging.views.capture` returns.
---@return nil
function M.messages_capture()
  local ok, _, detail = capture.capture_messages({ debug = false })
  if ok then
    notify.info(detail)
  else
    notify.warn(detail)
  end
end

---Show the recent-messages popup, unfiltered. Replaces the old `:Noice all`
---dump -- see `M.messages_show`'s doc comment.
---@return nil
function M.noice_all()
  require("debugging.views.recent").show("all")
end

---Show the recent-messages popup, filtered to errors only. Replaces the old
---`:Noice errors` passthrough -- see `M.messages_show`'s doc comment.
---@return nil
function M.noice_errors()
  require("debugging.views.recent").show("error")
end

---Close all debug windows.
---@return nil
function M.windows_clear()
  display.clear_all()
end

return M
