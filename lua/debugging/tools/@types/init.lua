---@meta
---@module 'debugging.tools.@types'

-- #####################################################################
-- proc_trace.lua

---What `:Debug proc start` parses out of its arguments, and hands straight to
---`lib.nvim.system.proc_trace.start`. An alias rather than a second class:
---LuaLS decides assignability by name, so a parallel class with the same
---fields could never be passed to the function it was written for.
---@alias Dbg.Tools.ProcTraceOpts Lib.System.ProcTrace.StartOptions

-- #####################################################################
--
-- The remaining tools (`buffer_inspector`, `cursor.state`, `vardump`)
-- deliberately declare no classes here: they take only primitives
-- (`integer?` handles, a `string` variable name) and render their findings
-- straight to a notify string, so there is no shared data model to name.

return {}
