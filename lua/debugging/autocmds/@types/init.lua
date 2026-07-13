---@meta
---@module 'debugging.autocmds.@types'

-- #####################################################################
-- sources.lua

---@class Dbg.Autocmds.SourceItem
---@field path string           Path of the file the autocmd was found in (relative to root)
---@field line integer          1-indexed line number of the nvim_create_autocmd call
---@field implementation string The full call-site text (from nvim_create_autocmd(... to the matching closing brace)
---@field events? string[]      Event names this call registers (only set on entries in `all`)

---@class Dbg.Autocmds.SourceOpts
---@field event string|nil       Filter to a single event, or nil for all
---@field sort "source"|"event"|"frequency"
---@field show_impl boolean      Include the call-site implementation text in the report
---@field show_summary boolean   Include the per-event count summary
---@field show_freq boolean      (reserved; frequency info is folded into `sort = "frequency"`)
---@field root string            Directory scanned for nvim_create_autocmd call sites
---@field refresh boolean        Force a rescan, bypassing the cache

---@class Dbg.Autocmds.SourceCache
---@field root string                                   Root the cached scan was run against
---@field scanned_at integer                             os.time() the scan completed
---@field by_event table<string, Dbg.Autocmds.SourceItem[]>
---@field all Dbg.Autocmds.SourceItem[]

return {}
