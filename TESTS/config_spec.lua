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

  -- A clean setup() reports no issues.
  config.setup({ features = { views = false } })
  H.eq(#config.issues(), 0, "config: valid setup() reports no issues")

  -- Leave a clean default config behind for the specs that run after this one.
  config.setup({})
end
