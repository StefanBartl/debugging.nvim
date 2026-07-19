---@module 'debugging.terminals.keylogger'
---@brief Terminal keylogger for Neovim.
---@description
--- Starts/stops via `:Debug keylogger start|stop`. Every key pressed while the
--- terminal buffer active at start() remains current is echoed via
--- `lib.nvim.notify`, and — when a logfile is configured — appended to disk so
--- long sessions can be reviewed afterwards.
---
--- A logfile is used when either `:Debug keylogger start {path}` passes one, or
--- `config.terminals.keylogger.logfile` is set. `~` and env vars are expanded.

local notify = require("lib.nvim.notify").create("[debugging.terminals.keylogger]")

local M = {}

-- Whether logging is currently active
M.logging = false
M.bufnr = nil

---@type string|nil  Absolute path of the active logfile (nil = notify only)
M.logfile = nil

---@type file*|nil  Open append handle for the active logfile
local _fh = nil

---Resolve the logfile path from an explicit arg or the config default.
---@param explicit string|nil
---@return string|nil  Expanded absolute path, or nil for notify-only mode
local function resolve_logfile(explicit)
  local path = explicit
  if not path or path == "" then
    local ok, config = pcall(require, "debugging.config")
    if ok then
      local kl = config.get().terminals and config.get().terminals.keylogger
      path = kl and kl.logfile or nil
    end
  end
  if not path or path == "" then
    return nil
  end
  return vim.fn.expand(path)
end

---Append one recorded key to the open logfile, if any.
---@param key string
local function write_key(key)
  if not _fh then
    return
  end
  local ok = pcall(function()
    _fh:write(string.format("%s  %q\n", os.date("%H:%M:%S"), key))
    _fh:flush()
  end)
  if not ok then
    -- A broken handle should not wedge the recursive logging loop.
    _fh = nil
  end
end

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
      M.stop("left the terminal buffer")
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
      write_key(key)
    end
    -- Recurse (re-checks buftype) while logging is still active
    if M.logging then
      log_key()
    end
  end)
end

---Start logging keys in the current terminal buffer.
---@param logfile? string  Optional path to append recorded keys to.
---@return nil
function M.start(logfile)
  if M.logging then
    notify.warn("Already logging!")
    return
  end

  M.logfile = resolve_logfile(logfile)
  if M.logfile then
    vim.fn.mkdir(vim.fn.fnamemodify(M.logfile, ":h"), "p")
    local fh, err = io.open(M.logfile, "a")
    if not fh then
      notify.error(("could not open logfile %q: %s"):format(M.logfile, tostring(err)))
      M.logfile = nil
      return
    end
    _fh = fh
    _fh:write(string.format("\n=== keylogger session %s ===\n", os.date("%Y-%m-%d %H:%M:%S")))
    _fh:flush()
  end

  M.logging = true
  M.bufnr = vim.api.nvim_get_current_buf()
  notify.info(("Started logging keys in this terminal buffer%s. Press keys now.")
    :format(M.logfile and (" (→ " .. M.logfile .. ")") or ""))
  log_key()
end

---Stop logging keys.
---@param reason? string  Optional context (e.g. why logging auto-stopped).
---@return nil
function M.stop(reason)
  if not M.logging then
    notify.warn("Not currently logging!")
    return
  end
  M.logging = false
  if _fh then
    pcall(function() _fh:close() end)
    _fh = nil
  end
  if reason then
    notify.warn("Stopped: " .. reason)
  else
    notify.info("Stopped logging keys.")
  end
end

return M
