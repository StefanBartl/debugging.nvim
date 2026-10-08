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

  -- `inspect buffer` reads a buffer *number* and nothing else (`commands.parse_id`). The stock BUFFER type
  -- completes basenames, which the handler rejects, so the slot has to offer and accept numbers.

  vim.cmd("edit lua/debugging/init.lua")
  local cur_buf = vim.api.nvim_get_current_buf()
  local got_buf = complete("Debug inspect buffer ")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    ok(
      vim.tbl_contains(got_buf, tostring(buf)),
      "Debug inspect buffer offers buffer number " .. buf
    )
  end
  ok(
    not vim.tbl_contains(got_buf, "init.lua"),
    "...and no basename, which the handler would reject"
  )
  ok(
    vim.tbl_contains(complete("Debug inspect buffer " .. cur_buf), tostring(cur_buf)),
    "...narrowed by what is typed"
  )

  local argtypes = require("lib.nvim.bindings.usercmd.composer.argtypes")
  local function accepts(raw)
    return (argtypes.validate(raw, { name = "bufnr", type = "DBG_BUFNR" }))
  end
  ok(accepts(tostring(cur_buf)), "a buffer number is accepted")
  ok(not accepts("init.lua"), "a buffer name is not")
  ok(not accepts("1.5"), "a fractional number is not")
  ok(not accepts("999999"), "a number that is no buffer is not")

  -- End to end: a number reaches the dispatcher with the token the handler reads, a name stops at the
  -- composer with its own message instead of reaching the handler's "invalid buffer id".
  local commands = require("debugging.commands")
  local orig_dispatch, orig_notify = commands.dispatch, vim.notify
  local reached, shown = nil, {}
  -- Test doubles over a module field and a typed `vim.*` field: replacing them is the point of the case.
  ---@diagnostic disable-next-line: duplicate-set-field
  commands.dispatch = function(fargs)
    reached = fargs
  end
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.notify = function(msg)
    shown[#shown + 1] = tostring(msg)
  end
  local ran, run_err = pcall(function()
    vim.cmd("Debug inspect buffer " .. cur_buf)
    eq(table.concat(reached or {}, " "), "inspect buffer " .. cur_buf, "a number is dispatched")

    reached = nil
    vim.cmd("Debug inspect buffer init.lua")
    eq(reached, nil, "a name is not dispatched")
    -- the composer reports through vim.schedule
    vim.wait(1000, function()
      return #shown > 0
    end)
    ok(#shown > 0 and shown[#shown]:find("bufnr", 1, true), "...the composer names the argument")
  end)
  commands.dispatch, vim.notify = orig_dispatch, orig_notify
  if not ran then
    error(run_err, 0)
  end

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
