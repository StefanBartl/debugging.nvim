---@module 'debugging.vardump'

-- Simple vardump utility that recursively prints Lua tables and values
-- Usage:
-- :VardumpVar some_var           -> dumps 'some_var'
-- :VardumpVar                    -> dumps variable under cursor

local api =vim.api

local M = {}

function M.Vardump(value, depth, key)
    local linePrefix = ""
    local spaces = ""
    if key ~= nil then
        linePrefix = "["..tostring(key).."] = "
    end
    if depth == nil then
        depth = 0
    else
        depth = depth + 1
        for _ = 1, depth do spaces = spaces .. "  " end
    end

    if type(value) == "table" then
        local mTable = getmetatable(value)
        if mTable == nil then
            print(spaces .. linePrefix .. "(table)")
        else
            print(spaces .. "(metatable)")
            value = mTable
        end
        for k, v in pairs(value) do
            M.Vardump(v, depth, k)
        end
    elseif type(value) == "function"
        or type(value) == "thread"
        or type(value) == "userdata"
        or value == nil
    then
        print(spaces .. tostring(value))
    else
        print(spaces .. linePrefix .. "(" .. type(value) .. ") " .. tostring(value))
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
            print("[debugging.tools.vardump] No variable provided and no word under cursor")
            return
        end
    end

    -- Try to get the global variable
    local success, value = pcall(function() return _G[varname] end)
    if not success then
        print(("[debugging.tools.vardump] Variable '%s' not found"):format(varname))
        return
    end

    print(("[debugging.tools.vardump] Variable '%s':"):format(varname))
    M.Vardump(value, 0)
end

return M
