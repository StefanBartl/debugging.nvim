---@module 'debugging.views.display'
--- Close (and, for whatever still uses tag-matched command re-runs, refresh)
--- the debug log windows. Windows are identified solely by the `custom_tag`
--- window variable and looked up via find_window_by_tag() rather than
--- tracked in a module-level registry — a deliberate choice, since a stale
--- registry is exactly what once made clear_all() miss open windows.
---
--- `<m`/`<n`/`<e` (messages/all/errors) moved to `debugging.views.recent`'s
--- live, `lib.nvim.messages`-backed popup; `show_command_output` (the raw
--- `:messages`/`:Noice *` dispatcher they used to share) went with it.
--- `refresh_log_view`'s `messages`/`noice_all`/`noice_errors` branches are
--- unreachable now (nothing produces those tags anymore) but harmless --
--- left in place rather than also ripped out, since `clear_all()`/
--- `find_window_by_tag`/`get_window_tag` stay genuinely used.

local notify = require("lib.nvim.notify").create("[debugging.views.display]")
local window_tag = require("lib.nvim.window").tag

local utils = require("debugging.views.utils")
local api = vim.api

local M = {}

---@type string[]  Known view tags, so `clear_all()` finds every window this
--- subsystem can open. `messages`/`noice_all`/`noice_errors` are now
--- unreachable (debugging.views.recent's "recent_*" tags replaced them as
--- the <m>/<n>/<e> targets) but `refresh_log_view` below still matches them
--- harmlessly if some other caller ever produces one again -- left in place
--- rather than ripped out along with the three now-dead tags.
local KNOWN_TAGS = { "recent_messages", "recent_all", "recent_errors" }

---Find the window currently showing the view tagged `tag`.
---@param tag string
---@return integer|nil
function M.find_window_by_tag(tag)
  return window_tag.find(tag)
end

---Get the view tag attached to a window, if any.
---@param win integer
---@return string|nil
function M.get_window_tag(win)
  return window_tag.get(win)
end

---Re-run the command backing an already-open tagged view window.
---@param win integer
---@param tag string
---@param timings Dbg.Views.Timings
---@return nil
function M.refresh_log_view(win, tag, timings)
  if not (win and api.nvim_win_is_valid(win)) then
    return
  end

  local ok_config, config = pcall(api.nvim_win_get_config, win)
  if not ok_config or config.relative == "win" or config.width <= 1 or config.height <= 1 then
    return
  end

  if tag == "messages" then
    vim.cmd("messages")
  elseif tag == "noice_all" then
    vim.cmd("Noice all")
  elseif tag == "noice_errors" then
    vim.cmd("Noice errors")
  else
    return
  end

  vim.defer_fn(function()
    if not api.nvim_win_is_valid(win) then
      if tag == "noice_errors" then
        notify.info("No errors available")
      end
      return
    end
    utils.reveal_at_bottom(win, timings.attempts, timings.retry_delay_ms)
  end, 50)
end

---Clear all debug windows.
---@return nil
function M.clear_all()
  for _, tag in ipairs(KNOWN_TAGS) do
    local win = M.find_window_by_tag(tag)
    if win and api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end
end

return M
