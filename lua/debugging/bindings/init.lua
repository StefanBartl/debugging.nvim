---@module 'debugging.bindings'
---@brief Orchestrates debugging.nvim's bindings: usercmds, keymaps, autocmds, which-key.
---@description
--- Single entry point for every user-facing trigger. The `:Debug` user
--- command is always registered; the views keymaps/autocmds/which-key label
--- are only wired when `features.views` is active, using the config already
--- resolved by `debugging.views.setup()`.

local M = {}

---Wire up every binding for the resolved config.
---@param cfg Dbg.Config
---@return nil
function M.setup(cfg)
  require("debugging.bindings.usercmds").setup(cfg)

  if not cfg.features.views then
    return
  end

  local views = require("debugging.views")
  local timings = views.get_timings()
  local km = views.get_keymaps_config()
  local ac = views.get_autocmds_config()

  if km.enable then
    require("debugging.bindings.keymaps").setup(km, timings)
    require("debugging.bindings.which_key").setup(km.prefix)
  end

  if ac.enable then
    require("debugging.bindings.autocmds").setup(ac, timings)
  end
end

return M
