-- .testing.lua -- configuration of testing.nvim for this project.
-- Written by `testing migrate`; edit freely (it is never overwritten). Every key is optional; the
-- keys are documented in testing.nvim's docs/CONFIG.md. Loading this file executes it (same trust
-- as running the specs).
return {
  -- Lua module root of the project.
  plugin = "debugging",
  -- How the spec files are run: "auto" = sniffed per file, "h" = on the project's own TESTS/harness.lua,
  -- "script" = a self-running script in its own process.
  dialect = "h",
  -- Dependencies (directory names) put on the runtimepath: $<NAME>_DIR, .deps/<name>, ../<name>,
  -- stdpath('data')/lazy/<name>.
  deps = { "lib.nvim" },
  -- "none" = all specs in one nvim, "file" = one nvim per spec file
  -- (nothing leaks from one file into the next).
  isolated = "file",
  -- Guards (docs/GUARDS.md of testing.nvim): the suite is clean under every one of them with the
  -- per-file isolation above (setup() state, plugin-owned log/capture dirs and the clipboard job
  -- die with the child), so all of them fail the run.
  guards = {
    fs = "error",
    state = "error",
    scheduled_error = "error",
    prompt = "error",
    deprecation = "error",
    process_net = "error",
  },
  -- The keymaps live under views: `views.keymaps = false` (same as `{ enable = false }`) registers none.
  conformance = { keymaps_off = { views = { keymaps = false } } },
  -- Nothing legitimate needs an allowlist: no spec spawns a foreign executable or opens a socket,
  -- and writes below the child's own stdpath() sandbox are not findings.
  guard_allow = { fs = {}, spawn = {}, network = {} },
}
