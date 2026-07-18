# Architecture

```
docs/BINDINGS.md             Cheatsheet: every keymap, :Debug action, autocmd
scripts/watch-nvim-procs.ps1  Bundled external process-tree watcher (Windows)
plugin/debugging.lua          Load guard (vim.g.loaded_debugging)
lua/debugging/
  init.lua                    setup() — feature gating + bindings registration
  @types.lua                  LuaLS type definitions
  config/
    DEFAULTS.lua              Immutable defaults
    init.lua                  Merge + access to active config
  commands.lua                :Debug dispatch + two-level completion (logic only)
  health.lua                  :checkhealth debugging
  bindings/                   Every user-facing trigger — registration only
    @types/init.lua             Dbg.ActionFn, Dbg.Bindings.RegistryEntry
    init.lua                   orchestrates usercmds/keymaps/autocmds/which_key
    usercmds.lua                registers the single :Debug user command
    keymaps.lua                 views subsystem normal-mode keymaps
    autocmds.lua                views subsystem auto-refresh + close-window autocmds
    which_key.lua                optional which-key group label for the prefix
  views/                      messages/Noice capture, display; timings/keymap/autocmd config
  actions/                    action logic invoked by the :Debug dispatcher
    reports.lua               buf/tab/win reports (lib.nvim.buf_win_tab.*)
    module_reload.lua         reload Lua module of the current buffer
    neotree_safety.lua        opt-in Neo-tree bridge (pcall-guarded)
  autocmds/
    @types/init.lua           Dbg.Autocmds.SourceItem/SourceOpts/SourceCache
    runtime.lua               live nvim_get_autocmds view
    sources.lua               static source-code audit (cached per root)
  tools/
    buffer_inspector/         buffer option/state inspection
    cursor/state.lua          cursor/window/buffer state
    vardump/                  recursive Lua value dump
    proc_trace.lua            :Debug proc — freeze diagnosis (delegates to
                              lib.nvim.system.proc_trace; drives the bundled
                              watcher script for `proc watch`)
  terminals/keylogger.lua     terminal keylogger
  nvim_options/indent_helpers.lua   indent diagnostics
  markdown/inline_debug.lua   markdown inline-highlight debug
```

Each leaf module exposes plain action functions; `bindings/usercmds.lua` is
the only place that registers a user command. lib.nvim provides notify,
`buf_win_tab.*`, `fs.*`, `cross`, `lazy`, `normalize`, and `system.proc_trace`.
