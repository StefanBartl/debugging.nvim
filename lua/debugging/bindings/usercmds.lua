---@module 'debugging.bindings.usercmds'
--- Registers the single `:Debug` user command, built via lib.nvim.usercmd.composer.
---
--- Command *logic* (dispatch + the feature-flag-gated category/action
--- registry) lives in `debugging.commands`; this module only builds a
--- composer route tree from that registry and wires up registration.
---
---@see debugging.commands  Dispatch side of the same split: owns the
--- category/action registry, `dispatch()` and `complete()`. Every route
--- built here ultimately calls its `dispatch()`.
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
  validate = function(raw)
    return true, raw, nil
  end,
  complete = function(arg_lead)
    return require("debugging.autocmds.sources").complete(arg_lead)
  end,
})

---@internal
---Actions whose single argument is a concrete handle or path, and the
---composer argtype that knows how to complete it.
---
--- Everything else keeps the generic `STRING` slot: `proc` ids and
--- `performance startup` take values this plugin does not enumerate, so a
--- completer would have nothing true to offer.
---@type table<string, table<string, string>>
local HANDLE_ARG = {
  report = { win = "WINDOW" },
  inspect = { buffer = "BUFFER", window = "WINDOW" },
  -- `:Debug keylogger start [path]` writes a file, so file completion is the
  -- right one even though the file does not exist yet -- it completes the
  -- directory part on the way there.
  keylogger = { start = "PATH" },
}

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
            args = {
              { name = "enable", type = "STRING", optional = true, values = { "true", "false" } },
            }
          elseif HANDLE_ARG[category] and HANDLE_ARG[category][action] then
            -- Handle-taking actions. These used to share the generic STRING
            -- slot below, which completed nothing -- and a window or buffer id
            -- is unguessable, so the only way to supply one was to run
            -- `:echo win_getid()` first. That is exactly the friction
            -- completion exists to remove.
            args = {
              { name = "arg", type = HANDLE_ARG[category][action], optional = true },
            }
          else
            -- Covers zero-arg actions (extra token harmlessly falls into
            -- ctx.rest/dispatch re-parses it) and the remaining
            -- single-handle-id actions (proc start/stop/status/log/watch,
            -- performance startup) -- <Tab> completion beyond this one slot
            -- matches the original, which also offered nothing past the first
            -- arg for these.
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
    default = function()
      commands.dispatch({})
    end,
    routes = build_routes(commands),
  })
end

return M
