---@module 'debugging'
---@brief Public entry point for debugging.nvim.
---@description
--- A single `:Debug {category} {action}` command groups every debugging tool:
--- message/Noice views, buffer/tab/window reports, autocmd inspection (runtime +
--- static source audit), buffer/cursor/var inspection, a terminal keylogger,
--- indent diagnostics, markdown inline-highlight debug, and an opt-in Neo-tree
--- safety bridge.
---
--- Depends on lib.nvim (deliberate shared dependency).
---
--- Example: >lua
---   require("debugging").setup({ all = true })
---   require("debugging").setup({ features = { neotree = true } })
--- <

local M = {}

---@type boolean
local _done = false

---Configure and activate debugging.nvim.
---@param opts? Dbg.Config|table
---@return nil
function M.setup(opts)
  if _done then
    return
  end
  _done = true

  local config = require("debugging.config")
  local cfg = config.setup(opts)

  -- Views resolves its own timings/keymap/autocmd config first.
  if cfg.features.views then
    require("debugging.views").setup(cfg.views)
  end

  -- Bindings: the single unified :Debug command, plus keymaps/autocmds/
  -- which-key label for the views subsystem (if enabled).
  require("debugging.bindings").setup(cfg)

  vim.g.loaded_debugging = 1
end

return M
