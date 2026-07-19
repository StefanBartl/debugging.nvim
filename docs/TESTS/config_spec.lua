-- docs/TESTS/config_spec.lua
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
  H.eq(config.get().features.views, DEFAULTS.features.views, "config: setup() re-merges from defaults")

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

  -- Leave a clean default config behind for the specs that run after this one.
  config.setup({})
end
