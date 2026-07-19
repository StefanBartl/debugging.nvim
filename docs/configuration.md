# Configuration

Full defaults:

```lua
require("debugging").setup({
  -- Per-category enable flags. `all = true` activates everything.
  features = {
    views        = true,   -- :Debug messages / noice / windows
    reports      = true,   -- :Debug report buf|tab|win
    autocmds     = true,   -- :Debug autocmds runtime|sources
    tools        = true,   -- :Debug inspect|cursor|dump
    terminals    = true,   -- :Debug keylogger
    nvim_options = true,   -- :Debug indent
    markdown     = true,   -- :Debug markdown
    module_reload = true,  -- :Debug module reload
    neotree      = false,  -- :Debug neotree … (config-specific, opt-in)
    proc_trace   = true,   -- :Debug proc start|stop|status|log|watch
    performance  = true,   -- :Debug performance startup
  },
  -- Terminals subsystem (:Debug keylogger).
  terminals = {
    keylogger = {
      logfile = nil,       -- append recorded keys here; nil = notify only.
                           -- `~`/env vars expand; `:Debug keylogger start {path}`
                           -- overrides this per-session.
    },
  },
  -- Neo-tree safety bridge targets (opt-in via features.neotree). Each is a
  -- module name to `require`, or an already-loaded table injected directly —
  -- so the bridge works without the private `config.neotree.*` layout.
  neotree = {
    quarantine = "config.neotree.watcher_quarantine",
    safety     = "config.neotree.safety",
  },
  views = {
    keymaps  = { enable = true, prefix = "<lt>" },
    autocmds = { enable = true, group_name = "DebugViewsAuto", auto_refresh = true },
    timings  = { delay_messages_ms = 30, delay_noice_ms = 50, retry_delay_ms = 60, attempts = 3 },
    capture  = true,
    output_dir = nil,  -- default: stdpath("config")/docs/debug_views
  },
  command = "Debug",   -- name of the single unified command
  overview = "float",  -- how `:Debug` (no args) renders: "float" or "notify"
})

-- Shorthand: enable every category
require("debugging").setup({ all = true })
```
