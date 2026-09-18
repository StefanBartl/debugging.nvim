-- TESTS/health_spec.lua
-- `health.lua` is intentionally NOT given full coverage (see TESTS/README.md
-- "Deliberately left untested") -- it is a declarative :checkhealth reporter
-- whose failure mode is a wrong hint in :checkhealth output, and exercising
-- every branch would mock every external it probes without asserting
-- anything about this plugin's own logic.
--
-- This spec pins two real crashes, both found in a 2026-09-18 re-audit.

---Run `body` with `vim.health.{start,ok,warn,error,info}` captured into a
---list instead of printed, and `require` swapped for `stub_require` for the
---duration -- both restored afterward even if `body` throws.
---@param stub_require fun(orig_require: function, mod: string, ...): any
---@param body fun(seen: {level: string, msg: string, advice: any}[], orig_require: function): nil
local function with_health_capture(stub_require, body)
  local seen = {}
  local fields = { "start", "ok", "warn", "error", "info" }
  local orig_health = {}
  for _, f in ipairs(fields) do
    orig_health[f] = vim.health[f]
    vim.health[f] = function(msg, advice)
      seen[#seen + 1] = { level = f, msg = tostring(msg), advice = advice }
    end
  end

  local orig_require = _G.require
  _G.require = function(mod, ...)
    return stub_require(orig_require, mod, ...)
  end

  local ok, err = pcall(body, seen, orig_require)

  _G.require = orig_require
  for _, f in ipairs(fields) do
    vim.health[f] = orig_health[f]
  end
  if not ok then
    error(err, 0)
  end
end

return function(H)
  -- Scenario 1: `M.check()`'s last section called
  -- `require("lib.nvim.bindings.usercmd.composer").checkhealth("Debug")`
  -- unguarded -- even though the module-resolution section a few lines above
  -- it already probes that exact same module via `check_require(..., "error",
  -- ...)` and would have already reported it missing. If composer really is
  -- unavailable, that bare `require` throws an uncaught Lua error instead of
  -- degrading to the warning already issued, which also means every section
  -- after it (neotree, proc) never runs and :checkhealth shows a raw
  -- traceback instead of a graceful report.
  --
  -- Composer is faked missing by swapping the global `require` for the
  -- duration of the call: both `check_require`'s internal `pcall(require,
  -- mod)` and the composer pre-flight's own `require(...)` resolve `require`
  -- live at call time (neither captures it as an upvalue at module load), so
  -- this reaches both without needing package.loaded gymnastics.
  with_health_capture(function(orig_require, mod, ...)
    if mod == "lib.nvim.bindings.usercmd.composer" then
      error("module '" .. mod .. "' not found (health_spec stub)", 0)
    end
    return orig_require(mod, ...)
  end, function(seen, orig_require)
    local health = orig_require("debugging.health")

    local ok_check, err_check = pcall(health.check)
    H.ok(
      ok_check,
      "check(): composer missing must degrade to the warning already issued, not crash -- got: "
        .. tostring(err_check)
    )

    local found_error, found_warn = false, false
    for _, entry in ipairs(seen) do
      if entry.level == "error" and entry.msg:match("composer") then
        found_error = true
      end
      if entry.level == "warn" and entry.msg:match("composer") then
        found_warn = true
      end
    end
    H.ok(found_error, "check(): module-resolution section still reports composer missing")
    H.ok(found_warn, "check(): composer pre-flight degrades to a warn instead of an uncaught error")
  end)

  -- Scenario 2: `health.lua` used to `require("lib.nvim.health")` at MODULE
  -- LOAD TIME (`local check_require = require("lib.nvim.health").check_require`,
  -- outside `M.check()`), so an older/partial lib.nvim missing just this one
  -- submodule crashed `require("debugging.health")` itself -- before a single
  -- section of the report, including the one meant to explain that lib.nvim
  -- is the problem, ever ran. Fixed by moving the require inside `M.check()`
  -- and falling back to a local copy of the same helper on failure, so every
  -- OTHER section (externals, write permissions, neotree, proc, composer)
  -- keeps reporting normally even when lib.nvim.health specifically can't be
  -- loaded.
  --
  -- `package.loaded["debugging.health"]` is cleared first so this scenario
  -- doesn't just observe scenario 1's already-cached module table --
  -- `require("lib.nvim.health")` now happens inside `M.check()`, not at
  -- module load, so this also verifies the fresh-require actually re-runs.
  with_health_capture(function(orig_require, mod, ...)
    if mod == "lib.nvim.health" then
      error("module '" .. mod .. "' not found (health_spec stub)", 0)
    end
    return orig_require(mod, ...)
  end, function(seen, orig_require)
    package.loaded["debugging.health"] = nil
    local health = orig_require("debugging.health")

    local ok_check, err_check = pcall(health.check)
    H.ok(
      ok_check,
      "check(): lib.nvim.health missing must degrade to a fallback reporter, not crash on require -- got: "
        .. tostring(err_check)
    )

    local found_composer_report = false
    for _, entry in ipairs(seen) do
      if entry.msg:match("composer") then
        found_composer_report = true
      end
    end
    H.ok(
      found_composer_report,
      "check(): the lib.nvim.bindings.usercmd.composer probe still ran via the fallback check_require"
    )
  end)

  package.loaded["debugging.health"] = nil
end
