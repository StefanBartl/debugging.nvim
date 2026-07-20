---@module 'debugging.bindings.usercmds'
---@brief Registers the single `:Debug` user command, built via
--- lib.nvim.usercmd.composer.
---@description
--- Command *logic* (dispatch + the feature-flag-gated category/action
--- registry) lives in `debugging.commands`; this module only builds a
--- composer route tree from that registry and wires up registration.
---
--- Every route's `run` bypasses composer's own bound ctx.args/ctx.pos and
--- calls the ORIGINAL, unmodified `commands.dispatch(ctx.raw.fargs)` (composer's
--- untouched nvim-callback opts table has the exact same `.fargs` shape the
--- old `nvim_create_user_command` callback received) -- so the declared
--- per-route `args` schema below exists purely to drive <Tab> completion;
--- dispatch/feature-gating/error messages are unchanged.
---
--- Only categories enabled by the resolved config get a route, snapshotted
--- at setup() time -- matching the original completion's own
--- enabled_categories() filtering (a disabled category no longer offers
--- <Tab> candidates). One accepted, minor tradeoff: dispatching a DISABLED
--- category by typing its exact name now gets composer's generic "unknown
--- subcommand" instead of the original's specific "category %q is disabled
--- (enable features.%s)" hint, since an unregistered category has no route
--- to carry that message through composer's own error path.

local composer = require("lib.nvim.usercmd.composer")

local M = {}

-- Dynamic completion for the two free-form autocmds sub-actions -- resolves
-- fresh each call since discovered autocmd sources can change.
composer.register_type("DBG_AUTOCMD_EXPR", {
  validate = function(raw) return true, raw, nil end,
  complete = function(arg_lead)
    return require("debugging.autocmds.sources").complete(arg_lead)
  end,
})

---Build one composer route per enabled category/action, all dispatching
--- through the unchanged commands.dispatch(ctx.raw.fargs).
---@param commands table  the `debugging.commands` module
---@return table[]
local function build_routes(commands)
  local dispatch_route = function(ctx) commands.dispatch(ctx.raw.fargs) end
  local routes = {}

  for category, entry in pairs(commands.registry()) do
    if commands.enabled(entry) then
      if entry.run.__default then
        -- Free-form categories (dump, health): :Debug {category} [arg]
        routes[#routes + 1] = {
          path = { category },
          args = { { name = "arg", type = "STRING", optional = true } },
          run = dispatch_route,
        }
      else
        for _, action in ipairs(entry.actions) do
          local args
          if category == "autocmds" and action == "runtime" then
            args = {
              { name = "event", type = "STRING", optional = true },
              { name = "pattern", type = "STRING", optional = true },
            }
          elseif category == "autocmds" and (action == "sources" or action == "all") then
            args = { { name = "expr", type = "DBG_AUTOCMD_EXPR", optional = true } }
          elseif category == "indent" and action == "treesitter" then
            args = { { name = "enable", type = "STRING", optional = true, values = { "true", "false" } } }
          else
            -- Covers zero-arg actions (extra token harmlessly falls into
            -- ctx.rest/dispatch re-parses it) and single-handle-id actions
            -- (report win, inspect buffer/window/tab, keylogger start,
            -- proc start/stop/status/log/watch, performance startup) --
            -- <Tab> completion beyond this one slot matches the original,
            -- which also offered nothing past the first arg for these.
            args = { { name = "arg", type = "STRING", optional = true } }
          end
          routes[#routes + 1] = {
            path = { category, action },
            args = args,
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
    default = function() commands.dispatch({}) end,
    routes = build_routes(commands),
  })
end

return M
