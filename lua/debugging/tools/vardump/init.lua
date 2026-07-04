---@module 'debugging.tools.vardump'
---@brief Recursively dump a global Lua variable to a report.
---@description
--- Usage: :Debug dump [varname]  -- dumps `varname`, or the word under the
--- cursor when no name is given.

local notify = require("lib.nvim.notify").create("[debugging.tools.vardump]")

local api = vim.api

local M = {}

---@type integer  Hard recursion-depth limit against cyclic tables/huge structures.
local MAX_DEPTH = 30

---@param value any
---@param depth integer|nil
---@param key any
---@param lines string[]
---@return nil
local function dump_value(value, depth, key, lines)
    local line_prefix = ""
    local spaces = ""
    if key ~= nil then
        line_prefix = "["..tostring(key).."] = "
    end
    if depth == nil then
        depth = 0
    else
        depth = depth + 1
        for _ = 1, depth do spaces = spaces .. "  " end
    end

    if depth > MAX_DEPTH then
        lines[#lines + 1] = spaces .. line_prefix .. "<max depth reached>"
        return
    end

    if type(value) == "table" then
        local mTable = getmetatable(value)
        if mTable == nil then
            lines[#lines + 1] = spaces .. line_prefix .. "(table)"
        else
            lines[#lines + 1] = spaces .. "(metatable)"
            value = mTable
        end
        for k, v in pairs(value) do
            dump_value(v, depth, k, lines)
        end
    elseif type(value) == "function"
        or type(value) == "thread"
        or type(value) == "userdata"
        or value == nil
    then
        lines[#lines + 1] = spaces .. tostring(value)
    else
        lines[#lines + 1] = spaces .. line_prefix .. "(" .. type(value) .. ") " .. tostring(value)
    end
end

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

    local lines = { ("Variable '%s':"):format(varname) }
    local ok, err = pcall(dump_value, value, 0, nil, lines)
    if not ok then
        notify.error(("failed to dump '%s': %s"):format(varname, tostring(err)))
        return
    end

    notify.info(table.concat(lines, "\n"))
end

return M
