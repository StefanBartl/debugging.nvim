---@module 'debugging.autocmds.runtime'
---@brief Runtime autocmd inspection via nvim_get_autocmds().
---@description
--- The "live" view: which autocmds are currently registered for an event /
--- pattern. Complements `debugging.autocmds.sources` (static source scan).

local notify = require("lib.nvim.notify").create("[debugging.autocmds.runtime]")

local M = {}

---Report all registered autocommands matching an event and pattern.
---@param event? string   Event to filter by (e.g. "BufAdd"); default "BufAdd"
---@param pattern? string  Pattern to match (e.g. "*"); default "*"
---@return nil
function M.list(event, pattern)
  event = (event and event ~= "") and event or "BufAdd"
  pattern = pattern or "*"

  local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { event = event, pattern = pattern })
  if not ok then
    notify.error(string.format("invalid event %q: %s", event, tostring(autocmds)))
    return
  end

  if #autocmds == 0 then
    notify.info(string.format("No autocommands found for event '%s' with pattern '%s'", event, pattern))
    return
  end

  local lines = { string.format("=== Autocommands for %s %s ===", event, pattern), "" }

  for i, cmd in ipairs(autocmds) do
    lines[#lines + 1] = string.format("[%d] Group: %s", i, cmd.group_name or "default")
    lines[#lines + 1] = string.format("    Event: %s", cmd.event)
    lines[#lines + 1] = string.format("    Pattern: %s", cmd.pattern or "N/A")
    lines[#lines + 1] = string.format("    Buffer: %s", cmd.buffer or "N/A")
    if cmd.command then
      lines[#lines + 1] = string.format("    Command: %s", cmd.command)
    end
    if cmd.callback then
      lines[#lines + 1] = "    Callback: <function>"
    end
    if cmd.desc then
      lines[#lines + 1] = string.format("    Description: %s", cmd.desc)
    end
    lines[#lines + 1] = ""
  end

  notify.info(table.concat(lines, "\n"))
end

return M
