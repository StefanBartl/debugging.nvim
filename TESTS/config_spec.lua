-- TESTS/config_spec.lua
-- Covers debugging.config: DEFAULTS merging, user overrides and the
-- feature flags the dispatch layer gates on.

return function(H)
  local config = require("debugging.config")
  local DEFAULTS = require("debugging.config.DEFAULTS")

  -- Setup with no user table yields the defaults verbatim.
  config.setup({})
  local base = config.get()
  H.ok(type(base) == "table", "config: get() returns a table")
  H.ok(type(base.features) == "table", "config: features present after empty setup")

  for name, want in pairs(DEFAULTS.features) do
    H.eq(base.features[name], want, "config: default feature " .. name)
  end

  -- A partial user table overrides only the keys it names; sibling keys in
  -- the same nested table survive the merge.
  config.setup({ features = { views = false } })
  local merged = config.get()
  H.eq(merged.features.views, false, "config: user override applied")
  H.eq(merged.features.tools, DEFAULTS.features.tools, "config: sibling feature keeps its default")

  -- Re-running setup starts from the defaults again rather than accumulating
  -- the previous run's overrides.
  config.setup({})
  H.eq(
    config.get().features.views,
    DEFAULTS.features.views,
    "config: setup() re-merges from defaults"
  )

  -- Back-compat: `all = true` turns on every category, including the ones
  -- that are opt-in by default (neotree).
  H.eq(DEFAULTS.features.neotree, false, "config: neotree is opt-in by default")
  config.setup({ all = true })
  for name in pairs(DEFAULTS.features) do
    H.eq(config.get().features[name], true, "config: all=true enables " .. name)
  end

  -- The DEFAULTS table itself must survive every merge — it is documented as
  -- immutable and shared by reference across setup() calls.
  H.eq(DEFAULTS.features.neotree, false, "config: DEFAULTS not mutated by all=true")

  -- A misspelled top-level key is dropped, not silently merged in -- and does
  -- not affect any sibling key.
  config.setup({ feature = { neotree = true } })
  H.eq(config.get().features.neotree, false, "config: typo'd top-level key does not apply")
  local issues = config.issues()
  H.eq(#issues, 1, "config: typo'd top-level key recorded one issue")
  H.match(issues[1], "unknown option 'feature'", "config: issue names the bad key")
  H.match(issues[1], "did you mean 'features'", "config: issue hints the nearest known key")

  -- A misspelled key nested one level in is dropped the same way; the rest of
  -- that table's keys still apply.
  config.setup({ views = { timing = { attempts = 5 }, capture = false } })
  H.eq(
    config.get().views.timings.attempts,
    DEFAULTS.views.timings.attempts,
    "config: typo'd nested key does not apply"
  )
  H.eq(config.get().views.capture, false, "config: sibling key in the same table still applies")
  H.match(config.issues()[1], "unknown option 'views.timing'", "config: nested issue is prefixed")

  -- A misspelled key nested two levels in (inside an option group that is
  -- itself nested, e.g. views.timings.*) is caught the same way, not merged
  -- in as a dead field beside the untouched default (ERR-50).
  config.setup({ views = { timings = { attempt = 5 } } })
  H.eq(
    config.get().views.timings.attempts,
    DEFAULTS.views.timings.attempts,
    "config: typo'd twice-nested key does not apply"
  )
  H.ok(
    config.get().views.timings.attempt == nil,
    "config: typo'd twice-nested key is not silently carried into the active config"
  )
  H.match(
    config.issues()[1],
    "unknown option 'views.timings.attempt'",
    "config: twice-nested issue carries the full dotted path"
  )
  H.match(
    config.issues()[1],
    "did you mean 'views.timings.attempts'",
    "config: twice-nested issue hints the nearest known key"
  )

  -- An option table given as the wrong type falls back to its default
  -- instead of replacing the whole table (which would break every reader
  -- that indexes straight into it, e.g. views.keymaps.enable).
  config.setup({ views = "nope" })
  H.eq(
    config.get().views.keymaps.enable,
    true,
    "config: mistyped option table falls back to default"
  )
  H.match(config.issues()[1], "option 'views' must be a table", "config: type mismatch recorded")

  -- `views.keymaps = false` / `views.autocmds = false` mean { enable = false }
  -- (REL-20); `true` keeps the defaults; the caller's table is not touched.
  local given = { views = { keymaps = false, autocmds = true } }
  config.setup(given)
  H.eq(config.get().views.keymaps.enable, false, "config: keymaps = false switches the keymaps off")
  H.eq(config.get().views.autocmds.enable, true, "config: autocmds = true keeps the defaults")
  H.eq(config.get().views.keymaps.prefix, "<lt>", "config: the switch keeps the other defaults")
  H.eq(given.views.keymaps, false, "config: the caller's table is left as written")
  H.eq(#config.issues(), 0, "config: a boolean switch group is no issue")

  -- End to end: with the switch off, the bindings register no keymap at all.
  require("debugging.views").setup(config.get().views)
  local before = #vim.api.nvim_get_keymap("n")
  require("debugging.bindings").setup(config.get())
  H.eq(#vim.api.nvim_get_keymap("n"), before, "config: keymaps = false registers no keymap")

  -- Per-action keymap overrides (docs/configuration.md, "Views keymaps"): a key per action name,
  -- an lhs, a list of them, or `false`. They used to be reported as unknown options and dropped,
  -- because the schema knew `enable` and `prefix` only -- the keymap registry that consumes them
  -- never saw one. The example is the one the documentation shows.
  local actions = require("debugging.config.KEYMAP_ACTIONS")
  config.setup({
    views = {
      keymaps = {
        enable = true,
        prefix = "<leader>d",
        messages = "<F12>",
        capture = { "<leader>dc", "<F9>" },
        capture_clipboard = false,
      },
    },
  })
  local km = config.get().views.keymaps
  H.eq(#config.issues(), 0, "config: the documented keymap action keys are no issue")
  H.eq(km.prefix, "<leader>d", "config: prefix is kept beside the action keys")
  H.eq(km.messages, "<F12>", "config: an lhs for one action reaches the merged config")
  H.eq_list(km.capture, { "<leader>dc", "<F9>" }, "config: a list of lhs for one action is kept")
  H.eq(km.capture_clipboard, false, "config: false (no key for this action) is kept")
  H.eq(km.noice_all, nil, "config: an action that was not named is not invented")

  -- Every action name is accepted, with each of the three value shapes.
  for _, action in ipairs(actions) do
    for _, value in ipairs({ "<F5>", { "<F5>", "<F6>" }, false }) do
      config.setup({ views = { keymaps = { [action] = value } } })
      H.eq(
        #config.issues(),
        0,
        "config: views.keymaps." .. action .. " = " .. vim.inspect(value) .. " is accepted"
      )
    end
  end

  -- A mistyped action name is still reported, with the nearest real one.
  config.setup({ views = { keymaps = { mesages = "<F12>" } } })
  H.eq(config.get().views.keymaps.mesages, nil, "config: a mistyped action key does not apply")
  H.match(
    config.issues()[1],
    "unknown option 'views.keymaps.mesages'",
    "config: a mistyped action key is reported with its full path"
  )
  H.match(
    config.issues()[1],
    "did you mean 'views.keymaps.messages'",
    "config: a mistyped action key hints the nearest action"
  )

  -- The list the schema reads and the actions the keymap registry declares are the same set, in
  -- both directions: an action added to bindings/keymaps.lua without its name in the list (the
  -- state in which an override of it is dropped as unknown) fails here.
  config.setup({
    views = { keymaps = { enable = true, prefix = "<leader>d", messages = "<F12>", clear = false } },
  })
  require("debugging.views").setup(config.get().views)
  local bound =
    require("debugging.bindings.keymaps").setup(require("debugging.views").get_keymaps_config())
  local declared, lhs_of = {}, {}
  for _, entry in ipairs(bound) do
    declared[entry.name] = true
    if entry.lhs then
      lhs_of[entry.name] = lhs_of[entry.name] or {}
      table.insert(lhs_of[entry.name], entry.lhs)
      pcall(vim.keymap.del, entry.mode, entry.lhs)
    end
  end
  local listed = {}
  for _, action in ipairs(actions) do
    listed[action] = true
    H.ok(declared[action], "config: action '" .. action .. "' is declared by bindings.keymaps")
  end
  for name in pairs(declared) do
    H.ok(listed[name], "config: declared action '" .. name .. "' is in KEYMAP_ACTIONS")
  end
  H.eq_list(lhs_of.messages, { "<F12>" }, "config: the override reaches the keymap registry")
  H.eq(lhs_of.clear, nil, "config: clear = false binds no key for that action")
  H.eq_list(lhs_of.noice_all, { "<leader>dn" }, "config: an unnamed action keeps its prefix key")

  -- A clean setup() reports no issues.
  config.setup({ features = { views = false } })
  H.eq(#config.issues(), 0, "config: valid setup() reports no issues")

  -- Leave a clean default config behind for the specs that run after this one.
  config.setup({})
end
