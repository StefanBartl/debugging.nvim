---@module 'debugging.config'
--- Runtime configuration store for debugging.nvim.
---
--- Merges user options over the immutable DEFAULTS and exposes the active config
--- via `get()`. No global state — the active table is module-local.

local DEFAULTS = require("debugging.config.DEFAULTS")

local M = {}

---@type Dbg.Config|nil
local _active = nil

---What the last `setup()` had to ignore, for `:checkhealth`.
---@type string[]
local _issues = {}

---Keys `setup()` accepts and, for the option tables among them, their keys.
---`true` means any key goes; deeper structures (e.g. `terminals.keylogger`,
---`views.timings`) are accepted opaquely once their own table is known.
---@type table<string, true|table<string, true>>
local KNOWN = {
  features = {
    views = true,
    reports = true,
    autocmds = true,
    tools = true,
    terminals = true,
    nvim_options = true,
    markdown = true,
    neotree = true,
    module_reload = true,
    proc_trace = true,
    performance = true,
  },
  terminals = { keylogger = true },
  neotree = { quarantine = true, safety = true },
  views = { keymaps = true, autocmds = true, timings = true, capture = true, output_dir = true },
  command = true,
  overview = true,
  all = true, -- back-compat: bare `all = true` activates every feature category
}

---@internal
---`key` with the nearest known one as a hint when there is a plausible one.
---@param key any
---@param known table<string, any>
---@param prefix string
---@return string
local function describe_unknown(key, known, prefix)
  local levenshtein = require("lib.lua.strings.distance").levenshtein
  local name = tostring(key)
  local best, best_distance = nil, nil
  for candidate in pairs(known) do
    local d = levenshtein(name, candidate)
    if d <= 3 and (best_distance == nil or d < best_distance) then
      best, best_distance = candidate, d
    end
  end
  if best then
    return string.format("unknown option '%s%s' (did you mean '%s%s'?)", prefix, name, prefix, best)
  end
  return string.format("unknown option '%s%s'", prefix, name)
end

---@internal
---Drop what cannot be merged, and say so. A misspelled key would otherwise
---land in the active config as a dead field with the default still in
---force -- silently, since `tbl_deep_extend("force", ...)` accepts anything.
---@param user_opts table
---@return table clean  the accepted subset, nested option tables copied
---@return string[] issues
local function sanitize(user_opts)
  local clean, issues = {}, {}
  for key, value in pairs(user_opts) do
    local known = KNOWN[key]
    if known == nil then
      issues[#issues + 1] = describe_unknown(key, KNOWN, "")
    elseif type(DEFAULTS[key]) == "table" and type(value) ~= "table" then
      issues[#issues + 1] =
        string.format("option '%s' must be a table, got %s -- using the default", key, type(value))
    elseif type(known) == "table" then
      local nested = {}
      for sub_key, sub_value in pairs(value) do
        if known[sub_key] then
          nested[sub_key] = sub_value
        else
          issues[#issues + 1] = describe_unknown(sub_key, known, key .. ".")
        end
      end
      clean[key] = nested
    else
      clean[key] = value
    end
  end
  table.sort(issues)
  return clean, issues
end

---Merge user options over the defaults and store the result.
--- Back-compat: a bare `all = true` activates every feature category.
---
--- Unknown keys and mistyped option tables are reported once here and again
--- by `:checkhealth debugging` (see `issues()`); they never reach the merge.
---@param user_opts? Dbg.Config|table
---@return Dbg.Config
function M.setup(user_opts)
  if type(user_opts) ~= "table" then
    user_opts = {}
  end

  local clean, issues = sanitize(user_opts)
  _issues = issues
  if #issues > 0 then
    require("lib.nvim.notify")
      .create("[debugging]")
      .warn("ignored config: " .. table.concat(issues, "; "))
  end

  local merged = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), clean)

  if user_opts.all == true then
    for k in pairs(merged.features) do
      merged.features[k] = true
    end
  end

  _active = merged
  return _active
end

---Return the active config, initializing it from DEFAULTS if setup() hasn't run yet.
---@return Dbg.Config
function M.get()
  if _active == nil then
    _active = vim.deepcopy(DEFAULTS)
  end
  return _active
end

---What the last `setup()` ignored: unknown keys and option tables of the
---wrong type, one human-readable line each. Empty when everything was
---accepted.
---@return string[]
function M.issues()
  return vim.list_extend({}, _issues)
end

return M
