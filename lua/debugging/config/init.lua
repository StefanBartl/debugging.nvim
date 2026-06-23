---@module 'debugging.config'
---@brief Runtime configuration store for debugging.nvim.
---@description
--- Merges user options over the immutable DEFAULTS and exposes the active config
--- via `get()`. No global state — the active table is module-local.

local DEFAULTS = require("debugging.config.DEFAULTS")

local M = {}

---@type Dbg.Config|nil
local _active = nil

---Merge user options over the defaults and store the result.
--- Back-compat: a bare `all = true` activates every feature category.
---@param user_opts? Dbg.Config|table
---@return Dbg.Config
function M.setup(user_opts)
  if type(user_opts) ~= "table" then
    user_opts = {}
  end

  local merged = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), user_opts)

  if user_opts.all == true then
    for k in pairs(merged.features) do
      merged.features[k] = true
    end
  end

  _active = merged
  return _active
end

---@return Dbg.Config
function M.get()
  if _active == nil then
    _active = vim.deepcopy(DEFAULTS)
  end
  return _active
end

return M
