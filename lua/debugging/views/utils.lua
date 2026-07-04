---@module 'debugging.views.utils'

local api = vim.api
local M = {}

---@param win integer
---@return boolean
local function at_bottom(win)
  if not (win and api.nvim_win_is_valid(win)) then
    return true
  end
  local ok_buf, buf = pcall(api.nvim_win_get_buf, win)
  if not ok_buf or not (buf and api.nvim_buf_is_valid(buf)) then
    return true
  end
  local last = api.nvim_buf_line_count(buf)
  local row = api.nvim_win_get_cursor(win)[1]
  return row >= last
end

---@param win integer
---@param row integer
---@return boolean
local function safe_win_set_cursor(win, row)
  if not (win and api.nvim_win_is_valid(win)) then
    return false
  end
  local ok_buf, buf = pcall(api.nvim_win_get_buf, win)
  if not ok_buf or not (buf and api.nvim_buf_is_valid(buf)) then
    return false
  end
  return pcall(api.nvim_win_set_cursor, win, { math.max(1, row), 0 })
end

---Identify messages/noice buffers by filetype
---@param buf integer
---@return boolean
function M.is_target_view(buf)
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return false
  end
  local ok_ft, ft = pcall(function()
    return vim.bo[buf].filetype
  end)
  if not ok_ft then
    return false
  end
  if ft == "messages" then
    return true
  end
  if ft == "noice" then
    local ok_bt, bt = pcall(function()
      return vim.bo[buf].buftype
    end)
    return ok_bt and (bt == "nofile" or bt == "")
  end
  return false
end

---Move cursor to bottom with retries
---@param win integer
---@param attempts integer
---@param retry_delay integer
function M.ensure_bottom(win, attempts, retry_delay)
  if not (win and api.nvim_win_is_valid(win)) then
    return
  end
  attempts = attempts or 1
  retry_delay = retry_delay or 60

  local ok_buf, buf = pcall(api.nvim_win_get_buf, win)
  if not ok_buf or not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  local last = math.max(1, api.nvim_buf_line_count(buf))
  safe_win_set_cursor(win, last)

  if attempts > 1 and not at_bottom(win) then
    vim.defer_fn(function()
      if win and api.nvim_win_is_valid(win) then
        M.ensure_bottom(win, attempts - 1, retry_delay)
      end
    end, retry_delay)
  end
end

---Make window focusable
---@param win integer
---@return boolean
function M.make_focusable(win)
  if not (win and api.nvim_win_is_valid(win)) then
    return false
  end

  local ok_config, config = pcall(api.nvim_win_get_config, win)
  if not ok_config then
    return false
  end

  if not config.focusable then
    config.focusable = true
    local ok_set = pcall(api.nvim_win_set_config, win, config)
    if not ok_set then
      return false
    end
  end

  return true
end

---Force window focus with cursor visibility
---@param win integer
---@return boolean
function M.force_focus(win)
  if not (win and api.nvim_win_is_valid(win)) then
    return false
  end

  if not M.make_focusable(win) then
    return false
  end

  local ok = pcall(api.nvim_set_current_win, win)
  if not ok then
    return false
  end

  local ok_buf, buf = pcall(api.nvim_win_get_buf, win)
  if not ok_buf or not api.nvim_buf_is_valid(buf) then
    return false
  end

  vim.cmd("redraw")
  return true
end

---Focus window and move cursor to bottom
---@param win integer
---@param attempts integer
---@param retry_delay integer
function M.focus_and_bottom(win, attempts, retry_delay)
  if not (win and api.nvim_win_is_valid(win)) then
    return
  end

  local ok_config, config = pcall(api.nvim_win_get_config, win)
  if not ok_config then
    return
  end

  if config.relative == "win" or config.width <= 1 or config.height <= 1 then
    return
  end

  M.force_focus(win)

  if not api.nvim_win_is_valid(win) then
    return
  end

  local ok_buf, buf = pcall(api.nvim_win_get_buf, win)
  if not ok_buf or not api.nvim_buf_is_valid(buf) then
    return
  end

  local last = api.nvim_buf_line_count(buf)
  pcall(api.nvim_win_set_cursor, win, { last, 0 })
  vim.cmd("normal! G")
  M.ensure_bottom(win, attempts, retry_delay)
end

return M

