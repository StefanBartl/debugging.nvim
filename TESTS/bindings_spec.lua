-- TESTS/bindings_spec.lua
-- Covers `debugging.bindings.*`: the top-level orchestrator's features.views
-- gate, the views keymaps' action wiring (driven end to end through a real
-- lib.nvim.bindings.keymap registration), the views autocmds' enable gate
-- and its FileType close-on-`q` behaviour, and the one bit of
-- `bindings.usercmds` not already exercised by handle_args_spec.lua: the
-- DBG_AUTOCMD_EXPR composer argtype actually delegating to the sources
-- completer through the real `:Debug` command.

return function(H)
  local orig_notify = vim.notify
  local seen = {}
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.notify = function(msg, level)
    seen[#seen + 1] = { msg = tostring(msg), level = level }
  end
  local function reset()
    seen = {}
  end

  local ok, err = pcall(function()
    require("debugging").setup({})

    -- ==================================================================== init

    do
      local orig_usercmds = package.loaded["debugging.bindings.usercmds"]
      local orig_views = package.loaded["debugging.views"]
      local orig_keymaps = package.loaded["debugging.bindings.keymaps"]
      local orig_autocmds = package.loaded["debugging.bindings.autocmds"]

      local usercmds_calls, views_calls, keymaps_calls, autocmds_calls = 0, 0, 0, 0
      package.loaded["debugging.bindings.usercmds"] = {
        setup = function()
          usercmds_calls = usercmds_calls + 1
        end,
      }
      package.loaded["debugging.views"] = {
        get_timings = function()
          views_calls = views_calls + 1
          return {}
        end,
        get_keymaps_config = function()
          return { enable = true }
        end,
        get_autocmds_config = function()
          return { enable = true }
        end,
      }
      package.loaded["debugging.bindings.keymaps"] = {
        setup = function()
          keymaps_calls = keymaps_calls + 1
        end,
      }
      package.loaded["debugging.bindings.autocmds"] = {
        setup = function()
          autocmds_calls = autocmds_calls + 1
        end,
      }
      package.loaded["debugging.bindings"] = nil
      local bindings = require("debugging.bindings")

      bindings.setup({ features = { views = false } })
      H.eq(usercmds_calls, 1, "bindings.setup: usercmds.setup() always runs")
      H.eq(views_calls, 0, "bindings.setup: features.views=false skips the views wiring entirely")

      bindings.setup({ features = { views = true } })
      H.eq(keymaps_calls, 1, "bindings.setup: features.views=true wires up keymaps")
      H.eq(autocmds_calls, 1, "bindings.setup: features.views=true wires up autocmds")

      package.loaded["debugging.bindings.usercmds"] = orig_usercmds
      package.loaded["debugging.views"] = orig_views
      package.loaded["debugging.bindings.keymaps"] = orig_keymaps
      package.loaded["debugging.bindings.autocmds"] = orig_autocmds
      package.loaded["debugging.bindings"] = nil
      require("debugging.bindings") -- restore the real module
    end

    -- ================================================================= keymaps

    do
      local keymaps = require("debugging.bindings.keymaps")
      local capture = require("debugging.views.capture")
      local display = require("debugging.views.display")

      local capture_calls = {}
      local orig_capture_messages = capture.capture_messages
      capture.capture_messages = function(opts)
        capture_calls[#capture_calls + 1] = opts
        return true, "content", "ok"
      end
      local clear_calls = 0
      local orig_clear_all = display.clear_all
      display.clear_all = function()
        clear_calls = clear_calls + 1
      end

      local timings = { attempts = 3, retry_delay_ms = 60 }
      local bound = keymaps.setup({ enable = true, prefix = "<lt>" }, timings)

      local function find(name)
        for _, entry in ipairs(bound) do
          if entry.name == name then
            return entry
          end
        end
        return nil
      end

      local capture_entry = find("capture")
      capture_entry.rhs()
      local plain_call = capture_calls[#capture_calls]
      H.eq(plain_call.debug, false, "keymaps: 'capture' does not turn on debug diagnostics")
      H.eq(
        plain_call.clipboard,
        nil,
        "keymaps: 'capture' leaves clipboard at its capture_messages default"
      )
      H.eq(
        plain_call.save_file,
        nil,
        "keymaps: 'capture' leaves save_file at its capture_messages default"
      )

      find("capture_file").rhs()
      H.eq(
        capture_calls[#capture_calls].clipboard,
        false,
        "keymaps: 'capture_file' disables the clipboard sink"
      )

      find("capture_clipboard").rhs()
      H.eq(
        capture_calls[#capture_calls].save_file,
        false,
        "keymaps: 'capture_clipboard' disables the file sink"
      )

      reset()
      find("clear").rhs()
      H.eq(clear_calls, 1, "keymaps: 'clear' calls display.clear_all()")

      capture.capture_messages = orig_capture_messages
      display.clear_all = orig_clear_all
    end

    -- ================================================================ autocmds

    do
      local bindings_autocmds = require("debugging.bindings.autocmds")
      local timings = { attempts = 1, retry_delay_ms = 10 }

      -- enable = false: no augroup is created at all.
      local disabled_ok = pcall(
        bindings_autocmds.setup,
        { enable = false, group_name = "DebuggingBindingsSpecOff" },
        timings
      )
      H.ok(disabled_ok, "bindings.autocmds.setup: enable=false does not error")
      local group_missing_ok =
        pcall(vim.api.nvim_get_autocmds, { group = "DebuggingBindingsSpecOff" })
      H.ok(not group_missing_ok, "bindings.autocmds.setup: enable=false creates no augroup")

      ---@param cmds table[]
      ---@return table<string, integer>
      local function count_by_event(cmds)
        local counts = {}
        for _, c in ipairs(cmds) do
          counts[c.event] = (counts[c.event] or 0) + 1
        end
        return counts
      end

      -- enable = true, auto_refresh = false: only the FileType close-on-q
      -- autocmd -- registered with a 2-element pattern list, which
      -- nvim_get_autocmds reports as one row per pattern, hence ">= 1"
      -- rather than an exact count tied to that implementation detail.
      bindings_autocmds.setup(
        { enable = true, auto_refresh = false, group_name = "DebuggingBindingsSpecA" },
        timings
      )
      local a_counts =
        count_by_event(vim.api.nvim_get_autocmds({ group = "DebuggingBindingsSpecA" }))
      H.ok(
        (a_counts.FileType or 0) >= 1,
        "bindings.autocmds.setup: auto_refresh=false registers the FileType autocmd"
      )
      H.eq(a_counts.WinEnter, nil, "bindings.autocmds.setup: auto_refresh=false skips WinEnter")
      H.eq(
        a_counts.BufWinEnter,
        nil,
        "bindings.autocmds.setup: auto_refresh=false skips BufWinEnter"
      )

      -- The FileType autocmd calls lib.nvim.window.nice_quit, which does not
      -- close the window itself -- it *binds* q/<Esc> (buffer-local, Normal
      -- mode) to close it. So the observable effect is a new buffer-local
      -- keymap, not an immediate close.
      vim.cmd("vsplit")
      local win = vim.api.nvim_get_current_win()
      local buf = vim.api.nvim_win_get_buf(win)
      vim.bo[buf].filetype = "messages"

      local function has_close_keymap()
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
          if m.lhs == "q" then
            return true
          end
        end
        return false
      end
      H.ok(
        has_close_keymap(),
        "bindings.autocmds: FileType=messages binds a buffer-local 'q' to close"
      )

      -- Pressing it actually closes the window (nice_quit's real job).
      local wins_before = #vim.api.nvim_list_wins()
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("q", true, false, true), "x", false)
      H.eq(
        #vim.api.nvim_list_wins(),
        wins_before - 1,
        "bindings.autocmds: pressing 'q' closes the window"
      )

      -- enable = true, auto_refresh = true: WinEnter + BufWinEnter + FileType.
      bindings_autocmds.setup(
        { enable = true, auto_refresh = true, group_name = "DebuggingBindingsSpecB" },
        timings
      )
      local b_counts =
        count_by_event(vim.api.nvim_get_autocmds({ group = "DebuggingBindingsSpecB" }))
      H.eq(b_counts.WinEnter, 1, "bindings.autocmds.setup: auto_refresh=true registers WinEnter")
      H.eq(
        b_counts.BufWinEnter,
        1,
        "bindings.autocmds.setup: auto_refresh=true registers BufWinEnter"
      )
      H.ok(
        (b_counts.FileType or 0) >= 1,
        "bindings.autocmds.setup: auto_refresh=true also keeps FileType"
      )

      -- Re-running setup() with the same group clears rather than stacks.
      bindings_autocmds.setup(
        { enable = true, auto_refresh = true, group_name = "DebuggingBindingsSpecB" },
        timings
      )
      local b_counts_again =
        count_by_event(vim.api.nvim_get_autocmds({ group = "DebuggingBindingsSpecB" }))
      H.eq_list(
        { b_counts_again.WinEnter, b_counts_again.BufWinEnter },
        { b_counts.WinEnter, b_counts.BufWinEnter },
        "bindings.autocmds.setup: re-running setup() does not stack duplicate autocmds"
      )

      -- Entering the (untagged) window fires WinEnter harmlessly (no tag ->
      -- early return, no display.refresh_log_view / real ':messages' call).
      vim.cmd("vsplit")
      local enter_ok = pcall(vim.cmd, "wincmd p")
      H.ok(enter_ok, "bindings.autocmds: WinEnter on an untagged window is a harmless no-op")
      vim.cmd("only")

      pcall(vim.api.nvim_del_augroup_by_name, "DebuggingBindingsSpecA")
      pcall(vim.api.nvim_del_augroup_by_name, "DebuggingBindingsSpecB")
    end

    -- =============================================================== usercmds

    -- The DBG_AUTOCMD_EXPR argtype (registered by bindings.usercmds) delegates
    -- straight to the sources completer -- exercised here through the real
    -- registered `:Debug` command, which handle_args_spec.lua does not cover.
    local sort_completions = vim.fn.getcompletion("Debug autocmds sources sort=", "cmdline")
    H.ok(
      #sort_completions > 0,
      "usercmds: 'Debug autocmds sources sort=' completes via DBG_AUTOCMD_EXPR"
    )
    local all_completions = vim.fn.getcompletion("Debug autocmds all event=", "cmdline")
    H.ok(
      #all_completions > 0,
      "usercmds: 'Debug autocmds all event=' also delegates to the completer"
    )
  end)

  vim.notify = orig_notify
  if not ok then
    error(err, 0)
  end
end
