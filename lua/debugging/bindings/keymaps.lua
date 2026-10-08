---@module 'debugging.bindings.keymaps'
--- Normal-mode keymaps for the views subsystem (messages/Noice/capture).

local notify = require("lib.nvim.notify").create("[debugging.bindings.keymaps]")

local display = require("debugging.views.display")
local capture = require("debugging.views.capture")

local M = {}

---Declare and bind the views subsystem's normal-mode keymaps.
---
---Declared through `lib.nvim.bindings.keymap`'s registry, which is what makes
---each one individually overridable: `prefix` used to be the only lever, so a
---user who wanted a different key for one view had to move all seven.
---`keymaps = { messages = "<leader>dm" }` now moves exactly one, `= false`
---drops one, and `prefix` still supplies the default for the rest.
---@param km Dbg.Views.Keymaps
---@return Lib.Keymap.Registered[]
function M.setup(km)
  local prefix = km.prefix

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

  ---@type Lib.Keymap.Spec
  local spec = {
    prefix = prefix,
    which_key = { group = "Debug" },
    -- Shared with the config schema: `views.keymaps.<action>` is only an
    -- accepted option for the names in this list.
    order = require("debugging.config.KEYMAP_ACTIONS"),
    actions = {
      -- Delegate to debugging.views' own action functions (single source of
      -- truth, shared with the :Debug dispatcher) rather than calling
      -- display.show_command_output directly -- all three now open the
      -- recent-messages popup with a different filter, not a raw :messages/
      -- :Noice dump. See debugging.views.recent.
      messages = {
        default = prefix .. "m",
        rhs = function()
          require("debugging.views").messages_show()
        end,
        desc = "Messages view (non-error)",
      },
      noice_all = {
        default = prefix .. "n",
        rhs = function()
          require("debugging.views").noice_all()
        end,
        desc = "Recent messages (all)",
      },
      noice_errors = {
        default = prefix .. "e",
        rhs = function()
          require("debugging.views").noice_errors()
        end,
        desc = "Recent errors",
      },

      capture = {
        default = prefix .. "c",
        rhs = capture_to({}),
        desc = "Capture to file+clipboard",
      },
      capture_file = {
        default = prefix .. "f",
        rhs = capture_to({ clipboard = false }),
        desc = "Capture to file only",
      },
      capture_clipboard = {
        default = prefix .. "y",
        rhs = capture_to({ save_file = false }),
        desc = "Capture to clipboard only",
      },

      clear = {
        default = prefix .. "x",
        rhs = function()
          display.clear_all()
          notify.info("All debug windows closed")
        end,
        desc = "Clear all windows",
      },
    },
  }

  return require("lib.nvim.bindings.keymap").register("Debug", spec, km)
end

return M
