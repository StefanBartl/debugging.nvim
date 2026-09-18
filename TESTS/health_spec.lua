-- TESTS/health_spec.lua
-- `health.lua` is intentionally NOT given full coverage (see TESTS/README.md
-- "Deliberately left untested") -- it is a declarative :checkhealth reporter
-- whose failure mode is a wrong hint in :checkhealth output, and exercising
-- every branch would mock every external it probes without asserting
-- anything about this plugin's own logic.
--
-- This spec covers exactly one thing: a real crash found in a 2026-09-18
-- re-audit. `M.check()`'s last section called
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

return function(H)
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
    if mod == "lib.nvim.bindings.usercmd.composer" then
      error("module '" .. mod .. "' not found (health_spec stub)", 0)
    end
    return orig_require(mod, ...)
  end

  local ok, err = pcall(function()
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

  _G.require = orig_require
  for _, f in ipairs(fields) do
    vim.health[f] = orig_health[f]
  end
  if not ok then
    error(err, 0)
  end
end
