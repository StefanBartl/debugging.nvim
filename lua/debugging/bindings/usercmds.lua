---@module 'debugging.bindings.usercmds'
---@brief Registers the single `:Debug` user command.
---@description
--- Command *logic* (dispatch + completion) lives in `debugging.commands`;
--- this module only registers the command.

local M = {}

---Register the unified :Debug command for the resolved config.
---@param cfg Dbg.Config
---@return nil
function M.setup(cfg)
  local commands = require("debugging.commands")

  vim.api.nvim_create_user_command(cfg.command, function(a)
    commands.dispatch(a.fargs)
  end, {
    nargs = "*",
    complete = commands.complete,
    desc = "Unified debugging entry point — :" .. cfg.command .. " {category} {action}",
  })
end

return M
