---@module 'debugging.views.display'
---@brief Open, refresh and close the debug log windows.
---@description
--- Owns the lifecycle of the split windows behind `:Debug messages` and
--- `:Debug noice`. Windows are identified solely by the `custom_tag` window
--- variable and looked up via find_window_by_tag() rather than tracked in a
--- module-level registry — a deliberate choice, since a stale registry is
--- exactly what once made clear_all() miss open windows.

local notify = require("lib.nvim.notify").create("[debugging.views.display]")

local utils = require("debugging.views.utils")
local api = vim.api

local M = {}

---@type string[]  Known view tags — kept in sync with the tags passed to
--- execute_and_refresh()/refresh_log_view() by debugging.views.
local KNOWN_TAGS = { "messages", "noice_all", "noice_errors" }

---@param tag string
---@return integer|nil
function M.find_window_by_tag(tag)
  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(win) then
      local win_tag = vim.w[win] and vim.w[win].custom_tag or nil
      if win_tag == tag then
        local ok_config, config = pcall(api.nvim_win_get_config, win)
        if ok_config and config.relative ~= "win" and config.width > 1 and config.height > 1 then
          return win
        end
      end
    end
  end
  return nil
end

---@param win integer
---@return string|nil
function M.get_window_tag(win)
  if not api.nvim_win_is_valid(win) then
    return nil
  end
  return vim.w[win] and vim.w[win].custom_tag or nil
end

---@param tag string
---@param cmd string
---@param timings Dbg.Views.Timings
function M.execute_and_refresh(tag, cmd, timings)
  local existing_win = M.find_window_by_tag(tag)

  if existing_win and api.nvim_win_is_valid(existing_win) then
    utils.make_focusable(existing_win)
    utils.force_focus(existing_win)
    vim.cmd(cmd)
    vim.defer_fn(function()
      if api.nvim_win_is_valid(existing_win) then
        utils.focus_and_bottom(existing_win, timings.attempts, timings.retry_delay_ms)
      end
    end, 50)
    return
  end

  -- Try to use lib.buf_win_tab.capture if available
  local ok_capture, capture_lib = pcall(require, "lib.nvim.buf_win_tab.capture")
  if ok_capture and capture_lib.capture then
    capture_lib.capture(cmd, {
      timeout = 500,
      tag = { buf = tag, win = tag },
    }, function(result)
      if not result.wins or #result.wins == 0 then
        if tag == "noice_errors" then
          notify.info("No errors available")
        end
        return
      end

      for _, win in ipairs(result.wins) do
        if api.nvim_win_is_valid(win) then
          utils.make_focusable(win)
          vim.defer_fn(function()
            if not api.nvim_win_is_valid(win) then
              if tag == "noice_errors" then
                notify.info("No errors available")
              end
              return
            end
            utils.focus_and_bottom(win, timings.attempts, timings.retry_delay_ms)
          end, 30)
        end
      end
    end)
  else
    -- Fallback: just execute command
    vim.cmd(cmd)
  end
end

---@param win integer
---@param tag string
---@param timings Dbg.Views.Timings
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
    utils.focus_and_bottom(win, timings.attempts, timings.retry_delay_ms)
  end, 50)
end

---Clear all debug windows
function M.clear_all()
  for _, tag in ipairs(KNOWN_TAGS) do
    local win = M.find_window_by_tag(tag)
    if win and api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end
end

return M

