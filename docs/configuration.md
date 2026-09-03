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
    -- `capture_timeout_ms`: how long to wait for the window a command opens
    -- (:messages, Noice) to appear. Too short on a slow machine and the view
    -- reports "no output" for a command that was merely still rendering.
    timings  = {
      delay_messages_ms  = 30,
      delay_noice_ms     = 50,
      retry_delay_ms     = 60,
      attempts           = 3,
      capture_timeout_ms = 500,
    },
    capture  = true,
    output_dir = nil,  -- default: stdpath("config")/docs/debug_views
  },
  command = "Debug",   -- name of the single unified command
  overview = "float",  -- how `:Debug` (no args) renders: "float" or "notify"
})

-- Shorthand: enable every category
require("debugging").setup({ all = true })
```

## Views keymaps

`views.keymaps` takes more than `enable` and `prefix`. Every key is declared
through `lib.nvim`'s keymap registry under an action name, and any of those
names can be given a different `lhs` — one string, a list of them, or `false`
to drop the key entirely. `prefix` still supplies the default for every action
left unnamed, so overriding one key no longer means moving all seven.

```lua
require("debugging").setup({
  views = {
    keymaps = {
      enable = true,
      prefix = "<leader>d",  -- supplies the default lhs for every action

      messages          = "<F12>",                -- one explicit lhs
      capture           = { "<leader>dc", "<F9>" },  -- or several
      capture_clipboard = false,                  -- or none at all
      -- noice_all, noice_errors, capture_file and clear keep the
      -- prefix-derived defaults: <leader>dn, <leader>de, <leader>df,
      -- <leader>dx
    },
  },
})
```

The action names are `messages`, `noice_all`, `noice_errors`, `capture`,
`capture_file`, `capture_clipboard` and `clear` — the same names listed in the
[bindings cheatsheet](BINDINGS.md#default-keymaps).
