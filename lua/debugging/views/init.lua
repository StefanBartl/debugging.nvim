---@module 'debugging.views'
--- Unified debug views: :messages / Noice with capture, display, windows.
---
--- setup() resolves timings + keymap/autocmd config for the views subsystem.
--- The actual keymaps/autocmds/which-key labels are wired by
--- `debugging.bindings` (see lua/debugging/bindings/); this module exposes
--- the resolved config via getters plus the plain action functions invoked
--- by the central `:Debug` dispatcher.

require("debugging.views.@types")

local notify = require("lib.nvim.notify").create("[debugging.views]")
local capture = require("debugging.views.capture")
local display = require("debugging.views.display")

local M = {}

---@type Dbg.Views.Timings
local DEFAULT_TIMINGS = {
  delay_messages_ms = 30,
  delay_noice_ms = 50,
  retry_delay_ms = 60,
  attempts = 3,
  -- How long to wait for the window a command opens (:messages, Noice) to
  -- actually appear. Too short on a slow machine and the view reports "no
  -- output" for a command that was merely still rendering -- which is why it
  -- belongs here with the other timings rather than in display.lua.
  capture_timeout_ms = 500,
}

---@type Dbg.Views.Recent
local DEFAULT_RECENT = {
  window_s = 10,
  order = "newest_last",
  collapsed_default = false,
}

---@type Dbg.Views.Timings  Resolved timings, shared with the action functions.
local _timings = vim.tbl_extend("force", {}, DEFAULT_TIMINGS)

---@type Dbg.Views.Keymaps
local _keymaps_cfg = { enable = true, prefix = "<lt>" }

---@type Dbg.Views.Autocmds
local _autocmds_cfg = { enable = true, group_name = "DebugViewsAuto", auto_refresh = true }

---@type Dbg.Views.Recent
local _recent_cfg = vim.tbl_extend("force", {}, DEFAULT_RECENT)

---Resolve timings + keymap/autocmd config for the views subsystem.
---@param opts Dbg.Views.Modules|nil
---@return nil
function M.setup(opts)
  opts = opts or {}

  -- Merge into a fresh copy of the defaults, not the live `_timings` table --
  -- otherwise a value only ever accumulates: a later setup({}) would leave
  -- whatever the previous call set instead of resetting it, unlike the two
  -- sibling assignments below.
  _timings = vim.tbl_extend("force", {}, DEFAULT_TIMINGS, opts.timings or {})

  _keymaps_cfg = vim.tbl_extend("force", {
    enable = true,
    prefix = "<lt>",
  }, opts.keymaps or {})

  _autocmds_cfg = vim.tbl_extend("force", {
    enable = true,
    group_name = "DebugViewsAuto",
    auto_refresh = true,
  }, opts.autocmds or {})

  _recent_cfg = vim.tbl_extend("force", {}, DEFAULT_RECENT, opts.recent or {})

  if opts.capture and opts.output_dir then
    capture.base_dir = opts.output_dir
  end
end

---Get the resolved timings config.
---@return Dbg.Views.Timings
function M.get_timings()
  return _timings
end

---Get the resolved keymaps config.
---@return Dbg.Views.Keymaps
function M.get_keymaps_config()
  return _keymaps_cfg
end

---Get the resolved autocmds config.
---@return Dbg.Views.Autocmds
function M.get_autocmds_config()
  return _autocmds_cfg
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
