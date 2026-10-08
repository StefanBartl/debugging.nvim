-- TESTS/commands_spec.lua
-- Covers the :Debug dispatch layer (debugging.commands): feature gating,
-- unknown category/action handling, argument validation and completion.

return function(H)
  require("debugging").setup({})
  local commands = require("debugging.commands")

  -- Captured notifications, so we can assert on the *reason* a dispatch
  -- refused instead of only on "nothing happened".
  local seen = {}
  local orig_notify = vim.notify
  -- A test double over typed `vim.*` surface: replacing the field is the
  -- point of the case, not a second definition of it.
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
    H.eq_list(
      commands.complete("", "Debug bogus ", 12),
      {},
      "complete: unknown category yields nothing"
    )

    -- `autocmds` now offers the combined `all` action too.
    H.eq_list(
      commands.complete("", "Debug autocmds ", 15),
      { "runtime", "sources", "all" },
      "complete: autocmds actions include all"
    )

    -- `autocmds sources` hands off to the sources completer.
    local src = commands.complete("sort=", "Debug autocmds sources sort=", 28)
    H.ok(#src > 0, "complete: autocmds sources delegates to the sources completer")

    -- `autocmds all` delegates to the same completer (root=/refresh=/event=).
    local all = commands.complete("re", "Debug autocmds all re", 21)
    H.ok(#all > 0, "complete: autocmds all delegates to the sources completer")

    -- `inspect` offers buffer/window/tab.
    H.eq_list(
      commands.complete("", "Debug inspect ", 14),
      { "buffer", "window", "tab" },
      "complete: inspect actions"
    )

    -- The window/tab inspectors reject non-numeric handles like buffer does.
    reset()
    commands.dispatch({ "inspect", "window", "abc" })
    H.match(last(), "invalid window id", "dispatch: non-numeric window id rejected")
    reset()
    commands.dispatch({ "inspect", "tab", "abc" })
    H.match(last(), "invalid tab number", "dispatch: non-numeric tab number rejected")

    -- `performance` offers the startup action.
    H.eq_list(
      commands.complete("", "Debug performance ", 18),
      { "startup" },
      "complete: performance actions"
    )

    -- `indent treesitter` offers the boolean argument.
    local ts = commands.complete("", "Debug indent treesitter ", 24)
    H.eq_list(ts, { "true", "false" }, "complete: indent treesitter booleans")
  end)

  -- The key of every `:Debug` route: "<category> <action>", or "<category>" for a free-form
  -- one. The registry lists all categories whatever the feature flags say, so the opt-in ones
  -- (neotree) are covered too.
  ---@return table<string, true>
  local function route_keys()
    local keys = {}
    for category, entry in pairs(require("debugging.commands").registry()) do
      if entry.run.__default then
        keys[category] = true
      else
        for _, action in ipairs(entry.actions) do
          keys[category .. " " .. action] = true
        end
      end
    end
    return keys
  end

  -- Every `:Debug` route carries a description (composer option float, docs), and every
  -- text belongs to a route.
  local ok_desc, err_desc = pcall(function()
    local descs = require("debugging.command_descs")
    local expected = route_keys()
    local bare, dead = {}, {}
    for key in pairs(expected) do
      if not descs[key] then
        bare[#bare + 1] = key
      end
    end
    for key in pairs(descs) do
      if not expected[key] then
        dead[#dead + 1] = key
      end
    end
    table.sort(bare)
    table.sort(dead)
    H.eq(table.concat(bare, ", "), "", "every :Debug route has a description")
    H.eq(table.concat(dead, ", "), "", "command_descs.lua has no entry without a route")
  end)

  -- Every positional argument of a `:Debug` route says what it is in the composer option float.
  -- `command_args.lua` holds them (a route that is not listed there takes no argument), each text
  -- is one line without a closing full stop, and every entry belongs to a route.
  local ok_args, err_args = pcall(function()
    local args = require("debugging.command_args")
    local argtypes = require("lib.nvim.bindings.usercmd.composer.argtypes")
    local expected = route_keys()

    local dead = {}
    for key in pairs(args) do
      if not expected[key] then
        dead[#dead + 1] = key
      end
    end
    table.sort(dead)
    H.eq(table.concat(dead, ", "), "", "command_args.lua has no entry without a route")

    ---@param label string
    ---@param text any
    local function check_text(label, text)
      H.ok(type(text) == "string" and text ~= "", label .. ": has a text")
      if type(text) == "string" then
        H.ok(not text:find("[\r\n]"), label .. ": the text is one line")
        H.ok(not text:find("%.$"), label .. ": the text has no closing full stop")
        H.ok(#text >= 12 and #text <= 80, label .. ": the text is 12 to 80 characters long")
      end
    end
    local texts = 0
    for key, specs in pairs(args) do
      for _, spec in ipairs(specs) do
        local label = ("%s <%s>"):format(key, spec.name)
        -- the type's own text stands in for an argument without one (`autocmds all`)
        local text = spec.desc or argtypes.get(spec.type).desc
        check_text(label, text)
        texts = texts + 1
        for value, value_text in pairs(spec.enum_desc or {}) do
          H.ok(
            vim.tbl_contains(spec.enum or spec.values or {}, value),
            label .. ": enum_desc names '" .. value .. "', which is not one of its values"
          )
          H.ok(
            not value_text:find("%.$") and not value_text:find("[\r\n]"),
            label .. ": enum_desc '" .. value .. "' is one line"
          )
        end
      end
    end
    H.ok(texts >= 10, "command_args.lua carries the arguments of the routes, saw " .. texts)

    -- The routes the command was built from carry exactly these slots and texts. The checks above
    -- read the files, and `undocumented` below only sees slots that exist, so a route that lost its
    -- slot or its text in `usercmds.build_routes` would otherwise ship green.
    local composer = require("lib.nvim.bindings.usercmd.composer")
    local descs = require("debugging.command_descs")
    local built = {}
    for _, route in ipairs(composer.registry().Debug:spec().routes) do
      local key = table.concat(route.path, " ")
      built[key] = true
      H.eq(route.desc, descs[key], key .. ": the route carries its description")
      if args[key] then
        H.ok(
          vim.deep_equal(route.args, args[key]),
          key .. ": the route carries the slots of command_args.lua"
        )
      else
        H.eq(route.args, nil, key .. ": the route takes no slot")
      end
    end
    -- a listed route of an enabled category exists, so the loop above cannot pass by seeing nothing
    local registry = commands.registry()
    for key in pairs(args) do
      if commands.enabled(registry[key:match("^%S+")]) then
        H.ok(built[key], key .. ": the route is built")
      end
    end

    -- A token beyond a route's slots still reaches the dispatcher, which ignores what it does not read.
    H.ok(built["messages show"], "fixture: messages show is a built route")
    local orig_dispatch, reached = commands.dispatch, nil
    -- A test double over a module field: replacing it is the point of the case.
    ---@diagnostic disable-next-line: duplicate-set-field
    commands.dispatch = function(fargs)
      reached = fargs
    end
    local ran, run_err = pcall(vim.cmd, "Debug messages show foo")
    commands.dispatch = orig_dispatch
    H.ok(ran, "a stray token does not fail the command: " .. tostring(run_err))
    H.eq(
      table.concat(reached or {}, " "),
      "messages show foo",
      "a stray token is dispatched as typed"
    )

    -- A lib.nvim older than `help.undocumented` cannot answer the question; that is a missing
    -- feature of the dependency, not a defect of this plugin.
    if type(composer.help.undocumented) ~= "function" then
      return
    end
    local missing = {}
    for _, m in ipairs(composer.help.undocumented("Debug", { args = true })) do
      missing[#missing + 1] = ("%s <%s>"):format(m.route, m.name)
    end
    H.eq(table.concat(missing, ", "), "", "every :Debug argument has a help text")
  end)

  vim.notify = orig_notify
  if not ok then
    error(err, 0)
  end
  if not ok_desc then
    error(err_desc, 0)
  end
  if not ok_args then
    error(err_args, 0)
  end
end
