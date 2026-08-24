---@module 'debugging.bindings.keymaps'
--- Normal-mode keymaps for the views subsystem (messages/Noice/capture).

local notify = require("lib.nvim.notify").create("[debugging.bindings.keymaps]")

local display = require("debugging.views.display")
local capture = require("debugging.views.capture")

local M = {}

---Wire up the views subsystem's normal-mode keymaps under `km.prefix`.
---@param km Dbg.Views.Keymaps
---@param timings Dbg.Views.Timings
---@return nil
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

  ---`capture_messages` has always taken `save_file`/`clipboard`, but the only
  --- key bound the both-at-once default -- picking one sink meant calling the
  --- Lua API by hand. These three cover the choice with three distinct keys
  --- rather than a prefix tree: `c` then waiting to see whether an `f`
  --- follows would delay the common case for the sake of the rare ones.
  ---@param opts { save_file?: boolean, clipboard?: boolean }
  ---@return fun(): nil
  local function capture_to(opts)
    return function()
      local ok, _, detail =
        capture.capture_messages(vim.tbl_extend("force", { debug = false }, opts))
      if ok then
        notify.info(detail)
      else
        notify.warn(detail)
      end
    end
  end

  km.map(
    "n",
    km.prefix .. "c",
    capture_to({}),
    { desc = "[Debug] Capture to file+clipboard", silent = true }
  )

  km.map(
    "n",
    km.prefix .. "f",
    capture_to({ clipboard = false }),
    { desc = "[Debug] Capture to file only", silent = true }
  )

  km.map(
    "n",
    km.prefix .. "y",
    capture_to({ save_file = false }),
    { desc = "[Debug] Capture to clipboard only", silent = true }
  )

  km.map("n", km.prefix .. "x", function()
    display.clear_all()
    notify.info("All debug windows closed")
  end, { desc = "[Debug] Clear all windows", silent = true })
end

return M
