-- docs/BINDINGS.lua — debugging.nvim binding cheatsheet.
--
-- A single, machine-readable overview of every keymap, user command and
-- autocommand debugging.nvim defines. DOCUMENTATION only: not required at
-- runtime. It mirrors the source of truth:
--   keymaps   — lua/debugging/bindings/keymaps.lua
--   commands  — lua/debugging/bindings/usercmds.lua (registration) +
--               lua/debugging/commands.lua (dispatch/completion logic)
--   autocmds  — lua/debugging/bindings/autocmds.lua
-- If you add or rename a binding there, update the matching entry here.
--
-- Structure:
--   default_keys   — normal-mode keymaps installed by bindings.setup()
--                     (gated by config.views.keymaps.enable, prefix defaults
--                     to "<lt>", i.e. the literal "<" key).
--   commands        — the single :Debug {category} {action} [args] dispatcher.
--                     Categories are gated by config.features.*.
--   autocmds        — registered by bindings.setup() into the
--                     config.views.autocmds.group_name augroup (default
--                     "DebugViewsAuto"), plus the FileType close-window autocmd.

return {
  default_keys = {
    { lhs = "<lt>m", mode = "n", desc = "Show :messages view (auto-refreshing)" },
    { lhs = "<lt>n", mode = "n", desc = "Show Noice all view (auto-refreshing)" },
    { lhs = "<lt>e", mode = "n", desc = "Show Noice errors (:Noice errors)" },
    { lhs = "<lt>c", mode = "n", desc = "Capture :messages to file + clipboard" },
    { lhs = "<lt>x", mode = "n", desc = "Close all debug views windows" },
  },

  commands = {
    debug = {
      { name = "Debug",                                        desc = "Overview of enabled categories" },
      { name = "Debug messages show|capture|clear",             desc = "Show / capture (file+clipboard) / clear :messages views" },
      { name = "Debug noice all|errors",                        desc = "Show all Noice messages / only errors" },
      { name = "Debug report buf|tab|win [id]",                 desc = "Buffer / tab / window report to :messages" },
      { name = "Debug autocmds runtime [event] [pat]",          desc = "Live nvim_get_autocmds() view" },
      { name = "Debug autocmds sources [event=][sort=][impl=][summary=][freq=][root=]", desc = "Static source-code audit of nvim_create_autocmd call sites" },
      { name = "Debug inspect buffer [bufnr]",                  desc = "Inspect buffer-scoped options and state" },
      { name = "Debug cursor state",                            desc = "Print cursor / window / buffer state" },
      { name = "Debug dump [varname]",                          desc = "Recursively dump a global Lua var (or word under cursor)" },
      { name = "Debug keylogger start|stop",                    desc = "Log keys pressed in the current terminal buffer" },
      { name = "Debug indent show",                             desc = "Print indentation-related buffer options" },
      { name = "Debug indent treesitter [true|false]",          desc = "Prefer Tree-sitter indent, or restore with false" },
      { name = "Debug markdown inline",                         desc = "Gather markdown inline-highlight debug info" },
      { name = "Debug markdown log",                            desc = "Open the most recent markdown debug log" },
      { name = "Debug module reload",                           desc = "Reload the Lua module of the current buffer" },
      { name = "Debug neotree status|exit|restart|backup-list|backup-clean|dryrun-toggle|dryrun-report|queue-status|queue-clear",
        desc = "Opt-in Neo-tree safety bridge (needs features.neotree = true)" },
      { name = "Debug health",                                  desc = "Run :checkhealth debugging" },
    },
  },

  autocmds = {
    { event = "WinEnter",     group = "DebugViewsAuto", pattern = "*",                desc = "Auto-refresh an open debug view when re-entering its window" },
    { event = "BufWinEnter",  group = "DebugViewsAuto", pattern = "*",                desc = "Auto-refresh an open debug view when its buffer re-enters a window" },
    { event = "FileType",     group = "DebugViewsAuto", pattern = "messages/noice",   desc = "Bind q / <Esc> to close the debug window" },
  },
}
