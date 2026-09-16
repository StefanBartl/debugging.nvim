-- TESTS/autocmds_runtime_spec.lua
-- Covers `debugging.autocmds.runtime` (the "live" nvim_get_autocmds() view,
-- as opposed to sources.lua's static source scan): event/pattern defaulting,
-- the empty-result and invalid-event branches, and that the report actually
-- reflects group/command/desc/callback fields of a real registered autocmd.

return function(H)
  local runtime = require("debugging.autocmds.runtime")

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
    local group = vim.api.nvim_create_augroup("DebuggingRuntimeSpec", { clear = true })

    -- No autocmds registered for this event/pattern combo: reported, not silent.
    reset()
    runtime.list("User", "NoSuchDebuggingRuntimeSpecPattern")
    H.match(last(), "No autocommands found", "runtime.list: empty result is reported")

    -- A real autocmd with a command, a desc, and a plain pattern shows up
    -- with every field rendered.
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "DebuggingRuntimeSpecEvent",
      command = "echo 'spec'",
      desc = "spec fixture",
    })
    reset()
    runtime.list("User", "DebuggingRuntimeSpecEvent")
    H.match(last(), "Group: DebuggingRuntimeSpec", "runtime.list: reports the owning group")
    H.match(last(), "Event: User", "runtime.list: reports the event")
    H.match(last(), "Pattern: DebuggingRuntimeSpecEvent", "runtime.list: reports the pattern")
    H.match(last(), "Command: echo 'spec'", "runtime.list: reports the command")
    H.match(last(), "Description: spec fixture", "runtime.list: reports the desc")

    -- A callback-backed autocmd is labelled distinctly from a command one.
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "DebuggingRuntimeSpecCallback",
      callback = function() end,
    })
    reset()
    runtime.list("User", "DebuggingRuntimeSpecCallback")
    H.match(last(), "Callback: <function>", "runtime.list: callback-backed autocmd is labelled")

    -- Default event/pattern when both are omitted (empty string counts as
    -- omitted too, matching the composer's optional-arg convention).
    reset()
    local ok_default = pcall(runtime.list, "", nil)
    H.ok(ok_default, "runtime.list: default event/pattern do not error")
    H.match(last(), "BufAdd", "runtime.list: defaults to the BufAdd event")
    H.match(last(), "'%*'", "runtime.list: defaults to the '*' pattern")

    -- An event name Neovim rejects outright is reported as an error, not raised.
    reset()
    local ok_invalid = pcall(runtime.list, "Not A Valid Event Name", "*")
    H.ok(ok_invalid, "runtime.list: an invalid event name does not raise")
    H.ok(#seen > 0, "runtime.list: an invalid event name is still reported to the user")

    vim.api.nvim_del_augroup_by_id(group)
  end)

  vim.notify = orig_notify
  if not ok then
    error(err, 0)
  end
end
