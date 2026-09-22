-- TESTS/actions_spec.lua
-- Covers `debugging.actions.*`: module_reload (path -> module name ->
-- reload), neotree_safety (the injectable table/module-name bridge), and
-- reports (the report/win id-validation branch; tab just delegates to
-- lib.nvim and is exercised for "does not error"; buf additionally gets a
-- pcall-guarded gitsuite.nvim conflict-marker check, covered here with a
-- faked module for the absent/clean/conflicted cases).

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
    -- ============================================================ module_reload

    local module_reload = require("debugging.actions.module_reload")

    -- A non-.lua buffer is rejected before any module-name lookup happens.
    H.scratch("plain.txt")
    reset()
    module_reload.reload_current()
    H.match(last(), "not a Lua file", "module_reload: non-lua buffer is rejected")

    -- A .lua buffer outside any lua/ directory has no derivable module name.
    H.scratch("/tmp/outside/nope.lua")
    reset()
    module_reload.reload_current()
    H.match(last(), "Could not determine module name", "module_reload: outside lua/ is rejected")

    -- A .lua buffer inside a real lua/ tree, naming an actually-requireable
    -- module, reloads it end to end (package.loaded cleared + re-required).
    local real_path = vim.fn.fnamemodify(
      vim.api.nvim_get_runtime_file("lua/debugging/tools/vardump/init.lua", false)[1] or "",
      ":p"
    )
    H.ok(real_path ~= "", "module_reload: fixture module is on the runtimepath")
    H.scratch(real_path)
    reset()
    module_reload.reload_current()
    H.match(
      last(),
      "Reloaded: debugging%.tools%.vardump",
      "module_reload: a real module reloads successfully"
    )
    H.ok(package.loaded["debugging.tools.vardump"] ~= nil, "module_reload: module is loaded again")

    -- ============================================================ neotree_safety

    local config = require("debugging.config")
    local neotree_safety = require("debugging.actions.neotree_safety")

    -- Default config targets are strings naming modules that do not exist in
    -- this environment ("config.neotree.*" is the user's own config, not a
    -- dependency) -- need() must degrade to a warning, not an error.
    config.setup({})
    reset()
    neotree_safety.quarantine_status()
    H.match(last(), "not found", "neotree_safety: unresolvable module name warns, not errors")

    -- A target that is neither a table nor a string (e.g. `false`) is "not
    -- configured" rather than "not found" -- a different, more accurate hint.
    config.setup({ neotree = { quarantine = false, safety = false } })
    reset()
    neotree_safety.quarantine_status()
    H.match(
      last(),
      "not configured",
      "neotree_safety: non-table/string target reports unconfigured"
    )

    -- An injected table is used as-is, with no require() involved.
    local quarantine_calls = {}
    local fake_quarantine = {
      is_quarantined = function()
        return true
      end,
      health_check = function()
        return false, "watcher died"
      end,
      exit_quarantine = function()
        quarantine_calls[#quarantine_calls + 1] = "exit"
      end,
      restart_watchers = function()
        return true
      end,
    }
    config.setup({ neotree = { quarantine = fake_quarantine } })
    reset()
    neotree_safety.quarantine_status()
    H.match(last(), "Active: YES", "neotree_safety: quarantine_status reports the injected state")
    H.match(last(), "Watchers Healthy: NO", "neotree_safety: quarantine_status reports health")
    H.match(last(), "watcher died", "neotree_safety: quarantine_status includes the reason")

    neotree_safety.quarantine_exit()
    H.eq_list(quarantine_calls, { "exit" }, "neotree_safety: quarantine_exit calls exit_quarantine")

    reset()
    neotree_safety.restart_watchers()
    H.match(last(), "Watchers restarted", "neotree_safety: restart_watchers reports success")

    fake_quarantine.restart_watchers = function()
      return false, "port busy"
    end
    reset()
    neotree_safety.restart_watchers()
    H.match(last(), "port busy", "neotree_safety: restart_watchers reports the failure reason")

    -- Safety bridge: backup / dry-run / queue helpers.
    local fake_safety = {
      backup = {
        show_backup_ui = function()
          quarantine_calls[#quarantine_calls + 1] = "backup_ui"
        end,
        clean_old_backups = function(days)
          H.eq(days, 7, "neotree_safety: backup_clean asks for 7-day retention")
          return 3
        end,
      },
      dry_run = {
        toggle = function()
          quarantine_calls[#quarantine_calls + 1] = "dryrun_toggle"
        end,
        show_report = function()
          quarantine_calls[#quarantine_calls + 1] = "dryrun_report"
        end,
      },
      queue = {
        status = function()
          return { pending = 2 }
        end,
        clear = function()
          quarantine_calls[#quarantine_calls + 1] = "queue_clear"
        end,
      },
    }
    config.setup({ neotree = { safety = fake_safety } })

    neotree_safety.backup_list()
    reset()
    neotree_safety.backup_clean()
    H.match(last(), "Cleaned 3 old backups", "neotree_safety: backup_clean reports the count")

    neotree_safety.dryrun_toggle()
    neotree_safety.dryrun_report()

    reset()
    neotree_safety.queue_status()
    H.match(last(), "pending", "neotree_safety: queue_status inspects the status table")

    neotree_safety.queue_clear()
    H.eq_list(
      quarantine_calls,
      { "exit", "backup_ui", "dryrun_toggle", "dryrun_report", "queue_clear" },
      "neotree_safety: safety bridge helpers all reached their injected target"
    )

    config.setup({}) -- leave a clean config behind

    -- ==================================================================== reports

    local reports = require("debugging.actions.reports")

    reset()
    reports.win(999999)
    H.match(last(), "Invalid window ID", "reports.win: rejects an invalid window id")

    local ok_buf = pcall(reports.buf)
    H.ok(ok_buf, "reports.buf: does not error")

    local ok_tab = pcall(reports.tab)
    H.ok(ok_tab, "reports.tab: does not error")

    local ok_win = pcall(reports.win)
    H.ok(ok_win, "reports.win: no-arg (report every window) does not error")

    local ok_win_id = pcall(reports.win, vim.api.nvim_get_current_win())
    H.ok(ok_win_id, "reports.win: valid explicit window id does not error")

    -- reports.buf: gitsuite.nvim conflict-marker check (optional, pcall-guarded)
    local saved_conflict = package.loaded["gitsuite.features.conflict"]

    package.loaded["gitsuite.features.conflict"] = nil
    local orig_preload = package.preload["gitsuite.features.conflict"]
    package.preload["gitsuite.features.conflict"] = function()
      error("no gitsuite here")
    end
    reset()
    local ok_buf_absent = pcall(reports.buf)
    H.ok(ok_buf_absent, "reports.buf: does not error without gitsuite.nvim")
    package.preload["gitsuite.features.conflict"] = orig_preload

    -- print_summary() itself notify.debug()s a "Listed buffer: N" line on
    -- every call (lib.nvim.buf_win_tab.buffer_utils, unrelated to this
    -- check) -- assert on message content, not on #seen being empty.
    local function any_match(pat)
      for _, s in ipairs(seen) do
        if s.msg:match(pat) then
          return true
        end
      end
      return false
    end

    package.loaded["gitsuite.features.conflict"] = {
      has_conflicts = function()
        return false
      end,
    }
    reset()
    pcall(reports.buf)
    H.ok(
      not any_match("unresolved merge%-conflict markers"),
      "reports.buf: no conflict warning on a clean buffer"
    )

    package.loaded["gitsuite.features.conflict"] = {
      has_conflicts = function()
        return true
      end,
    }
    reset()
    pcall(reports.buf)
    H.match(
      last(),
      "unresolved merge%-conflict markers",
      "reports.buf: warns about conflict markers"
    )

    package.loaded["gitsuite.features.conflict"] = saved_conflict
  end)

  vim.notify = orig_notify
  if not ok then
    error(err, 0)
  end
end
