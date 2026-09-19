---@module 'debugging.config.DEFAULTS'
--- Immutable default configuration for debugging.nvim.
---
--- Single source of truth. `config/init.lua` deep-merges user options over a copy
--- of this table; it is never mutated at runtime.

---@type Dbg.Config
local DEFAULTS = {
  -- Per-category enable flags. `all = true` activates everything.
  features = {
    views = true, -- :Debug messages / noice / windows
    reports = true, -- :Debug report buf|tab|win
    autocmds = true, -- :Debug autocmds runtime|sources
    tools = true, -- :Debug inspect|cursor|dump
    terminals = true, -- :Debug keylogger
    nvim_options = true, -- :Debug indent
    markdown = true, -- :Debug markdown
    neotree = false, -- :Debug neotree … (config-specific, opt-in)
    neotest = true, -- :Debug neotest adapters|state|file|root|framework|discover
    module_reload = true, -- :Debug module reload
    proc_trace = true, -- :Debug proc start|stop|status|log|watch
    performance = true, -- :Debug performance startup
  },

  -- Terminals subsystem (:Debug keylogger).
  terminals = {
    keylogger = {
      -- Path to append recorded keys to. nil = notify only (no file).
      -- `~` and env vars are expanded. `:Debug keylogger start {path}`
      -- overrides this per-session.
      logfile = nil,
    },
  },

  -- Neo-tree safety bridge (opt-in via features.neotree). Each target is
  -- either a module name to `require`, or an already-loaded table injected
  -- directly — so the bridge works without the private `config.neotree.*`
  -- layout. Defaults keep the original hardcoded module names.
  neotree = {
    quarantine = "config.neotree.watcher_quarantine",
    safety = "config.neotree.safety",
  },

  -- neotest diagnostics (:Debug neotest …). Reads neotest's public state and
  -- the adapter tables from `neotest.setup()`; without neotest every action
  -- degrades to one notification.
  neotest = {
    -- "float" -- scratch float per report (default); "notify" -- one notification
    output = "float",
    -- Files whose presence in a project root / the cwd is worth reporting
    -- (`:Debug neotest root|framework`).
    markers = {
      "package.json",
      "vitest.config.ts",
      "vitest.config.js",
      "vitest.config.mjs",
      "vitest.workspace.ts",
      "jest.config.ts",
      "jest.config.js",
      "jest.config.mjs",
      "tsconfig.json",
      "go.mod",
      "Cargo.toml",
      "pyproject.toml",
      "pytest.ini",
      "setup.cfg",
      "TESTS/run.lua",
    },
    -- Dependency names `:Debug neotest framework` looks for in package.json.
    package_frameworks = { "vitest", "jest", "mocha", "ava", "playwright", "cypress" },
  },

  -- Views subsystem (keymaps, auto-refresh autocmds, capture).
  views = {
    keymaps = { enable = true, prefix = "<lt>" },
    autocmds = { enable = true, group_name = "DebugViewsAuto", auto_refresh = true },
    -- `capture_timeout_ms`: how long to wait for the window a command opens
    -- (:messages, Noice) to appear. Too short on a slow machine and the view
    -- reports "no output" for a command that was merely still rendering.
    timings = {
      delay_messages_ms = 30,
      delay_noice_ms = 50,
      retry_delay_ms = 60,
      attempts = 3,
      capture_timeout_ms = 500,
    },
    capture = true,
    output_dir = nil, -- defaults to stdpath("config")/docs/debug_views inside capture
  },

  command = "Debug", -- name of the single unified user command

  -- How `:Debug` with no arguments renders the category overview:
  --   "float"  -- scrollable floating window (default), q/<Esc> to close
  --   "notify" -- single lib.nvim notification (previous behaviour)
  overview = "float",
}

return DEFAULTS
