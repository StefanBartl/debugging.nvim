---@module 'debugging.views.recent'
--- Thin dispatcher behind `<m`/`<n`/`<e` (messages/all/errors): pulls data
--- from `lib.nvim.messages`, renders it via `ui.kit.message_log` (a live,
--- paginated, collapsible popup) when ui.nvim is installed, falls back to a
--- static `lib.nvim.output.viewer` dump otherwise. Owns no window-tracking
--- of its own beyond `lib.nvim.window.tag` -- the same primitive
--- `debugging.views.display` already uses for the older command-output views.

local window_tag = require("lib.nvim.window").tag
local notify = require("lib.nvim.notify").create("[debugging.views.recent]")

local M = {}

local NON_ERROR_LEVELS = {
  vim.log.levels.TRACE,
  vim.log.levels.DEBUG,
  vim.log.levels.INFO,
  vim.log.levels.WARN,
}

---@type table<string, integer[]|nil>
local FILTER_LEVELS = {
  all = nil,
  non_error = NON_ERROR_LEVELS,
  error = { vim.log.levels.ERROR },
}

local FILTER_TAG = {
  all = "recent_all",
  non_error = "recent_messages",
  error = "recent_errors",
}

local FILTER_TITLE = {
  all = "Recent messages (all)",
  non_error = "Recent messages",
  error = "Recent errors",
}

---@internal
---@param levels integer[]|nil
---@param level integer
---@return boolean
local function level_matches(levels, level)
  if not levels then
    return true
  end
  for _, l in ipairs(levels) do
    if l == level then
      return true
    end
  end
  return false
end

---@internal
---@param entry table
---@return string
local function fallback_line(entry)
  local delta_s = math.max(0, (vim.uv.hrtime() / 1e6 - (entry.time_ms or 0)) / 1000)
  return ("[%ds ago] %s"):format(math.floor(delta_s), tostring(entry.content or ""))
end

---Open (or focus, if already open) the recent-messages popup for `filter`.
---@param filter "all"|"non_error"|"error"
---@return nil
function M.show(filter)
  local tag = FILTER_TAG[filter]
  if not tag then
    notify.warn(("recent view: unknown filter %q"):format(tostring(filter)))
    return
  end

  local existing_win = window_tag.find(tag)
  if existing_win then
    vim.api.nvim_set_current_win(existing_win)
    return
  end

  local cfg = require("debugging.views").get_recent_config()
  local messages = require("lib.nvim.messages")
  local levels = FILTER_LEVELS[filter]
  local window_s = cfg.window_s or 10

  local loaded_since_ms = (vim.uv.hrtime() / 1e6) - (window_s * 1000)
  local entries = messages.snapshot({ since_ms = loaded_since_ms, levels = levels })

  local ok_kit, kit = pcall(require, "ui.kit")
  if not ok_kit or type(kit.message_log) ~= "function" then
    local lines = {}
    for _, entry in ipairs(entries) do
      lines[#lines + 1] = fallback_line(entry)
    end
    if #lines == 0 then
      lines = { "(no messages)" }
    end
    local surf = require("lib.nvim.output.viewer").show_lines(FILTER_TITLE[filter], lines)
    if surf then
      window_tag.set(surf.winid, tag, surf.bufnr)
    end
    notify.info("ui.nvim not installed -- showing a static snapshot, no live updates/pagination")
    return
  end

  local handle = kit.message_log({
    title = FILTER_TITLE[filter],
    entries = entries,
    order = cfg.order or "newest_last",
    collapsed_default = cfg.collapsed_default == true,
    load_more = function(direction)
      if direction ~= "older" then
        return {}
      end
      local new_since = loaded_since_ms - (window_s * 1000)
      local older = messages.snapshot({
        since_ms = new_since,
        until_ms = loaded_since_ms - 0.001,
        levels = levels,
      })
      loaded_since_ms = new_since
      return older
    end,
  })
  if not handle then
    return
  end

  window_tag.set(handle.surf.winid, tag, handle.surf.bufnr)

  local unsubscribe
  unsubscribe = messages.on_message(function(entry)
    if level_matches(levels, entry.level) then
      handle:append({ entry })
    end
  end)
  handle:on_close(function()
    messages.off_message(unsubscribe)
  end)
end

return M
