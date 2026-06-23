---@module 'debugging.views.keymaps'

local notify = require("lib.nvim.notify").create("[debugging.views.keymaps]")

local display = require("debugging.views.display")
local capture = require("debugging.views.capture")

local M = {}

---@param km Dbg.Views.Keymaps
---@param timings Dbg.Views.Timings
function M.setup(km, timings)
  if not km.enable then
    return
  end

  km.map("n", km.prefix .. "m", function()
    display.execute_and_refresh("messages", "messages", timings)
  end, { desc = "[Debug] Messages view", silent = true })

  km.map("n", km.prefix .. "n", function()
    display.execute_and_refresh("noice_all", "Noice all", timings)
  end, { desc = "[Debug] Noice all", silent = true })

  km.map("n", km.prefix .. "e", function()
    vim.cmd("Noice errors")
  end, { desc = "[Debug] Noice errors", silent = true })

  km.map("n", km.prefix .. "c", function()
    capture.capture_messages({ debug = false })
  end, { desc = "[Debug] Capture to file+clipboard", silent = true })

  km.map("n", km.prefix .. "x", function()
    display.clear_all()
    notify.info("All debug windows closed")
  end, { desc = "[Debug] Clear all windows", silent = true })
end

return M

