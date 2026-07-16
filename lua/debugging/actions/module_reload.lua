---@module 'debugging.actions.module_reload'
---@brief Reload the Lua module of the current buffer via :Debug module reload.

local notify = require("lib.nvim.notify").create("[debugging.module_reload]")
local get_module_path = require("lib.nvim.lua_ls.get_module_path")

local M = {}

---Convert a buffer file path to its Lua module name.
---@param filepath string  Absolute path to a .lua file
---@return string|nil module_name
---@return string|nil error_msg
local function path_to_module(filepath)
  filepath = vim.fn.fnamemodify(filepath, ":p")
  local module_name = get_module_path(filepath)
  if not module_name then
    return nil, "file is not inside a lua/ directory"
  end
  return module_name
end

---Clear caches and re-require a module by name.
---@param module_name string
---@return boolean ok
---@return any result_or_err
local function reload_module(module_name)
  package.loaded[module_name] = nil
  if vim.loader then
    local fp = vim.api.nvim_buf_get_name(0)
    pcall(vim.loader.reset, fp)
  end
  return pcall(require, module_name)
end

---Reload the Lua module that corresponds to the current buffer.
---Called by :Debug module reload.
---@return nil
function M.reload_current()
  local filepath = vim.api.nvim_buf_get_name(0)

  if not filepath:match("%.lua$") then
    notify.warn("Current buffer is not a Lua file")
    return
  end

  local module_name, err = path_to_module(filepath)
  if not module_name then
    notify.error("Could not determine module name: " .. (err or "unknown"))
    return
  end

  notify.info("Reloading: " .. module_name)

  local ok, result = reload_module(module_name)
  if ok then
    notify.info("✓ Reloaded: " .. module_name)
  else
    notify.error("✗ Error reloading " .. module_name .. ": " .. tostring(result))
  end
end

return M
