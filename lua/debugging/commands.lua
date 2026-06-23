---@module 'debugging.commands'
---@brief The single unified :Debug command — dispatch + two-level completion.
---@description
--- `:Debug {category} {action} [args]`. Categories/actions are gated by the
--- active feature flags. Leaf logic lives in the submodules; this file only
--- routes to their exposed functions.

local notify = require("lib.nvim.notify").create("[debugging]")
local config = require("debugging.config")

local M = {}

---@alias Dbg.ActionFn fun(args: string[]): nil

-- Category -> { action -> fn }. Built lazily so leaf modules load on demand.
-- Each entry also carries an `actions` order list for completion.

---@return table<string, { feature: string, actions: string[], run: table<string, Dbg.ActionFn> }>
local function build_registry()
  return {
    messages = {
      feature = "views",
      actions = { "show", "capture", "clear" },
      run = {
        show    = function() require("debugging.views").messages_show() end,
        capture = function() require("debugging.views").messages_capture() end,
        clear   = function() require("debugging.views").windows_clear() end,
      },
    },
    noice = {
      feature = "views",
      actions = { "all", "errors" },
      run = {
        all    = function() require("debugging.views").noice_all() end,
        errors = function() require("debugging.views").noice_errors() end,
      },
    },
    report = {
      feature = "reports",
      actions = { "buf", "tab", "win" },
      run = {
        buf = function() require("debugging.usercmds.reports").buf() end,
        tab = function() require("debugging.usercmds.reports").tab() end,
        win = function(args)
          local id = args[1] and tonumber(args[1]) or nil
          require("debugging.usercmds.reports").win(id)
        end,
      },
    },
    autocmds = {
      feature = "autocmds",
      actions = { "runtime", "sources" },
      run = {
        runtime = function(args)
          require("debugging.autocmds.runtime").list(args[1], args[2])
        end,
        sources = function(args)
          require("debugging.autocmds.sources").run(table.concat(args, " "))
        end,
      },
    },
    inspect = {
      feature = "tools",
      actions = { "buffer" },
      run = {
        buffer = function(args)
          local b = args[1] and tonumber(args[1]) or nil
          require("debugging.tools.buffer_inspector").inspect(b)
        end,
      },
    },
    cursor = {
      feature = "tools",
      actions = { "state" },
      run = {
        state = function() require("debugging.tools.cursor.state").print() end,
      },
    },
    dump = {
      feature = "tools",
      actions = {},  -- free-form: :Debug dump [varname]
      run = {
        __default = function(args) require("debugging.tools.vardump").dump(args[1]) end,
      },
    },
    keylogger = {
      feature = "terminals",
      actions = { "start", "stop" },
      run = {
        start = function() require("debugging.terminals.keylogger").start() end,
        stop  = function() require("debugging.terminals.keylogger").stop() end,
      },
    },
    indent = {
      feature = "nvim_options",
      actions = { "show", "treesitter" },
      run = {
        show = function() require("debugging.nvim_options.indent_helpers").print_indent_options() end,
        treesitter = function(args)
          local enable = not (args[1] == "false" or args[1] == "0")
          require("debugging.nvim_options.indent_helpers").prefer_treesitter_indent(enable)
        end,
      },
    },
    markdown = {
      feature = "markdown",
      actions = { "inline", "log" },
      run = {
        inline = function()
          local ok, res = require("debugging.markdown.inline_debug").gather()
          if not ok then notify.error("markdown inline: " .. tostring(res)) end
        end,
        log = function() require("debugging.markdown.inline_debug").open_log() end,
      },
    },
    neotree = {
      feature = "neotree",
      actions = {
        "status", "exit", "restart",
        "backup-list", "backup-clean",
        "dryrun-toggle", "dryrun-report",
        "queue-status", "queue-clear",
      },
      run = {
        ["status"]        = function() require("debugging.usercmds.neotree_safety").quarantine_status() end,
        ["exit"]          = function() require("debugging.usercmds.neotree_safety").quarantine_exit() end,
        ["restart"]       = function() require("debugging.usercmds.neotree_safety").restart_watchers() end,
        ["backup-list"]   = function() require("debugging.usercmds.neotree_safety").backup_list() end,
        ["backup-clean"]  = function() require("debugging.usercmds.neotree_safety").backup_clean() end,
        ["dryrun-toggle"] = function() require("debugging.usercmds.neotree_safety").dryrun_toggle() end,
        ["dryrun-report"] = function() require("debugging.usercmds.neotree_safety").dryrun_report() end,
        ["queue-status"]  = function() require("debugging.usercmds.neotree_safety").queue_status() end,
        ["queue-clear"]   = function() require("debugging.usercmds.neotree_safety").queue_clear() end,
      },
    },
    health = {
      feature = "__always",
      actions = {},
      run = {
        __default = function() vim.cmd("checkhealth debugging") end,
      },
    },
  }
