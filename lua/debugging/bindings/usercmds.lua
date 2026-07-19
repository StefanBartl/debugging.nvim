---@module 'debugging.bindings.usercmds'
---@brief Registers the single `:Debug` user command.
---@description
--- Command *logic* (dispatch + completion) lives in `debugging.commands`;
--- this module only registers the command.
---
--- Registration goes through `lib.nvim.usercmd.create`, which pcalls the
--- callback and reports failures instead of letting a broken dispatch surface
--- as a raw stack trace — and defaults to `force = true`, so re-running
--- `setup()` overwrites the command rather than raising E174.

local usercmd = require("lib.nvim.usercmd")

local M = {}

---Register the unified :Debug command for the resolved config.
---@param cfg Dbg.Config
---@return nil
function M.setup(cfg)
  local commands = require("debugging.commands")

  usercmd.create(cfg.command, function(a)
    commands.dispatch(a.fargs)
  end, {
    nargs = "*",
    complete = commands.complete,
    desc = "Unified debugging entry point — :" .. cfg.command .. " {category} {action}",
  })
end

return M
