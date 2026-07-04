---@module 'debugging.terminals.keylogger'
---@brief Terminal keylogger for Neovim.
---@description
--- Starts/stops via `:Debug keylogger start|stop`. Every key pressed while
--- the terminal buffer active at start() remains current is echoed via
--- `lib.nvim.notify`.

local notify = require("lib.nvim.notify").create("[debugging.terminals.keylogger]")

local M = {}

-- Whether logging is currently active
M.logging = false
M.bufnr = nil

-- Buffers all keys pressed while the terminal buffer is current
local function log_key()
  if not M.logging then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= "terminal" then
    -- Left the terminal buffer while logging was active: the recursive
    -- getcharstr chain below would otherwise die silently, leaving
    -- M.logging stuck at `true` while nothing is actually being logged.
    if M.logging then
      M.logging = false
      notify.warn("Stopped: left the terminal buffer")
    end
    return
  end

  -- getcharstr blocks, so re-invoke repeatedly via vim.schedule
  vim.schedule(function()
    if not M.logging then
      return
    end
    local ok, key = pcall(vim.fn.getcharstr)
    if ok and key then
      notify.info(string.format("Key pressed: %q", key))
    end
    -- Recurse (re-checks buftype) while logging is still active
    if M.logging then
      log_key()
    end
  end)
end

---Start logging keys in the current terminal buffer.
---@return nil
function M.start()
  if M.logging then
    notify.warn("Already logging!")
    return
  end
  M.logging = true
  M.bufnr = vim.api.nvim_get_current_buf()
  notify.info("Started logging keys in this terminal buffer. Press keys now.")
  log_key()
end

---Stop logging keys.
---@return nil
function M.stop()
  if not M.logging then
    notify.warn("Not currently logging!")
    return
  end
  M.logging = false
  notify.info("Stopped logging keys.")
end

return M
