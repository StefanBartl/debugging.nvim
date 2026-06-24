---@meta
---@module 'debugging.types'
require("debugging.views.@types")

---@class Dbg.Autocmds.Modules
---@field all? boolean
---@field list_autocmds? boolean

---@class Dbg.Markdown.Modules
---@field all? boolean
---@field inline_debug_fixed? boolean

---@class Dbg.NvimOpts.Modules
---@field all? boolean
---@field indent_helpers boolean

---@class Dbg.Terminals.Modules
---@field all? boolean
---@field keylogger? boolean

---@class Dbg.Performance.Modules
---@field all? boolean
---@field startup_benchmark? boolean

---@class Dbg.Tools.Modules
---@field all? boolean
---@field buffer_inspector? boolean
---@field cursor_state? boolean
---@field vardump? boolean

---@class Dbg.Usercmds.Modules
---@field all? boolean
---@field neotree? boolean
---@field reports? boolean

---@class Dbg.Views.Modules
---@field keymaps? Dbg.Views.Keymaps
---@field autocmds? Dbg.Views.Autocmds
---@field timings? Dbg.Views.Timings
---@field capture? boolean
---@field output_dir? string # Only used if capture=true

---@class Dbg.Setup
---@field all? boolean
---@field autocmds? Dbg.Autocmds.Modules|nil
---@field markdown? Dbg.Markdown.Modules|nil
---@field terminals? Dbg.Terminals.Modules|nil
---@field views? Dbg.Views.Modules|nil
---@field usercmds? boolean|nil
---@field tools? Dbg.Tools.Modules|nil
---@field performance? Dbg.Performance.Modules|nil
---@field nvim_options? Dbg.NvimOpts.Modules|nil

-- #####################################################################
-- debugging.nvim config (unified :Debug surface)

---@class Dbg.Config.Features
--- Per-category enable flags for the :Debug command surface.
---@field views boolean          # :Debug messages / noice / windows
---@field reports boolean        # :Debug report buf|tab|win
---@field autocmds boolean       # :Debug autocmds runtime|sources
---@field tools boolean          # :Debug inspect|cursor|dump
---@field terminals boolean      # :Debug keylogger
---@field nvim_options boolean   # :Debug indent
---@field markdown boolean       # :Debug markdown
---@field module_reload boolean  # :Debug module reload
---@field neotree boolean        # :Debug neotree … (config-specific, opt-in)

---@class Dbg.Config
---@field features Dbg.Config.Features
---@field views Dbg.Views.Modules
---@field command string         # name of the unified user command (default "Debug")
---@field all? boolean           # shorthand: enable every feature category

return {}
