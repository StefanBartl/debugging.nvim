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
-- display.lua

---@class Dbg.Views.DisplayOpts
---@field tag? string                 Window tag used to find/reuse the view
---@field cmd? string                 Command whose output is displayed
---@field attempts? integer|nil       Retries before giving up on the source
---@field retry_delay_ms? integer|nil Delay between those retries
---@field auto_bottom? boolean|nil    Keep the cursor pinned to the last line

---@class Dbg.Views.WindowRegistry
---@field messages? integer|nil      Window id of the :messages view
---@field noice_all? integer|nil     Window id of the Noice "all" view
---@field noice_errors? integer|nil  Window id of the Noice error view

-- #####################################################################
-- init.lua

---@class Dbg.Views.Keymaps
---@field enable? boolean
---@field prefix? string  # default lhs prefix for every key below, e.g. "<leader>d"
---@field [string] string|string[]|false  # per-action override: an lhs, several, or false to drop it

---@class Dbg.Views.Autocmds
---@field enable? boolean
---@field group_name? string
---@field auto_refresh? boolean

-- #####################################################################
-- display.lua + init.lua (shared timing budget)

---@class Dbg.Views.Timings
---@field delay_messages_ms? integer  Wait before reading :messages output
---@field delay_noice_ms? integer     Wait before reading Noice output
---@field retry_delay_ms? integer     Delay between retries
---@field attempts? integer           Retry count

return {}
