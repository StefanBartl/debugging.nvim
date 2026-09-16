-- TESTS/keylogger_spec.lua
-- Covers `debugging.terminals.keylogger`: logfile resolution (explicit arg >
-- config default > notify-only), the file lifecycle (header written on
-- start, handle closed on stop), and the start/stop guard warnings.
--
-- M.start() always ends by calling into a recursive `vim.schedule(getcharstr)`
-- loop that blocks waiting for a real keypress -- that loop must never
-- actually run in a headless suite. Every case below calls M.stop()
-- synchronously, in the same call stack as M.start(), before control ever
-- returns to the event loop -- the deferred callback checks `M.logging` and
-- exits immediately once it does eventually run, instead of blocking on
-- getcharstr.

return function(H)
  local keylogger = require("debugging.terminals.keylogger")
  local config = require("debugging.config")

  local orig_notify = vim.notify
  local seen = {}
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.notify = function(msg, level)
    seen[#seen + 1] = { msg = tostring(msg), level = level }
  end
  local function last()
    return seen[#seen] and seen[#seen].msg or ""
  end
  local function reset()
    seen = {}
  end

  local ok, err = pcall(function()
    config.setup({})

    -- log_key() (called synchronously at the end of every M.start()) checks
    -- whether the *current* buffer is a terminal, and self-stops immediately
    -- -- synchronously, no schedule involved -- if it is not. A plain
    -- scratch buffer would make every start() below revert to `logging =
    -- false` before it even returns. Faking `buftype = "terminal"` on an
    -- ordinary scratch buffer satisfies that check without spawning a real
    -- terminal/shell process.
    local term_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(term_buf)
    vim.api.nvim_open_term(term_buf, {}) -- sets buftype=terminal, no real shell spawned

    -- --------------------------------------------------------- notify-only mode

    reset()
    keylogger.start()
    H.eq(keylogger.logging, true, "start: logging becomes active")
    H.eq(keylogger.logfile, nil, "start: no logfile configured -> notify-only")
    H.ok(not last():match("→"), "start: notify-only mode has no file arrow in the message")
    keylogger.stop()
    H.eq(keylogger.logging, false, "stop: logging becomes inactive")
    H.match(last(), "Stopped logging keys", "stop: plain stop message with no reason")

    -- ---------------------------------------------------------- double start/stop

    keylogger.start()
    reset()
    keylogger.start()
    H.match(last(), "Already logging", "start: a second start warns instead of restarting")
    keylogger.stop()

    reset()
    keylogger.stop()
    H.match(last(), "Not currently logging", "stop: stopping when idle warns")

    -- -------------------------------------------------------- explicit logfile

    local tmp_dir = vim.fs.normalize(vim.fn.tempname())
    local explicit_path = tmp_dir .. "/explicit.log"

    keylogger.start(explicit_path)
    H.eq(keylogger.logfile, vim.fn.expand(explicit_path), "start(path): explicit path wins")
    keylogger.stop()

    H.eq(vim.fn.filereadable(explicit_path), 1, "start(path): logfile was actually created")
    local content = table.concat(vim.fn.readfile(explicit_path), "\n")
    H.match(content, "keylogger session", "start(path): session header was written")

    vim.fn.delete(tmp_dir, "rf")

    -- --------------------------------------------------------- config default

    local cfg_path = vim.fs.normalize(vim.fn.tempname()) .. "/cfg.log"
    config.setup({ terminals = { keylogger = { logfile = cfg_path } } })

    keylogger.start() -- no explicit arg -> falls back to config
    H.eq(keylogger.logfile, vim.fn.expand(cfg_path), "start(): falls back to config.logfile")
    keylogger.stop()
    vim.fn.delete(vim.fn.fnamemodify(cfg_path, ":h"), "rf")

    -- An explicit arg still overrides a configured default.
    local override_path = vim.fs.normalize(vim.fn.tempname()) .. "/override.log"
    keylogger.start(override_path)
    H.eq(
      keylogger.logfile,
      vim.fn.expand(override_path),
      "start(path): explicit arg overrides config default"
    )
    keylogger.stop()
    vim.fn.delete(vim.fn.fnamemodify(override_path, ":h"), "rf")

    config.setup({}) -- leave a clean config behind

    -- ------------------------------------------------------- unopenable logfile

    -- Pointing the "logfile" at an existing directory is a portable way to
    -- make io.open(..., "a") fail on every platform -- mkdir() on its
    -- (already-existing) parent trivially succeeds either way, so this
    -- isolates the io.open failure branch specifically.
    local unopenable_dir = vim.fs.normalize(vim.fn.tempname())
    vim.fn.mkdir(unopenable_dir, "p")
    reset()
    keylogger.start(unopenable_dir)
    H.ok(keylogger.logging == false, "start(bad path): does not start logging on a write failure")
    H.match(last(), "could not open logfile", "start(bad path): reports the open failure")
    vim.fn.delete(unopenable_dir, "rf")
  end)

  vim.notify = orig_notify
  if keylogger.logging then
    keylogger.stop()
  end
  if not ok then
    error(err, 0)
  end
end
