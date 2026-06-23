---@module 'debugging.terminals.keylogger'
-- Terminal-Keylogger für Neovim
-- Startet und stoppt Keylogging über User-Commands.
-- Alle gedrückten Keys im Terminal-Modus werden über vim.notify angezeigt.

local notify = require("lib.nvim.notify").create("[debugging.terminals.keylogger]")

local M = {}

-- interne Variable, ob Logging aktiv ist
M.logging = false
M.bufnr = nil

-- Funktion, die alle gedrückten Keys im Terminal puffert
local function log_key()
  -- nur wenn Logging aktiv ist
  if not M.logging then
    return
  end

  -- aktuelle Puffer-ID prüfen
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= "terminal" then
    return
  end

  -- getcharstr blockiert, daher über vim.schedule wiederholt aufrufen
  vim.schedule(function()
    if not M.logging then
      return
    end
    local ok, key = pcall(vim.fn.getcharstr)
    if ok and key then
      notify.info(string.format("[debugging.terminals.keylogger] Key pressed: %q", key))
    end
    -- wieder rekursiv aufrufen, solange Logging aktiv ist
    if M.logging then
      log_key()
    end
  end)
end

-- Startfunktion
---Start logging keys in the current terminal buffer.
---@return nil
function M.start()
  if M.logging then
    notify.warn("[debugging.terminals.keylogger] Already logging!")
    return
  end
  M.logging = true
  M.bufnr = vim.api.nvim_get_current_buf()
  notify.info("[debugging.terminals.keylogger] Started logging keys in this terminal buffer. Press keys now.")
  log_key()
end

-- Stopfunktion
---Stop logging keys.
---@return nil
function M.stop()
  if not M.logging then
    notify.warn("[debugging.terminals.keylogger] Not currently logging!")
    return
  end
  M.logging = false
  notify.info("[debugging.terminals.keylogger] Stopped logging keys.")
end

return M
