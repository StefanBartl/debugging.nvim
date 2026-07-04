---@module 'debugging.bindings.autocmds'
---@brief Auto-refresh + close-window autocmds for the views subsystem.

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
    api.nvim_create_autocmd("WinEnter", {
      group = AUG,
      desc = "Auto-refresh debug views on WinEnter",
      callback = function()
        local win = api.nvim_get_current_win()
        local tag = display.get_window_tag(win)
        if not tag then return end

        vim.defer_fn(function()
          if api.nvim_win_is_valid(win) and api.nvim_get_current_win() == win then
            display.refresh_log_view(win, tag, timings)
          end
        end, 30)
      end,
    })

    api.nvim_create_autocmd("BufWinEnter", {
      group = AUG,
      desc = "Refresh on BufWinEnter",
      callback = function(ev)
        local win = vim.fn.bufwinid(ev.buf)
        if win == -1 then return end

        local tag = display.get_window_tag(win)
        if not tag then return end

        vim.defer_fn(function()
          if api.nvim_win_is_valid(win) then
            display.refresh_log_view(win, tag, timings)
          end
        end, 30)
      end,
    })
  end

  api.nvim_create_autocmd("FileType", {
    group = AUG,
    pattern = { "messages", "noice" },
    desc = "Close debug windows with q or <Esc>",
    callback = function(ev)
      local buf = ev.buf
      if not api.nvim_buf_is_valid(buf) then return end
      if not utils.is_target_view(buf) then return end

      local function close_dbg_window()
        local win = vim.fn.bufwinid(buf)
        if win ~= -1 and api.nvim_win_is_valid(win) then
          api.nvim_win_close(win, true)
        end
      end

      vim.keymap.set("n", "q", close_dbg_window, {
        buffer = buf,
        nowait = true,
        silent = true,
        desc = "Close debug window",
      })

      vim.keymap.set("n", "<Esc>", close_dbg_window, {
        buffer = buf,
        nowait = true,
        silent = true,
        desc = "Close debug window",
      })
    end,
  })
end

return M

