---@module 'debugging.autocmds.runtime'
---@brief Runtime autocmd inspection via nvim_get_autocmds().
---@description
--- The "live" view: which autocmds are currently registered for an event /
--- pattern. Complements `debugging.autocmds.sources` (static source scan).

local M = {}

---List all registered autocommands matching an event and pattern, to :messages.
---@param event? string   Event to filter by (e.g. "BufAdd"); default "BufAdd"
---@param pattern? string  Pattern to match (e.g. "*"); default "*"
---@return nil
function M.list(event, pattern)
  event = (event and event ~= "") and event or "BufAdd"
  pattern = pattern or "*"

  local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { event = event, pattern = pattern })
  if not ok then
    print(string.format("[debugging.autocmds] invalid event %q: %s", event, tostring(autocmds)))
    return
  end

  if #autocmds == 0 then
    print(string.format("No autocommands found for event '%s' with pattern '%s'", event, pattern))
    return
  end

  print(string.format("\n=== Autocommands for %s %s ===\n", event, pattern))

  for i, cmd in ipairs(autocmds) do
    print(string.format("[%d] Group: %s", i, cmd.group_name or "default"))
    print(string.format("    Event: %s", cmd.event))
    print(string.format("    Pattern: %s", cmd.pattern or "N/A"))
    print(string.format("    Buffer: %s", cmd.buffer or "N/A"))
    if cmd.command then
      print(string.format("    Command: %s", cmd.command))
    end
    if cmd.callback then
      print("    Callback: <function>")
    end
    if cmd.desc then
      print(string.format("    Description: %s", cmd.desc))
    end
    print("")
  end
end

return M
