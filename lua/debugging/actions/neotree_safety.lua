---@module 'debugging.actions.neotree_safety'
--- Neo-tree watcher-quarantine / backup / dry-run / queue helpers.
---
--- This module bridges to a user-specific Neo-tree safety layer. The two
--- targets — the watcher-quarantine module and the safety module — are
--- injectable via `config.neotree` (see `config/DEFAULTS.lua`): each may be a
--- module name to `require`, or an already-loaded table passed in directly.
--- The defaults point at `config.neotree.watcher_quarantine` /
--- `config.neotree.safety`, which live in the user's own config, not in this
--- plugin — so every access is pcall-guarded and degrades gracefully with a
--- clear notification instead of erroring when the target is absent.
---
--- Opt-in only (disabled by default) — see `config/DEFAULTS.lua`.

local notify = require("lib.nvim.notify").create("[debugging.actions.neotree_safety]")
local config = require("debugging.config")

local M = {}

---@internal
---Resolve one of the injectable neotree targets.
--- The config value is either a table (used as-is) or a module name to
--- `require`. Notifies and returns nil when the target cannot be resolved.
---@param key "quarantine"|"safety"
---@return table|nil
local function need(key)
  local target = (config.get().neotree or {})[key]
  if type(target) == "table" then
    return target
  end
  if type(target) ~= "string" then
    notify.warn(("neotree.%s is not configured (set it to a module name or table)"):format(key))
    return nil
  end
  local ok, m = pcall(require, target)
  if not ok or type(m) ~= "table" then
    notify.warn(
      ("'%s' not found — Neo-tree integration is config-specific and not present here"):format(
        target
      )
    )
    return nil
  end
  return m
end

---@internal
---Run an operation against an injected neotree target, guarding against a
---target of unexpected shape (missing/misnamed fields, wrong types) so a
---malformed injection degrades to a notification instead of an uncaught
---error, matching the module's pcall-guarantee.
---@param label string
---@param fn fun()
local function guarded(label, fn)
  local ok, err = pcall(fn)
  if not ok then
    notify.warn(("neotree.%s: unexpected error — %s"):format(label, err))
  end
end

---@return nil
function M.quarantine_status()
  local wq = need("quarantine")
  if not wq then
    return
  end
  guarded("quarantine_status", function()
    local in_q = wq.is_quarantined()
    local healthy, reason = wq.health_check()
    notify.info(
      string.format(
        "Quarantine Status:\n  Active: %s\n  Watchers Healthy: %s%s",
        in_q and "YES" or "NO",
        healthy and "YES" or "NO",
        reason and ("\n  Reason: " .. reason) or ""
      )
    )
  end)
end

---@return nil
function M.quarantine_exit()
  local wq = need("quarantine")
  if not wq then
    return
  end
  guarded("quarantine_exit", function()
    wq.exit_quarantine()
    notify.info("Quarantine exited manually")
  end)
end

---@return nil
function M.restart_watchers()
  local wq = need("quarantine")
  if not wq then
    return
  end
  guarded("restart_watchers", function()
    local ok, msg = wq.restart_watchers()
    if ok then
      notify.info("Watchers restarted")
    else
      notify.warn("Failed to restart watchers: " .. (msg or "unknown"))
    end
  end)
end

---@return nil
function M.backup_list()
  local safety = need("safety")
  if not safety then
    return
  end
  guarded("backup_list", function()
    safety.backup.show_backup_ui()
  end)
end

---@return nil
function M.backup_clean()
  local safety = need("safety")
  if not safety then
    return
  end
  guarded("backup_clean", function()
    local cleaned = safety.backup.clean_old_backups(7)
    notify.info(string.format("Cleaned %d old backups", cleaned))
  end)
end

---@return nil
function M.dryrun_toggle()
  local safety = need("safety")
  if not safety then
    return
  end
  guarded("dryrun_toggle", function()
    safety.dry_run.toggle()
  end)
end

---@return nil
function M.dryrun_report()
  local safety = need("safety")
  if not safety then
    return
  end
  guarded("dryrun_report", function()
    safety.dry_run.show_report()
  end)
end

---@return nil
function M.queue_status()
  local safety = need("safety")
  if not safety then
    return
  end
  guarded("queue_status", function()
    notify.info(vim.inspect(safety.queue.status()))
  end)
end

---@return nil
function M.queue_clear()
  local safety = need("safety")
  if not safety then
    return
  end
  guarded("queue_clear", function()
    safety.queue.clear()
    notify.info("Queue cleared")
  end)
end

return M
