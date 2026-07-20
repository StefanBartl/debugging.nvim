---@module 'debugging.bindings.autocmds'
---@brief Auto-refresh + close-window autocmds for the views subsystem.
---@description
--- Registers every autocmd this plugin owns in one configurable augroup.
---
--- The callbacks go through `lib.nvim.autocmd.create`, which pcalls them and
--- notifies on error — an autocmd that throws would otherwise fail silently
--- on every WinEnter. The augroup itself is still created directly via
--- `nvim_create_augroup(..., { clear = true })` rather than via
--- `lib.nvim.autocmd.group()`: that helper caches groups by name and skips
--- the clear on subsequent calls, which would stack duplicate autocmds every
--- time `setup()` re-runs. Clearing on each setup is what makes reloading
--- the config without restarting Neovim work.

local autocmd = require("lib.nvim.autocmd")
local window = require("lib.nvim.window")
local display = require("debugging.views.display")
local utils = require("debugging.views.utils")
local api = vim.api

local M = {}

---@param ac Dbg.Views.Autocmds
---@param timings Dbg.Views.Timings
function M.setup(ac, timings)
  if not ac.enable then
    return
  end

  local AUG = api.nvim_create_augroup(ac.group_name, { clear = true })

  if ac.auto_refresh then
    autocmd.create("WinEnter", function()
      local win = api.nvim_get_current_win()
      local tag = display.get_window_tag(win)
      if not tag then return end

      vim.defer_fn(function()
        if api.nvim_win_is_valid(win) and api.nvim_get_current_win() == win then
          display.refresh_log_view(win, tag, timings)
        end
      end, 30)
    end, {
      group = AUG,
      desc = "Auto-refresh debug views on WinEnter",
    })

    autocmd.create("BufWinEnter", function(ev)
      local win = vim.fn.bufwinid(ev.buf)
      if win == -1 then return end

      local tag = display.get_window_tag(win)
      if not tag then return end

      vim.defer_fn(function()
        if api.nvim_win_is_valid(win) then
          display.refresh_log_view(win, tag, timings)
        end
      end, 30)
    end, {
      group = AUG,
      desc = "Refresh on BufWinEnter",
    })
  end

  autocmd.create("FileType", function(ev)
    local buf = ev.buf
    if not api.nvim_buf_is_valid(buf) then return end
    if not utils.is_target_view(buf) then return end

    local win = vim.fn.bufwinid(buf)
    if win == -1 then return end

    window.nice_quit(win, { force = true })
  end, {
    group = AUG,
    pattern = { "messages", "noice" },
    desc = "Close debug windows with q or <Esc>",
  })
end

return M

