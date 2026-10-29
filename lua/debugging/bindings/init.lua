---@module 'debugging.bindings'
--- Orchestrates debugging.nvim's bindings: usercmds and keymaps.
---
--- Single entry point for every user-facing trigger. The `:Debug` user
--- command is always registered; the views keymaps are only wired when
--- `features.views` is active, using the config already resolved by
--- `debugging.views.setup()`. The plugin owns no autocmds of its own.

local M = {}

---Wire up every binding for the resolved config.
---@param cfg Dbg.Config
---@return nil
function M.setup(cfg)
  require("debugging.bindings.usercmds").setup(cfg)

  if not cfg.features.views then
    return
  end

  local km = require("debugging.views").get_keymaps_config()

  if km.enable then
    require("debugging.bindings.keymaps").setup(km)
  end
end

return M
