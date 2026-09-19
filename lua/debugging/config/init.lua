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

---Keys `setup()` accepts, recursively. `true` means "leaf -- any value of the
---right shape goes"; a nested table names that option group's own accepted
---keys, walked to whatever depth the group actually has, so a typo inside a
---nested table (e.g. `views.timings.attempt`) is caught exactly like a
---top-level one instead of vanishing into the merge unexamined.
---
---`neotree.quarantine`/`neotree.safety` and `neotest.markers`/
---`neotest.package_frameworks` stay `true` (leaves) on purpose: the former
---are polymorphic (module-name string or an already-loaded table, per
---DEFAULTS' comment), the latter are plain string arrays -- neither is a
---named option group, so recursing into them would misread numeric array
---indices as unknown option keys.
---@type table<string, true|table<string, any>>
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
    neotest = true,
    module_reload = true,
    proc_trace = true,
    performance = true,
  },
  terminals = { keylogger = { logfile = true } },
  neotree = { quarantine = true, safety = true },
  neotest = { output = true, markers = true, package_frameworks = true },
  views = {
    keymaps = { enable = true, prefix = true },
    autocmds = { enable = true, group_name = true, auto_refresh = true },
    timings = {
      delay_messages_ms = true,
      delay_noice_ms = true,
      retry_delay_ms = true,
      attempts = true,
      capture_timeout_ms = true,
    },
    capture = true,
    output_dir = true,
  },
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
---Recursively drop what cannot be merged at this level, and say so, walking
---into nested option groups by their full dotted path. A misspelled key --
---at any depth -- would otherwise land in the active config as a dead field
---with the real default still in force, silently, since
---`tbl_deep_extend("force", ...)` accepts anything.
---@param user_tbl table  this level's user-supplied options
---@param known table<string, true|table>  this level's accepted keys (a KNOWN subtree)
---@param defaults table  this level's defaults, for nested "must be a table" checks
---@param prefix string  dotted path prefix for messages, e.g. "views." ("" at the root)
---@return table clean  the accepted subset, nested option tables copied
---@return string[] issues
local function sanitize_level(user_tbl, known, defaults, prefix)
  local clean, issues = {}, {}
  for key, value in pairs(user_tbl) do
    local known_entry = known[key]
    if known_entry == nil then
      issues[#issues + 1] = describe_unknown(key, known, prefix)
    elseif type(known_entry) == "table" then
      if type(value) ~= "table" then
        issues[#issues + 1] = string.format(
          "option '%s%s' must be a table, got %s -- using the default",
          prefix,
          key,
          type(value)
        )
      else
        local sub_defaults = type(defaults[key]) == "table" and defaults[key] or {}
        local nested, nested_issues =
          sanitize_level(value, known_entry, sub_defaults, prefix .. key .. ".")
        clean[key] = nested
        vim.list_extend(issues, nested_issues)
      end
    else
      clean[key] = value
    end
  end
  return clean, issues
end

---@internal
---Entry point for `sanitize_level()`: validates the whole user table against
---the root `KNOWN`/`DEFAULTS` trees and sorts the collected issues.
---@param user_opts table
---@return table clean
---@return string[] issues
local function sanitize(user_opts)
  local clean, issues = sanitize_level(user_opts, KNOWN, DEFAULTS, "")
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
