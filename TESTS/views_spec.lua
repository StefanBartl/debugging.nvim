-- TESTS/views_spec.lua
-- Covers `debugging.views` (the setup()/getter merge logic, not the
-- command-executing action functions -- see TESTS/README.md),
-- `views.display`'s `clear_all` and tag-lookup wrappers, and
-- `views.capture.clipboard` (stubbed against a fake
-- `lib.nvim.cross.copy_to_clipboard`).

return function(H)
  local orig_notify = vim.notify

  local ok, err = pcall(function()
    -- ====================================================================== init

    do
      local views = require("debugging.views")

      -- The tag-refresh machinery (timings, autocmds config) was removed:
      -- views neither resolves nor exposes either any more.
      H.eq(views.get_timings, nil, "views: get_timings is gone")
      H.eq(views.get_autocmds_config, nil, "views: get_autocmds_config is gone")

      views.setup({ keymaps = { prefix = "<Space>d" } })
      H.eq(
        views.get_keymaps_config().prefix,
        "<Space>d",
        "views.setup: keymaps.prefix is overridden"
      )
      H.eq(
        views.get_keymaps_config().enable,
        true,
        "views.setup: keymaps.enable survives the merge"
      )

      -- capture.base_dir is only overridden when BOTH `capture` and
      -- `output_dir` are truthy -- either alone leaves it untouched.
      local capture = require("debugging.views.capture")
      local orig_base_dir = capture.base_dir

      views.setup({ capture = true, output_dir = nil })
      H.eq(
        capture.base_dir,
        orig_base_dir,
        "views.setup: capture=true alone does not move base_dir"
      )

      views.setup({ capture = false, output_dir = "/tmp/debugging-spec-unused" })
      H.eq(capture.base_dir, orig_base_dir, "views.setup: output_dir alone does not move base_dir")

      views.setup({ capture = true, output_dir = "/tmp/debugging-spec-out" })
      H.eq(
        capture.base_dir,
        "/tmp/debugging-spec-out",
        "views.setup: capture=true + output_dir together move base_dir"
      )

      capture.base_dir = orig_base_dir
    end

    -- =================================================================== display

    do
      local display = require("debugging.views.display")
      local window_tag = require("lib.nvim.window").tag

      vim.cmd("vsplit")
      local tagged_win = vim.api.nvim_get_current_win()
      window_tag.set(tagged_win, "recent_messages")
      vim.cmd("vsplit")
      local other_win = vim.api.nvim_get_current_win()

      H.eq(
        display.find_window_by_tag("recent_messages"),
        tagged_win,
        "display.find_window_by_tag: finds it"
      )
      H.eq(
        display.get_window_tag(tagged_win),
        "recent_messages",
        "display.get_window_tag: reads it back"
      )
      H.eq(display.get_window_tag(other_win), nil, "display.get_window_tag: untagged window is nil")

      H.eq(display.refresh_log_view, nil, "display: refresh_log_view is gone")

      display.clear_all()
      H.eq(
        vim.api.nvim_win_is_valid(tagged_win),
        false,
        "display.clear_all: closes the tagged window"
      )
      H.eq(
        vim.api.nvim_win_is_valid(other_win),
        true,
        "display.clear_all: leaves the untagged window open"
      )

      vim.cmd("only")
    end

    -- ========================================================== capture.clipboard

    do
      package.loaded["debugging.views.capture.clipboard"] = nil
      local orig_copy = package.loaded["lib.nvim.cross.copy_to_clipboard"]

      local last_text
      package.loaded["lib.nvim.cross.copy_to_clipboard"] = function(text)
        last_text = text
        return true
      end
      local clip_ok = require("debugging.views.capture.clipboard")

      local seen = {}
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.notify = function(msg)
        seen[#seen + 1] = tostring(msg)
      end

      H.eq(clip_ok("hello", false), true, "capture.clipboard: returns the underlying result")
      H.eq(last_text, "hello", "capture.clipboard: forwards the text unchanged")
      H.eq(#seen, 0, "capture.clipboard: debug=false notifies nothing")

      H.eq(clip_ok("hello", true), true, "capture.clipboard: still returns true with debug=true")
      H.match(seen[1], "clipboard write ok", "capture.clipboard: debug=true reports success")

      package.loaded["lib.nvim.cross.copy_to_clipboard"] = function()
        return false
      end
      package.loaded["debugging.views.capture.clipboard"] = nil
      local clip_fail = require("debugging.views.capture.clipboard")
      seen = {}
      clip_fail("x", true)
      H.match(
        seen[1],
        "clipboard write failed",
        "capture.clipboard: debug=true reports failure too"
      )

      package.loaded["lib.nvim.cross.copy_to_clipboard"] = orig_copy
      package.loaded["debugging.views.capture.clipboard"] = nil
      require("debugging.views.capture.clipboard") -- restore the real module
    end
  end) -- pcall

  vim.notify = orig_notify
  if not ok then
    error(err, 0)
  end
end
