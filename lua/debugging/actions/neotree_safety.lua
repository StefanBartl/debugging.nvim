---@module 'debugging.actions.neotree_safety'
---@brief Neo-tree watcher-quarantine / backup / dry-run / queue helpers.
---@description
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
    notify.warn(("'%s' not found — Neo-tree integration is config-specific and not present here"):format(target))
    return nil
  end
  return m
end

---@return nil
function M.quarantine_status()
  local wq = need("quarantine")
  if not wq then return end
  local in_q = wq.is_quarantined()
  local healthy, reason = wq.health_check()
  notify.info(string.format(
    "Quarantine Status:\n  Active: %s\n  Watchers Healthy: %s%s",
    in_q and "YES" or "NO",
    healthy and "YES" or "NO",
    reason and ("\n  Reason: " .. reason) or ""
  ))
end

---@return nil
function M.quarantine_exit()
  local wq = need("quarantine")
  if not wq then return end
  wq.exit_quarantine()
  notify.info("Quarantine exited manually")
end

---@return nil
function M.restart_watchers()
  local wq = need("quarantine")
  if not wq then return end
  local ok, msg = wq.restart_watchers()
  if ok then
    notify.info("Watchers restarted")
  else
    notify.warn("Failed to restart watchers: " .. (msg or "unknown"))
  end
end

---@return nil
function M.backup_list()
  local safety = need("safety")
  if not safety then return end
  safety.backup.show_backup_ui()
end

---@return nil
function M.backup_clean()
  local safety = need("safety")
  if not safety then return end
  local cleaned = safety.backup.clean_old_backups(7)
  notify.info(string.format("Cleaned %d old backups", cleaned))
end

---@return nil
function M.dryrun_toggle()
  local safety = need("safety")
  if not safety then return end
  safety.dry_run.toggle()
end

---@return nil
function M.dryrun_report()
  local safety = need("safety")
  if not safety then return end
  safety.dry_run.show_report()
end

---@return nil
function M.queue_status()
  local safety = need("safety")
  if not safety then return end
  notify.info(vim.inspect(safety.queue.status()))
end

---@return nil
function M.queue_clear()
  local safety = need("safety")
  if not safety then return end
  safety.queue.clear()
  notify.info("Queue cleared")
end

return M
