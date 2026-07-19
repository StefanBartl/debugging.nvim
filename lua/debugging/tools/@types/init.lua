---@meta
---@module 'debugging.tools.@types'

-- #####################################################################
-- proc_trace.lua

---@class Dbg.Tools.ProcTraceOpts
---@field threshold_ms? integer Only log spawns that blocked at least this long

-- #####################################################################
--
-- The remaining tools (`buffer_inspector`, `cursor.state`, `vardump`)
-- deliberately declare no classes here: they take only primitives
-- (`integer?` handles, a `string` variable name) and render their findings
-- straight to a notify string, so there is no shared data model to name.

return {}
