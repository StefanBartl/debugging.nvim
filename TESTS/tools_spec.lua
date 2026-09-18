-- TESTS/tools_spec.lua
-- Covers `debugging.tools.buffer_inspector`, `debugging.tools.cursor.state`,
-- `debugging.tools.vardump`, and the argument-parsing / dispatch logic of
-- `debugging.tools.proc_trace` (stubbed against a fake
-- lib.nvim.system.proc_trace so no real instrumentation is installed).

return function(H)
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
    -- ============================================================ buffer_inspector

    local inspector = require("debugging.tools.buffer_inspector")

    reset()
    inspector.inspect(999999)
    H.match(last(), "Invalid buffer", "inspector.inspect: rejects an invalid buffer")

    local buf = H.scratch("buffer_inspector_spec.lua", "lua")
    reset()
    inspector.inspect(buf)
    H.match(last(), "Buffer " .. buf .. " state", "inspector.inspect: reports the buffer state")
    H.match(last(), "filetype  = lua", "inspector.inspect: reports buffer-scoped options")

    reset()
    inspector.window(999999)
    H.match(last(), "Invalid window", "inspector.window: rejects an invalid window")

    reset()
    inspector.window(vim.api.nvim_get_current_win())
    H.match(last(), "state:", "inspector.window: reports the window state")
    H.match(last(), "cursorline", "inspector.window: reports window-scoped options")

    -- A floating window's config.relative is non-empty -- the "floating" line
    -- only appears for those, not for a normal split.
    local float_buf = vim.api.nvim_create_buf(false, true)
    local float_win = vim.api.nvim_open_win(float_buf, false, {
      relative = "editor",
      row = 0,
      col = 0,
      width = 10,
      height = 3,
    })
    reset()
    inspector.window(float_win)
    H.match(last(), "floating  = yes", "inspector.window: flags a floating window")
    vim.api.nvim_win_close(float_win, true)

    reset()
    inspector.tab(9999)
    H.match(last(), "Invalid tab number", "inspector.tab: rejects an out-of-range tab number")

    reset()
    inspector.tab()
    H.match(last(), "Tabpage", "inspector.tab: reports the current tabpage by default")
    H.match(last(), "<%-%- current", "inspector.tab: marks the current window in the layout")

    -- ================================================================ cursor.state

    local cursor_state = require("debugging.tools.cursor.state")
    reset()
    cursor_state.print()
    H.match(last(), "Cursor Debug State", "cursor.state.print: reports the header")
    H.match(last(), "Window Tag", "cursor.state.print: reports the current window's tag")
    H.match(last(), "All Windows", "cursor.state.print: lists every window")

    -- =================================================================== vardump

    local vardump = require("debugging.tools.vardump")

    _G.__debugging_spec_var = { a = 1, nested = { b = 2 } }
    reset()
    vardump.dump("__debugging_spec_var")
    H.match(last(), "Variable '__debugging_spec_var'", "vardump.dump: reports the variable name")
    H.match(last(), "nested", "vardump.dump: dumps the value recursively")
    _G.__debugging_spec_var = nil

    -- No name given and no word under the cursor (blank line): warns instead
    -- of raising or silently dumping the wrong thing.
    local vbuf = H.scratch("vardump_spec.txt")
    vim.api.nvim_buf_set_lines(vbuf, 0, -1, false, { "   " })
    vim.api.nvim_win_set_cursor(0, { 1, 1 })
    reset()
    vardump.dump(nil)
    H.match(
      last(),
      "No variable provided and no word under cursor",
      "vardump.dump: warns when there is nothing to dump"
    )

    -- No name given, but a word sits under the cursor: that word is dumped.
    vim.api.nvim_buf_set_lines(vbuf, 0, -1, false, { "helloworld" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    reset()
    vardump.dump(nil)
    H.match(
      last(),
      "Variable 'helloworld'",
      "vardump.dump: falls back to the word under the cursor"
    )

    -- get_word_under_cursor() matches Lua's `%w+` (alnum only -- no
    -- underscore), so on a snake_case identifier it only grabs the first
    -- segment. Not necessarily wrong (word-boundary definitions vary), but
    -- worth pinning: `:Debug dump` with the cursor on a snake_case name
    -- silently dumps a *different, truncated* global instead of the one
    -- under the cursor.
    vim.api.nvim_buf_set_lines(vbuf, 0, -1, false, { "hello_from_cursor" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    reset()
    vardump.dump(nil)
    H.match(
      last(),
      "Variable 'hello'",
      "vardump.dump: on a snake_case word, only the segment before '_' is used"
    )

    -- ================================================================= proc_trace

    package.loaded["debugging.tools.proc_trace"] = nil
    local orig_trace = package.loaded["lib.nvim.system.proc_trace"]

    local trace_calls = {}
    package.loaded["lib.nvim.system.proc_trace"] = {
      start = function(opts)
        trace_calls[#trace_calls + 1] = { fn = "start", opts = opts }
        return { path = "/tmp/proc.log" }
      end,
      stop = function()
        trace_calls[#trace_calls + 1] = { fn = "stop" }
        return { path = "/tmp/proc.log" }
      end,
      is_active = function()
        return true
      end,
      log_path = function()
        return "/tmp/proc.log"
      end,
    }

    local proc_trace = require("debugging.tools.proc_trace")

    proc_trace.start({})
    H.eq(trace_calls[1].fn, "start", "proc_trace.start: reaches the underlying tracer")
    H.eq(trace_calls[1].opts, nil, "proc_trace.start: no threshold arg -> nil opts")

    proc_trace.start({ "250" })
    H.eq(trace_calls[2].opts.threshold_ms, 250, "proc_trace.start: numeric threshold is parsed")

    reset()
    proc_trace.start({ "not-a-number" })
    -- notify.warn (the bad-threshold message) fires before notify.info
    -- ("tracing active -> ..."), so it is seen[1], not the last message.
    H.match(
      seen[1] and seen[1].msg or "",
      "ignoring non%-numeric threshold_ms",
      "proc_trace.start: warns on a bad threshold"
    )
    H.eq(trace_calls[3].opts, nil, "proc_trace.start: bad threshold still starts with nil opts")

    reset()
    proc_trace.stop()
    H.match(last(), "stopped %(log: /tmp/proc%.log%)", "proc_trace.stop: reports the log path")

    reset()
    proc_trace.status()
    H.match(last(), "active=true", "proc_trace.status: reports active state")
    H.match(last(), "/tmp/proc%.log", "proc_trace.status: reports the log path")

    -- open_log(): no readable log yet -> warns instead of opening a buffer.
    package.loaded["lib.nvim.system.proc_trace"].log_path = function()
      return "/does/not/exist.log"
    end
    reset()
    proc_trace.open_log()
    H.match(last(), "no proc_trace log yet", "proc_trace.open_log: warns when there is no log")

    -- open_log(): a real, readable log opens in a scratch tab.
    local log_path = vim.fn.tempname() .. ".log"
    vim.fn.writefile({ "line one", "line two" }, log_path)
    package.loaded["lib.nvim.system.proc_trace"].log_path = function()
      return log_path
    end
    local tabs_before = #vim.api.nvim_list_tabpages()
    proc_trace.open_log()
    H.eq(#vim.api.nvim_list_tabpages(), tabs_before + 1, "proc_trace.open_log: opens a new tab")
    -- Both sides through H.realpath: `:edit` hands the buffer a name Neovim
    -- has already canonicalized, while `log_path` is a raw `tempname()` that
    -- never went through the editor. On macOS those are the same file spelled
    -- two ways (`/var/...` vs `/private/var/...`), and normalizing separators
    -- alone does not reconcile them.
    H.eq(
      H.realpath(vim.api.nvim_buf_get_name(0)),
      H.realpath(vim.fn.fnamemodify(log_path, ":p")),
      "proc_trace.open_log: opens the actual log file"
    )
    vim.cmd("tabclose")
    vim.fn.delete(log_path)

    package.loaded["lib.nvim.system.proc_trace"] = orig_trace
    package.loaded["debugging.tools.proc_trace"] = nil
  end)

  vim.notify = orig_notify
  if not ok then
    error(err, 0)
  end
end