end

---@type table<string, any>|nil
local _registry = nil

---@return table
local function registry()
  if not _registry then _registry = build_registry() end
  return _registry
end

---Whether a category is enabled by the active feature flags.
---@param entry table
---@return boolean
local function enabled(entry)
  if entry.feature == "__always" then return true end
  return config.get().features[entry.feature] == true
end

---@return string[]  Enabled category names (stable order)
local function enabled_categories()
  local order = {
    "messages", "noice", "report", "autocmds", "inspect", "cursor",
    "dump", "keylogger", "indent", "markdown", "neotree", "health",
  }
  local out = {}
  local reg = registry()
  for _, name in ipairs(order) do
    if reg[name] and enabled(reg[name]) then
      out[#out + 1] = name
    end
  end
  return out
end

-- Dispatch --------------------------------------------------------------------

---Show a compact overview when :Debug is called with no arguments.
---@return nil
local function overview()
  local lines = { "debugging.nvim — :Debug {category} {action}", "" }
  local reg = registry()
  for _, cat in ipairs(enabled_categories()) do
    local acts = reg[cat].actions
    local suffix = (#acts > 0) and ("  [" .. table.concat(acts, "|") .. "]") or ""
    lines[#lines + 1] = string.format("  %-10s%s", cat, suffix)
  end
  notify.info(table.concat(lines, "\n"))
end

---@param fargs string[]
---@return nil
local function dispatch(fargs)
  if #fargs == 0 then
    overview()
    return
  end

  local category = fargs[1]:lower()
  local entry = registry()[category]
  if not entry then
    notify.error(("unknown category %q — try: %s"):format(category, table.concat(enabled_categories(), ", ")))
    return
  end
  if not enabled(entry) then
    notify.warn(("category %q is disabled (enable features.%s)"):format(category, entry.feature))
    return
  end

  local rest = vim.list_slice(fargs, 2)

  -- Free-form categories (dump, health) have a __default handler.
  if entry.run.__default then
    entry.run.__default(rest)
    return
  end

  local action = rest[1] and rest[1]:lower() or nil
  if not action then
    notify.error(("usage: :%s %s {%s}"):format(config.get().command, category, table.concat(entry.actions, "|")))
    return
  end

  local fn = entry.run[action]
  if not fn then
    notify.error(("unknown action %q for %q — try: %s"):format(action, category, table.concat(entry.actions, "|")))
    return
  end

  fn(vim.list_slice(rest, 2))
end

-- Completion ------------------------------------------------------------------

---@param list string[]
---@param lead string
---@return string[]
local function filter(list, lead)
  if lead == "" then return list end
  local out = {}
  for i = 1, #list do
    if list[i]:sub(1, #lead) == lead then out[#out + 1] = list[i] end
  end
  return out
end

---@param arglead string
---@param cmdline string
---@return string[]
local function complete(arglead, cmdline, _)
  local tokens = {}
  for t in cmdline:gmatch("%S+") do tokens[#tokens + 1] = t end
  local trailing = cmdline:sub(-1) == " "
  local committed = #tokens - (trailing and 0 or 1) - 1  -- minus command name

  if committed <= 0 then
    return filter(enabled_categories(), arglead)
  end

  local category = tokens[2] and tokens[2]:lower() or ""
  local entry = registry()[category]
  if not entry or not enabled(entry) then return {} end

  -- autocmds sources free-form args (event=/sort=/…)
  if category == "autocmds" and tokens[3] and tokens[3]:lower() == "sources" and committed >= 2 then
    return require("debugging.autocmds.sources").complete(arglead)
  end

  if committed == 1 then
    return filter(entry.actions, arglead)
  end

  -- indent treesitter true/false
  if category == "indent" and tokens[3] and tokens[3]:lower() == "treesitter" and committed == 2 then
    return filter({ "true", "false" }, arglead)
  end

  return {}
end

---Register the unified :Debug command.
---@param cfg Dbg.Config
---@return nil
function M.register(cfg)
  vim.api.nvim_create_user_command(cfg.command, function(a)
    dispatch(a.fargs)
  end, {
    nargs = "*",
    complete = complete,
    desc = "Unified debugging entry point — :" .. cfg.command .. " {category} {action}",
  })
end

return M
