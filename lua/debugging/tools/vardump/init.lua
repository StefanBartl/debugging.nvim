---@module 'debugging.tools.vardump'
---@brief Recursively dump a global Lua variable to a report.
---@description
--- Usage: :Debug dump [varname]  -- dumps `varname`, or the word under the
--- cursor when no name is given.

local notify = require("lib.nvim.notify").create("[debugging.tools.vardump]")

local api = vim.api

local M = {}

-- Helper to get word under cursor
local function get_word_under_cursor()
    ---@diagnostic disable-next-line: deprecated
    local _, col = unpack(api.nvim_win_get_cursor(0))
    local line = api.nvim_get_current_line()
    local from, to = line:find("%w+", col + 1)
    if from and to then
        return line:sub(from, to)
    end
    return nil
end

---Dump a global Lua variable by name. With no name, uses the word under cursor.
---@param varname? string
---@return nil
function M.dump(varname)
    if not varname or varname == "" then
        varname = get_word_under_cursor()
        if not varname then
            notify.warn("No variable provided and no word under cursor")
            return
        end
    end

    local value = _G[varname]

    -- Delegates to lib.lua.dump, which this module's own recursive dumper
    -- was upstreamed into (with one bugfix versus the original: a
    -- metatable no longer replaces the value's own fields in the dump
    -- output, it's shown alongside them).
    local ok, result = pcall(require("lib.lua.dump").to_string, value)
    if not ok then
        notify.error(("failed to dump '%s': %s"):format(varname, tostring(result)))
        return
    end

    notify.info(("Variable '%s':\n%s"):format(varname, result))
end

return M
