---@module 'debugging.usercmds.neotree_safety'
---@brief Neo-tree watcher-quarantine / backup / dry-run / queue helpers.
---@description
--- This module bridges to a user-specific Neo-tree safety layer
--- (`config.neotree.watcher_quarantine` and `config.neotree.safety`). Those
--- modules live in the user's own config, not in this plugin, so every access is
--- pcall-guarded: if they are absent, the action degrades gracefully with a
--- clear notification instead of erroring.
---
--- Opt-in only (disabled by default) — see `config/DEFAULTS.lua`.
--- Making the bridge target injectable is a roadmap item.

local notify = require("lib.nvim.notify").create("[debugging.usercmds.neotree_safety]")

local M = {}

---Safely require a user neotree module; notifies and returns nil if missing.
---@param mod string
---@return table|nil
local function need(mod)
  local ok, m = pcall(require, mod)
  if not ok or type(m) ~= "table" then
    notify.warn(("'%s' not found — Neo-tree integration is config-specific and not present here"):format(mod))
    return nil
  end
  return m
end

---@return nil
function M.quarantine_status()
  local wq = need("config.neotree.watcher_quarantine")
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
  local wq = need("config.neotree.watcher_quarantine")
  if not wq then return end
  wq.exit_quarantine()
  notify.info("Quarantine exited manually")
end

---@return nil
function M.restart_watchers()
  local wq = need("config.neotree.watcher_quarantine")
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
  local safety = need("config.neotree.safety")
  if not safety then return end
  safety.backup.show_backup_ui()
end

---@return nil
function M.backup_clean()
  local safety = need("config.neotree.safety")
  if not safety then return end
  local cleaned = safety.backup.clean_old_backups(7)
  notify.info(string.format("Cleaned %d old backups", cleaned))
end

---@return nil
function M.dryrun_toggle()
  local safety = need("config.neotree.safety")
  if not safety then return end
  safety.dry_run.toggle()
end

---@return nil
function M.dryrun_report()
  local safety = need("config.neotree.safety")
  if not safety then return end
  safety.dry_run.show_report()
end

---@return nil
function M.queue_status()
  local safety = need("config.neotree.safety")
  if not safety then return end
  notify.info(vim.inspect(safety.queue.status()))
end

---@return nil
function M.queue_clear()
  local safety = need("config.neotree.safety")
  if not safety then return end
  safety.queue.clear()
  notify.info("Queue cleared")
end

return M
