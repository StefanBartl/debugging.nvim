-- TESTS/handle_args_spec.lua
-- Covers the argtypes on the handle-taking :Debug actions.
--
-- These used to share the generic STRING slot, which completed nothing — and
-- a window or buffer id is unguessable, so supplying one meant running
-- `:echo win_getid()` first. What matters here is that each action is wired
-- to the argtype that can actually enumerate its values, and that the ones
-- deliberately left as STRING stay that way.

return function(H)
  local eq, ok = H.eq, H.ok
  require("debugging").setup({})

  ---@param lead string
  ---@return string[]
  local function complete(lead)
    return vim.fn.getcompletion(lead, "cmdline")
  end

  -- ------------------------------------------------------------------ windows

  vim.cmd("vsplit")
  local wins = vim.api.nvim_list_wins()
  ok(#wins >= 2, "fixture: at least two windows are open")

  for _, lead in ipairs({ "Debug report win ", "Debug inspect window " }) do
    local got = complete(lead)
    for _, win in ipairs(wins) do
      ok(vim.tbl_contains(got, tostring(win)), lead .. "offers window id " .. win)
    end
  end

  -- ------------------------------------------------------------------ buffers

  vim.cmd("edit lua/debugging/init.lua")
  local got_buf = complete("Debug inspect buffer ")
  ok(
    vim.tbl_contains(got_buf, "init.lua"),
    "Debug inspect buffer offers a loaded buffer by basename"
  )

  -- --------------------------------------------------------------------- path
  --
  -- The keylogger writes a file that does not exist yet, so what is being
  -- checked is that the *directory* part completes on the way there.

  local got_path = complete("Debug keylogger start ")
  ok(#got_path > 0, "Debug keylogger start completes paths")
  ok(
    vim.tbl_contains(got_path, "lua\\") or vim.tbl_contains(got_path, "lua/"),
    "...including directories, so a path can be typed out"
  )

  -- ------------------------------------------------- deliberately still STRING
  --
  -- `proc` ids and `performance startup` take values this plugin does not
  -- enumerate. A completer there would have nothing true to offer, so the
  -- generic slot is the honest answer rather than an oversight — pinned so a
  -- later change has to be deliberate.

  eq(#complete("Debug performance startup "), 0, "performance startup offers no completion")
end
