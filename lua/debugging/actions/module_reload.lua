---@module 'debugging.actions.module_reload'
---@brief Reload the Lua module of the current buffer via :Debug module reload.

local notify = require("lib.nvim.notify").create("[debugging.module_reload]")

local M = {}

---Convert a buffer file path to its Lua module name.
---Walks vim.api.nvim_list_runtime_paths() looking for a lua/ prefix match;
---falls back to finding /lua/ anywhere in the path.
---@param filepath string  Absolute path to a .lua file
---@return string|nil module_name
---@return string|nil error_msg
local function path_to_module(filepath)
  filepath = vim.fn.fnamemodify(filepath, ":p")

  for _, rtp in ipairs(vim.api.nvim_list_runtime_paths()) do
    local lua_path = rtp .. "/lua/"
    if filepath:sub(1, #lua_path) == lua_path then
      local rel = filepath:sub(#lua_path + 1)
      rel = rel:gsub("%.lua$", ""):gsub("%.init$", ""):gsub("/", ".")
      return rel
    end
  end

  -- Fallback: find /lua/ segment anywhere in path
  local idx = filepath:find("/lua/")
  if not idx then
    -- Windows paths may use backslashes
    idx = filepath:find("\\lua\\")
  end
  if idx then
    local rel = filepath:sub(idx + 5)
    rel = rel:gsub("%.lua$", ""):gsub("%.init$", ""):gsub("[/\\]", ".")
    return rel
  end

  return nil, "file is not inside a lua/ directory"
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
