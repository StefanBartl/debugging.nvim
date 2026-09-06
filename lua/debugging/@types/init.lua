---@meta
---@module 'debugging.types'
require("debugging.views.@types")

---@class Dbg.Views.Modules
---@field keymaps? Dbg.Views.Keymaps
---@field autocmds? Dbg.Views.Autocmds
---@field timings? Dbg.Views.Timings
---@field capture? boolean
---@field output_dir? string # Only used if capture=true

-- #####################################################################
-- debugging.nvim config (unified :Debug surface)

---@class Dbg.Config.Features
--- Per-category enable flags for the :Debug command surface.
---@field views? boolean          # :Debug messages / noice / windows
---@field reports? boolean        # :Debug report buf|tab|win
---@field autocmds? boolean       # :Debug autocmds runtime|sources
---@field tools? boolean          # :Debug inspect|cursor|dump
---@field terminals? boolean      # :Debug keylogger
---@field nvim_options? boolean   # :Debug indent
---@field markdown? boolean       # :Debug markdown
---@field module_reload? boolean  # :Debug module reload
---@field neotree? boolean        # :Debug neotree … (config-specific, opt-in)
---@field proc_trace? boolean     # :Debug proc start|stop|status|log|watch
---@field performance? boolean    # :Debug performance startup

---@class Dbg.Config.Keylogger
---@field logfile? string        # append recorded keys here; nil = notify only

---@class Dbg.Config.Terminals
---@field keylogger Dbg.Config.Keylogger

---@class Dbg.Config.Neotree
--- Injectable Neo-tree bridge targets. Each is a module name to `require`,
--- or an already-loaded table used directly.
---@field quarantine string|table
---@field safety string|table

---@class Dbg.Config
---@field features? Dbg.Config.Features
---@field views? Dbg.Views.Modules
---@field terminals? Dbg.Config.Terminals
---@field neotree? Dbg.Config.Neotree
---@field command? string         # name of the unified user command (default "Debug")
---@field overview? "float"|"notify"  # how `:Debug` (no args) renders the overview
---@field all? boolean           # shorthand: enable every feature category

return {}
