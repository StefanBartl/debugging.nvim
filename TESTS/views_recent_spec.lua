-- TESTS/views_recent_spec.lua
-- Covers `debugging.views.recent`: filter -> lib.nvim.messages.snapshot()
-- levels mapping, the ui.kit.message_log path (stubbed -- ui.nvim is not on
-- this suite's rtp) vs. the lib.nvim.output.viewer fallback, window-tag
-- reuse (focus instead of reopening), the live on_message subscription
-- respecting the filter, and unsubscribe-on-close.

return function(H)
  local eq, ok = H.eq, H.ok
  local orig_notify = vim.notify

  local run_ok, err = pcall(function()
    package.loaded["debugging.views.recent"] = nil

    -- A fake lib.nvim.messages: records every snapshot() call's opts,
    -- exposes a single on_message listener for the test to drive directly
    -- (push isn't needed -- the real module's push/ring/kind logic has its
    -- own suite in lib.nvim).
    local snapshot_calls = {}
    local listener
    local orig_messages = package.loaded["lib.nvim.messages"]
    package.loaded["lib.nvim.messages"] = {
      snapshot = function(opts)
        snapshot_calls[#snapshot_calls + 1] = opts
        return opts.entries_to_return or {}
      end,
      on_message = function(fn)
        listener = fn
        return fn
      end,
      off_message = function(fn)
        if listener == fn then
          listener = nil
        end
      end,
    }

    local orig_views = package.loaded["debugging.views"]
    package.loaded["debugging.views"] = {
      get_recent_config = function()
        return { window_s = 10, order = "newest_last", collapsed_default = false }
      end,
    }

    -- ============================================================= fallback
    -- ui.kit genuinely is not installed in this test env -- require("ui.kit")
    -- fails for real, exercising the actual fallback branch, not a stub of it.
    do
      snapshot_calls = {}
      local seen = {}
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.notify = function(msg, level)
        seen[#seen + 1] = { msg = tostring(msg), level = level }
      end

      local orig_viewer = package.loaded["lib.nvim.output.viewer"]
      local dumped
      local fallback_bufnr = vim.api.nvim_create_buf(false, true)
      local fallback_winid = vim.api.nvim_open_win(fallback_bufnr, false, {
        relative = "editor",
        row = 0,
        col = 0,
        width = 10,
        height = 3,
      })
      package.loaded["lib.nvim.output.viewer"] = {
        show_lines = function(title, lines, opts)
          dumped = { title = title, lines = lines, opts = opts }
          return { winid = fallback_winid, bufnr = fallback_bufnr }
        end,
      }

      local recent = require("debugging.views.recent")
      recent.show("error")

      eq(snapshot_calls[1].levels[1], vim.log.levels.ERROR, "error filter: only ERROR level")
      ok(dumped ~= nil, "no ui.kit: falls back to lib.nvim.output.viewer.show_lines")
      eq(dumped.lines[1], "(no messages)", "fallback: empty snapshot shows the placeholder line")
      ok(#seen > 0, "fallback: notifies that live updates/pagination are unavailable")

      -- A 1-line snapshot ("(no messages)" or a single entry) must still ask
      -- for at least a 2-row window -- lib.nvim.window.tag.find() requires
      -- height > 1 strictly, so a literal height=1 window would be tagged
      -- but never findable, silently defeating the tagging above.
      ok(dumped.opts ~= nil, "show_lines was called with an opts table")
      ok(dumped.opts.height >= 2, "height is floored at 2 even for a 1-line snapshot")

      -- The fallback window must be tagged too -- otherwise display.clear_all()
      -- (the `<x>` cleanup) and M.show()'s own reuse check silently don't see
      -- it, since both only ever look through lib.nvim.window.tag.
      local window_tag = require("lib.nvim.window").tag
      eq(
        window_tag.get(fallback_winid),
        "recent_errors",
        "the fallback popup's window is tagged too"
      )

      pcall(vim.api.nvim_win_close, fallback_winid, true)
      package.loaded["lib.nvim.output.viewer"] = orig_viewer
    end

    -- ===================================================== fallback multiline
    -- Multi-line contents (Lua errors, stack traces) must be split before they
    -- reach the viewer, which rejects embedded newlines; the height follows the
    -- split line count, not the entry count.
    do
      local orig_viewer = package.loaded["lib.nvim.output.viewer"]
      local dumped
      package.loaded["lib.nvim.output.viewer"] = {
        show_lines = function(_, lines, opts)
          dumped = { lines = lines, opts = opts }
        end,
      }
      local now_ms = vim.uv.hrtime() / 1e6
      local entries = {
        { content = "a\nb", level = 2, time_ms = now_ms },
        { content = "c\r\nd\r\ne", level = 2, time_ms = now_ms },
        { content = "f\n", level = 2, time_ms = now_ms },
      }
      local fake_messages = package.loaded["lib.nvim.messages"]
      local orig_snapshot = fake_messages.snapshot
      fake_messages.snapshot = function()
        return entries
      end
      require("debugging.views.recent").show("all")
      ok(dumped ~= nil, "multiline: show_lines is reached without error")
      eq(#dumped.lines, 6, "multiline: 2 + 3 + 1 lines (CRLF split, trailing newline dropped)")
      for _, line in ipairs(dumped.lines) do
        ok(not line:find("[\r\n]"), "multiline: no line holds a newline")
      end
      ok(dumped.lines[1]:find("^%[%ds ago%] a$") ~= nil, "multiline: age prefix on the first line")
      ok(dumped.lines[2]:find("^%s+b$") ~= nil, "multiline: continuation line is indented")
      eq(dumped.opts.height, 6, "multiline: height follows the split line count")
      fake_messages.snapshot = orig_snapshot
      package.loaded["lib.nvim.output.viewer"] = orig_viewer
    end

    -- ============================================================ non_error
    do
      snapshot_calls = {}
      local recent = require("debugging.views.recent")

      local orig_viewer = package.loaded["lib.nvim.output.viewer"]
      package.loaded["lib.nvim.output.viewer"] = { show_lines = function() end }
      recent.show("non_error")
      local levels = snapshot_calls[1].levels
      local has_error = false
      for _, l in ipairs(levels) do
        if l == vim.log.levels.ERROR then
          has_error = true
        end
      end
      eq(has_error, false, "non_error filter: ERROR is excluded")
      eq(#levels, 4, "non_error filter: the other four levels are included")
      package.loaded["lib.nvim.output.viewer"] = orig_viewer
    end

    -- ================================================================== all
    do
      snapshot_calls = {}
      local orig_viewer = package.loaded["lib.nvim.output.viewer"]
      package.loaded["lib.nvim.output.viewer"] = { show_lines = function() end }
      require("debugging.views.recent").show("all")
      eq(snapshot_calls[1].levels, nil, "all filter: no levels restriction")
      package.loaded["lib.nvim.output.viewer"] = orig_viewer
    end

    -- ======================================================= unknown filter
    do
      local seen = {}
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.notify = function(msg, level)
        seen[#seen + 1] = { msg = tostring(msg), level = level }
      end
      ok(pcall(require("debugging.views.recent").show, "bogus"), "an unknown filter does not raise")
      ok(#seen > 0, "an unknown filter is reported via notify.warn")
    end

    -- ============================================== window-tag reuse (real window)
    do
      local window_tag = require("lib.nvim.window").tag
      vim.cmd("vsplit")
      local win = vim.api.nvim_get_current_win()
      window_tag.set(win, "recent_messages")

      local open_calls = 0
      package.loaded["ui.kit"] = {
        message_log = function()
          open_calls = open_calls + 1
          return nil
        end,
      }

      require("debugging.views.recent").show("non_error")
      eq(open_calls, 0, "an already-open tagged window is focused, not reopened")
      eq(vim.api.nvim_get_current_win(), win, "focus actually moved to the existing window")

      vim.cmd("only")
      package.loaded["ui.kit"] = nil
    end

    -- ===================================== ui.kit.message_log path (stubbed)
    do
      vim.cmd("only")
      local fake_bufnr = vim.api.nvim_create_buf(false, true)
      local fake_winid = vim.api.nvim_open_win(fake_bufnr, false, {
        relative = "editor",
        row = 0,
        col = 0,
        width = 10,
        height = 3,
      })

      local open_opts
      local appended = {}
      local close_cb
      local fake_handle = {
        surf = { winid = fake_winid, bufnr = fake_bufnr },
        append = function(_, entries)
          for _, e in ipairs(entries) do
            appended[#appended + 1] = e
          end
        end,
        on_close = function(_, cb)
          close_cb = cb
        end,
      }
      package.loaded["ui.kit"] = {
        message_log = function(opts)
          open_opts = opts
          return fake_handle
        end,
      }

      snapshot_calls = {}
      require("debugging.views.recent").show("error")

      ok(open_opts ~= nil, "ui.kit.message_log.open is called when ui.kit is present")
      eq(open_opts.title, "Recent errors", "error filter: title mentions errors")
      ok(type(open_opts.load_more) == "function", "load_more callback is wired")

      -- The window-tag primitive is reused here too, not reimplemented --
      -- same lib.nvim.window.tag the display.lua path already relies on.
      local window_tag = require("lib.nvim.window").tag
      eq(window_tag.get(fake_winid), "recent_errors", "the new popup's window is tagged")

      -- Live feed: the on_message listener only appends entries matching
      -- this view's filter.
      ok(listener ~= nil, "recent.show subscribed to lib.nvim.messages.on_message")
      listener({ level = vim.log.levels.ERROR, content = "boom" })
      eq(#appended, 1, "a matching live entry is appended")
      listener({ level = vim.log.levels.INFO, content = "ignored" })
      eq(#appended, 1, "a non-matching live entry is NOT appended")

      -- load_more("older") extends the window and does not touch "newer".
      local before = #snapshot_calls
      open_opts.load_more("newer")
      eq(#snapshot_calls, before, "load_more('newer') does not query the store")
      open_opts.load_more("older")
      eq(#snapshot_calls, before + 1, "load_more('older') queries for an earlier window")

      -- on_close unsubscribes.
      ok(close_cb ~= nil, "on_close callback was registered")
      close_cb()
      ok(listener == nil, "closing the popup unsubscribes from lib.nvim.messages")

      pcall(vim.api.nvim_win_close, fake_winid, true)
      package.loaded["ui.kit"] = nil
    end

    package.loaded["lib.nvim.messages"] = orig_messages
    package.loaded["debugging.views"] = orig_views
    package.loaded["debugging.views.recent"] = nil
  end) -- pcall

  vim.notify = orig_notify
  if not run_ok then
    error(err, 0)
  end
end
