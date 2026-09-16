-- TESTS/views_spec.lua
-- Covers `debugging.views` (the setup()/getter merge logic, not the
-- command-executing action functions -- see TESTS/README.md), `views.utils`
-- (the window focus/scroll primitives), `views.display`'s `clear_all` and
-- tag-lookup wrappers, and `views.capture.clipboard` (stubbed against a fake
-- `lib.nvim.cross.copy_to_clipboard`).

return function(H)
  local orig_notify = vim.notify

  local ok, err = pcall(function()
    -- ====================================================================== init

    do
      local views = require("debugging.views")

      local baseline = vim.deepcopy(views.get_timings())

      views.setup({ timings = { delay_messages_ms = 12345 } })
      H.eq(views.get_timings().delay_messages_ms, 12345, "views.setup: timings key is overridden")
      H.eq(
        views.get_timings().delay_noice_ms,
        baseline.delay_noice_ms,
        "views.setup: sibling timing keys are preserved"
      )

      -- NOTE (documented behaviour, not a bug): unlike debugging.config.setup(),
      -- which deep-copies a fresh DEFAULTS table on every call, views.setup()
      -- merges onto whatever _timings/_keymaps_cfg/_autocmds_cfg already hold.
      -- A second call with no `timings` key does NOT revert the override --
      -- it accumulates. Harmless in practice because debugging.init's `_done`
      -- guard means the real setup() path only ever calls this once, but worth
      -- pinning so a future change of that guard is a deliberate decision.
      views.setup({})
      H.eq(
        views.get_timings().delay_messages_ms,
        12345,
        "views.setup: repeated calls accumulate rather than reset to hardcoded defaults"
      )

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

    -- ===================================================================== utils

    do
      local utils = require("debugging.views.utils")

      H.eq(utils.is_target_view(999999), false, "utils.is_target_view: invalid buffer is false")

      local msg_buf = H.scratch("views_utils_messages.spec")
      vim.bo[msg_buf].filetype = "messages"
      H.eq(utils.is_target_view(msg_buf), true, "utils.is_target_view: filetype=messages matches")

      local noice_buf = H.scratch("views_utils_noice.spec")
      vim.bo[noice_buf].filetype = "noice"
      H.eq(
        utils.is_target_view(noice_buf),
        true,
        "utils.is_target_view: filetype=noice with buftype nofile/empty matches"
      )

      local other_buf = H.scratch("views_utils_other.spec")
      vim.bo[other_buf].filetype = "lua"
      H.eq(
        utils.is_target_view(other_buf),
        false,
        "utils.is_target_view: an unrelated filetype is false"
      )

      vim.cmd("vsplit")
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, msg_buf)
      vim.api.nvim_buf_set_lines(msg_buf, 0, -1, false, { "one", "two", "three" })
      vim.api.nvim_win_set_cursor(win, { 1, 0 })

      utils.ensure_bottom(win, 1, 10)
      H.eq(
        vim.api.nvim_win_get_cursor(win)[1],
        3,
        "utils.ensure_bottom: cursor moves to the last line"
      )

      local floating = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
        relative = "editor",
        row = 0,
        col = 0,
        width = 10,
        height = 3,
        focusable = false,
      })
      H.eq(utils.make_focusable(floating), true, "utils.make_focusable: reports success")
      H.eq(
        vim.api.nvim_win_get_config(floating).focusable,
        true,
        "utils.make_focusable: actually flips a non-focusable float to focusable"
      )
      vim.api.nvim_win_close(floating, true)

      H.eq(utils.force_focus(win), true, "utils.force_focus: switches to a valid window")
      H.eq(vim.api.nvim_get_current_win(), win, "utils.force_focus: the window is now current")

      H.eq(utils.force_focus(999999), false, "utils.force_focus: an invalid window reports failure")
      H.eq(
        utils.make_focusable(999999),
        false,
        "utils.make_focusable: an invalid window reports failure"
      )

      vim.api.nvim_win_set_cursor(win, { 1, 0 })
      utils.focus_and_bottom(win, 1, 10)
      H.eq(
        vim.api.nvim_win_get_cursor(win)[1],
        3,
        "utils.focus_and_bottom: also moves cursor to bottom"
      )

      vim.cmd("only")
    end

    -- =================================================================== display

    do
      local display = require("debugging.views.display")
      local window_tag = require("lib.nvim.window").tag

      vim.cmd("vsplit")
      local tagged_win = vim.api.nvim_get_current_win()
      window_tag.set(tagged_win, "messages")
      vim.cmd("vsplit")
      local other_win = vim.api.nvim_get_current_win()

      H.eq(
        display.find_window_by_tag("messages"),
        tagged_win,
        "display.find_window_by_tag: finds it"
      )
      H.eq(display.get_window_tag(tagged_win), "messages", "display.get_window_tag: reads it back")
      H.eq(display.get_window_tag(other_win), nil, "display.get_window_tag: untagged window is nil")

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
