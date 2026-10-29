-- TESTS/bindings_spec.lua
-- Covers `debugging.bindings.*`: the top-level orchestrator's features.views
-- gate, the views keymaps' action wiring (driven end to end through a real
-- lib.nvim.bindings.keymap registration), the proof that the retired views
-- autocmds (WinEnter/BufWinEnter refresh, FileType close) are really gone,
-- and the one bit of
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

      local usercmds_calls, views_calls, keymaps_calls = 0, 0, 0
      package.loaded["debugging.bindings.usercmds"] = {
        setup = function()
          usercmds_calls = usercmds_calls + 1
        end,
      }
      package.loaded["debugging.views"] = {
        get_keymaps_config = function()
          views_calls = views_calls + 1
          return { enable = true }
        end,
      }
      package.loaded["debugging.bindings.keymaps"] = {
        setup = function()
          keymaps_calls = keymaps_calls + 1
        end,
      }
      package.loaded["debugging.bindings"] = nil
      local bindings = require("debugging.bindings")

      bindings.setup({ features = { views = false } })
      H.eq(usercmds_calls, 1, "bindings.setup: usercmds.setup() always runs")
      H.eq(views_calls, 0, "bindings.setup: features.views=false skips the views wiring entirely")

      bindings.setup({ features = { views = true } })
      H.eq(keymaps_calls, 1, "bindings.setup: features.views=true wires up keymaps")

      package.loaded["debugging.bindings.usercmds"] = orig_usercmds
      package.loaded["debugging.views"] = orig_views
      package.loaded["debugging.bindings.keymaps"] = orig_keymaps
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

      local bound = keymaps.setup({ enable = true, prefix = "<lt>" })

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

    -- The views subsystem used to register WinEnter/BufWinEnter (refresh a
    -- tagged window) and FileType messages/noice (bind q) autocmds in a
    -- `DebugViewsAuto` augroup. All of it was dead (nothing produces those
    -- tags or filetypes any more) and was removed outright: the plugin owns
    -- no autocmd now, and the options that configured them are unknown keys.
    do
      local views = require("debugging.views")
      local display = require("debugging.views.display")

      views.setup({})
      local cfg = require("debugging.config").get()
      require("debugging.bindings").setup(cfg)
      require("debugging.bindings").setup(cfg) -- idempotent

      local group_ok = pcall(vim.api.nvim_get_autocmds, { group = "DebugViewsAuto" })
      H.ok(not group_ok, "bindings.setup: no DebugViewsAuto augroup is created")

      H.ok(
        not pcall(require, "debugging.bindings.autocmds"),
        "bindings: the autocmds module no longer exists"
      )
      H.ok(
        not pcall(require, "debugging.views.utils"),
        "views: the utils module (is_target_view) no longer exists"
      )
      H.eq(display.refresh_log_view, nil, "display: refresh_log_view is gone")
      H.eq(views.get_autocmds_config, nil, "views: get_autocmds_config is gone")
      H.eq(views.get_timings, nil, "views: get_timings is gone")

      -- A `messages` buffer is no longer a debug view: no buffer-local `q`.
      vim.cmd("vsplit")
      local buf = vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win())
      vim.bo[buf].filetype = "messages"
      local has_q = false
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
        has_q = has_q or m.lhs == "q"
      end
      H.ok(not has_q, "bindings: FileType=messages no longer binds a close keymap")

      -- Entering a tagged window must not schedule anything: no WinEnter
      -- autocmd of this plugin is left, so no 30 ms timer is started.
      local timers = 0
      local orig_defer = vim.defer_fn
      vim.defer_fn = function(...)
        timers = timers + 1
        return orig_defer(...)
      end
      require("lib.nvim.window").tag.set(vim.api.nvim_get_current_win(), "recent_messages")
      vim.cmd("vsplit")
      vim.cmd("wincmd p")
      vim.cmd("wincmd p")
      vim.defer_fn = orig_defer
      H.eq(timers, 0, "bindings: entering a tagged window schedules no refresh")
      vim.cmd("only")
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
