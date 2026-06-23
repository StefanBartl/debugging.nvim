---@module 'debugging.config.DEFAULTS'
---@brief Immutable default configuration for debugging.nvim.
---@description
--- Single source of truth. `config/init.lua` deep-merges user options over a copy
--- of this table; it is never mutated at runtime.

---@type Dbg.Config
local DEFAULTS = {
  -- Per-category enable flags. `all = true` activates everything.
  features = {
    views        = true,   -- :Debug messages / noice / windows
    reports      = true,   -- :Debug report buf|tab|win
    autocmds     = true,   -- :Debug autocmds runtime|sources
    tools        = true,   -- :Debug inspect|cursor|dump
    terminals    = true,   -- :Debug keylogger
    nvim_options = true,   -- :Debug indent
    markdown     = true,   -- :Debug markdown
    neotree      = false,  -- :Debug neotree … (config-specific, opt-in)
  },

  -- Views subsystem (keymaps, auto-refresh autocmds, capture).
  views = {
    keymaps  = { enable = true, prefix = "<lt>" },
    autocmds = { enable = true, group_name = "DebugViewsAuto", auto_refresh = true },
    timings  = { delay_messages_ms = 30, delay_noice_ms = 50, retry_delay_ms = 60, attempts = 3 },
    capture  = true,
    output_dir = nil,  -- defaults to stdpath("config")/docs/debug_views inside capture
  },

  command = "Debug",     -- name of the single unified user command
}

return DEFAULTS
