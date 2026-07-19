-- docs/TESTS/commands_spec.lua
-- Covers the :Debug dispatch layer (debugging.commands): feature gating,
-- unknown category/action handling, argument validation and completion.

return function(H)
  require("debugging").setup({})
  local commands = require("debugging.commands")

  -- Captured notifications, so we can assert on the *reason* a dispatch
  -- refused instead of only on "nothing happened".
  local seen = {}
  local orig_notify = vim.notify
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
    -- ------------------------------------------------------------ dispatch

    -- An unknown category must name the alternatives rather than fail silently.
    reset()
    commands.dispatch({ "nosuchcategory" })
    H.match(last(), "unknown category", "dispatch: unknown category is reported")

    -- Unknown action inside a known category.
    reset()
    commands.dispatch({ "report", "nosuchaction" })
    H.ok(#seen > 0, "dispatch: unknown action is reported")

    -- Case-insensitive category lookup.
    reset()
    commands.dispatch({ "NOSUCHCATEGORY" })
    H.match(last(), "unknown category", "dispatch: category is lowercased")

    -- ------------------------------------------------------ id validation

    -- The regression this suite was written for: a non-numeric id used to
    -- collapse to nil and silently report *all* windows.
    reset()
    commands.dispatch({ "report", "win", "abc" })
    H.match(last(), "invalid window id", "dispatch: non-numeric window id is rejected")

    reset()
    commands.dispatch({ "inspect", "buffer", "abc" })
    H.match(last(), "invalid buffer id", "dispatch: non-numeric buffer id is rejected")

    -- A float is not a handle either.
    reset()
    commands.dispatch({ "inspect", "buffer", "1.5" })
    H.match(last(), "invalid buffer id", "dispatch: fractional buffer id is rejected")

    -- A valid id passes validation (the inspector itself may still notify
    -- about an invalid handle — that is its job, not the parser's).
    reset()
    commands.dispatch({ "inspect", "buffer", "1" })
    H.ok(not last():match("invalid buffer id"), "dispatch: numeric id passes validation")

    -- ---------------------------------------------------------- completion

    -- First token completes categories.
    local cats = commands.complete("", "Debug ", 6)
    H.ok(#cats > 0, "complete: categories offered for the first token")

    -- Second token completes that category's actions.
    local actions = commands.complete("", "Debug report ", 13)
    H.eq_list(actions, { "buf", "tab", "win" }, "complete: report actions")

    -- Prefix filtering applies.
    H.eq_list(commands.complete("w", "Debug report w", 14), { "win" }, "complete: prefix filter")

    -- Unknown category completes to nothing rather than erroring.
    H.eq_list(commands.complete("", "Debug bogus ", 12), {}, "complete: unknown category yields nothing")

    -- `autocmds sources` hands off to the sources completer.
    local src = commands.complete("sort=", "Debug autocmds sources sort=", 28)
    H.ok(#src > 0, "complete: autocmds sources delegates to the sources completer")

    -- `indent treesitter` offers the boolean argument.
    local ts = commands.complete("", "Debug indent treesitter ", 24)
    H.eq_list(ts, { "true", "false" }, "complete: indent treesitter booleans")
  end)

  vim.notify = orig_notify
  if not ok then
    error(err, 0)
  end
end
