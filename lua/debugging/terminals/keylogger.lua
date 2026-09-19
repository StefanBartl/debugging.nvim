---@module 'debugging.terminals.keylogger'
--- Terminal keylogger for Neovim.
---
--- Starts/stops via `:Debug keylogger start|stop`. Every key pressed while the
--- terminal buffer active at start() remains current is echoed via
--- `lib.nvim.notify`, and — when a logfile is configured — appended to disk so
--- long sessions can be reviewed afterwards.
---
--- A logfile is used when either `:Debug keylogger start {path}` passes one, or
--- `config.terminals.keylogger.logfile` is set. `~` and env vars are expanded.
---
--- **What ends up in it.** Every key pressed in that terminal buffer, in
--- order -- which routinely includes whatever is typed at a `sudo`, `ssh`
--- or `gpg` prompt, because a password prompt is just more keystrokes as
--- far as this is concerned. Neither the shell's echo suppression nor the
--- prompt's own masking applies: those hide characters on screen, and
--- this reads them before the terminal ever sees them.
---
--- The logfile is therefore created 0600 -- and notify-only mode is not
--- the safer choice, it echoes the same keys into the message area where
--- they stay in `:messages`. Stop the logger before authenticating.
---
--- **Observes keys, it does not eat them.** This used to drive a recursive
--- `vim.schedule` loop around `vim.fn.getcharstr()`, which is not an
--- observer at all: `getcharstr()` blocks and *consumes* the keypress, so
--- the terminal being logged never received what you typed. The loop was
--- also unrunnable in a headless test -- the spec had to stop the logger
--- synchronously before control reached the event loop, and said so.
---
--- `vim.on_key(cb, ns)` is the right primitive and has been since it
--- learned about namespaces: it observes without consuming, several
--- listeners coexist under distinct namespaces, and `vim.on_key(nil, ns)`
--- detaches one without touching the others. `ui.nvim`'s screenkey HUD and
--- macro counter already use it that way; this was the odd one out
--- (cross-feature report, finding C6).
---
--- The callback runs inside Neovim's input-processing path, not a normal
--- call stack, so it does the least possible there and defers the notify
--- and the file write onto the main loop — the same shape screenkey uses.

local notify = require("lib.nvim.notify").create("[debugging.terminals.keylogger]")
local expand_path = require("lib.nvim.cross.fs.expand_path")

local M = {}

--- Namespace for this module's `vim.on_key` listener. Created once; the
--- listener itself is attached only while logging.
local NS = vim.api.nvim_create_namespace("debugging_keylogger")

-- Whether logging is currently active
M.logging = false
M.bufnr = nil

---@type string|nil  Absolute path of the active logfile (nil = notify only)
M.logfile = nil

---@type file*|nil  Open append handle for the active logfile
local _fh = nil

---@internal
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
  return expand_path(path)
end

---@internal
---Append one recorded key to the open logfile, if any.
---@param key string
---@return nil
local function write_key(key)
  if not _fh then
    return
  end
  local ok = pcall(function()
    _fh:write(string.format("%s  %q\n", os.date("%H:%M:%S"), key))
    _fh:flush()
  end)
  if not ok then
    -- A broken handle must not take the observer down with it.
    _fh = nil
  end
end

---@internal
---Record one observed key: notify, and append to the logfile if there is one.
---
---Deferred out of the `vim.on_key` callback, which runs in Neovim's input
---path where neither `notify` nor file IO belongs.
---@param key string # already human-readable, via `keytrans()`
---@return nil
local function record(key)
  notify.info(string.format("Key pressed: %s", key))
  write_key(key)
end

---@internal
---The `vim.on_key` callback. Deliberately minimal: it decides whether this
---keypress is one of ours and hands everything else to the event loop.
---@param key string # raw, post-mapping byte sequence
---@return nil
local function on_key(key)
  if not M.logging or key == "" then
    return
  end

  -- Keys arrive for the whole session, not per buffer, so the filter is
  -- here. Leaving the logged buffer stops the logger rather than silently
  -- recording keys meant for somewhere else.
  if vim.api.nvim_get_current_buf() ~= M.bufnr then
    vim.schedule(function()
      if M.logging then
        M.stop("left the terminal buffer")
      end
    end)
    return
  end

  local ok, pretty = pcall(vim.fn.keytrans, key)
  local text = (ok and type(pretty) == "string" and pretty ~= "") and pretty or key

  vim.schedule(function()
    -- Re-checked: stop() may have run between the keypress and this
    -- callback reaching the main loop.
    if M.logging then
      record(text)
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

    -- 0600 before the first keystroke is written. The file is about to
    -- contain every key typed into a terminal, which routinely includes
    -- what someone types at a `sudo`, `ssh` or `gpg` prompt -- not a file
    -- to leave at the mercy of the process umask. Best-effort:
    -- `fs_chmod` is meaningless on Windows and must not stop logging. The
    -- `vim.uv` lookup itself is inside the pcall too -- it doesn't exist
    -- before 0.10, and this plugin declares 0.9+.
    pcall(function()
      (vim.uv or vim.loop).fs_chmod(M.logfile, 384) -- 0600
    end)

    _fh:write(string.format("\n=== keylogger session %s ===\n", os.date("%Y-%m-%d %H:%M:%S")))
    _fh:flush()
  end

  M.logging = true
  M.bufnr = vim.api.nvim_get_current_buf()
  vim.on_key(on_key, NS)
  notify.info(
    ("Started logging keys in this terminal buffer%s. Press keys now."):format(
      M.logfile and (" (→ " .. M.logfile .. ")") or ""
    )
  )
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
  -- Detach rather than leave the hook attached and ignore its own calls:
  -- every keypress in the session would otherwise keep paying for it.
  vim.on_key(nil, NS)
  if _fh then
    pcall(function()
      _fh:close()
    end)
    _fh = nil
  end
  if reason then
    notify.warn("Stopped: " .. reason)
  else
    notify.info("Stopped logging keys.")
  end
end

return M
