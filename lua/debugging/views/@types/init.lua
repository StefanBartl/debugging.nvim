---@meta
---@module 'debugging.views.@types'

-- #####################################################################
-- capture/init.lua

---@class Dbg.Views.CaptureOpts
---@field debug? boolean|nil       Emit extra diagnostics while capturing
---@field clipboard? boolean|nil   Copy the captured text to the clipboard
---@field save_file? boolean|nil   Also write the capture to disk
---@field output_dir? string|nil   Target directory when `save_file` is set

-- #####################################################################
-- recent.lua

---@class Dbg.Views.Recent
---@field window_s? integer   Seconds of history shown on open (default 10); <C-j> / + adds that much older history each time (quiet stretches are skipped)
---@field min_entries? integer  Show at least this many of the newest entries on open even if older than `window_s` (default 5; 0 = strictly `window_s`)
---@field order? "newest_last"|"newest_first"  Default "newest_last"
---@field collapsed_default? boolean  Start with first-line-only rendering

-- #####################################################################
-- init.lua

---@class Dbg.Views.Keymaps
---@field enable? boolean
---@field prefix? string  # default lhs prefix for every key below, e.g. "<leader>d"
---@field [string] string|string[]|false  # per-action override: an lhs, several, or false to drop it

return {}
