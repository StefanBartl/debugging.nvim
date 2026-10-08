---@module 'debugging.bindings.usercmds'
--- Registers the single `:Debug` user command, built via lib.nvim.bindings.usercmd.composer.
---
--- Command *logic* (dispatch + the feature-flag-gated category/action
--- registry) lives in `debugging.commands`; this module only builds a
--- composer route tree from that registry and wires up registration.
---
---@see debugging.commands  Dispatch side of the same split: owns the
--- category/action registry, `dispatch()` and `complete()`. Every route
--- built here ultimately calls its `dispatch()`.
---
--- Every route's `run` bypasses composer's bound ctx.args/ctx.pos and calls
--- the unmodified `commands.dispatch(ctx.raw.fargs)` (ctx.raw is the same
--- `.fargs`-shaped opts table the old `nvim_create_user_command` callback
--- received) -- the per-route `args` schema (`debugging.command_args`) exists
--- purely to drive <Tab> completion and the option float; dispatch/feature-
--- gating/error messages are unchanged.
---
--- Only categories enabled by the resolved config get a route, snapshotted
--- at setup() time. Tradeoff: typing a DISABLED category's exact name now
--- gets composer's generic "unknown subcommand" instead of the original's
--- "category %q is disabled (enable features.%s)" hint, since an
--- unregistered category has no route to carry that message through.

local composer = require("lib.nvim.bindings.usercmd.composer")

local M = {}

-- Dynamic completion for the two free-form autocmds sub-actions -- resolves
-- fresh each call since discovered autocmd sources can change.
composer.register_type("DBG_AUTOCMD_EXPR", {
  -- Shown for an argument of this type without a text of its own (`autocmds all`);
  -- `autocmds sources` words its own, with all of its keys.
  desc = "key=value options such as event= root= refresh=",
  validate = function(raw)
    return true, raw, nil
  end,
  complete = function(arg_lead)
    return require("debugging.autocmds.sources").complete(arg_lead)
  end,
})

---@internal
--- One-line text per route (`"<category> <action>"`), for the composer option float.
---@type table<string, string>
local descs = require("debugging.command_descs")

---@internal
--- The positional arguments per route, with the text of each for the option float. A route not listed there takes
--- no argument and gets no slot.
---@type table<string, Lib.UserCmd.Composer.ArgSpec[]>
local arg_specs = require("debugging.command_args")

---@internal
---The argument slots of a route: a copy of its entry in `command_args`, or nil when it takes none.
---@param key string  `"<category> <action>"`, or `"<category>"` for a free-form category
---@return Lib.UserCmd.Composer.ArgSpec[]|nil
local function args_of(key)
  return arg_specs[key] and vim.deepcopy(arg_specs[key]) or nil
end

---@internal
---Build one composer route per enabled category/action, all dispatching
--- through the unchanged commands.dispatch(ctx.raw.fargs).
---@param commands table  the `debugging.commands` module
---@return table[]
local function build_routes(commands)
  local dispatch_route = function(ctx)
    commands.dispatch(ctx.raw.fargs)
  end
  local routes = {}

  for category, entry in pairs(commands.registry()) do
    if commands.enabled(entry) then
      if entry.run.__default then
        -- Free-form categories (dump, health): :Debug {category}, no action
        routes[#routes + 1] = {
          path = { category },
          desc = descs[category],
          args = args_of(category),
          run = dispatch_route,
        }
      else
        for _, action in ipairs(entry.actions) do
          local key = category .. " " .. action
          routes[#routes + 1] = {
            path = { category, action },
            desc = descs[key],
            args = args_of(key),
            run = dispatch_route,
          }
        end
      end
    end
  end

  return routes
end

---Register the unified :Debug command for the resolved config.
---@param cfg Dbg.Config
---@return nil
function M.setup(cfg)
  local commands = require("debugging.commands")

  composer.verb(cfg.command, {
    desc = "Unified debugging entry point — :" .. cfg.command .. " {category} {action}",
    default = function()
      commands.dispatch({})
    end,
    routes = build_routes(commands),
  })
end

return M
